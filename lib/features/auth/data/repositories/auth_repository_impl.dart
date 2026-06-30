import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._storageService);

  final SecureStorageService _storageService;

  @override
  Future<({User user, String accessToken, String refreshToken})> login({
    required String phone,
    required String password,
  }) async {
    // TODO: real API qo'shilganda shu yerga Dio call keladi
    await Future.delayed(const Duration(milliseconds: 600));
    const mockToken = 'mock_access_token';
    const mockRefresh = 'mock_refresh_token';
    final user = User(id: '1', name: 'Foydalanuvchi', email: '', phone: phone);
    await _storageService.saveAccessToken(mockToken);
    await _storageService.saveRefreshToken(mockRefresh);
    return (user: user, accessToken: mockToken, refreshToken: mockRefresh);
  }

  @override
  Future<void> logout() => _storageService.clearTokens();

  @override
  Future<User?> getCurrentUser() async => null;
}
