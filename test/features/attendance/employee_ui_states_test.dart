import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_attendance_app/core/constants/app_constants.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_summary_entity.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_event.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_state.dart';
import 'package:qr_attendance_app/features/attendance/presentation/pages/attendance_history_page.dart';
import 'package:qr_attendance_app/features/attendance/presentation/pages/employee_dashboard_page.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_event.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_state.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAttendanceBloc extends MockBloc<AttendanceEvent, AttendanceState>
    implements AttendanceBloc {}

void main() {
  const employee = UserEntity(
    id: 26,
    username: 'emily',
    email: 'emily@company.com',
    firstName: 'Evelyn',
    lastName: 'Carter',
    image: '',
    phone: '123456',
    department: 'Engineering',
    jobTitle: 'Developer',
    companyName: 'HQ',
    role: 'employee',
  );

  AttendanceRecordEntity buildRecord(
    String id, {
    bool isPendingSync = false,
  }) =>
      AttendanceRecordEntity(
        id: id,
        userId: 26,
        workDate: '2026-11-12',
        sessionId: 'sess_1',
        locationName: 'HQ Campus',
        status: AttendanceStatus.checkedIn,
        checkInAt: DateTime.utc(2026, 11, 12, 9, 0),
        checkInLat: 12.9716,
        checkInLng: 77.5946,
        isPendingSync: isPendingSync,
      );

  Widget wrapWithBlocs({
    required AuthBloc authBloc,
    required AttendanceBloc attendanceBloc,
    required Widget child,
  }) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<AttendanceBloc>.value(value: attendanceBloc),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('Employee UI states & rules', () {
    late _MockAuthBloc authBloc;
    late _MockAttendanceBloc attendanceBloc;

    setUp(() {
      authBloc = _MockAuthBloc();
      attendanceBloc = _MockAttendanceBloc();
      when(() => authBloc.state).thenReturn(
        const AuthState(status: AuthStatus.authenticated, user: employee),
      );
    });

    testWidgets(
        'Dashboard shows empty state, caps recent records to 3, and reflects Checked In status',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => attendanceBloc.state).thenReturn(
        AttendanceState(
          dashboardStatus: AttendanceLoadStatus.loaded,
          todayOverview: TodayAttendanceOverview(
            workDate: '2026-11-12',
            status: AttendanceStatus.checkedIn,
            todayRecord: buildRecord('today'),
            summary: AttendanceSummaryEntity.empty(),
            recentRecords: [
              buildRecord('r1'),
              buildRecord('r2'),
              buildRecord('r3'),
              buildRecord('r4'),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        wrapWithBlocs(
          authBloc: authBloc,
          attendanceBloc: attendanceBloc,
          child: const EmployeeDashboardPage(),
        ),
      );

      expect(find.text('Checked In'), findsAtLeastNWidgets(1));
      expect(find.text('Already checked in'), findsOneWidget);
      expect(find.text('Scan to end shift'), findsOneWidget);
      // 4 recent records passed, capped to 3 tiles rendered under Recent Attendance.
      expect(find.text('HQ Campus'), findsNWidgets(3));
    });

    testWidgets('Dashboard shows exact empty text when no records exist',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => attendanceBloc.state).thenReturn(
        AttendanceState(
          dashboardStatus: AttendanceLoadStatus.loaded,
          todayOverview: TodayAttendanceOverview(
            workDate: '2026-11-12',
            status: AttendanceStatus.notCheckedIn,
            summary: AttendanceSummaryEntity.empty(),
            recentRecords: const [],
          ),
        ),
      );

      await tester.pumpWidget(
        wrapWithBlocs(
          authBloc: authBloc,
          attendanceBloc: attendanceBloc,
          child: const EmployeeDashboardPage(),
        ),
      );

      expect(find.text('No attendance records yet'), findsOneWidget);
    });

    testWidgets('History shows Pending sync badge on queued records',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => attendanceBloc.state).thenReturn(
        AttendanceState(
          historyStatus: AttendanceLoadStatus.loaded,
          historyRecords: [buildRecord('p1', isPendingSync: true)],
        ),
      );

      await tester.pumpWidget(
        wrapWithBlocs(
          authBloc: authBloc,
          attendanceBloc: attendanceBloc,
          child: const AttendanceHistoryPage(),
        ),
      );

      expect(find.text('Pending sync'), findsOneWidget);
      expect(AppConstants.enableManualPayloadEntry, isTrue);
    });

    testWidgets(
        'History shows filtered empty state when active filter has no records',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => attendanceBloc.state).thenReturn(
        const AttendanceState(
          historyStatus: AttendanceLoadStatus.loaded,
          statusFilter: 'completed',
          historyRecords: [],
        ),
      );

      await tester.pumpWidget(
        wrapWithBlocs(
          authBloc: authBloc,
          attendanceBloc: attendanceBloc,
          child: const AttendanceHistoryPage(),
        ),
      );

      expect(find.text('No records match your filter.'), findsOneWidget);
    });

    testWidgets('History shows Retry button when load fails', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => attendanceBloc.state).thenReturn(
        const AttendanceState(
          historyStatus: AttendanceLoadStatus.failure,
          historyError: 'No internet connection.',
          historyRecords: [],
        ),
      );

      await tester.pumpWidget(
        wrapWithBlocs(
          authBloc: authBloc,
          attendanceBloc: attendanceBloc,
          child: const AttendanceHistoryPage(),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
