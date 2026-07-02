class OneIdConfig {
  const OneIdConfig._();

  static const String baseUrl =
      'https://sso.egov.uz/sso/oauth/Authorization.do';
  static const String responseType = 'one_code';
  static const String clientId = 'efito_uz';
  static const String scope = 'efito_uz';
  static const String state = 'agrokomakchi';

  // TODO: sso.egov.uz'da client_id=efito_uz uchun ro'yxatdan o'tgan aniq
  // redirect_uri bilan almashtiring. WebView shu manzilga o'tishga urinishni
  // ushlab, undagi "code" parametrini o'qib oladi.
  static const String redirectUri =
      'https://dala.efito.uz/api/v1/users/login/gov';

  static String buildAuthorizationUrl() =>
      '$baseUrl?response_type=$responseType&client_id=$clientId'
      '&redirect_uri=$redirectUri&scope=$scope&state=$state';
}
