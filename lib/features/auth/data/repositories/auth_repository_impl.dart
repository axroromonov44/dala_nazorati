import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remoteDataSource, this._storageService);

  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;

  @override
  Future<({User user, String accessToken, String refreshToken})> login({
    required String username,
    required String password,
  }) async {
    final data = await _remoteDataSource.login(
      username: username,
      password: password,
    );
    return _completeLogin(data);
  }

  @override
  Future<({User user, String accessToken, String refreshToken})>
      loginWithGovCode({required String code}) async {
    final data = await _remoteDataSource.loginGov(code: code);
    return _completeLogin(data);
  }

  Future<({User user, String accessToken, String refreshToken})>
      _completeLogin(Map<String, dynamic> data) async {
    final accessToken = data['access'] as String;
    final refreshToken = data['refresh'] as String;
    final user = UserModel.fromAccessToken(accessToken);

    await _storageService.saveAccessToken(accessToken);
    await _storageService.saveRefreshToken(refreshToken);

    return (user: user, accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> logout() => _storageService.clearTokens();

  @override
  Future<User?> getCurrentUser() async {
    final token = await _storageService.getAccessToken();
    if (token == null) return null;
    try {
      return UserModel.fromAccessToken(token);
    } catch (_) {
      return null;
    }
  }
}
