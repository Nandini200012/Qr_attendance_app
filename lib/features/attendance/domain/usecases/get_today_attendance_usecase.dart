import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_summary_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/repositories/attendance_repository.dart';

class GetTodayAttendanceUseCase {
  const GetTodayAttendanceUseCase(this._repository);

  final AttendanceRepository _repository;

  Future<Result<TodayAttendanceOverview>> call({required int userId}) {
    return _repository.getTodayOverview(userId: userId);
  }
}

