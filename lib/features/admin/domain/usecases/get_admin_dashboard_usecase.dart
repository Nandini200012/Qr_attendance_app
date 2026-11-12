import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/admin_dashboard_summary_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/repositories/admin_repository.dart';

class GetAdminDashboardUseCase {
  const GetAdminDashboardUseCase(this._repository);

  final AdminRepository _repository;

  Future<Result<AdminDashboardSummaryEntity>> call({
    required DateTime date,
    required String userRole,
  }) {
    if (userRole.toLowerCase() != 'admin') {
      return Future.value(
        const ResultFailure(
          UnauthorizedFailure(
            'Administrator privileges are required to view all employee attendance records.',
          ),
        ),
      );
    }
    return _repository.getAdminDashboard(date: date, userRole: userRole);
  }
}

