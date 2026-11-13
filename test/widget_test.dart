import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_attendance_app/core/network/auth_interceptor.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_event.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_state.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/get_current_user_usecase.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/login_usecase.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/logout_usecase.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_event.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_state.dart';
import 'package:qr_attendance_app/features/authentication/presentation/pages/login_page.dart';
import 'package:qr_attendance_app/features/authentication/presentation/pages/profile_page.dart';

class _MockLoginUseCase extends Mock implements LoginUseCase {}

class _MockGetCurrentUserUseCase extends Mock
    implements GetCurrentUserUseCase {}

class _MockLogoutUseCase extends Mock implements LogoutUseCase {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _MockAttendanceBloc extends MockBloc<AttendanceEvent, AttendanceState>
    implements AttendanceBloc {}

void main() {
  testWidgets('LoginPage validates empty inputs and supports demo credential chips',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sessionEvents = AuthSessionEvents();
    final authBloc = AuthBloc(
      loginUseCase: _MockLoginUseCase(),
      getCurrentUserUseCase: _MockGetCurrentUserUseCase(),
      logoutUseCase: _MockLogoutUseCase(),
      sessionEvents: sessionEvents,
    );
    addTearDown(() async {
      await authBloc.close();
      await sessionEvents.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const LoginPage(),
        ),
      ),
    );

    expect(find.text('Smart QR Attendance'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    // Tapping Sign In with empty fields triggers form validation messages.
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);

    // Tapping Demo Admin chip populates credentials via AuthBloc.
    await tester.tap(find.text('Admin'));
    await tester.pump();

    final emailField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(emailField.controller?.text, 'emily.johnson@x.dummyjson.com');
  });

  testWidgets('ProfilePage displays confirmation alertbox before signing out',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mockAuthBloc = _MockAuthBloc();
    final mockAttendanceBloc = _MockAttendanceBloc();

    const employee = UserEntity(
      id: 26,
      username: 'emily',
      email: 'emily@company.com',
      firstName: 'Emily',
      lastName: 'Johnson',
      image: '',
      phone: '123456',
      department: 'Engineering',
      jobTitle: 'Developer',
      companyName: 'HQ',
      role: 'employee',
    );

    when(() => mockAuthBloc.state).thenReturn(
      const AuthState(
        status: AuthStatus.authenticated,
        user: employee,
      ),
    );
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockAttendanceBloc.state).thenReturn(const AttendanceState());
    when(() => mockAttendanceBloc.stream)
        .thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: mockAuthBloc),
            BlocProvider<AttendanceBloc>.value(value: mockAttendanceBloc),
          ],
          child: const ProfilePage(),
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Sign Out'), 200);
    final signOutBtn = find.widgetWithText(FilledButton, 'Sign Out');
    expect(signOutBtn, findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(signOutBtn);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Are you sure you want to sign out of your account?'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(() => mockAuthBloc.add(const AuthLogoutRequested()));

    await tester.tap(signOutBtn);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    final confirmDialogBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Sign Out'),
    );
    await tester.tap(confirmDialogBtn);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verify(() => mockAttendanceBloc.add(const AttendanceCleared())).called(1);
    verify(() => mockAuthBloc.add(const AuthLogoutRequested())).called(1);
  });
}
