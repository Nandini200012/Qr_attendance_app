import 'package:equatable/equatable.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';

sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message =
        'Unable to reach the server. Please verify your internet connection.',
  ]) : super(code: 'NETWORK_ERROR');
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([
    super.message = 'The server took too long to respond. Please retry.',
  ]) : super(code: 'TIMEOUT');
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'Authentication required or session expired.',
  ]) : super(code: 'UNAUTHORIZED');
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure([
    super.message = 'Access denied for your account role.',
  ]) : super(code: 'FORBIDDEN');
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code = 'SERVER_ERROR'});
}

class QrValidationFailure extends Failure {
  const QrValidationFailure({
    required this.reason,
    required String message,
  }) : super(message, code: 'QR_VALIDATION_ERROR');

  final QrValidationErrorCode reason;

  @override
  List<Object?> get props => [message, code, reason];
}

class LocationFailure extends Failure {
  const LocationFailure(
    super.message, {
    this.errorType = LocationErrorType.unavailable,
    this.isPermissionDeniedForever = false,
    this.isServiceDisabled = false,
  }) : super(code: 'LOCATION_ERROR');

  final LocationErrorType errorType;
  final bool isPermissionDeniedForever;
  final bool isServiceDisabled;

  @override
  List<Object?> get props => [
        message,
        code,
        errorType,
        isPermissionDeniedForever,
        isServiceDisabled,
      ];
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local storage operation failed.'])
      : super(code: 'CACHE_ERROR');
}

Failure mapExceptionToFailure(Object error) {
  return switch (error) {
    NetworkException(:final message) => NetworkFailure(message),
    TimeoutException(:final message) => TimeoutFailure(message),
    UnauthorizedException(:final message) => UnauthorizedFailure(message),
    ForbiddenException(:final message) => ForbiddenFailure(message),
    QrValidationException(:final reason, :final message) =>
      QrValidationFailure(reason: reason, message: message),
    LocationException(
      :final message,
      :final errorType,
      :final isPermissionDeniedForever,
      :final isServiceDisabled,
    ) =>
      LocationFailure(
        message,
        errorType: errorType,
        isPermissionDeniedForever: isPermissionDeniedForever,
        isServiceDisabled: isServiceDisabled,
      ),
    CacheException(:final message) => CacheFailure(message),
    ServerException(:final message, :final code) =>
      ServerFailure(message, code: code),
    _ => ServerFailure('Unexpected error: $error'),
  };
}

