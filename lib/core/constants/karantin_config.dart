class KarantinIdConfig {
  const KarantinIdConfig._();

  static const String baseUrl = 'https://id.karantin.uz';
  static const String authorizationPath = '/app/project/oauth/authorize';
  static const String responseType = 'code';
  static const String clientId = 'dala_nazorat_muucpk';
  static const String scope = 'openid profile';
  static const String authType = 'login';

  static const String redirectUri =
      'https://dala.efito.uz/api/v1/auth/one-id/callback';

  static String buildAuthorizationUrl() =>
      '$baseUrl$authorizationPath?response_type=$responseType'
      '&client_id=$clientId'
      '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
      '&scope=${Uri.encodeComponent(scope)}'
      '&auth_type=$authType';
}
