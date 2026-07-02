part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();
}

final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.username, required this.password});

  final String username;
  final String password;

  @override
  List<Object> get props => [username, password];
}

final class AuthGovLoginRequested extends AuthEvent {
  const AuthGovLoginRequested({required this.code});

  final String code;

  @override
  List<Object> get props => [code];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();

  @override
  List<Object> get props => [];
}
