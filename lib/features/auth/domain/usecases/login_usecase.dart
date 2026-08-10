import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<({User user, String accessToken, String refreshToken})> call({
    required String username,
    required String password,
  }) => _repository.login(username: username, password: password);
}
