import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path_provider/path_provider.dart';

class ReferenceImageDownloadException implements Exception {
  const ReferenceImageDownloadException({this.failed = 0, this.total = 0});

  /// Images that could not be fetched and are worth retrying later.
  final int failed;
  final int total;

  @override
  String toString() =>
      'ReferenceImageDownloadException($failed of $total images failed)';
}

/// Outcome of a single image download.
enum _Outcome {
  ok,

  /// The server answered, but this URL will never work (404/410/403). Retrying
  /// it is pointless and must not block the whole catalog step.
  gone,

  /// Timeout, connection error or 5xx — worth another attempt.
  retryable,
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
  static const _concurrency = 20;

  /// Attempts per image, including the first one. Only retryable failures
  /// (timeouts, 5xx, dropped connections) consume an attempt.
  static const _maxAttempts = 3;

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

    // Deliberately no debug logger here: a catalog sync is ~2000 downloads, and
    // two log lines each is thousands of logcat writes that slow the device
    // down and bury everything else in the console.
  }

  static File? cachedFile(String url) {
    final dir = _dir;
    if (dir == null) return null;

    final file = File('${dir.path}/${_fileNameFor(url)}');
    if (file.existsSync()) return file;

    // Files cached before the switch to md5 names are still good; move them
    // over instead of downloading everything again.
    final legacy = File('${dir.path}/${_legacyFileNameFor(url)}');
    if (legacy.existsSync()) {
      try {
        return legacy.renameSync(file.path);
      } catch (_) {
        return legacy;
      }
    }
    return null;
  }

  /// Downloads everything that is not cached yet.
  ///
  /// Throws [ReferenceImageDownloadException] when images are still missing for
  /// a reason worth retrying, so the caller does not record the catalog step as
  /// complete. Already-downloaded files are never fetched twice, so a retry
  /// only picks up what is left.
  static Future<void> downloadAll(
    Iterable<String> urls, {
    void Function(int done, int total)? onProgress,
  }) async {
    final dir = _dir;
    if (dir == null) return;

    // One directory read instead of two stat() calls per url. The catalog is
    // ~2000 images, and probing each one individually stalls the isolate that
    // is also driving the progress dialog.
    final existing = <String>{};
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) existing.add(entity.uri.pathSegments.last);
    }

    final pending = <String>[];
    for (final url in urls.toSet()) {
      final name = _fileNameFor(url);
      if (existing.contains(name)) continue;
      final legacy = _legacyFileNameFor(url);
      if (existing.contains(legacy)) {
        try {
          File('${dir.path}/$legacy').renameSync('${dir.path}/$name');
          continue;
        } catch (_) {
          // Fall through and fetch it again.
        }
      }
      pending.add(url);
    }
    if (pending.isEmpty) return;

    final total = pending.length;
    var next = 0;
    var done = 0;
    var succeeded = 0;
    var retryable = 0;

    // Worker pool: each worker pulls the next URL as soon as it frees up, so
    // [_concurrency] downloads stay in flight the whole time — a slow image no
    // longer blocks the others behind a batch barrier.
    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= total) break;
        final outcome = await _downloadWithRetry(pending[index]);
        switch (outcome) {
          case _Outcome.ok:
            succeeded++;
          case _Outcome.retryable:
            retryable++;
          case _Outcome.gone:
            break;
        }
        done++;
        onProgress?.call(done, total);
      }
    }

    await Future.wait([
      for (var w = 0; w < _concurrency && w < total; w++) worker(),
    ]);

    if (succeeded == 0 || retryable > 0) {
      throw ReferenceImageDownloadException(failed: retryable, total: total);
    }
  }

  static Future<_Outcome> _downloadWithRetry(String url) async {
    for (var attempt = 1; ; attempt++) {
      final outcome = await _download(url);
      if (outcome != _Outcome.retryable || attempt >= _maxAttempts) {
        return outcome;
      }
      // Back off a little so a struggling server is not hammered.
      await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
    }
  }

  static Future<_Outcome> _download(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return _Outcome.retryable;
      await File('${_dir!.path}/${_fileNameFor(url)}').writeAsBytes(bytes);
      return _Outcome.ok;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // A 4xx (other than 408/429) means this URL is simply wrong or removed.
      if (status != null &&
          status >= 400 &&
          status < 500 &&
          status != 408 &&
          status != 429) {
        return _Outcome.gone;
      }
      return _Outcome.retryable;
    } catch (_) {
      return _Outcome.retryable;
    }
  }

  /// md5 of the URL: stable across app restarts and Dart SDK upgrades, and wide
  /// enough that two of the catalog's images cannot collide.
  static String _fileNameFor(String url) =>
      '${md5.convert(utf8.encode(url))}${_extensionOf(url)}';

  /// The old 32-bit `String.hashCode` naming, kept only to adopt files that are
  /// already on disk (see [cachedFile]).
  static String _legacyFileNameFor(String url) {
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
