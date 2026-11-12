import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/admin_dashboard_summary_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/employee_attendance_item_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/failed_attempt_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/repositories/admin_repository.dart';
import 'package:qr_attendance_app/features/admin/domain/usecases/get_admin_dashboard_usecase.dart';
import 'package:qr_attendance_app/features/admin/domain/usecases/get_employee_detail_usecase.dart';
import 'package:qr_attendance_app/features/admin/domain/usecases/get_failed_attempts_usecase.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_event.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_state.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/repositories/qr_attendance_repository.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/generate_qr_session_usecase.dart';

class _MockGetAdminDashboardUseCase extends Mock
    implements GetAdminDashboardUseCase {}

class _MockGetEmployeeDetailUseCase extends Mock
    implements GetEmployeeDetailUseCase {}

class _MockGetFailedAttemptsUseCase extends Mock
    implements GetFailedAttemptsUseCase {}

class _MockAdminRepository extends Mock implements AdminRepository {}

class _MockQrAttendanceRepository extends Mock
    implements QrAttendanceRepository {}

void main() {
  late _MockGetAdminDashboardUseCase dashboardUseCase;
  late _MockGetEmployeeDetailUseCase detailUseCase;
  late _MockGetFailedAttemptsUseCase failedAttemptsUseCase;

  const emily = UserEntity(
    id: 1,
    username: 'emilys',
    email: 'emily.johnson@x.dummyjson.com',
    firstName: 'Emily',
    lastName: 'Johnson',
    image: '',
    phone: '',
    department: 'Engineering',
    jobTitle: 'Manager',
    companyName: 'Corp',
    role: 'admin',
  );

  const evelyn = UserEntity(
    id: 26,
    username: 'evelyng',
    email: 'evelyn.gonzalez@x.dummyjson.com',
    firstName: 'Evelyn',
    lastName: 'Gonzalez',
    image: '',
    phone: '',
    department: 'Design',
    jobTitle: 'Designer',
    companyName: 'Corp',
    role: 'user',
  );

  final presentItem = EmployeeAttendanceItemEntity(
    employee: emily,
    status: AttendanceStatus.checkedIn,
    record: AttendanceRecordEntity(
      id: 'att_1',
      userId: 1,
      workDate: '2026-11-12',
      sessionId: 'sess_1',
      locationName: 'HQ',
      status: AttendanceStatus.checkedIn,
      checkInAt: DateTime.utc(2026, 11, 12, 9, 0),
      checkInLat: 12.9716,
      checkInLng: 77.5946,
      isLate: true,
    ),
  );

  const absentItem = EmployeeAttendanceItemEntity(
    employee: evelyn,
    status: AttendanceStatus.notCheckedIn,
  );

  final summary = AdminDashboardSummaryEntity(
    dateKey: '2026-11-12',
    totalEmployees: 2,
    presentCount: 1,
    checkedInCount: 1,
    completedCount: 0,
    lateCount: 1,
    absentCount: 1,
    employees: [presentItem, absentItem],
  );

  setUp(() {
    dashboardUseCase = _MockGetAdminDashboardUseCase();
    detailUseCase = _MockGetEmployeeDetailUseCase();
    failedAttemptsUseCase = _MockGetFailedAttemptsUseCase();
  });

  AdminBloc buildBloc() => AdminBloc(
        getAdminDashboardUseCase: dashboardUseCase,
        getEmployeeDetailUseCase: detailUseCase,
        getFailedAttemptsUseCase: failedAttemptsUseCase,
      );

  group('AdminBloc', () {
    blocTest<AdminBloc, AdminState>(
      'loads dashboard summary and filters by search and status',
      setUp: () {
        when(() => dashboardUseCase(
              date: any(named: 'date'),
              userRole: 'admin',
            )).thenAnswer((_) async => Success(summary));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AdminDashboardRequested(userRole: 'admin'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const AdminStatusFilterChanged('late'));
        bloc.add(const AdminStatusFilterChanged('absent'));
        bloc.add(const AdminSearchQueryChanged('Evelyn'));
      },
      expect: () => [
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminLoadStatus.loading),
        isA<AdminState>()
            .having((s) => s.status, 'status', AdminLoadStatus.loaded)
            .having((s) => s.summary?.lateCount, 'lateCount', 1)
            .having((s) => s.filteredEmployees.length, 'count', 2),
        isA<AdminState>()
            .having((s) => s.statusFilter, 'statusFilter', 'late')
            .having((s) => s.filteredEmployees.length, 'count', 1)
            .having(
              (s) => s.filteredEmployees.first.employee.id,
              'employeeId',
              1,
            ),
        isA<AdminState>()
            .having((s) => s.statusFilter, 'statusFilter', 'absent')
            .having((s) => s.filteredEmployees.length, 'count', 1)
            .having(
              (s) => s.filteredEmployees.first.employee.id,
              'employeeId',
              26,
            ),
        isA<AdminState>()
            .having((s) => s.searchQuery, 'searchQuery', 'Evelyn')
            .having((s) => s.filteredEmployees.length, 'count', 1),
      ],
    );

    blocTest<AdminBloc, AdminState>(
      'loads failed attendance attempts for admin console',
      setUp: () {
        when(() => failedAttemptsUseCase(
              userRole: 'admin',
              date: any(named: 'date'),
            )).thenAnswer(
          (_) async => Success([
            FailedAttemptEntity(
              id: 'fail_1',
              employeeId: 26,
              employeeName: 'Evelyn Gonzalez',
              timestamp: DateTime.utc(2026, 11, 12, 9, 5),
              reason: FailedAttemptReason.expired,
              sessionId: 'sess_expired',
              lat: 12.9716,
              lng: 77.5946,
              message: 'QR expired',
            ),
          ]),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AdminFailedAttemptsRequested(userRole: 'admin'),
      ),
      expect: () => [
        isA<AdminState>().having(
          (s) => s.failedAttemptsStatus,
          'failedAttemptsStatus',
          AdminLoadStatus.loading,
        ),
        isA<AdminState>()
            .having(
              (s) => s.failedAttemptsStatus,
              'failedAttemptsStatus',
              AdminLoadStatus.loaded,
            )
            .having((s) => s.failedAttempts.length, 'count', 1)
            .having(
              (s) => s.failedAttempts.first.reason,
              'reason',
              FailedAttemptReason.expired,
            ),
      ],
    );
  });

  group('Admin role enforcement in domain use cases', () {
    test('returns UnauthorizedFailure when non-admin calls admin use cases',
        () async {
      final adminRepo = _MockAdminRepository();
      final qrRepo = _MockQrAttendanceRepository();

      final getDashboard = GetAdminDashboardUseCase(adminRepo);
      final getFailed = GetFailedAttemptsUseCase(adminRepo);
      final genQr = GenerateQrSessionUseCase(qrRepo);

      final dashRes = await getDashboard(
        date: DateTime(2026, 11, 12),
        userRole: 'user',
      );
      expect(dashRes.failureOrNull, isA<UnauthorizedFailure>());

      final failedRes = await getFailed(userRole: 'user');
      expect(failedRes.failureOrNull, isA<UnauthorizedFailure>());

      final qrRes = await genQr(
        locationName: 'HQ',
        createdByUserId: 26,
        userRole: 'user',
      );
      expect(qrRes.failureOrNull, isA<UnauthorizedFailure>());

      verifyZeroInteractions(adminRepo);
      verifyZeroInteractions(qrRepo);
    });
  });
}

