import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/di/injection.dart';
import '../../../core/network/dio_debug_logger.dart';
import '../../../core/storage/hive_service.dart';
import '../domain/entities/field_detail.dart';

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
    attachDebugLogger(_dio, logBody: false);
  }

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

  static Future<void> clear() async {
    final dir = _dir;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
    await getIt<HiveService>().fieldPhotoMetaBox.clear();
  }
}
