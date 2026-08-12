import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

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
