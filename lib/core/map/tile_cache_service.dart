import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:path_provider/path_provider.dart';

/// Map tile cache: 30 kunlik offline saqlash.
/// App ishga tushganda `init()` chaqiriladi.
class TileCacheService {
  TileCacheService._();

  static HiveCacheStore? _store;
  static final Dio _dio = Dio()
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 30);

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _store = HiveCacheStore('${dir.path}/tile_cache');
  }

  static TileProvider build({bool isOnline = true}) {
    final store = _store;
    if (store == null) return NetworkTileProvider();
    return CachedTileProvider(
      dio: _dio,
      store: store,
      // Onlaynda yangilaydi, oflaynda keshdan darhol qaytaradi
      cachePolicy:
          isOnline ? CachePolicy.request : CachePolicy.forceCache,
      maxStale: const Duration(days: 30),
      hitCacheOnErrorExcept: [401, 403],
    );
  }
}
