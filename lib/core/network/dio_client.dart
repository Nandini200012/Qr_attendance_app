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
    );
    dummyJsonDio.interceptors.addAll([
      authInterceptor,
      _TransientNetworkRetryInterceptor(dummyJsonDio),
    ]);

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
    } else {
      attendanceDio.interceptors.add(
        _TransientNetworkRetryInterceptor(attendanceDio),
      );
    }
  }

  late final Dio dummyJsonDio;
  late final Dio attendanceDio;
}

class _TransientNetworkRetryInterceptor extends Interceptor {
  _TransientNetworkRetryInterceptor(this._dio);

  final Dio _dio;
  static const String _retriedKey = '_transient_retried';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;
    final msg = err.message ?? '';
    final isTransientReset =
        err.type == DioExceptionType.connectionError ||
        (err.type == DioExceptionType.unknown &&
            (msg.contains('HandshakeException') ||
                msg.contains('Connection reset') ||
                msg.contains('Connection terminated')));

    if (!alreadyRetried && isTransientReset) {
      err.requestOptions.extra[_retriedKey] = true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      try {
        final response = await _dio.fetch<dynamic>(err.requestOptions);
        handler.resolve(response);
        return;
      } on DioException catch (retryErr) {
        handler.next(retryErr);
        return;
      }
    }

    handler.next(err);
  }
}

