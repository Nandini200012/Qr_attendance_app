import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/core/network/auth_interceptor.dart';
import 'package:qr_attendance_app/core/router/app_router.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/admin_dashboard_summary_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/usecases/get_admin_dashboard_usecase.dart';
import 'package:qr_attendance_app/features/admin/domain/usecases/get_employee_detail_usecase.dart';
import 'package:qr_attendance_app/features/admin/domain/usecases/get_failed_attempts_usecase.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_summary_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/usecases/get_attendance_history_usecase.dart';
import 'package:qr_attendance_app/features/attendance/domain/usecases/get_today_attendance_usecase.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/get_current_user_usecase.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/login_usecase.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/logout_usecase.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_event.dart';

class _MockLoginUseCase extends Mock implements LoginUseCase {}

class _MockGetCurrentUserUseCase extends Mock
    implements GetCurrentUserUseCase {}

class _MockLogoutUseCase extends Mock implements LogoutUseCase {}

class _MockGetTodayAttendanceUseCase extends Mock
    implements GetTodayAttendanceUseCase {}

class _MockGetAttendanceHistoryUseCase extends Mock
    implements GetAttendanceHistoryUseCase {}

class _MockGetAdminDashboardUseCase extends Mock
    implements GetAdminDashboardUseCase {}

class _MockGetEmployeeDetailUseCase extends Mock
    implements GetEmployeeDetailUseCase {}

class _MockGetFailedAttemptsUseCase extends Mock
    implements GetFailedAttemptsUseCase {}

