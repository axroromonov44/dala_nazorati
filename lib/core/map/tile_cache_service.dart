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

class TileDownloadNetworkLostException implements Exception {
  const TileDownloadNetworkLostException();
}

class TileDownloadJob {
  const TileDownloadJob({
    required this.regionId,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    this.checkFreshness = true,
  });

  final String regionId;
  final LatLngBounds bounds;
  final int minZoom;
  final int maxZoom;

  final bool checkFreshness;
}

class TileCacheService {
  TileCacheService._();

  static HiveCacheStore? _store;
  static final Dio _dio = Dio()
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 30);

  static CachedTileProvider? _onlineProvider;
  static CachedTileProvider? _offlineProvider;

  static Dio? _bulkDio;

  static final ValueNotifier<int> cacheVersion = ValueNotifier<int>(0);

  static const _regionFreshDuration = Duration(days: 25);
  static const _declineCooldown = Duration(days: 3);
  static const _avgTileBytes =
      20 * 1024;
  static const _retinaSizeMultiplier = 3;
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
        cachePolicy: CachePolicy.request,
        maxStale: const Duration(days: 30),
        hitCacheOnErrorExcept: const [401, 403],
      );
    }
    return _offlineProvider ??= CachedTileProvider(
      dio: _dio,
      store: store,
      cachePolicy: CachePolicy.forceCache,
      maxStale: const Duration(days: 30),
      hitCacheOnErrorExcept: const [401, 403],
    );
  }

  static ({int tileCount, int estimatedBytes}) estimateJobs(
    List<TileDownloadJob> jobs, {
    bool retina = false,
  }) {
    final count = _combinedTiles(jobs).length;
    final perTileBytes = retina
        ? _avgTileBytes * _retinaSizeMultiplier
        : _avgTileBytes;
    return (tileCount: count, estimatedBytes: count * perTileBytes);
  }

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
    yield TileDownloadProgress(
      downloadedTiles: 0,
      totalTiles: total,
      downloadedBytes: 0,
    );

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
      for (final tile in TileMath.tilesForBounds(
        bounds: job.bounds,
        minZoom: job.minZoom,
        maxZoom: job.maxZoom,
      )) {
        if (seen.add('${tile.z}/${tile.x}/${tile.y}')) tiles.add(tile);
      }
    }
    return tiles;
  }

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
    final created =
        Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              sendTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
            ),
          )
          ..interceptors.add(
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

  static bool shouldPromptDownload(
    String regionId, {
    required bool isOnline,
    bool checkFreshness = true,
  }) {
    if (!isOnline) return false;
    if (_isRegionDownloaded(regionId, checkFreshness: checkFreshness)) {
      return false;
    }
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

  static bool _isRegionDownloaded(
    String regionId, {
    required bool checkFreshness,
  }) {
    final savedAt =
        getIt<HiveService>().userBox.get(
              '${StorageKeys.mapRegionDownloadedPrefix}$regionId',
            )
            as int?;
    if (savedAt == null) return false;
    if (!checkFreshness) return true;
    final downloadedAt = DateTime.fromMillisecondsSinceEpoch(savedAt);
    return DateTime.now().difference(downloadedAt) < _regionFreshDuration;
  }

  static bool _wasRecentlyDeclined(String regionId) {
    final declinedAt =
        getIt<HiveService>().userBox.get(
              '${StorageKeys.mapRegionDeclinedPrefix}$regionId',
            )
            as int?;
    if (declinedAt == null) return false;
    final at = DateTime.fromMillisecondsSinceEpoch(declinedAt);
    return DateTime.now().difference(at) < _declineCooldown;
  }

  static String locationRegionId(LatLng center) =>
      '${center.latitude.toStringAsFixed(3)}_${center.longitude.toStringAsFixed(3)}';

  static String regionalRegionId(LatLng center) =>
      'region_${center.latitude.toStringAsFixed(1)}_${center.longitude.toStringAsFixed(1)}';

  static String assignedFieldsRegionId(LatLngBounds bounds) =>
      'fields_'
      '${bounds.south.toStringAsFixed(2)}_${bounds.west.toStringAsFixed(2)}_'
      '${bounds.north.toStringAsFixed(2)}_${bounds.east.toStringAsFixed(2)}';

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

String formatMapCacheSize(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}
