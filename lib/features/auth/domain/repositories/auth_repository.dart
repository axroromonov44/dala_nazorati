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

  /// Fetches the authoritative profile (`GET /users/me`) and merges it into
  /// the locally-known [User] (`id`/`roles` still come from the access
  /// token, since the profile endpoint doesn't return them) — called once
  /// whenever the home page loads, so the cached username/full name/phone
  /// stay fresh. Cached to disk so it's still available offline afterwards.
  Future<User> fetchProfile();
}
