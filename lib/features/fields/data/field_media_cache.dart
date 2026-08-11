import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/di/injection.dart';
import '../../../core/network/dio_debug_logger.dart';
import '../../../core/storage/hive_service.dart';
import '../domain/entities/field_detail.dart';

/// Downloads field photos on demand for display. Persisting them as a
/// durable offline cache is disabled for now (see [ensureCached]).
///
/// Modeled directly on `TileCacheService`: a static service holding a
/// directory + dedicated short-timeout `Dio`.
class FieldMediaCache {
  FieldMediaCache._();

  static Directory? _dir;
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/field_photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    // logBody: false — photo responses are raw image bytes, not JSON.
    attachDebugLogger(_dio, logBody: false);
  }

  /// Returns the local file path for [photo], always downloading it fresh.
  /// Prefers [FieldPhoto.thumbUrl] when present.
  ///
  /// Backend/data are still being finalized, so persisting photo metadata
  /// (and reusing a previous download) is disabled for now — every call
  /// re-fetches from the API instead of trusting a local cache entry.
  static Future<String> ensureCached(FieldPhoto photo) async {
    final url = photo.thumbUrl ?? photo.remoteUrl;
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data ?? const <int>[];
    final path = '${_dir!.path}/${photo.id}';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// Deletes every cached photo file and its metadata — called on logout so
  /// the next person to use this device can't see the previous employee's
  /// field photos still sitting on disk.
  static Future<void> clear() async {
    final dir = _dir;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
    await getIt<HiveService>().fieldPhotoMetaBox.clear();
  }
}
