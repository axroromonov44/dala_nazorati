class OneIdConfig {
  const OneIdConfig._();

  static const String baseUrl =
      'https://sso.egov.uz/sso/oauth/Authorization.do';
  static const String responseType = 'one_code';
  static const String clientId = 'efito_uz';
  static const String scope = 'efito_uz';
  static const String state = 'agrokomakchi';

  // Web ilovada (VITE_API_ONE_ID_REDIRECT_URL) ham shu manzil ishlatiladi —
  // sso.egov.uz'da client_id=efito_uz uchun ro'yxatdan o'tgan yagona
  // redirect_uri shu. WebView shu manzilga o'tishga urinishni ushlab,
  // undagi "code" parametrini o'qib oladi.
  static const String redirectUri = 'https://dala.efito.uz/auth/login';

  static String buildAuthorizationUrl() =>
      '$baseUrl?response_type=$responseType&client_id=$clientId'
      '&redirect_uri=$redirectUri&scope=$scope&state=$state';
}
