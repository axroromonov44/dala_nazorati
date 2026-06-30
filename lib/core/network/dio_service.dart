import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';

class DioService {
  DioService(this._storageService) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
        sendTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.addAll([
      _AuthInterceptor(_storageService, _dio),
      PrettyDioLogger(
        requestBody: true,
        responseBody: true,
        compact: false,
      ),
    ]);
  }

  final SecureStorageService _storageService;
  late final Dio _dio;

  Dio get client => _dio;

  // ---- Convenience methods ----

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Options? options,
  }) =>
      _dio.post<T>(path, data: data, options: options);

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Options? options,
  }) =>
      _dio.put<T>(path, data: data, options: options);

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Options? options,
  }) =>
      _dio.patch<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Options? options,
  }) =>
      _dio.delete<T>(path, data: data, options: options);
}

// ---------------------------------------------------------------------------
// Auth interceptor — token qo'shadi, 401 da refresh qiladi
// ---------------------------------------------------------------------------

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage, this._dio);

  final SecureStorageService _storage;
  final Dio _dio;
  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshed = await _refresh();
        _isRefreshing = false;
        if (refreshed) {
          final token = await _storage.getAccessToken();
          err.requestOptions.headers['Authorization'] = 'Bearer $token';
          final response = await _dio.fetch<dynamic>(err.requestOptions);
          return handler.resolve(response);
        }
      } catch (_) {
        _isRefreshing = false;
        await _storage.clearTokens();
      }
    }

    // Timeout xatolarini tushunarli formatga o'tkazish
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return handler.next(
        DioException(
          requestOptions: err.requestOptions,
          type: err.type,
          message: 'So\'rov vaqti tugadi. Internetni tekshiring.',
        ),
      );
    }

    handler.next(err);
  }

  Future<bool> _refresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Authorization': null}),
      );
      final newToken = response.data!['access_token'] as String;
      final newRefresh = response.data!['refresh_token'] as String? ?? refreshToken;
      await _storage.saveAccessToken(newToken);
      await _storage.saveRefreshToken(newRefresh);
      return true;
    } catch (_) {
      return false;
    }
  }
}
