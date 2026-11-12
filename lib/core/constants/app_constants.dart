import 'package:flutter/foundation.dart';

class AppConstants {
  const AppConstants._();

  static const String appName = 'Smart QR Attendance';
  static const String qrAppIdentifier = 'smart_qr_attendance';
  static const int qrValiditySeconds = 30;
  static const int qrClockSkewGraceSeconds = 2;

  /// Demo & testing toggle for manual QR JSON payload entry on the scanner screen.
  /// Automatically enabled only in debug builds ([kDebugMode]) and hidden in release.
  static const bool enableManualPayloadEntry = kDebugMode;

  /// Shared HMAC-SHA256 secret used by the QR signing/verification service layer.
  /// Note: In a production deployment, this secret would live strictly on the
  /// backend server (e.g., KMS/environment secret) and never ship in the client app.
  static const String qrServiceSecret =
      'sqa-assessment-hmac-v1-secret-9c41f7a2';

  static const Duration connectTimeout = Duration(seconds: 12);
  static const Duration receiveTimeout = Duration(seconds: 12);
  static const Duration locationTimeout = Duration(seconds: 10);

  static const double defaultGeofenceRadiusMeters = 250.0;

  /// Corporate shift start (09:00 AM local) with 15-minute grace period.
  static const int shiftStartHour = 9;
  static const int shiftLateGraceMinutes = 15;
}