void main() {
  const adminUser = UserEntity(
    id: 1,
    username: 'emilys',
    email: 'emily.johnson@x.dummyjson.com',
    firstName: 'Emily',
    lastName: 'Johnson',
    image: '',
    phone: '',
    department: 'Engineering',
    jobTitle: 'Engineering Manager',
    companyName: 'Corp',
    role: 'admin',
  );

  const employeeUser = UserEntity(
    id: 26,
    username: 'evelyng',
    email: 'evelyn.gonzalez@x.dummyjson.com',
    firstName: 'Evelyn',
    lastName: 'Gonzalez',
    image: '',
    phone: '',
    department: 'Design',
    jobTitle: 'Product Designer',
    companyName: 'Corp',
    role: 'user',
  );

  Widget buildTestApp({
    required AuthBloc authBloc,
    required AppRouter appRouter,
    required AttendanceBloc attendanceBloc,
    required AdminBloc adminBloc,
  }) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<AttendanceBloc>.value(value: attendanceBloc),
        BlocProvider<AdminBloc>.value(value: adminBloc),
      ],
      child: MaterialApp.router(
        routerConfig: appRouter.router,
      ),
    );
  }

  testWidgets('Employee hides Admin tab and blocks /admin routes',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final getCurrentUser = _MockGetCurrentUserUseCase();
    final getToday = _MockGetTodayAttendanceUseCase();
    final getHistory = _MockGetAttendanceHistoryUseCase();
    final getAdminDashboard = _MockGetAdminDashboardUseCase();
    final getEmployeeDetail = _MockGetEmployeeDetailUseCase();
    final getFailedAttempts = _MockGetFailedAttemptsUseCase();
    final sessionEvents = AuthSessionEvents();

    when(() => getCurrentUser.checkSession())
        .thenAnswer((_) async => const Success(employeeUser));
    when(() => getToday(userId: 26)).thenAnswer(
      (_) async => const Success(
        TodayAttendanceOverview(
          workDate: '2026-11-12',
          status: AttendanceStatus.notCheckedIn,
          summary: AttendanceSummaryEntity.empty(),
          recentRecords: [],
        ),
      ),
    );

    final authBloc = AuthBloc(
      loginUseCase: _MockLoginUseCase(),
      getCurrentUserUseCase: getCurrentUser,
      logoutUseCase: _MockLogoutUseCase(),
      sessionEvents: sessionEvents,
    );
    final attendanceBloc = AttendanceBloc(
      getTodayAttendanceUseCase: getToday,
      getAttendanceHistoryUseCase: getHistory,
    );
    final adminBloc = AdminBloc(
      getAdminDashboardUseCase: getAdminDashboard,
      getEmployeeDetailUseCase: getEmployeeDetail,
      getFailedAttemptsUseCase: getFailedAttempts,
    );
    final appRouter = AppRouter(authBloc);

    addTearDown(() async {
      appRouter.dispose();
      await authBloc.close();
      await attendanceBloc.close();
      await adminBloc.close();
      await sessionEvents.dispose();
    });

    authBloc.add(const AuthCheckRequested());
    await tester.pumpWidget(
      buildTestApp(
        authBloc: authBloc,
        appRouter: appRouter,
        attendanceBloc: attendanceBloc,
        adminBloc: adminBloc,
      ),
    );
    await tester.pumpAndSettle();

    // Employee lands on Dashboard with Employee tabs and no Admin Console tab
    expect(find.text('Attendance Dashboard'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Console'), findsNothing);
    expect(find.text('QR Kiosk'), findsNothing);

    // Attempting to navigate to /admin redirects back to /dashboard
    appRouter.router.go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('Attendance Dashboard'), findsOneWidget);
    expect(find.text('Admin Attendance Console'), findsNothing);
  });

  testWidgets('Admin lands on Admin Console without Check In / Check Out actions',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final getCurrentUser = _MockGetCurrentUserUseCase();
    final getToday = _MockGetTodayAttendanceUseCase();
    final getHistory = _MockGetAttendanceHistoryUseCase();
    final getAdminDashboard = _MockGetAdminDashboardUseCase();
    final getEmployeeDetail = _MockGetEmployeeDetailUseCase();
    final getFailedAttempts = _MockGetFailedAttemptsUseCase();
    final sessionEvents = AuthSessionEvents();

    when(() => getCurrentUser.checkSession())
        .thenAnswer((_) async => const Success(adminUser));
    when(
      () => getAdminDashboard(
        date: any(named: 'date'),
        userRole: 'admin',
      ),
    ).thenAnswer(
      (_) async => const Success(
        AdminDashboardSummaryEntity(
          dateKey: '2026-11-12',
          totalEmployees: 2,
          presentCount: 1,
          checkedInCount: 1,
          completedCount: 0,
          lateCount: 0,
          absentCount: 1,
          employees: [],
        ),
      ),
    );
    when(
      () => getFailedAttempts(
        userRole: 'admin',
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => const Success([]));

    final authBloc = AuthBloc(
      loginUseCase: _MockLoginUseCase(),
      getCurrentUserUseCase: getCurrentUser,
      logoutUseCase: _MockLogoutUseCase(),
      sessionEvents: sessionEvents,
    );
    final attendanceBloc = AttendanceBloc(
      getTodayAttendanceUseCase: getToday,
      getAttendanceHistoryUseCase: getHistory,
    );
    final adminBloc = AdminBloc(
      getAdminDashboardUseCase: getAdminDashboard,
      getEmployeeDetailUseCase: getEmployeeDetail,
      getFailedAttemptsUseCase: getFailedAttempts,
    );
    final appRouter = AppRouter(authBloc);

    addTearDown(() async {
      appRouter.dispose();
      await authBloc.close();
      await attendanceBloc.close();
      await adminBloc.close();
      await sessionEvents.dispose();
    });

    authBloc.add(const AuthCheckRequested());
    await tester.pumpWidget(
      buildTestApp(
        authBloc: authBloc,
        appRouter: appRouter,
        attendanceBloc: attendanceBloc,
        adminBloc: adminBloc,
      ),
    );
    await tester.pumpAndSettle();

    // Admin lands on Console with Console / QR Kiosk / Profile tabs
    expect(find.text('Admin Attendance Console'), findsOneWidget);
    expect(find.text('Console'), findsOneWidget);
    expect(find.text('QR Kiosk'), findsWidgets);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Check In'), findsNothing);
    expect(find.text('Check Out'), findsNothing);

    // Attempting to navigate to /dashboard or /scan redirects back to /admin
    appRouter.router.go('/dashboard');
    await tester.pumpAndSettle();
    expect(find.text('Admin Attendance Console'), findsOneWidget);

    appRouter.router.go('/scan');
    await tester.pumpAndSettle();
    expect(find.text('Admin Attendance Console'), findsOneWidget);
  });
}
