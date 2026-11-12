import 'package:equatable/equatable.dart';

class QrSessionEntity extends Equatable {
  const QrSessionEntity({
    required this.sessionId,
    required this.nonce,
    required this.locationName,
    required this.issuedAt,
    required this.expiresAt,
    required this.validitySeconds,
    required this.rawQrPayload,
    required this.isActive,
    this.geofenceLat,
    this.geofenceLng,
    this.geofenceRadiusMeters,
  });

  final String sessionId;
  final String nonce;
  final String locationName;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int validitySeconds;
  final String rawQrPayload;
  final bool isActive;
  final double? geofenceLat;
  final double? geofenceLng;
  final double? geofenceRadiusMeters;

  bool get hasGeofence => geofenceLat != null && geofenceLng != null;

  int remainingSecondsAt(DateTime nowUtc) {
    final diffMs = expiresAt.toUtc().millisecondsSinceEpoch -
        nowUtc.toUtc().millisecondsSinceEpoch;
    if (diffMs <= 0) return 0;
    return (diffMs / 1000).ceil();
  }

  @override
  List<Object?> get props => [
        sessionId,
        nonce,
        locationName,
        issuedAt,
        expiresAt,
        validitySeconds,
        rawQrPayload,
        isActive,
        geofenceLat,
        geofenceLng,
        geofenceRadiusMeters,
      ];
}

