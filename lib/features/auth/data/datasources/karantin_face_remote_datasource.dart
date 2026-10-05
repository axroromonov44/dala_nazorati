import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../../../../core/constants/karantin_config.dart';
import '../../../../core/device/karantin_device_data.dart';
import '../../../../core/network/api_exception.dart';
import '../face/karantin_face_session.dart';

/// A captured face payload ready to upload: the primary (cropped) image plus up
/// to four additional "check" frames, mirroring the web client's
/// `face_image` + `check_image1..4` multipart fields.
class KarantinFacePayload {
  const KarantinFacePayload({required this.faceImage, required this.checkImages});

  final Uint8List faceImage;
  final List<Uint8List> checkImages;
}

/// Native client for the karantin-id OAuth endpoints under `https://id.karantin.uz/app`.
///
/// This replaces the in-webview React SPA: it fetches the session token from
/// `authorize`, submits the face verification multipart request, and follows
/// the resulting redirect chain until the `code` lands on the configured
/// redirect_uri — the exact value the webview used to capture.
class KarantinFaceRemoteDataSource {
  KarantinFaceRemoteDataSource({Dio? dio, Dio? redirectDio, CookieJar? cookieJar})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: '${KarantinIdConfig.baseUrl}/app',
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
              headers: {'Accept-Language': 'uz'},
            ),
          ),
      // A bare client used only to walk redirect chains manually.
      _redirectDio =
          redirectDio ??
          Dio(
            BaseOptions(
              followRedirects: false,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (status) => status != null && status < 400,
            ),
          ) {
    // Share one cookie jar across both clients so any session cookie the
    // `authorize` step sets is replayed through submit and the redirect walk,
    // exactly as a browser would within one login session.
    final jar = cookieJar ?? CookieJar();
    _dio.interceptors.add(CookieManager(jar));
    _redirectDio.interceptors.add(CookieManager(jar));
  }

  final Dio _dio;
  final Dio _redirectDio;

  static const int _maxRedirects = 10;

  /// Hits `authorize` and parses the SPA route it redirects to, yielding the
  /// token/name (login, verify-document) or code/state (register).
  Future<KarantinFaceSession> startSession() async {
    final authUrl = KarantinIdConfig.buildAuthorizationUrl();

    final Response response;
    try {
      response = await _redirectDio.getUri<void>(Uri.parse(authUrl));
    } on DioException catch (e) {
      throw ApiException(
        'Karantin ID bilan bogʻlanib boʻlmadi. Qayta urinib koʻring.',
        statusCode: e.response?.statusCode,
      );
    }

    final location = _locationHeader(response);
    if (location == null) {
      throw ApiException('Karantin ID sessiyasini ochib boʻlmadi.');
    }

    final uri = _resolve(location);
    final query = uri.queryParameters;
    final path = uri.path;

    if (path.contains('sign-up')) {
      return KarantinFaceSession(
        flow: KarantinFaceFlow.register,
        code: query['code'],
        state: query['state'],
        name: query['name'],
      );
    }
    if (path.contains('verify-document')) {
      return KarantinFaceSession(
        flow: KarantinFaceFlow.verifyDocument,
        token: query['token'],
        name: query['name'],
      );
    }
    return KarantinFaceSession(
      flow: KarantinFaceFlow.login,
      token: query['token'],
      name: query['name'],
    );
  }

  /// `sendPassport` — notifies the backend which identifier is attempting login
  /// before the face scan. Best-effort: failures here must not block the scan.
  Future<void> notifyLogin({
    required String token,
    required String passportNumber,
  }) async {
    try {
      await _dio.post<void>(
        '/project/notify/login/',
        data: {'token': token, 'passport_number': passportNumber},
      );
    } on DioException {
      // Non-fatal, mirror the web client which ignores notify failures.
    }
  }

  /// Submits the login face verification and returns `redirect_to`.
  Future<String> submitLogin({
    required String token,
    required String identifier,
    required bool isPnfl,
    required bool includeScreens,
    required KarantinFacePayload payload,
    required KarantinDeviceData device,
  }) {
    return _submitFace(
      '/project/oauth/login',
      payload: payload,
      includeScreens: includeScreens,
      device: device,
      fields: {isPnfl ? 'pinfl' : 'passport_number': identifier, 'token': token},
    );
  }

  /// Submits the register face verification and returns `redirect_to`.
  Future<String> submitRegister({
    required String oneCode,
    required String? token,
    required bool includeScreens,
    required KarantinFacePayload payload,
    required KarantinDeviceData device,
  }) {
    return _submitFace(
      '/project/oauth/register',
      payload: payload,
      includeScreens: includeScreens,
      device: device,
      fields: {'one_code': oneCode, 'token': ?token},
    );
  }

  /// Submits the verify-document face verification and returns `redirect_to`.
  Future<String> submitVerifyDocument({
    required String token,
    required bool includeScreens,
    required KarantinFacePayload payload,
    required KarantinDeviceData device,
  }) {
    return _submitFace(
      '/project/oauth/verify-doc',
      payload: payload,
      includeScreens: includeScreens,
      device: device,
      fields: {'token': token},
    );
  }

  Future<String> _submitFace(
    String path, {
    required KarantinFacePayload payload,
    required bool includeScreens,
    required KarantinDeviceData device,
    required Map<String, String> fields,
  }) async {
    final form = FormData();

    device.toBackendFields().forEach((key, value) {
      form.fields.add(MapEntry(key, value));
    });
    fields.forEach((key, value) {
      if (value.isNotEmpty) form.fields.add(MapEntry(key, value));
    });

    form.files.add(
      MapEntry(
        'face_image',
        MultipartFile.fromBytes(
          payload.faceImage,
          filename: 'user.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      ),
    );

    if (includeScreens) {
      final screens = payload.checkImages.take(4).toList();
      for (var i = 0; i < screens.length; i++) {
        form.files.add(
          MapEntry(
            'check_image${i + 1}',
            MultipartFile.fromBytes(
              screens[i],
              filename: 'additional-${i + 1}-image.jpg',
              contentType: DioMediaType('image', 'jpeg'),
            ),
          ),
        );
      }
    }

    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(path, data: form);
    } on DioException catch (e) {
      throw ApiException(
        _faceErrorMessage(e),
        statusCode: e.response?.statusCode,
      );
    }

    final redirectTo = response.data?['redirect_to'];
    if (redirectTo is! String || redirectTo.isEmpty) {
      throw ApiException('Serverdan yoʻnaltirish manzili kelmadi.');
    }
    return redirectTo;
  }

  /// Walks the redirect chain starting at [redirectTo] until it reaches the
  /// configured redirect_uri and returns its `code` query parameter — the same
  /// value the webview's navigation delegate used to intercept.
  Future<String> followToCode(String redirectTo) async {
    var current = _resolve(redirectTo);

    for (var i = 0; i < _maxRedirects; i++) {
      if (current.toString().startsWith(KarantinIdConfig.redirectUri)) {
        final code = current.queryParameters['code'];
        if (code != null && code.isNotEmpty) return code;
        throw ApiException('Yakuniy manzilda kod topilmadi.');
      }

      final Response response;
      try {
        response = await _redirectDio.getUri<void>(current);
      } on DioException catch (e) {
        throw ApiException(
          'Yoʻnaltirishni kuzatib boʻlmadi.',
          statusCode: e.response?.statusCode,
        );
      }

      final location = _locationHeader(response);
      if (location == null) {
        // No further redirect: inspect the final URL for a code anyway.
        final finalUri = response.realUri;
        if (finalUri.toString().startsWith(KarantinIdConfig.redirectUri)) {
          final code = finalUri.queryParameters['code'];
          if (code != null && code.isNotEmpty) return code;
        }
        throw ApiException('Avtorizatsiya kodini olib boʻlmadi.');
      }

      current = _resolve(location, base: current);
    }

    throw ApiException('Juda koʻp yoʻnaltirish. Qayta urinib koʻring.');
  }

  String? _locationHeader(Response response) {
    final status = response.statusCode ?? 0;
    if (status < 300 || status >= 400) return null;
    final location = response.headers.value('location');
    if (location == null || location.isEmpty) return null;
    return location;
  }

  Uri _resolve(String location, {Uri? base}) {
    final uri = Uri.parse(location);
    if (uri.hasScheme) return uri;
    final root = base ?? Uri.parse(KarantinIdConfig.baseUrl);
    return root.resolveUri(uri);
  }

  String _faceErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message;
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map && first['message'] is String) {
          return first['message'] as String;
        }
      }
    }
    return 'Yuzni tasdiqlab boʻlmadi. Qaytadan urinib koʻring.';
  }
}
