import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';

/// Maps internal [Failure], [AppException], and camera scanner errors into
/// clear, user-facing copy without exposing raw enum or exception names.
class ErrorMessageMapper {
  const ErrorMessageMapper._();

  static String fromFailure(Failure failure) {
    return switch (failure) {
      NetworkFailure() =>
        'No internet connection. Please check your network and try again.',
      TimeoutFailure(:final message) => _friendlyOrFallback(
          message,
          'The server took too long to respond. Please retry.',
        ),
      UnauthorizedFailure(:final message) => _friendlyOrFallback(
          message,
          'Your session has expired or is unauthorized. Please sign in again.',
        ),
      ForbiddenFailure(:final message) => _friendlyOrFallback(
          message,
          'Your account does not have permission for this action.',
        ),
      QrValidationFailure(:final reason, :final message) =>
        fromQrReason(reason, serverMessage: message),
      LocationFailure(:final errorType, :final isServiceDisabled, :final isPermissionDeniedForever) =>
        _fromLocationError(
          errorType: errorType,
          isServiceDisabled: isServiceDisabled,
          isPermissionDeniedForever: isPermissionDeniedForever,
        ),
      CacheFailure() =>
        'Unable to save or read local attendance data on this device.',
      ServerFailure(:final message) => _friendlyOrFallback(
          message,
          'Something went wrong on the server. Please try again shortly.',
        ),
    };
  }

  static String fromException(Object error) {
    if (error is MobileScannerException) {
      return fromCameraError(error);
    }
    if (error is Failure) {
      return fromFailure(error);
    }
    return fromFailure(mapExceptionToFailure(error));
  }

  static String fromQrReason(
    QrValidationErrorCode reason, {
    String? serverMessage,
  }) {
    switch (reason) {
      case QrValidationErrorCode.expired:
        return 'This QR code has expired (codes are valid for 30 seconds). Ask your admin for a new QR code.';
      case QrValidationErrorCode.duplicateCheckIn:
        return 'You have already checked in today. Duplicate check-in is not allowed.';
      case QrValidationErrorCode.replayDetected:
        return 'This QR code was already used for this action. Wait for the next QR refresh.';
      case QrValidationErrorCode.invalidSignature:
        return 'This QR code failed security verification and may be tampered with. Please scan an official kiosk QR.';
      case QrValidationErrorCode.malformed:
        return 'Invalid or unrecognized QR code payload. Please scan an official attendance QR code.';
      case QrValidationErrorCode.inactiveSession:
        return 'This QR session is no longer active because a newer code was generated. Please scan the latest QR.';
      case QrValidationErrorCode.outsideGeofence:
        if (serverMessage != null &&
            serverMessage.contains('Outside allowed office radius')) {
          return '$serverMessage Move inside the 250m office boundary and try again.';
        }
        return 'You are outside the 250m office geofence radius. Move closer to your office location and retry.';
      case QrValidationErrorCode.alreadyCheckedOut:
        return 'You have already checked in and checked out today.';
      case QrValidationErrorCode.noActiveCheckIn:
        return 'You have not checked in yet today. Please complete Check In before checking out.';
    }
  }

  static String fromCameraError(MobileScannerException error) {
    return switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => kIsWeb
          ? 'Camera access is blocked in your browser. Click the lock icon next to the address bar, allow Camera, then reload.'
          : 'Camera permission was denied. Allow Camera access in your device settings to scan attendance QR codes.',
      MobileScannerErrorCode.unsupported =>
        'Camera scanning is unavailable on this device or browser.',
      MobileScannerErrorCode.controllerAlreadyInitialized ||
      MobileScannerErrorCode.controllerDisposed ||
      MobileScannerErrorCode.controllerInitializing ||
      MobileScannerErrorCode.controllerUninitialized ||
      MobileScannerErrorCode.controllerNotAttached =>
        'Camera is restarting. Wait a moment or tap Retry.',
      MobileScannerErrorCode.genericError =>
        'Unable to open the camera preview right now. Please check camera permissions and try again.',
    };
  }

  static String _fromLocationError({
    required LocationErrorType errorType,
    required bool isServiceDisabled,
    required bool isPermissionDeniedForever,
  }) {
    if (isServiceDisabled || errorType == LocationErrorType.servicesDisabled) {
      return 'Location services (GPS) are turned off. Please enable GPS to mark attendance.';
    }
    if (isPermissionDeniedForever ||
        errorType == LocationErrorType.permissionDeniedForever) {
      return kIsWeb
          ? 'Location permission is blocked. Click the lock icon next to the address bar, allow Location, then reload.'
          : 'Location permission is permanently denied. Enable Location access in Settings to mark attendance.';
    }
    return switch (errorType) {
      LocationErrorType.permissionDenied => kIsWeb
          ? 'Location access is required. Click the lock icon next to the address bar, allow Location, then reload.'
          : 'Location permission was denied. Allow location access and retry to mark attendance.',
      LocationErrorType.timeout =>
        'GPS signal timed out while reading your coordinates. Move near an open window and retry.',
      LocationErrorType.servicesDisabled =>
        'Location services (GPS) are turned off. Please enable GPS to mark attendance.',
      LocationErrorType.permissionDeniedForever =>
        'Location permission is permanently denied. Enable Location access in Settings.',
      LocationErrorType.unavailable =>
        'Unable to determine your GPS location. Please ensure location access is enabled and retry.',
    };
  }

  static String _friendlyOrFallback(String raw, String fallback) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback;
    final lower = trimmed.toLowerCase();
    if (lower.contains('exception') ||
        lower.contains('socket') ||
        lower.contains('formatexception') ||
        lower.startsWith('unexpected error:')) {
      return fallback;
    }
    return trimmed;
  }
}
