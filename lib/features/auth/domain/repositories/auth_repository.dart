import '../entities/user.dart';

abstract class AuthRepository {
  Future<({User user, String accessToken, String refreshToken})> login({
    required String username,
    required String password,
  });

  Future<({User user, String accessToken, String refreshToken})>
      loginWithGovCode({required String code});

  Future<({User user, String accessToken, String refreshToken})>
      loginWithKarantinCode({required String code});

  Future<void> logout();
  Future<User?> getCurrentUser();
}
