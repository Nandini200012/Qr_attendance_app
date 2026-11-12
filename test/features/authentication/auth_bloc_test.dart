import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/core/network/auth_interceptor.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/get_current_user_usecase.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/login_usecase.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/logout_usecase.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_event.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_state.dart';

class _MockLoginUseCase extends Mock implements LoginUseCase {}

class _MockGetCurrentUserUseCase extends Mock
    implements GetCurrentUserUseCase {}

class _MockLogoutUseCase extends Mock implements LogoutUseCase {}

void main() {
  late _MockLoginUseCase loginUseCase;
  late _MockGetCurrentUserUseCase getCurrentUserUseCase;
  late _MockLogoutUseCase logoutUseCase;
  late AuthSessionEvents sessionEvents;

  const sampleUser = UserEntity(
    id: 1,
    username: 'emilys',
    email: 'emily.johnson@x.dummyjson.com',
    firstName: 'Emily',
    lastName: 'Johnson',
    image: '',
    phone: '+81 965-431-3024',
    department: 'Engineering',
    jobTitle: 'Sales Manager',
    companyName: 'Smart Corp',
    role: 'admin',
  );

  setUp(() {
    loginUseCase = _MockLoginUseCase();
    getCurrentUserUseCase = _MockGetCurrentUserUseCase();
    logoutUseCase = _MockLogoutUseCase();
    sessionEvents = AuthSessionEvents();
  });

  tearDown(() async {
    await sessionEvents.dispose();
  });

  AuthBloc buildBloc() => AuthBloc(
        loginUseCase: loginUseCase,
        getCurrentUserUseCase: getCurrentUserUseCase,
        logoutUseCase: logoutUseCase,
        sessionEvents: sessionEvents,
      );

  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'emits validation error without calling loginUseCase when email is invalid',
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthLoginSubmitted(email: 'invalid-email', password: 'password123'),
      ),
      expect: () => [
        const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Enter a valid work email address.',
        ),
      ],
      verify: (_) {
        verifyNever(() => loginUseCase(email: any(named: 'email'), password: any(named: 'password')));
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [authenticating, authenticated] on successful login',
      setUp: () {
        when(() => loginUseCase(
              email: 'emily.johnson@x.dummyjson.com',
              password: 'emilyspass',
            )).thenAnswer((_) async => const Success(sampleUser));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthLoginSubmitted(
          email: 'emily.johnson@x.dummyjson.com',
          password: 'emilyspass',
        ),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        const AuthState(
          status: AuthStatus.authenticated,
          user: sampleUser,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [authenticating, unauthenticated] with error on network failure',
      setUp: () {
        when(() => loginUseCase(
              email: 'emily.johnson@x.dummyjson.com',
              password: 'emilyspass',
            )).thenAnswer((_) async => const ResultFailure(NetworkFailure()));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthLoginSubmitted(
          email: 'emily.johnson@x.dummyjson.com',
          password: 'emilyspass',
        ),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage:
              'Unable to reach the server. Please verify your internet connection.',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'toggles obscurePassword and sets demo prefill via BLoC events',
      build: buildBloc,
      act: (bloc) {
        bloc.add(const AuthPasswordVisibilityToggled());
        bloc.add(const AuthDemoAccountSelected(
          email: 'evelyn.gonzalez@x.dummyjson.com',
          password: 'evelyngpass',
        ));
      },
      expect: () => [
        const AuthState(obscurePassword: false),
        const AuthState(
          obscurePassword: false,
          prefillEmail: 'evelyn.gonzalez@x.dummyjson.com',
          prefillPassword: 'evelyngpass',
          prefillRevision: 1,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits unauthenticated with sign-out infoMessage on AuthLogoutRequested',
      setUp: () {
        when(() => logoutUseCase()).thenAnswer((_) async => const Success(null));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [
        const AuthState(
          status: AuthStatus.unauthenticated,
          infoMessage: 'You have been signed out successfully.',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits validation error without calling loginUseCase when password is too short',
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthLoginSubmitted(
          email: 'emily.johnson@x.dummyjson.com',
          password: '123',
        ),
      ),
      expect: () => [
        const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Password must be at least 6 characters.',
        ),
      ],
      verify: (_) {
        verifyNever(() => loginUseCase(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ));
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [authenticating, unauthenticated] on invalid credentials (401)',
      setUp: () {
        when(() => loginUseCase(
              email: 'emily.johnson@x.dummyjson.com',
              password: 'wrongpass',
            )).thenAnswer(
          (_) async => const ResultFailure(
            UnauthorizedFailure('Invalid email or password.'),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AuthLoginSubmitted(
          email: 'emily.johnson@x.dummyjson.com',
          password: 'wrongpass',
        ),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.authenticating),
        const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Invalid email or password.',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [checking, authenticated] on AuthCheckRequested when session is active',
      setUp: () {
        when(() => getCurrentUserUseCase.checkSession())
            .thenAnswer((_) async => const Success(sampleUser));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthState(status: AuthStatus.checking),
        const AuthState(
          status: AuthStatus.authenticated,
          user: sampleUser,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [checking, unauthenticated] on AuthCheckRequested when no session exists',
      setUp: () {
        when(() => getCurrentUserUseCase.checkSession())
            .thenAnswer((_) async => const Success(null));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthState(status: AuthStatus.checking),
        const AuthState(status: AuthStatus.unauthenticated),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'signs out automatically with error when 401 session expiration event arrives',
      seed: () => const AuthState(
        status: AuthStatus.authenticated,
        user: sampleUser,
      ),
      setUp: () {
        when(() => logoutUseCase()).thenAnswer((_) async => const Success(null));
      },
      build: buildBloc,
      act: (bloc) async {
        sessionEvents.notifyUnauthorized();
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      expect: () => [
        const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Session expired (401 Unauthorized). Please sign in again.',
        ),
      ],
    );
  });
}

