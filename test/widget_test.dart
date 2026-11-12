import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_attendance_app/core/network/auth_interceptor.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/get_current_user_usecase.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/login_usecase.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/logout_usecase.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:qr_attendance_app/features/authentication/presentation/pages/login_page.dart';

class _MockLoginUseCase extends Mock implements LoginUseCase {}

class _MockGetCurrentUserUseCase extends Mock
    implements GetCurrentUserUseCase {}

class _MockLogoutUseCase extends Mock implements LogoutUseCase {}

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
}
