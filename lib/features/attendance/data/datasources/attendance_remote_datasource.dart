import 'package:dio/dio.dart';
import 'package:qr_attendance_app/core/constants/api_constants.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/network/network_exceptions.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/features/attendance/data/models/attendance_record_model.dart';
import 'package:qr_attendance_app/features/attendance/data/models/attendance_summary_model.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_summary_entity.dart';

abstract class AttendanceRemoteDataSource {
  Future<TodayAttendanceOverview> getTodayOverview({required int userId});

  Future<AttendanceHistoryResult> getAttendanceHistory({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
    String statusFilter = 'all',
  });
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  AttendanceRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<TodayAttendanceOverview> getTodayOverview({
    required int userId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.attendanceTodayEndpoint,
        queryParameters: {'userId': userId},
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Empty attendance response from server.');
      }

      final statusRaw = (data['status'] as String?) ?? 'not_checked_in';
      final status = switch (statusRaw) {
        'completed' => AttendanceStatus.completed,
        'checked_in' => AttendanceStatus.checkedIn,
        _ => AttendanceStatus.notCheckedIn,
      };

      final todayJson = data['todayRecord'];
      final todayRecord = todayJson is Map<String, dynamic>
          ? AttendanceRecordModel.fromJson(todayJson)
          : null;

      final summaryJson = data['summary'];
      final summary = summaryJson is Map<String, dynamic>
          ? AttendanceSummaryModel.fromJson(summaryJson)
          : const AttendanceSummaryEntity.empty();

      final recentRaw = data['recentRecords'];
      final recentRecords = recentRaw is List
          ? recentRaw
              .whereType<Map<String, dynamic>>()
              .map(AttendanceRecordModel.fromJson)
              .toList()
          : <AttendanceRecordEntity>[];

      return TodayAttendanceOverview(
        workDate: (data['workDate'] as String?) ??
            DateTimeUtils.toDateKey(DateTime.now()),
        status: status,
        todayRecord: todayRecord,
        summary: summary,
        recentRecords: recentRecords,
      );
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkExceptionMapper.fromDioException(e);
    } catch (e) {
      throw ServerException('Failed to load today attendance: $e');
    }
  }

  @override
  Future<AttendanceHistoryResult> getAttendanceHistory({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
    String statusFilter = 'all',
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.attendanceHistoryEndpoint,
        queryParameters: {
          'userId': userId,
          if (startDate != null) 'startDate': DateTimeUtils.toDateKey(startDate),
          if (endDate != null) 'endDate': DateTimeUtils.toDateKey(endDate),
          'status': statusFilter,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Empty attendance history response.');
      }

      final summaryJson = data['summary'];
      final summary = summaryJson is Map<String, dynamic>
          ? AttendanceSummaryModel.fromJson(summaryJson)
          : const AttendanceSummaryEntity.empty();

      final recordsRaw = data['records'];
      final records = recordsRaw is List
          ? recordsRaw
              .whereType<Map<String, dynamic>>()
              .map(AttendanceRecordModel.fromJson)
              .toList()
          : <AttendanceRecordEntity>[];

      return AttendanceHistoryResult(summary: summary, records: records);
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkExceptionMapper.fromDioException(e);
    } catch (e) {
      throw ServerException('Failed to fetch attendance history: $e');
    }
  }
}

