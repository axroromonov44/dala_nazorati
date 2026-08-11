import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Attaches a debug-only `PrettyDioLogger` to [dio] — every `Dio` instance
/// in the app should get one of these (see `DioService`, which set the
/// original precedent), otherwise its requests are silently invisible in
/// the console when debugging, which is exactly what made the
/// `datahub.karantin.uz` reference calls (and the ones below) impossible
/// to spot next to the main API's already-logged ones.
///
/// [logBody] should stay `false` for endpoints returning binary payloads
/// (map tiles, field photos) — dumping raw bytes as text is just noise, so
/// those get a compact method/URL/status-only line instead.
void attachDebugLogger(Dio dio, {bool logBody = true}) {
  if (!kDebugMode) return;
  dio.interceptors.add(
    PrettyDioLogger(
      requestHeader: logBody,
      requestBody: logBody,
      responseBody: logBody,
      compact: !logBody,
    ),
  );
}
