import 'package:dio/dio.dart';
import 'package:qr_attendance_app/core/constants/api_constants.dart';
import 'package:qr_attendance_app/core/constants/app_constants.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/network/network_exceptions.dart';
import 'package:qr_attendance_app/core/services/location_service.dart';
import 'package:qr_attendance_app/features/attendance/data/models/attendance_record_model.dart';
import 'package:qr_attendance_app/features/qr_attendance/data/models/qr_session_model.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_scan_result_entity.dart';

abstract class QrRemoteDataSource {
  Future<QrSessionModel> generateQrSession({
    required String locationName,
    required int createdByUserId,
    required String userRole,
    double? geofenceLat,
    double? geofenceLng,
    double? geofenceRadiusMeters,
  });

  Future<QrSessionModel?> getActiveQrSession();

  Future<QrScanResultEntity> submitQrAttendance({
    required String rawQrPayload,
    required String action,
    required int userId,
    required CapturedLocation location,
  });
}

class QrRemoteDataSourceImpl implements QrRemoteDataSource {
  QrRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<QrSessionModel> generateQrSession({
    required String locationName,
    required int createdByUserId,
    required String userRole,
    double? geofenceLat,
    double? geofenceLng,
    double? geofenceRadiusMeters,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.qrSessionsEndpoint,
        data: {
          'locationName': locationName,
          'createdByUserId': createdByUserId,
          'validitySeconds': AppConstants.qrValiditySeconds,
          if (geofenceLat != null && geofenceLng != null) ...{
            'geofenceLat': geofenceLat,
            'geofenceLng': geofenceLng,
            'geofenceRadiusMeters':
                geofenceRadiusMeters ?? AppConstants.defaultGeofenceRadiusMeters,
          },
        },
        options: Options(headers: {'X-User-Role': userRole}),
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Failed to create QR session.');
      }
      return QrSessionModel.fromJson(data);
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkExceptionMapper.fromDioException(e);
    } catch (e) {
      throw ServerException('QR generation failed: $e');
    }
  }

  @override
  Future<QrSessionModel?> getActiveQrSession() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.activeQrSessionEndpoint,
      );
      final sessionJson = response.data?['session'];
      if (sessionJson is Map<String, dynamic>) {
        return QrSessionModel.fromJson(sessionJson);
      }
      return null;
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkExceptionMapper.fromDioException(e);
    } catch (e) {
      throw ServerException('Unable to load active QR session: $e');
    }
  }

  @override
  Future<QrScanResultEntity> submitQrAttendance({
    required String rawQrPayload,
    required String action,
    required int userId,
    required CapturedLocation location,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.attendanceScanEndpoint,
        data: {
          'qrPayload': rawQrPayload,
          'action': action,
          'userId': userId,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracyMeters': location.accuracyMeters,
          'clientTimestamp': location.capturedAtUtc.toIso8601String(),
        },
      );

      final data = response.data;
      if (data == null || data['record'] is! Map<String, dynamic>) {
        throw const ServerException('Invalid scan response from server.');
      }

      return QrScanResultEntity(
        action: (data['action'] as String?) ?? action,
        message: (data['message'] as String?) ?? 'Attendance recorded.',
        serverTimestamp: DateTime.parse(
          (data['serverTimestamp'] as String?) ??
              DateTime.now().toUtc().toIso8601String(),
        ),
        record: AttendanceRecordModel.fromJson(
          data['record'] as Map<String, dynamic>,
        ),
        capturedLocation: location,
      );
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkExceptionMapper.fromDioException(e);
    } catch (e) {
      throw ServerException('Unable to submit attendance scan: $e');
    }
  }
}

