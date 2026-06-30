import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<({User user, String accessToken, String refreshToken})> call({
    required String phone,
    required String password,
  }) =>
      _repository.login(phone: phone, password: password);
}
