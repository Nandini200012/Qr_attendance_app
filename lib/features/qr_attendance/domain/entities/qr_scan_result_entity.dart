import 'package:equatable/equatable.dart';
import 'package:qr_attendance_app/core/services/location_service.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';

class QrScanResultEntity extends Equatable {
  const QrScanResultEntity({
    required this.action,
    required this.message,
    required this.serverTimestamp,
    required this.record,
    required this.capturedLocation,
    this.isOfflineQueued = false,
  });

  final String action;
  final String message;
  final DateTime serverTimestamp;
  final AttendanceRecordEntity record;
  final CapturedLocation capturedLocation;
  final bool isOfflineQueued;

  bool get isCheckIn => action == 'check_in';

  @override
  List<Object?> get props => [
        action,
        message,
        serverTimestamp,
        record,
        capturedLocation,
        isOfflineQueued,
      ];
}

