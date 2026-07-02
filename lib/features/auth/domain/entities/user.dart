import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.username,
    required this.fullName,
    this.email,
    this.phone,
    this.roles = const [],
  });

  final String id;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;
  final List<String> roles;

  @override
  List<Object?> get props => [id, username, fullName, email, phone, roles];
}
