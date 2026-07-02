import '../../../../core/utils/jwt_utils.dart';
import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.username,
    required super.fullName,
    super.email,
    super.phone,
    super.roles,
  });

  /// Login javobida alohida foydalanuvchi obyekti kelmaydi — access token
  /// ichidagi claim'lardan (user_id, username, full_name, roles va h.k.)
  /// hosil qilinadi.
  factory UserModel.fromAccessToken(String accessToken) {
    final claims = decodeJwtPayload(accessToken);
    return UserModel(
      id: (claims['user_id'] ?? claims['id'] ?? '').toString(),
      username: claims['username'] as String? ?? '',
      fullName: claims['full_name'] as String? ?? '',
      email: claims['email'] as String?,
      phone: claims['phone'] as String?,
      roles: (claims['roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
