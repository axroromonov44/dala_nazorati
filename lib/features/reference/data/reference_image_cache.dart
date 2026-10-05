import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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

  // Number of images downloaded in parallel. A continuous worker pool keeps this
  // many requests in flight at all times (no batch barrier).
  static const _concurrency = 10;

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/reference_images');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;

    // Reuse TCP/TLS connections across the parallel downloads (keep-alive), so
    // each image doesn't pay a fresh handshake to the same host.
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.maxConnectionsPerHost = _concurrency;
        client.idleTimeout = const Duration(seconds: 20);
        return client;
      },
    );

    attachDebugLogger(_dio, logBody: false);
  }

  static File? cachedFile(String url) {
    final dir = _dir;
    if (dir == null) return null;
    final file = File('${dir.path}/${_fileNameFor(url)}');
    return file.existsSync() ? file : null;
  }

  static Future<void> downloadAll(
    Iterable<String> urls, {
    void Function(int done, int total)? onProgress,
  }) async {
    final pending = urls
        .toSet()
        .where((url) => cachedFile(url) == null)
        .toList();
    if (pending.isEmpty) return;

    final total = pending.length;
    var next = 0;
    var done = 0;
    var succeeded = 0;

    // Worker pool: each worker pulls the next URL as soon as it frees up, so
    // [_concurrency] downloads stay in flight the whole time — a slow image no
    // longer blocks the others behind a batch barrier.
    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= total) break;
        if (await _download(pending[index])) succeeded++;
        done++;
        onProgress?.call(done, total);
      }
    }

    await Future.wait([
      for (var w = 0; w < _concurrency && w < total; w++) worker(),
    ]);

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
