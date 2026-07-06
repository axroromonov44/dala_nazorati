class KarantinIdConfig {
  const KarantinIdConfig._();

  static const String baseUrl = 'https://id.karantin.uz';
  static const String authorizationPath = '/app/project/oauth/authorize';
  static const String responseType = 'code';
  static const String clientId = 'dala_nazorat_muucpk';

  static const String redirectUri = 'https://dala.efito.uz';

  static String buildAuthorizationUrl() =>
      '$baseUrl$authorizationPath?response_type=$responseType&client_id=$clientId';
}
