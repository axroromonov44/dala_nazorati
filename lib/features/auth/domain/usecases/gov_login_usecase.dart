import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class GovLoginUseCase {
  const GovLoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<({User user, String accessToken, String refreshToken})> call({
    required String code,
  }) =>
      _repository.loginWithGovCode(code: code);
}
