import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<RegisterSubmitted>(_onRegisterSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    if (await authRepository.isAuthenticated()) {
      emit(AuthAuthenticated(
        token: await authRepository.getSavedToken() ?? '',
        username: await authRepository.getUsername() ?? '',
      ));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onRegisterSubmitted(RegisterSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await authRepository.register(username: event.username, password: event.password);
    } catch (e) {
      emit(AuthFailure(message: _clean(e)));
      return;
    }
    try {
      final token = await authRepository.login(username: event.username, password: event.password);
      emit(AuthAuthenticated(token: token, username: event.username));
    } catch (_) {
      emit(const AuthRegistrationSuccess(
        message: 'Account created. Please log in with your new credentials.',
      ));
    }
  }

  Future<void> _onLoginSubmitted(LoginSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final token = await authRepository.login(username: event.username, password: event.password);
      emit(AuthAuthenticated(token: token, username: event.username));
    } catch (e) {
      emit(AuthFailure(message: _clean(e)));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    await authRepository.logout();
    emit(AuthUnauthenticated());
  }
}
