import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/storage_keys.dart';
import '../di/injection.dart';
import '../storage/hive_service.dart';
import 'tile_math.dart';

/// Progress snapshot emitted while [TileCacheService.downloadRegion] runs.
class TileDownloadProgress {
  const TileDownloadProgress({
    required this.downloadedTiles,
    required this.totalTiles,
    required this.downloadedBytes,
  });

  final int downloadedTiles;
  final int totalTiles;
  final int downloadedBytes;

  double get fraction => totalTiles == 0 ? 0 : downloadedTiles / totalTiles;
}

/// Thrown by [TileCacheService.downloadJobs] when too many tiles fail in a
/// row (e.g. the connection was actually a captive portal, or dropped
/// mid-download) — so the caller can stop instead of grinding through the
/// remaining tiles one slow timeout at a time.
class TileDownloadNetworkLostException implements Exception {
  const TileDownloadNetworkLostException();
}

/// One region to pre-download — e.g. the whole-city region, or the
/// high-detail area around the user's current location. Several jobs can be
/// combined into a single download (see [TileCacheService.downloadJobs]) so
/// the user only sees one dialog / one progress bar / one size estimate,
/// even though internally two differently-scoped regions are being fetched.
class TileDownloadJob {
  const TileDownloadJob({
    required this.regionId,
    required this.center,
    required this.radiusMeters,
    required this.minZoom,
    required this.maxZoom,
    this.checkFreshness = true,
  });

  final String regionId;
  final LatLng center;
  final double radiusMeters;
  final int minZoom;
  final int maxZoom;

  /// See [TileCacheService.shouldPromptDownload].
  final bool checkFreshness;
}

/// Map tile cache: 30 kunlik offline saqlash.
/// App ishga tushganda `init()` chaqiriladi.
///
/// Ikki xil kesh mavjud:
/// - Passiv kesh: foydalanuvchi xaritada yurgan sari ko'rilgan tayllar
///   avtomatik saqlanadi (`build`).
/// - Faol yuklab olish: `downloadJobs` orqali bir yoki bir nechta hudud
///   (kichik — joriy joylashuv atrofi, yoki katta — butun shahar) bitta
///   umumiy yuklashda birlashtirib, oldindan (internet bo'lganda) to'liq
///   yuklab olinadi, shunda internet uzilganda ham o'sha hudud(lar) ichida
///   erkin harakatlanish mumkin. Har bir hudud o'zining `regionId`si bilan
///   kuzatiladi (qachon yuklab olingani / rad etilgani).
class TileCacheService {
  TileCacheService._();

