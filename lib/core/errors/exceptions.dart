enum QrValidationErrorCode {
  malformed,
  invalidSignature,
  expired,
  inactiveSession,
  duplicateCheckIn,
  noActiveCheckIn,
  alreadyCheckedOut,
  outsideGeofence,
  replayDetected,
}

sealed class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

class NetworkException extends AppException {
  const NetworkException([
    super.message =
        'No internet connection. Please check your network and try again.',
  ]) : super(code: 'NETWORK_ERROR');
}

class TimeoutException extends AppException {
  const TimeoutException([
    super.message = 'Request timed out. Please try again.',
  ]) : super(code: 'TIMEOUT');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([
    super.message = 'Your session has expired. Please sign in again.',
  ]) : super(code: 'UNAUTHORIZED');
}

class ForbiddenException extends AppException {
  const ForbiddenException([
    super.message = 'You do not have permission to perform this action.',
  ]) : super(code: 'FORBIDDEN');
}

class ServerException extends AppException {
  const ServerException(
    super.message, {
    super.code = 'SERVER_ERROR',
    this.statusCode,
  });

  final int? statusCode;
}

class QrValidationException extends AppException {
  const QrValidationException({
    required this.reason,
    required String message,
  }) : super(message, code: 'QR_VALIDATION_ERROR');

  final QrValidationErrorCode reason;
}

enum LocationErrorType {
  permissionDenied,
  permissionDeniedForever,
  servicesDisabled,
  timeout,
  unavailable,
}

class LocationException extends AppException {
  const LocationException(
    super.message, {
    this.errorType = LocationErrorType.unavailable,
    this.isPermissionDeniedForever = false,
    this.isServiceDisabled = false,
  }) : super(code: 'LOCATION_ERROR');

  final LocationErrorType errorType;
  final bool isPermissionDeniedForever;
  final bool isServiceDisabled;
}

class CacheException extends AppException {
  const CacheException([
    super.message = 'Failed to access local storage.',
  ]) : super(code: 'CACHE_ERROR');
}

