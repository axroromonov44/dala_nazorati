import 'package:dio/dio.dart';

import '../observability/diagnostics_log.dart';

/// Records the outcome of every request in the diagnostics log.
///
/// This is what closes the "I cannot tell what went wrong" gap: when an
/// inspector says "I could not sign in", the log holds either
/// `POST /auth/login 401 820ms` or
/// `POST /auth/login FAILED connectionTimeout 15004ms` — a wrong password and
/// a dead connection stop looking like the same thing.
///
/// Response bodies are **not** recorded: catalog responses run to megabytes
/// and may carry personal data. Only methods, paths, status codes and timing.
class DiagnosticsInterceptor extends Interceptor {
  static const _startKey = 'diag_start';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;
    DiagnosticsLog.info(
      'http',
      '${options.method} ${_path(options)} '
          '${response.statusCode} ${_elapsed(options)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final status = err.response?.statusCode;
    // Naming the timeout kind matters: connectionTimeout means "never
    // reached the server", receiveTimeout means "the answer was too slow".
    // The two have completely different causes.
    final detail = status != null ? 'HTTP $status' : err.type.name;
    DiagnosticsLog.error(
      'http',
      '${options.method} ${_path(options)} FAILED $detail ${_elapsed(options)}',
      error: err.message,
    );
    handler.next(err);
  }

  /// Path only: a full URL may carry a token or other secrets in its query.
  String _path(RequestOptions options) => options.uri.path;

  String _elapsed(RequestOptions options) {
    final start = options.extra[_startKey];
    if (start is! DateTime) return '';
    return '${DateTime.now().difference(start).inMilliseconds}ms';
  }
}
