import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/admin_dashboard_summary_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/employee_attendance_item_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/failed_attempt_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/repositories/admin_repository.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._remoteDataSource);

  final AdminRemoteDataSource _remoteDataSource;

  @override
  Future<Result<AdminDashboardSummaryEntity>> getAdminDashboard({
    required DateTime date,
    required String userRole,
  }) async {
    if (userRole.toLowerCase() != 'admin') {
      return const ResultFailure(
        UnauthorizedFailure(
          'Administrator privileges are required to access all employee attendance records.',
        ),
      );
    }

    try {
      final dateKey = DateTimeUtils.toDateKey(date);

      final employeesFuture = _remoteDataSource.fetchEmployees(limit: 30);
      final recordsFuture = _remoteDataSource.fetchAttendanceByDate(
        dateKey: dateKey,
        userRole: userRole,
      );

      final results = await Future.wait<dynamic>([
        employeesFuture,
        recordsFuture,
      ]);

      final employees = results[0] as List<UserEntity>;
      final records = results[1] as List<AttendanceRecordEntity>;

      final recordByUserId = <int, AttendanceRecordEntity>{
        for (final rec in records) rec.userId: rec,
      };

      var checkedInCount = 0;
      var completedCount = 0;
      var lateCount = 0;
      var absentCount = 0;

      final items = employees.map((emp) {
        final rec = recordByUserId[emp.id];
        final status = rec?.status ?? AttendanceStatus.notCheckedIn;
        switch (status) {
          case AttendanceStatus.checkedIn:
            checkedInCount++;
          case AttendanceStatus.completed:
            completedCount++;
          case AttendanceStatus.notCheckedIn:
            absentCount++;
        }
        if (rec != null && rec.isLate) {
          lateCount++;
        }
        return EmployeeAttendanceItemEntity(
          employee: emp,
          status: status,
          record: rec,
        );
      }).toList()
        ..sort((a, b) {
          final priorityA = a.isPresent ? 0 : 1;
          final priorityB = b.isPresent ? 0 : 1;
          if (priorityA != priorityB) return priorityA.compareTo(priorityB);
          return a.employee.fullName.compareTo(b.employee.fullName);
        });

      return Success(
        AdminDashboardSummaryEntity(
          dateKey: dateKey,
          totalEmployees: employees.length,
          presentCount: checkedInCount + completedCount,
          checkedInCount: checkedInCount,
          completedCount: completedCount,
          lateCount: lateCount,
          absentCount: absentCount,
          employees: items,
        ),
      );
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<List<FailedAttemptEntity>>> getFailedAttempts({
    required String userRole,
    DateTime? date,
  }) async {
    if (userRole.toLowerCase() != 'admin') {
      return const ResultFailure(
        UnauthorizedFailure(
          'Administrator privileges are required to view failed attendance attempts.',
        ),
      );
    }

    try {
      final dateKey = date == null ? null : DateTimeUtils.toDateKey(date);
      final attempts = await _remoteDataSource.fetchFailedAttempts(
        dateKey: dateKey,
        userRole: userRole,
      );

      final nameByUserId = <int, String>{};
      try {
        final employees = await _remoteDataSource.fetchEmployees(limit: 30);
        for (final emp in employees) {
          nameByUserId[emp.id] = emp.fullName;
        }
      } catch (_) {
        // Fallback to employee ID badge when user directory is unreachable.
      }

      final enriched = attempts.map((attempt) {
        final resolvedName =
            attempt.employeeName ?? nameByUserId[attempt.employeeId];
        return resolvedName == null
            ? attempt
            : attempt.copyWith(employeeName: resolvedName);
      }).toList();

      return Success(enriched);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<UserEntity>> getEmployeeDetail(int userId) async {
    try {
      final employee = await _remoteDataSource.fetchEmployeeById(userId);
      return Success(employee);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }
}

