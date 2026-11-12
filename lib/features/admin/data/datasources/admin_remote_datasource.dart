import 'package:dio/dio.dart';
import 'package:qr_attendance_app/core/constants/api_constants.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/network/network_exceptions.dart';
import 'package:qr_attendance_app/features/admin/data/models/failed_attempt_model.dart';
import 'package:qr_attendance_app/features/attendance/data/models/attendance_record_model.dart';
import 'package:qr_attendance_app/features/authentication/data/models/user_model.dart';

abstract class AdminRemoteDataSource {
  Future<List<UserModel>> fetchEmployees({int limit = 30, int skip = 0});
  Future<UserModel> fetchEmployeeById(int userId);
  Future<List<AttendanceRecordModel>> fetchAttendanceByDate({
    required String dateKey,
    required String userRole,
  });
  Future<List<FailedAttemptModel>> fetchFailedAttempts({
    String? dateKey,
    required String userRole,
  });
}

class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  AdminRemoteDataSourceImpl({
    required Dio dummyJsonDio,
    required Dio attendanceDio,
  })  : _dummyJsonDio = dummyJsonDio,
        _attendanceDio = attendanceDio;

  final Dio _dummyJsonDio;
  final Dio _attendanceDio;

  @override
  Future<List<UserModel>> fetchEmployees({
    int limit = 30,
    int skip = 0,
  }) async {
    try {
      final response = await _dummyJsonDio.get<Map<String, dynamic>>(
        ApiConstants.usersEndpoint,
        queryParameters: {'limit': limit, 'skip': skip},
      );

      final usersRaw = response.data?['users'];
      if (usersRaw is! List) {
        throw const ServerException('Unexpected response from users API.');
      }

      return usersRaw
          .whereType<Map<String, dynamic>>()
          .map(UserModel.fromJson)
          .toList();
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkExceptionMapper.fromDioException(e);
    } catch (e) {
      throw ServerException('Failed to fetch employee directory: $e');
    }
  }

  @override
  Future<UserModel> fetchEmployeeById(int userId) async {
    try {
      final response = await _dummyJsonDio.get<Map<String, dynamic>>(
        '${ApiConstants.usersEndpoint}/$userId',
      );
      final data = response.data;
      if (data == null) {
        throw const ServerException('Employee profile not found.');
      }
      return UserModel.fromJson(data);
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkExceptionMapper.fromDioException(e);
    } catch (e) {
      throw ServerException('Failed to load employee #$userId: $e');
    }
  }

  @override
  Future<List<AttendanceRecordModel>> fetchAttendanceByDate({
    required String dateKey,
    required String userRole,
  }) async {
    try {
      final response = await _attendanceDio.get<Map<String, dynamic>>(
        ApiConstants.adminAttendanceEndpoint,
        queryParameters: {'date': dateKey},
        options: Options(headers: {'X-User-Role': userRole}),
      );

      final recordsRaw = response.data?['records'];
      if (recordsRaw is! List) return [];

      return recordsRaw
          .whereType<Map<String, dynamic>>()
          .map(AttendanceRecordModel.fromJson)
          .toList();
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkExceptionMapper.fromDioException(e);
    } catch (e) {
      throw ServerException('Failed to load admin attendance records: $e');
    }
  }

  @override
  Future<List<FailedAttemptModel>> fetchFailedAttempts({
    String? dateKey,
    required String userRole,
  }) async {
    try {
      final response = await _attendanceDio.get<Map<String, dynamic>>(
        ApiConstants.adminFailedAttemptsEndpoint,
        queryParameters: {
          if (dateKey != null && dateKey.isNotEmpty) 'date': dateKey,
        },
        options: Options(headers: {'X-User-Role': userRole}),
      );

      final attemptsRaw = response.data?['attempts'];
      if (attemptsRaw is! List) return [];

      return attemptsRaw
          .whereType<Map<String, dynamic>>()
          .map(FailedAttemptModel.fromJson)
          .toList();
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkExceptionMapper.fromDioException(e);
    } catch (e) {
      throw ServerException('Failed to load failed attendance attempts: $e');
    }
  }
}

