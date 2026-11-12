import 'package:dio/dio.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';

class NetworkExceptionMapper {
  const NetworkExceptionMapper._();

  static AppException fromDioException(DioException error) {
    final underlying = error.error;
    if (underlying is AppException) {
      return underlying;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutException(
          'Request timed out while contacting the server. Please try again.',
        );
      case DioExceptionType.connectionError:
        return const NetworkException(
          'Network connection unavailable. Please check your internet connection.',
        );
      case DioExceptionType.badCertificate:
        return const NetworkException(
          'Secure connection could not be verified.',
        );
      case DioExceptionType.cancel:
        return const ServerException('Request was cancelled.', code: 'CANCELLED');
      case DioExceptionType.badResponse:
        return _fromResponse(error.response);
      case DioExceptionType.unknown:
        final msg = error.message ?? '';
        if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
          return const NetworkException();
        }
        return ServerException(
          msg.isNotEmpty ? msg : 'An unexpected network error occurred.',
        );
    }
  }

  static AppException _fromResponse(Response<dynamic>? response) {
    final statusCode = response?.statusCode;
    final data = response?.data;
    String message = 'Request failed with status $statusCode.';
    String? errorCode;

    if (data is Map<String, dynamic>) {
      final rawMsg = data['message'] ?? data['error'];
      if (rawMsg is String && rawMsg.trim().isNotEmpty) {
        message = rawMsg.trim();
      }
      final rawCode = data['code'];
      if (rawCode is String && rawCode.trim().isNotEmpty) {
        errorCode = rawCode.trim();
      }
    }

    if (errorCode != null) {
      final qrReason = _mapQrErrorCode(errorCode);
      if (qrReason != null) {
        return QrValidationException(reason: qrReason, message: message);
      }
    }

    return switch (statusCode) {
      401 => UnauthorizedException(message),
      403 => ForbiddenException(message),
      _ => ServerException(
          message,
          code: errorCode ?? 'HTTP_${statusCode ?? 500}',
          statusCode: statusCode,
        ),
    };
  }

  static QrValidationErrorCode? _mapQrErrorCode(String code) {
    return switch (code) {
      'QR_MALFORMED' => QrValidationErrorCode.malformed,
      'QR_INVALID_SIGNATURE' => QrValidationErrorCode.invalidSignature,
      'QR_EXPIRED' => QrValidationErrorCode.expired,
      'SESSION_INACTIVE' => QrValidationErrorCode.inactiveSession,
      'DUPLICATE_CHECK_IN' => QrValidationErrorCode.duplicateCheckIn,
      'NO_ACTIVE_CHECK_IN' => QrValidationErrorCode.noActiveCheckIn,
      'ALREADY_CHECKED_OUT' => QrValidationErrorCode.alreadyCheckedOut,
      'OUTSIDE_GEOFENCE' => QrValidationErrorCode.outsideGeofence,
      'QR_REPLAY' => QrValidationErrorCode.replayDetected,
      _ => null,
    };
  }
}
