import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/gov_login_usecase.dart';
import '../../domain/usecases/login_usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._loginUseCase, this._govLoginUseCase)
      : super(const AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthGovLoginRequested>(_onGovLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final LoginUseCase _loginUseCase;
  final GovLoginUseCase _govLoginUseCase;

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) =>
      _login(
        emit,
        () => _loginUseCase(username: event.username, password: event.password),
      );

  Future<void> _onGovLoginRequested(
    AuthGovLoginRequested event,
    Emitter<AuthState> emit,
  ) =>
      _login(emit, () => _govLoginUseCase(code: event.code));

  Future<void> _login(
    Emitter<AuthState> emit,
    Future<({User user, String accessToken, String refreshToken})> Function()
        action,
  ) async {
    emit(const AuthLoading());
    try {
      final result = await action();
      emit(AuthAuthenticated(result.user));
    } on ApiException catch (e) {
      emit(AuthError(e.message));
    } catch (_) {
      emit(AuthError('errorUnexpected'.tr()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthUnauthenticated());
  }
}
