import 'package:qr_attendance_app/features/admin/domain/entities/failed_attempt_entity.dart';

class FailedAttemptModel extends FailedAttemptEntity {
  const FailedAttemptModel({
    required super.id,
    required super.employeeId,
    super.employeeName,
    required super.timestamp,
    required super.reason,
    super.sessionId,
    super.lat,
    super.lng,
    super.message,
  });

  factory FailedAttemptModel.fromJson(Map<String, dynamic> json) {
    return FailedAttemptModel(
      id: (json['id'] as String?) ?? '',
      employeeId: (json['employeeId'] as num?)?.toInt() ?? 0,
      employeeName: json['employeeName'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      reason: FailedAttemptReason.fromWireValue(json['reason'] as String?),
      sessionId: json['sessionId'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'reason': reason.wireValue,
        'sessionId': sessionId,
        'lat': lat,
        'lng': lng,
        'message': message,
      };
}

