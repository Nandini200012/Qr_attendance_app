import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_summary_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/repositories/attendance_repository.dart';

class GetAttendanceHistoryUseCase {
  const GetAttendanceHistoryUseCase(this._repository);

  final AttendanceRepository _repository;

  Future<Result<AttendanceHistoryResult>> call({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
    String statusFilter = 'all',
  }) {
    return _repository.getAttendanceHistory(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      statusFilter: statusFilter,
    );
  }
}

