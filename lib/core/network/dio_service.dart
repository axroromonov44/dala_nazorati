import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/api_endpoints.dart';
import '../router/navigation_service.dart';
import '../storage/secure_storage_service.dart';
import 'api_exception.dart';

class DioService {
  DioService(this._storageService) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(
          milliseconds: ApiEndpoints.connectTimeout,
        ),
        receiveTimeout: const Duration(
          milliseconds: ApiEndpoints.receiveTimeout,
        ),
        sendTimeout: const Duration(milliseconds: ApiEndpoints.connectTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(_storageService, _dio));
    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: false,
          requestBody: true,
          responseBody: true,
          compact: false,
        ),
      );
    }
  }

  final SecureStorageService _storageService;
  late final Dio _dio;

  Dio get client => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _handle(
    () => _dio.get<T>(path, queryParameters: queryParameters, options: options),
  );

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _handle(
    () => _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options),
  );

  Future<Response<T>> put<T>(String path, {Object? data, Options? options}) =>
      _handle(() => _dio.put<T>(path, data: data, options: options));

  Future<Response<T>> patch<T>(String path, {Object? data, Options? options}) =>
      _handle(() => _dio.patch<T>(path, data: data, options: options));

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Options? options,
  }) => _handle(() => _dio.delete<T>(path, data: data, options: options));

  Future<Response<T>> _handle<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException(
        _extractMessage(e),
        statusCode: e.response?.statusCode,
      );
    }
  }
}

String _extractMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final message = data['message'];
    if (message is List && message.isNotEmpty) return message.first.toString();
    if (message is String && message.isNotEmpty) return message;

    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) return detail;

    for (final value in data.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String && value.isNotEmpty) return value;
    }
  }

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'errorTimeout'.tr();
    case DioExceptionType.connectionError:
      return 'errorConnection'.tr();
    case DioExceptionType.badCertificate:
      return 'errorBadCertificate'.tr();
    case DioExceptionType.cancel:
      return 'errorCancelled'.tr();
    case DioExceptionType.badResponse:
      return _messageForStatusCode(e.response?.statusCode);
    case DioExceptionType.unknown:
    default:
      return 'errorUnknown'.tr();
  }
}

String _messageForStatusCode(int? code) {
  switch (code) {
    case 400:
      return 'errorBadRequest'.tr();
    case 401:
      return 'errorUnauthorized'.tr();
    case 403:
      return 'errorForbidden'.tr();
    case 404:
      return 'errorNotFound'.tr();
    case 422:
      return 'errorValidation'.tr();
    case 500:
    case 502:
    case 503:
      return 'errorServer'.tr();
    default:
      return 'errorGeneric'.tr();
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage, this._dio);

  final SecureStorageService _storage;
  final Dio _dio;
  Completer<bool>? _refreshCompleter;

  bool _isAuthEndpoint(String path) =>
      path.contains(ApiEndpoints.login) ||
      path.contains(ApiEndpoints.govLogin) ||
      path.contains(ApiEndpoints.refreshToken);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthEndpoint(options.path)) {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestPath = err.requestOptions.path;

    if (err.response?.statusCode == 401 && !_isAuthEndpoint(requestPath)) {
      final refreshed = await _refresh();
      if (refreshed) {
        final token = await _storage.getAccessToken();
        err.requestOptions.headers['Authorization'] = 'Bearer $token';
        try {
          final response = await _dio.fetch<dynamic>(err.requestOptions);
          return handler.resolve(response);
        } on DioException catch (retryErr) {
          return handler.next(retryErr);
        }
      } else {
        await _storage.clearTokens();
        _redirectToLogin();
      }
    }

    handler.next(err);
  }

  Future<bool> _refresh() {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    _performRefresh().then(completer.complete).whenComplete(() {
      _refreshCompleter = null;
    });
    return completer.future;
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.refreshToken,
        data: {'refresh': refreshToken},
      );
      final newAccess = response.data?['access'] as String?;
      if (newAccess == null || newAccess.isEmpty) return false;
      await _storage.saveAccessToken(newAccess);
      final newRefresh = response.data?['refresh'] as String?;
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await _storage.saveRefreshToken(newRefresh);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _redirectToLogin() {
    final context = NavigationService.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      context.go('/login');
    }
  }
}
