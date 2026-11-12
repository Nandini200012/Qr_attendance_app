import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/failed_attempt_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/repositories/admin_repository.dart';

class GetFailedAttemptsUseCase {
  const GetFailedAttemptsUseCase(this._repository);

  final AdminRepository _repository;

  Future<Result<List<FailedAttemptEntity>>> call({
    required String userRole,
    DateTime? date,
  }) {
    if (userRole.toLowerCase() != 'admin') {
      return Future.value(
        const ResultFailure(
          UnauthorizedFailure(
            'Only administrators can view failed attendance attempts.',
          ),
        ),
      );
    }
    return _repository.getFailedAttempts(userRole: userRole, date: date);
  }
}

