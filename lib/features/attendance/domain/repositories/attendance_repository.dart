import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_summary_entity.dart';

abstract class AttendanceRepository {
  Future<Result<TodayAttendanceOverview>> getTodayOverview({
    required int userId,
  });

  Future<Result<AttendanceHistoryResult>> getAttendanceHistory({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
    String statusFilter = 'all',
  });
}

