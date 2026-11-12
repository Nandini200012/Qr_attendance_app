import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';

class AttendanceRecordModel extends AttendanceRecordEntity {
  const AttendanceRecordModel({
    required super.id,
    required super.userId,
    required super.workDate,
    required super.sessionId,
    required super.locationName,
    required super.status,
    required super.checkInAt,
    required super.checkInLat,
    required super.checkInLng,
    super.checkInAccuracyMeters,
    super.checkOutAt,
    super.checkOutLat,
    super.checkOutLng,
    super.checkOutAccuracyMeters,
    super.durationMinutes,
    super.distanceMeters,
    super.geofenceEnforced = false,
    super.geofenceRadiusMeters,
    super.isLate = false,
    super.serverVerified = true,
    super.isPendingSync = false,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] as String?) ?? 'checked_in';
    final status = switch (statusRaw) {
      'completed' => AttendanceStatus.completed,
      'checked_in' => AttendanceStatus.checkedIn,
      _ => AttendanceStatus.notCheckedIn,
    };

    final checkInAt = DateTime.parse(json['checkInAt'] as String);
    final rawIsLate = json['isLate'];
    final isLate = rawIsLate is bool
        ? rawIsLate
        : rawIsLate is num
            ? rawIsLate != 0
            : DateTimeUtils.isLateCheckIn(checkInAt);

    final rawGeofenceEnforced = json['geofenceEnforced'];
    final geofenceEnforced = rawGeofenceEnforced is bool
        ? rawGeofenceEnforced
        : rawGeofenceEnforced is num
            ? rawGeofenceEnforced != 0
            : false;

    return AttendanceRecordModel(
      id: (json['id'] as String?) ?? '',
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      workDate: (json['workDate'] as String?) ?? '',
      sessionId: (json['sessionId'] as String?) ?? '',
      locationName: (json['locationName'] as String?) ?? 'Main Office',
      status: status,
      checkInAt: checkInAt,
      checkInLat: (json['checkInLat'] as num).toDouble(),
      checkInLng: (json['checkInLng'] as num).toDouble(),
      checkInAccuracyMeters: (json['checkInAccuracyMeters'] as num?)?.toDouble(),
      checkOutAt: json['checkOutAt'] != null
          ? DateTime.parse(json['checkOutAt'] as String)
          : null,
      checkOutLat: (json['checkOutLat'] as num?)?.toDouble(),
      checkOutLng: (json['checkOutLng'] as num?)?.toDouble(),
      checkOutAccuracyMeters:
          (json['checkOutAccuracyMeters'] as num?)?.toDouble(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      geofenceEnforced: geofenceEnforced,
      geofenceRadiusMeters:
          (json['geofenceRadiusMeters'] as num?)?.toDouble(),
      isLate: isLate,
      serverVerified: (json['serverVerified'] as bool?) ?? true,
      isPendingSync: (json['isPendingSync'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'workDate': workDate,
        'sessionId': sessionId,
        'locationName': locationName,
        'status': switch (status) {
          AttendanceStatus.completed => 'completed',
          AttendanceStatus.checkedIn => 'checked_in',
          AttendanceStatus.notCheckedIn => 'not_checked_in',
        },
        'checkInAt': checkInAt.toUtc().toIso8601String(),
        'checkInLat': checkInLat,
        'checkInLng': checkInLng,
        'checkInAccuracyMeters': checkInAccuracyMeters,
        'checkOutAt': checkOutAt?.toUtc().toIso8601String(),
        'checkOutLat': checkOutLat,
        'checkOutLng': checkOutLng,
        'checkOutAccuracyMeters': checkOutAccuracyMeters,
        'durationMinutes': durationMinutes,
        'distanceMeters': distanceMeters,
        'geofenceEnforced': geofenceEnforced,
        'geofenceRadiusMeters': geofenceRadiusMeters,
        'isLate': isLate,
        'serverVerified': serverVerified,
      };
}

