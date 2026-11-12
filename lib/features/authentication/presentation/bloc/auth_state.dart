import 'package:equatable/equatable.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';

enum AuthStatus {
  initial,
  checking,
  unauthenticated,
  authenticating,
  authenticated,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.obscurePassword = true,
    this.errorMessage,
    this.infoMessage,
    this.startupError,
    this.prefillEmail,
    this.prefillPassword,
    this.prefillRevision = 0,
  });

  final AuthStatus status;
  final UserEntity? user;
  final bool obscurePassword;
  final String? errorMessage;
  final String? infoMessage;
  final String? startupError;
  final String? prefillEmail;
  final String? prefillPassword;
  final int prefillRevision;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    bool clearUser = false,
    bool? obscurePassword,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
    String? startupError,
    bool clearStartupError = false,
    String? prefillEmail,
    String? prefillPassword,
    int? prefillRevision,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      obscurePassword: obscurePassword ?? this.obscurePassword,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      startupError:
          clearStartupError ? null : (startupError ?? this.startupError),
      prefillEmail: prefillEmail ?? this.prefillEmail,
      prefillPassword: prefillPassword ?? this.prefillPassword,
      prefillRevision: prefillRevision ?? this.prefillRevision,
    );
  }

  @override
  List<Object?> get props => [
        status,
        user,
        obscurePassword,
        errorMessage,
        infoMessage,
        startupError,
        prefillEmail,
        prefillPassword,
        prefillRevision,
      ];
}

