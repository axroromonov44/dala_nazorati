class OneIdConfig {
  const OneIdConfig._();

  static const String baseUrl =
      'https://sso.egov.uz/sso/oauth/Authorization.do';
  static const String responseType = 'one_code';
  static const String clientId = 'efito_uz';
  static const String scope = 'efito_uz';
  static const String state = 'agrokomakchi';

  static const String redirectUri = 'https://dala.efito.uz/auth/login';

  static String buildAuthorizationUrl() =>
      '$baseUrl?response_type=$responseType&client_id=$clientId'
      '&redirect_uri=$redirectUri&scope=$scope&state=$state';
}
