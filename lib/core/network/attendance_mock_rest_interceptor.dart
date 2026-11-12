import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:qr_attendance_app/features/attendance/data/datasources/attendance_local_mock_service.dart';

/// Dio interceptor acting as a mock REST API adapter when no external
/// attendance endpoint (e.g., MockAPI.io) is configured.
class AttendanceMockRestInterceptor extends Interceptor {
  AttendanceMockRestInterceptor(this._mockService);

  final AttendanceLocalMockService _mockService;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final result = await _mockService.handleRequest(
      method: options.method,
      path: options.path,
      headers: options.headers,
      queryParameters: options.queryParameters,
      body: options.data,
    );

    if (result.statusCode >= 200 && result.statusCode < 300) {
      log("response: ${result.data}");
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: result.statusCode,
          data: result.data,
        ),
      );
      return;
    }

    handler.reject(
      DioException.badResponse(
        statusCode: result.statusCode,
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: result.statusCode,
          data: result.data,
        ),
      ),
      true,
    );
  }
}
