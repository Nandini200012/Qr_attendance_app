import 'package:qr_attendance_app/core/constants/app_constants.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_session_entity.dart';

class QrSessionModel extends QrSessionEntity {
  const QrSessionModel({
    required super.sessionId,
    required super.nonce,
    required super.locationName,
    required super.issuedAt,
    required super.expiresAt,
    required super.validitySeconds,
    required super.rawQrPayload,
    required super.isActive,
    super.geofenceLat,
    super.geofenceLng,
    super.geofenceRadiusMeters,
  });

  factory QrSessionModel.fromJson(Map<String, dynamic> json) {
    return QrSessionModel(
      sessionId: (json['sessionId'] as String?) ?? '',
      nonce: (json['nonce'] as String?) ?? '',
      locationName: (json['locationName'] as String?) ?? 'HQ Campus',
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      validitySeconds: (json['validitySeconds'] as num?)?.toInt() ??
          AppConstants.qrValiditySeconds,
      rawQrPayload: (json['rawQrPayload'] as String?) ?? '',
      isActive: (json['isActive'] as bool?) ?? true,
      geofenceLat: (json['geofenceLat'] as num?)?.toDouble(),
      geofenceLng: (json['geofenceLng'] as num?)?.toDouble(),
      geofenceRadiusMeters: (json['geofenceRadiusMeters'] as num?)?.toDouble(),
    );
  }
}

