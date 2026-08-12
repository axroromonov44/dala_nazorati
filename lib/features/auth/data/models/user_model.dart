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
    super.imageUrl,
    super.passportNumber,
    super.pinfl,
    super.birthDate,
    super.address,
    super.gender,
    super.position,
    super.fullNameCyrillic,
    super.regionName,
    super.districtName,
  });

  factory UserModel.fromAccessToken(String accessToken) {
    final claims = decodeJwtPayload(accessToken);
    return UserModel(
      id: (claims['user_id'] ?? claims['id'] ?? '').toString(),
      username: claims['username'] as String? ?? '',
      fullName: claims['full_name'] as String? ?? '',
      email: claims['email'] as String?,
      phone: claims['phone'] as String?,
      roles:
          (claims['roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      imageUrl: claims['image_url'] as String?,
      passportNumber: claims['passport_number'] as String?,
      pinfl: claims['pinfl'] as String?,
      birthDate: claims['birth_date'] as String?,
      address: claims['address'] as String?,
      gender: claims['gender'] as String?,
      position: _nullIfEmpty(claims['position'] as String?),
      fullNameCyrillic: _nullIfEmpty(claims['full_name_cyrillic'] as String?),
      regionName: _extractName(claims['region']),
      districtName: _extractName(claims['district']),
    );
  }

  factory UserModel.fromMeResponse(
    Map<String, dynamic> json, {
    required User previous,
  }) => UserModel(
    id: previous.id,
    username: json['username'] as String? ?? previous.username,
    fullName: json['full_name'] as String? ?? previous.fullName,
    email: json['email'] as String? ?? previous.email,
    phone: json['phone'] as String? ?? previous.phone,
    roles: previous.roles,
    imageUrl:
        (json['image_url'] ?? json['image']) as String? ?? previous.imageUrl,
    passportNumber:
        json['passport_number'] as String? ?? previous.passportNumber,
    pinfl: json['pinfl'] as String? ?? previous.pinfl,
    birthDate: json['birth_date'] as String? ?? previous.birthDate,
    address: json['address'] as String? ?? previous.address,
    gender: json['gender'] as String? ?? previous.gender,
    position: _nullIfEmpty(json['position'] as String?) ?? previous.position,
    fullNameCyrillic:
        _nullIfEmpty(json['full_name_cyrillic'] as String?) ??
        previous.fullNameCyrillic,
    regionName: _extractName(json['region']) ?? previous.regionName,
    districtName: _extractName(json['district']) ?? previous.districtName,
  );

  static String? _extractName(dynamic value) {
    if (value is Map) {
      final name = value['name'];
      if (name is String && name.isNotEmpty) return name;
    }
    return null;
  }

  static String? _nullIfEmpty(String? value) =>
      (value == null || value.isEmpty) ? null : value;
}
