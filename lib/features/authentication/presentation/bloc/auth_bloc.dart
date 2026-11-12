import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:qr_attendance_app/core/network/auth_interceptor.dart';
import 'package:qr_attendance_app/core/utils/validators.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/get_current_user_usecase.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/login_usecase.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/logout_usecase.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_event.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required LoginUseCase loginUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required LogoutUseCase logoutUseCase,
    required AuthSessionEvents sessionEvents,
  })  : _loginUseCase = loginUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        _logoutUseCase = logoutUseCase,
        super(const AuthState()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthPasswordVisibilityToggled>(_onPasswordVisibilityToggled);
    on<AuthDemoAccountSelected>(_onDemoAccountSelected);
    on<AuthProfileRefreshRequested>(_onProfileRefreshRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthUnauthorizedDetected>(_onUnauthorizedDetected);

    _unauthorizedSubscription = sessionEvents.onUnauthorized.listen((_) {
      if (state.isAuthenticated) {
        add(const AuthUnauthorizedDetected());
      }
    });
  }

  final LoginUseCase _loginUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final LogoutUseCase _logoutUseCase;
  late final StreamSubscription<void> _unauthorizedSubscription;

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      status: AuthStatus.checking,
      clearError: true,
      clearInfo: true,
      clearStartupError: true,
    ));

    final result = await _getCurrentUserUseCase.checkSession();
    result.fold(
      onFailure: (failure) {
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          startupError: failure.message,
        ));
      },
      onSuccess: (user) {
        if (user == null) {
          emit(state.copyWith(
            status: AuthStatus.unauthenticated,
            clearUser: true,
          ));
        } else {
          emit(state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
          ));
        }
      },
    );
  }

  Future<void> _onLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final emailError = Validators.validateEmail(event.email);
    final passwordError = Validators.validatePassword(event.password);
    if (emailError != null || passwordError != null) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: emailError ?? passwordError,
      ));
      return;
    }

    emit(state.copyWith(
      status: AuthStatus.authenticating,
      clearError: true,
      clearInfo: true,
      clearStartupError: true,
    ));

    final result = await _loginUseCase(
      email: event.email,
      password: event.password,
    );

    result.fold(
      onFailure: (failure) {
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          errorMessage: failure.message,
        ));
      },
      onSuccess: (user) {
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          clearError: true,
        ));
      },
    );
  }

  void _onPasswordVisibilityToggled(
    AuthPasswordVisibilityToggled event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(obscurePassword: !state.obscurePassword));
  }

  void _onDemoAccountSelected(
    AuthDemoAccountSelected event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(
      prefillEmail: event.email,
      prefillPassword: event.password,
      prefillRevision: state.prefillRevision + 1,
      clearError: true,
    ));
  }

  Future<void> _onProfileRefreshRequested(
    AuthProfileRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _getCurrentUserUseCase.fetchProfile();
    result.fold(
      onFailure: (failure) {
        emit(state.copyWith(errorMessage: failure.message));
      },
      onSuccess: (user) {
        emit(state.copyWith(user: user, clearError: true));
      },
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _logoutUseCase();
    emit(const AuthState(
      status: AuthStatus.unauthenticated,
      infoMessage: 'You have been signed out successfully.',
    ));
  }

  Future<void> _onUnauthorizedDetected(
    AuthUnauthorizedDetected event,
    Emitter<AuthState> emit,
  ) async {
    await _logoutUseCase();
    emit(const AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: 'Session expired (401 Unauthorized). Please sign in again.',
    ));
  }

  @override
  Future<void> close() async {
    await _unauthorizedSubscription.cancel();
    return super.close();
  }
}

