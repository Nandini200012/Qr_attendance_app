import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/repositories/qr_attendance_repository.dart';

class SyncPendingScansUseCase {
  const SyncPendingScansUseCase(this._repository);

  final QrAttendanceRepository _repository;

  Future<Result<int>> call({required int userId}) {
    return _repository.syncPendingScans(userId: userId);
  }
}