  static HiveCacheStore? _store;
  static final Dio _dio = Dio()
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 30);

  // Bitta marta yaratiladi — har bir `build()` chaqiruvida yangi
  // CachedTileProvider yaratilsa, u `_dio`ga yana bitta cache interceptor
  // qo'shib qo'yardi (widget har rebuild bo'lganda) va ular jamlanib borardi.
  static CachedTileProvider? _onlineProvider;
  static CachedTileProvider? _offlineProvider;

  // Fonda hudud yuklab olish uchun alohida Dio: qisqaroq timeout bilan,
  // shunda tarmoq uzilib qolsa har bir tayl uchun 10s emas, tezroq
  // (fail-fast) bilinadi. Bir xil `_store`ga yozgani uchun natija baribir
  // asosiy `_dio` orqali (xarita ko'rilganda) keshdan o'qiladi.
  static Dio? _bulkDio;

  /// Increments every time [clearCache] runs, so already-mounted map
  /// widgets (e.g. the map behind an open drawer) can notice and re-offer
  /// the offline-download prompt without needing to be remounted.
  static final ValueNotifier<int> cacheVersion = ValueNotifier<int>(0);

  static const _regionFreshDuration = Duration(days: 25);
  static const _declineCooldown = Duration(days: 3);
  static const _avgTileBytes = 20 * 1024; // taxminiy: bitta tayl ~20 KB
  static const _bulkConcurrency = 6;
  static const _maxConsecutiveFailures = 8;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _store = HiveCacheStore('${dir.path}/tile_cache');
  }

  static TileProvider build({bool isOnline = true}) {
    final store = _store;
    if (store == null) return NetworkTileProvider();
    if (isOnline) {
      return _onlineProvider ??= CachedTileProvider(
        dio: _dio,
        store: store,
        // Onlaynda yangilaydi
        cachePolicy: CachePolicy.request,
        maxStale: const Duration(days: 30),
        hitCacheOnErrorExcept: const [401, 403],
      );
    }
    return _offlineProvider ??= CachedTileProvider(
      dio: _dio,
      store: store,
      // Oflaynda keshdan darhol qaytaradi
      cachePolicy: CachePolicy.forceCache,
      maxStale: const Duration(days: 30),
      hitCacheOnErrorExcept: const [401, 403],
    );
  }

  /// Taxminiy umumiy tayl soni va hajmi (baytlarda) — bir nechta [jobs]
  /// birlashtirilganda ikkalasiga umumiy tushadigan tayllar (masalan shahar
  /// va joy-darajasi hududlari kesishgan zoom'larda) ikki marta hisoblanmaydi.
  static ({int tileCount, int estimatedBytes}) estimateJobs(List<TileDownloadJob> jobs) {
    final count = _combinedTiles(jobs).length;
    return (tileCount: count, estimatedBytes: count * _avgTileBytes);
  }

  /// Bir nechta hududni ([jobs]) bitta umumiy yuklashda birlashtirib
  /// oldindan yuklab, keshga yozadi va har biri tugagach o'z `regionId`sini
  /// "yuklab olindi" deb belgilaydi. Ikkala hudud kesishgan joylardagi
  /// tayllar faqat bir marta yuklanadi (dublikat qilinmaydi). Tezlik uchun
  /// bir nechtasi baravariga ([_bulkConcurrency]) yuklanadi.
  ///
  /// [cancelToken] bekor qilinsa, joriy partiyadan keyin darhol to'xtaydi va
  /// hech qaysi [jobs] "yuklab olindi" deb belgilanmaydi. Agar ketma-ket ko'p
  /// tayl yuklanmasa (masalan, internet aslida ishlamayotgan bo'lsa — Wi-Fi
  /// ulangan-u lekin tarmoq yo'q), [TileDownloadNetworkLostException]
  /// tashlanadi va qolgan yuzlab tayllarni birma-bir kutib o'tirmaydi.
  static Stream<TileDownloadProgress> downloadJobs({
    required List<TileDownloadJob> jobs,
    required String urlTemplate,
    required List<String> subdomains,
    required bool retina,
    CancelToken? cancelToken,
  }) async* {
    final dio = _ensureBulkDio();
    final tiles = _combinedTiles(jobs);
    final total = tiles.length;

    var downloaded = 0;
    var bytes = 0;
    var consecutiveFailures = 0;
    yield TileDownloadProgress(downloadedTiles: 0, totalTiles: total, downloadedBytes: 0);

    for (var i = 0; i < total; i += _bulkConcurrency) {
      if (cancelToken?.isCancelled ?? false) return;

      final batch = tiles.sublist(i, (i + _bulkConcurrency).clamp(0, total));
      final List<int?> results;
      try {
        results = await Future.wait([
          for (final tile in batch)
            _fetchTile(
              dio: dio,
              tile: tile,
              urlTemplate: urlTemplate,
              subdomains: subdomains,
              retina: retina,
              cancelToken: cancelToken,
            ),
        ]);
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) return;
        rethrow;
      }

      for (final tileBytes in results) {
        downloaded++;
        if (tileBytes == null) {
          consecutiveFailures++;
        } else {
          consecutiveFailures = 0;
          bytes += tileBytes;
        }
      }

      yield TileDownloadProgress(
        downloadedTiles: downloaded,
        totalTiles: total,
        downloadedBytes: bytes,
      );

      if (consecutiveFailures >= _maxConsecutiveFailures) {
        throw const TileDownloadNetworkLostException();
      }
    }

    for (final job in jobs) {
      await _markRegionDownloaded(job.regionId);
    }
  }

  static List<TileCoord> _combinedTiles(List<TileDownloadJob> jobs) {
    final seen = <String>{};
    final tiles = <TileCoord>[];
    for (final job in jobs) {
      for (final tile in TileMath.tilesForRegion(
        center: job.center,
        radiusMeters: job.radiusMeters,
        minZoom: job.minZoom,
        maxZoom: job.maxZoom,
      )) {
        if (seen.add('${tile.z}/${tile.x}/${tile.y}')) tiles.add(tile);
      }
    }
    return tiles;
  }

  /// Fetches a single tile; returns its byte size, or `null` on failure.
  /// Rethrows [DioException] on user cancellation so the batch can stop
  /// immediately instead of masking it as an ordinary failed tile.
  static Future<int?> _fetchTile({
    required Dio dio,
    required TileCoord tile,
    required String urlTemplate,
    required List<String> subdomains,
    required bool retina,
    CancelToken? cancelToken,
  }) async {
    final url = TileMath.buildTileUrl(
      urlTemplate: urlTemplate,
      subdomains: subdomains,
      coord: tile,
      retina: retina,
    );
    try {
      final response = await dio.get<List<int>>(
        url,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'User-Agent': 'flutter_map (uz.dala.nazorati)'},
        ),
      );
      return response.data?.length ?? 0;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return null;
    }
  }

  static Dio _ensureBulkDio() {
    final dio = _bulkDio;
    if (dio != null) return dio;
    final created = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        sendTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 8),
      ),
    )..interceptors.add(
        DioCacheInterceptor(
          options: CacheOptions(
            store: _store!,
            policy: CachePolicy.request,
            maxStale: const Duration(days: 30),
            hitCacheOnErrorExcept: const [401, 403],
          ),
        ),
      );
    return _bulkDio = created;
  }

  /// Foydalanuvchiga [regionId] hududini oflayn yuklab olishni taklif qilish
  /// kerakmi? Internet yo'q bo'lsa, hudud yaqinda yuklab olingan (yoki
  /// [checkFreshness]=false bo'lsa — umuman bir marta yuklab olingan) yoki
  /// foydalanuvchi yaqinda rad etgan bo'lsa — taklif qilinmaydi.
  ///
  /// [checkFreshness]=false — kengroq (viloyat darajasidagi) bir martalik
  /// yuklab olishlar uchun: muddat tugashi tekshirilmaydi, faqat "hali
  /// umuman yuklab olinmaganmi" tekshiriladi.
  static bool shouldPromptDownload(
    String regionId, {
    required bool isOnline,
    bool checkFreshness = true,
  }) {
    if (!isOnline) return false;
    if (_isRegionDownloaded(regionId, checkFreshness: checkFreshness)) return false;
    if (_wasRecentlyDeclined(regionId)) return false;
    return true;
  }

  static Future<void> markRegionDeclined(String regionId) async {
    await getIt<HiveService>().userBox.put(
          '${StorageKeys.mapRegionDeclinedPrefix}$regionId',
          DateTime.now().millisecondsSinceEpoch,
        );
  }

  static Future<void> _markRegionDownloaded(String regionId) async {
    await getIt<HiveService>().userBox.put(
          '${StorageKeys.mapRegionDownloadedPrefix}$regionId',
          DateTime.now().millisecondsSinceEpoch,
        );
  }

  static bool _isRegionDownloaded(String regionId, {required bool checkFreshness}) {
    final savedAt = getIt<HiveService>().userBox.get(
          '${StorageKeys.mapRegionDownloadedPrefix}$regionId',
        ) as int?;
    if (savedAt == null) return false;
    if (!checkFreshness) return true;
    final downloadedAt = DateTime.fromMillisecondsSinceEpoch(savedAt);
    return DateTime.now().difference(downloadedAt) < _regionFreshDuration;
  }

  static bool _wasRecentlyDeclined(String regionId) {
    final declinedAt = getIt<HiveService>().userBox.get(
          '${StorageKeys.mapRegionDeclinedPrefix}$regionId',
        ) as int?;
    if (declinedAt == null) return false;
    final at = DateTime.fromMillisecondsSinceEpoch(declinedAt);
    return DateTime.now().difference(at) < _declineCooldown;
  }

  /// ~111m aniqlikda yaxlitlangan joylashuv-hudud kaliti (dala darajasidagi
  /// yuqori tafsilotli kesh uchun) — bitta joy uchun bir xil kalit chiqishi
  /// kerak, lekin turli joylar uchun turlicha.
  static String locationRegionId(LatLng center) =>
      '${center.latitude.toStringAsFixed(3)}_${center.longitude.toStringAsFixed(3)}';

  /// ~11km aniqlikda yaxlitlangan hudud kaliti (viloyat darajasidagi keng
  /// qamrovli kesh uchun) — shu radius ichida harakatlanish qayta-qayta
  /// so'ralishiga sabab bo'lmaydi, lekin boshqa (hali qamrab olinmagan)
  /// hududga o'tilsa, yangi so'rov chiqadi.
  static String regionalRegionId(LatLng center) =>
      'region_${center.latitude.toStringAsFixed(1)}_${center.longitude.toStringAsFixed(1)}';

  /// Yuklab olingan barcha xarita tayllarining umumiy hajmi (baytlarda).
  static Future<int> cacheSizeBytes() async {
    final store = _store;
    if (store == null) return 0;
    final responses = await store.getFromPath(RegExp('.*'));
    var total = 0;
    for (final response in responses) {
      total += response.content?.length ?? 0;
    }
    return total;
  }

  /// Butun tayl keshini (yuklab olingan hamda passiv keshlangan barcha
  /// tayllarni) va "yuklab olindi/rad etildi" belgilarini tozalaydi.
  static Future<void> clearCache() async {
    await _store?.clean();
    final box = getIt<HiveService>().userBox;
    final keysToRemove = box.keys.where(
      (key) =>
          key is String &&
          (key.startsWith(StorageKeys.mapRegionDownloadedPrefix) ||
              key.startsWith(StorageKeys.mapRegionDeclinedPrefix)),
    );
    await box.deleteAll(keysToRemove);
    cacheVersion.value++;
  }
}

/// Formats a byte count as a human-readable MB string (e.g. `"8.6 MB"`).
String formatMapCacheSize(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}
