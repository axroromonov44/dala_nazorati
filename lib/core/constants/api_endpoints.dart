class ApiEndpoints {
  const ApiEndpoints._();

  static const String baseUrl = 'https://dala.efito.uz/api/v1';
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  static const String login = '/users/login';
  static const String govLogin = '/users/login/gov';
  static const String karantinLogin = '/users/login/karantin';
  static const String refreshToken = '/users/token/refresh';
}
