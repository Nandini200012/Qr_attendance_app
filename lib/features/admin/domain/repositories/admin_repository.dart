import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/admin_dashboard_summary_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/failed_attempt_entity.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';

abstract class AdminRepository {
  Future<Result<AdminDashboardSummaryEntity>> getAdminDashboard({
    required DateTime date,
    required String userRole,
  });

  Future<Result<List<FailedAttemptEntity>>> getFailedAttempts({
    required String userRole,
    DateTime? date,
  });

  Future<Result<UserEntity>> getEmployeeDetail(int userId);
}

