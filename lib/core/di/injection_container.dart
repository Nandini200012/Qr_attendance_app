import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_attendance_app/core/network/auth_interceptor.dart';
import 'package:qr_attendance_app/core/network/dio_client.dart';
import 'package:qr_attendance_app/core/services/connectivity_service.dart';
import 'package:qr_attendance_app/core/services/location_service.dart';
import 'package:qr_attendance_app/core/services/secure_storage_service.dart';
import 'package:qr_attendance_app/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:qr_attendance_app/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:qr_attendance_app/features/admin/domain/repositories/admin_repository.dart';
import 'package:qr_attendance_app/features/admin/domain/usecases/get_admin_dashboard_usecase.dart';
import 'package:qr_attendance_app/features/admin/domain/usecases/get_employee_detail_usecase.dart';
import 'package:qr_attendance_app/features/admin/domain/usecases/get_failed_attempts_usecase.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:qr_attendance_app/features/attendance/data/datasources/attendance_local_database.dart';
import 'package:qr_attendance_app/features/attendance/data/datasources/attendance_local_mock_service.dart';
import 'package:qr_attendance_app/features/attendance/data/datasources/attendance_remote_datasource.dart';
import 'package:qr_attendance_app/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:qr_attendance_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:qr_attendance_app/features/attendance/domain/usecases/get_attendance_history_usecase.dart';
import 'package:qr_attendance_app/features/attendance/domain/usecases/get_today_attendance_usecase.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:qr_attendance_app/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:qr_attendance_app/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:qr_attendance_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/get_current_user_usecase.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/login_usecase.dart';
import 'package:qr_attendance_app/features/authentication/domain/usecases/logout_usecase.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:qr_attendance_app/features/qr_attendance/data/datasources/qr_remote_datasource.dart';
import 'package:qr_attendance_app/features/qr_attendance/data/repositories/qr_attendance_repository_impl.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/repositories/qr_attendance_repository.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/generate_qr_session_usecase.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/submit_qr_attendance_usecase.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/sync_pending_scans_usecase.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_bloc.dart';

final GetIt sl = GetIt.instance;

Future<void> initDependencies() async {
  if (sl.isRegistered<SharedPreferences>()) return;

  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // Core services
  sl.registerLazySingleton<SecureStorageService>(
    () => FlutterSecureStorageService(const FlutterSecureStorage()),
  );
  sl.registerLazySingleton<LocationService>(() => GeolocatorLocationService());
  sl.registerLazySingleton<ConnectivityService>(
    () => ConnectivityPlusService(),
  );
  sl.registerLazySingleton<AuthSessionEvents>(() => AuthSessionEvents());

  sl.registerLazySingleton<AttendanceLocalDatabase>(
    () => kIsWeb
        ? SharedPrefsAttendanceDatabase(sl<SharedPreferences>())
        : SqliteAttendanceDatabase(),
  );

  sl.registerLazySingleton<AttendanceLocalMockService>(
    () => AttendanceLocalMockService(
      database: sl<AttendanceLocalDatabase>(),
    ),
  );

  sl.registerLazySingleton<AuthInterceptor>(
    () => AuthInterceptor(
      storageService: sl<SecureStorageService>(),
      sessionEvents: sl<AuthSessionEvents>(),
    ),
  );

  sl.registerLazySingleton<DioClient>(
    () => DioClient(
      authInterceptor: sl<AuthInterceptor>(),
      mockAttendanceService: sl<AttendanceLocalMockService>(),
    ),
  );

  // Authentication
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<DioClient>().dummyJsonDio),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl<AuthRemoteDataSource>(),
      storageService: sl<SecureStorageService>(),
    ),
  );
  sl.registerLazySingleton(() => LoginUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => LogoutUseCase(sl<AuthRepository>()));
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      loginUseCase: sl<LoginUseCase>(),
      getCurrentUserUseCase: sl<GetCurrentUserUseCase>(),
      logoutUseCase: sl<LogoutUseCase>(),
      sessionEvents: sl<AuthSessionEvents>(),
    ),
  );

  // Attendance
  sl.registerLazySingleton<AttendanceRemoteDataSource>(
    () => AttendanceRemoteDataSourceImpl(sl<DioClient>().attendanceDio),
  );
  sl.registerLazySingleton<AttendanceRepository>(
    () => AttendanceRepositoryImpl(
      sl<AttendanceRemoteDataSource>(),
      localDatabase: sl<AttendanceLocalDatabase>(),
    ),
  );
  sl.registerLazySingleton(
    () => GetTodayAttendanceUseCase(sl<AttendanceRepository>()),
  );
  sl.registerLazySingleton(
    () => GetAttendanceHistoryUseCase(sl<AttendanceRepository>()),
  );
  sl.registerFactory<AttendanceBloc>(
    () => AttendanceBloc(
      getTodayAttendanceUseCase: sl<GetTodayAttendanceUseCase>(),
      getAttendanceHistoryUseCase: sl<GetAttendanceHistoryUseCase>(),
      connectivityService: sl<ConnectivityService>(),
      syncPendingScansUseCase: sl<SyncPendingScansUseCase>(),
    ),
  );

  // QR Attendance (Generation + Scanning)
  sl.registerLazySingleton<QrRemoteDataSource>(
    () => QrRemoteDataSourceImpl(sl<DioClient>().attendanceDio),
  );
  sl.registerLazySingleton<QrAttendanceRepository>(
    () => QrAttendanceRepositoryImpl(
      remoteDataSource: sl<QrRemoteDataSource>(),
      locationService: sl<LocationService>(),
      localDatabase: sl<AttendanceLocalDatabase>(),
      connectivityService: sl<ConnectivityService>(),
    ),
  );
  sl.registerLazySingleton(
    () => GenerateQrSessionUseCase(sl<QrAttendanceRepository>()),
  );
  sl.registerLazySingleton(
    () => SubmitQrAttendanceUseCase(sl<QrAttendanceRepository>()),
  );
  sl.registerLazySingleton(
    () => SyncPendingScansUseCase(sl<QrAttendanceRepository>()),
  );
  sl.registerFactory<QRBloc>(
    () => QRBloc(
      generateQrSessionUseCase: sl<GenerateQrSessionUseCase>(),
      submitQrAttendanceUseCase: sl<SubmitQrAttendanceUseCase>(),
      locationService: sl<LocationService>(),
    ),
  );

  // Admin
  sl.registerLazySingleton<AdminRemoteDataSource>(
    () => AdminRemoteDataSourceImpl(
      dummyJsonDio: sl<DioClient>().dummyJsonDio,
      attendanceDio: sl<DioClient>().attendanceDio,
    ),
  );
  sl.registerLazySingleton<AdminRepository>(
    () => AdminRepositoryImpl(sl<AdminRemoteDataSource>()),
  );
  sl.registerLazySingleton(
    () => GetAdminDashboardUseCase(sl<AdminRepository>()),
  );
  sl.registerLazySingleton(
    () => GetEmployeeDetailUseCase(sl<AdminRepository>()),
  );
  sl.registerLazySingleton(
    () => GetFailedAttemptsUseCase(sl<AdminRepository>()),
  );
  sl.registerFactory<AdminBloc>(
    () => AdminBloc(
      getAdminDashboardUseCase: sl<GetAdminDashboardUseCase>(),
      getEmployeeDetailUseCase: sl<GetEmployeeDetailUseCase>(),
      getFailedAttemptsUseCase: sl<GetFailedAttemptsUseCase>(),
    ),
  );
}

