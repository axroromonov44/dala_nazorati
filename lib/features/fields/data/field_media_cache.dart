import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/di/injection.dart';
import '../../../core/storage/hive_service.dart';
import '../domain/entities/field_detail.dart';

/// On-disk, size-capped LRU cache for field photos — this is the actual
/// source of the 300MB offline-storage problem, so unlike the field index
/// (kept fully cached for every field), photos are fetched only when a
/// field is actually opened, and old ones get evicted once the cache grows
/// past [_maxCacheBytes].
///
/// Modeled directly on `TileCacheService`: a static service holding a
/// directory + dedicated short-timeout `Dio`, with Hive used only for
/// metadata (path/size/last-accessed), never for the bytes themselves.
class FieldMediaCache {
  FieldMediaCache._();

  static Directory? _dir;
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  static const _maxCacheBytes = 200 * 1024 * 1024;

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/field_photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
  }

  /// Returns the local file path for [photo], downloading it first if it
  /// isn't already cached. Prefers [FieldPhoto.thumbUrl] when present —
  /// callers that need the full-resolution image should pass a photo with
  /// `thumbUrl: null` or add a separate `ensureFullCached`, but for the
  /// steady-state "browse many fields" case the thumbnail is what keeps
  /// storage bounded.
  static Future<String> ensureCached(FieldPhoto photo) async {
    final box = getIt<HiveService>().fieldPhotoMetaBox;
    final existingRaw = box.get(photo.id) as String?;
    if (existingRaw != null) {
      final meta = jsonDecode(existingRaw) as Map<String, dynamic>;
      final path = meta['path'] as String;
      if (await File(path).exists()) {
        await box.put(photo.id, jsonEncode({...meta, 'lastAccessedAt': _now()}));
        return path;
      }
    }

    final url = photo.thumbUrl ?? photo.remoteUrl;
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data ?? const <int>[];
    final path = '${_dir!.path}/${photo.id}';
    await File(path).writeAsBytes(bytes);

    await box.put(
      photo.id,
      jsonEncode({
        'path': path,
        'sizeBytes': bytes.length,
        'lastAccessedAt': _now(),
      }),
    );
    await evictIfOverBudget();
    return path;
  }

  /// Deletes least-recently-accessed cached photos until total size is back
  /// under [_maxCacheBytes]. Call after downloads and once at app start.
  static Future<void> evictIfOverBudget() async {
    final box = getIt<HiveService>().fieldPhotoMetaBox;
    final entries = [
      for (final key in box.keys)
        MapEntry(key, jsonDecode(box.get(key) as String) as Map<String, dynamic>),
    ];

    var total = 0;
    for (final e in entries) {
      total += e.value['sizeBytes'] as int;
    }
    if (total <= _maxCacheBytes) return;

    entries.sort(
      (a, b) => (a.value['lastAccessedAt'] as int)
          .compareTo(b.value['lastAccessedAt'] as int),
    );

    for (final e in entries) {
      if (total <= _maxCacheBytes) break;
      final path = e.value['path'] as String;
      final file = File(path);
      if (await file.exists()) await file.delete();
      await box.delete(e.key);
      total -= e.value['sizeBytes'] as int;
    }
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch;

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
