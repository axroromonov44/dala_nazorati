import 'package:equatable/equatable.dart';

import 'inspector_role.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.username,
    required this.fullName,
    this.email,
    this.phone,
    this.roles = const [],
    this.imageUrl,
    this.passportNumber,
    this.pinfl,
    this.birthDate,
    this.address,
    this.gender,
    this.position,
    this.fullNameCyrillic,
    this.regionName,
    this.districtName,
  });

  final String id;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;
  final List<String> roles;
  final String? imageUrl;

  final String? passportNumber;
  final String? pinfl;
  final String? birthDate;
  final String? address;
  final String? gender;
  final String? position;
  final String? fullNameCyrillic;
  final String? regionName;
  final String? districtName;

  /// Inspectorate this user belongs to, derived from the token's `roles`
  /// claim. `null` when the claim carries no code we recognise.
  InspectorRole? get inspectorRole =>
      resolveInspectorRole(roles, position: position);

  @override
  List<Object?> get props => [
    id,
    username,
    fullName,
    email,
    phone,
    roles,
    imageUrl,
    passportNumber,
    pinfl,
    birthDate,
    address,
    gender,
    position,
    fullNameCyrillic,
    regionName,
    districtName,
  ];
}
