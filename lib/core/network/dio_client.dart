import 'package:dio/dio.dart';
import 'package:qr_attendance_app/core/constants/api_constants.dart';
import 'package:qr_attendance_app/core/constants/app_constants.dart';
import 'package:qr_attendance_app/core/network/attendance_mock_rest_interceptor.dart';
import 'package:qr_attendance_app/core/network/auth_interceptor.dart';
import 'package:qr_attendance_app/features/attendance/data/datasources/attendance_local_mock_service.dart';

class DioClient {
  DioClient({
    required AuthInterceptor authInterceptor,
    required AttendanceLocalMockService mockAttendanceService,
  }) {
    dummyJsonDio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.dummyJsonBaseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: const {'Content-Type': 'application/json'},
      ),
    )..interceptors.add(authInterceptor);

    attendanceDio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.useExternalAttendanceApi
            ? ApiConstants.attendanceBaseUrl
            : 'https://mock.attendance.local/api/v1',
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: const {'Content-Type': 'application/json'},
      ),
    )..interceptors.add(authInterceptor);

    if (!ApiConstants.useExternalAttendanceApi) {
      attendanceDio.interceptors.add(
        AttendanceMockRestInterceptor(mockAttendanceService),
      );
    }
  }

  late final Dio dummyJsonDio;
  late final Dio attendanceDio;
}

