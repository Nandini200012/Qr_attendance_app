import 'package:equatable/equatable.dart';

enum AttendanceStatus {
  notCheckedIn,
  checkedIn,
  completed;

  String get label => switch (this) {
        AttendanceStatus.notCheckedIn => 'Not Checked In',
        AttendanceStatus.checkedIn => 'Checked In',
        AttendanceStatus.completed => 'Completed',
      };
}

class AttendanceRecordEntity extends Equatable {
  const AttendanceRecordEntity({
    required this.id,
    required this.userId,
    required this.workDate,
    required this.sessionId,
    required this.locationName,
    required this.status,
    required this.checkInAt,
    required this.checkInLat,
    required this.checkInLng,
    this.checkInAccuracyMeters,
    this.checkOutAt,
    this.checkOutLat,
    this.checkOutLng,
    this.checkOutAccuracyMeters,
    this.durationMinutes,
    this.distanceMeters,
    this.geofenceEnforced = false,
    this.geofenceRadiusMeters,
    this.isLate = false,
    this.serverVerified = true,
    this.isPendingSync = false,
  });

  final String id;
  final int userId;
  final String workDate;
  final String sessionId;
  final String locationName;
  final AttendanceStatus status;
  final DateTime checkInAt;
  final double checkInLat;
  final double checkInLng;
  final double? checkInAccuracyMeters;
  final DateTime? checkOutAt;
  final double? checkOutLat;
  final double? checkOutLng;
  final double? checkOutAccuracyMeters;
  final int? durationMinutes;
  final double? distanceMeters;
  final bool geofenceEnforced;
  final double? geofenceRadiusMeters;
  final bool isLate;
  final bool serverVerified;
  final bool isPendingSync;

  bool? get isInsideGeofence {
    if (!geofenceEnforced) return null;
    if (distanceMeters == null) return true;
    final limit = geofenceRadiusMeters ?? 250.0;
    return distanceMeters! <= limit;
  }

  int get effectiveDurationMinutes {
    if (durationMinutes != null) return durationMinutes!;
    if (checkOutAt != null) {
      return checkOutAt!.difference(checkInAt).inMinutes.clamp(0, 1440);
    }
    return DateTime.now().toUtc().difference(checkInAt).inMinutes.clamp(0, 1440);
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        workDate,
        sessionId,
        locationName,
        status,
        checkInAt,
        checkInLat,
        checkInLng,
        checkInAccuracyMeters,
        checkOutAt,
        checkOutLat,
        checkOutLng,
        checkOutAccuracyMeters,
        durationMinutes,
        distanceMeters,
        geofenceEnforced,
        geofenceRadiusMeters,
        isLate,
        serverVerified,
        isPendingSync,
      ];
}

