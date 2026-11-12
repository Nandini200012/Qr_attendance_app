import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_scan_result_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_session_entity.dart';

abstract class QrAttendanceRepository {
  Future<Result<QrSessionEntity>> generateQrSession({
    required String locationName,
    required int createdByUserId,
    required String userRole,
    bool enforceGeofence = false,
  });

  Future<Result<QrSessionEntity?>> getActiveQrSession();

  Future<Result<QrScanResultEntity>> submitQrAttendance({
    required String rawQrPayload,
    required String action,
    required int userId,
  });

  Future<Result<int>> syncPendingScans({required int userId});
}

