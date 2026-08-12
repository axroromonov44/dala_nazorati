import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/dio_debug_logger.dart';

class ReferenceImageDownloadException implements Exception {
  const ReferenceImageDownloadException();
}

class ReferenceImageCache {
  ReferenceImageCache._();

  static Directory? _dir;
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  static const _concurrency = 6;

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/reference_images');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    attachDebugLogger(_dio, logBody: false);
  }

  static File? cachedFile(String url) {
    final dir = _dir;
    if (dir == null) return null;
    final file = File('${dir.path}/${_fileNameFor(url)}');
    return file.existsSync() ? file : null;
  }

  static Future<void> downloadAll(Iterable<String> urls) async {
    final pending = urls
        .toSet()
        .where((url) => cachedFile(url) == null)
        .toList();
    if (pending.isEmpty) return;

    var succeeded = 0;
    for (var i = 0; i < pending.length; i += _concurrency) {
      final batch = pending.sublist(
        i,
        (i + _concurrency).clamp(0, pending.length),
      );
      final results = await Future.wait([
        for (final url in batch) _download(url),
      ]);
      succeeded += results.where((ok) => ok).length;
    }
    if (succeeded == 0) throw const ReferenceImageDownloadException();
  }

  static Future<bool> _download(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return false;
      await File('${_dir!.path}/${_fileNameFor(url)}').writeAsBytes(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _fileNameFor(String url) {
    final hash = url.hashCode.toUnsigned(32).toRadixString(16);
    return '$hash${_extensionOf(url)}';
  }

  static String _extensionOf(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '';
    final ext = path.substring(dot);
    return ext.length <= 5 ? ext : '';
  }

  static Future<void> clear() async {
    final dir = _dir;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
  }
}
