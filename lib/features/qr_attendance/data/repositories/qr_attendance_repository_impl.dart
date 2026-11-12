import 'dart:convert';

import 'package:qr_attendance_app/core/constants/api_constants.dart';
import 'package:qr_attendance_app/core/constants/app_constants.dart';
import 'package:qr_attendance_app/core/errors/error_message_mapper.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/core/services/connectivity_service.dart';
import 'package:qr_attendance_app/core/services/location_service.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/core/utils/geo_utils.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/failed_attempt_entity.dart';
import 'package:qr_attendance_app/features/attendance/data/datasources/attendance_local_database.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/data/datasources/qr_remote_datasource.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_scan_result_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_session_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/repositories/qr_attendance_repository.dart';

class QrAttendanceRepositoryImpl implements QrAttendanceRepository {
  QrAttendanceRepositoryImpl({
    required QrRemoteDataSource remoteDataSource,
    required LocationService locationService,
    AttendanceLocalDatabase? localDatabase,
    ConnectivityService? connectivityService,
  })  : _remoteDataSource = remoteDataSource,
        _locationService = locationService,
        _localDatabase = localDatabase,
        _connectivityService = connectivityService;

  final QrRemoteDataSource _remoteDataSource;
  final LocationService _locationService;
  final AttendanceLocalDatabase? _localDatabase;
  final ConnectivityService? _connectivityService;

  @override
  Future<Result<QrSessionEntity>> generateQrSession({
    required String locationName,
    required int createdByUserId,
    required String userRole,
    bool enforceGeofence = false,
  }) async {
    if (userRole.toLowerCase() != 'admin') {
      return const ResultFailure(
        UnauthorizedFailure(
          'Only administrators can generate dynamic QR attendance sessions.',
        ),
      );
    }

    try {
      double? lat;
      double? lng;
      double? radius;
      if (enforceGeofence) {
        final loc = await _locationService.getCurrentLocation();
        lat = loc.latitude;
        lng = loc.longitude;
        radius = AppConstants.defaultGeofenceRadiusMeters;
      }

      final session = await _remoteDataSource.generateQrSession(
        locationName: locationName,
        createdByUserId: createdByUserId,
        userRole: userRole,
        geofenceLat: lat,
        geofenceLng: lng,
        geofenceRadiusMeters: radius,
      );
      return Success(session);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<QrSessionEntity?>> getActiveQrSession() async {
    try {
      final session = await _remoteDataSource.getActiveQrSession();
      return Success(session);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<QrScanResultEntity>> submitQrAttendance({
    required String rawQrPayload,
    required String action,
    required int userId,
  }) async {
    CapturedLocation? location;
    try {
      // Always capture fresh GPS coordinates before submitting scan to backend.
      location = await _locationService.getCurrentLocation();
      if (!GeoUtils.isValidCoordinate(location.latitude, location.longitude)) {
        return const ResultFailure(
          LocationFailure(
            'Unable to capture valid GPS coordinates. Please retry.',
            errorType: LocationErrorType.unavailable,
          ),
        );
      }

      final isConnected = await _connectivityService?.isConnected ?? true;
      if (!isConnected) {
        return await _queueOfflineScan(
          rawQrPayload: rawQrPayload,
          action: action,
          userId: userId,
          location: location,
        );
      }

      final result = await _remoteDataSource.submitQrAttendance(
        rawQrPayload: rawQrPayload,
        action: action,
        userId: userId,
        location: location,
      );
      return Success(result);
    } on NetworkException catch (e) {
      if (location != null &&
          GeoUtils.isValidCoordinate(location.latitude, location.longitude) &&
          _localDatabase != null) {
        return _queueOfflineScan(
          rawQrPayload: rawQrPayload,
          action: action,
          userId: userId,
          location: location,
        );
      }
      final failure = mapExceptionToFailure(e);
      await _logClientOrNetworkFailure(
        failure: failure,
        userId: userId,
        rawQrPayload: rawQrPayload,
        lat: location?.latitude,
        lng: location?.longitude,
      );
      return ResultFailure(failure);
    } catch (e) {
      final failure = mapExceptionToFailure(e);
      await _logClientOrNetworkFailure(
        failure: failure,
        userId: userId,
        rawQrPayload: rawQrPayload,
        lat: location?.latitude,
        lng: location?.longitude,
      );
      return ResultFailure(failure);
    }
  }

  @override
  Future<Result<int>> syncPendingScans({required int userId}) async {
    final db = _localDatabase;
    if (db == null) return const Success(0);

    final isConnected = await _connectivityService?.isConnected ?? true;
    if (!isConnected) {
      return const ResultFailure(
        NetworkFailure('No internet connection. Unable to sync pending scans.'),
      );
    }

    final pending = await db.getPendingScans(userId: userId);
    if (pending.isEmpty) return const Success(0);

    var syncedCount = 0;
    for (final scan in pending) {
      final id = scan['id'] as String;
      final lat = (scan['latitude'] as num?)?.toDouble();
      final lng = (scan['longitude'] as num?)?.toDouble();
      if (!GeoUtils.isValidCoordinate(lat, lng)) {
        await db.deletePendingScan(id);
        continue;
      }

      final capturedAtUtc =
          DateTime.tryParse(scan['capturedAt'] as String? ?? '') ??
              DateTime.now().toUtc();
      final location = CapturedLocation(
        latitude: lat!,
        longitude: lng!,
        accuracyMeters: (scan['accuracyMeters'] as num?)?.toDouble() ?? 10.0,
        capturedAtUtc: capturedAtUtc,
      );

      try {
        await _remoteDataSource.submitQrAttendance(
          rawQrPayload: scan['rawQrPayload'] as String,
          action: scan['action'] as String,
          userId: (scan['userId'] as num).toInt(),
          location: location,
        );
        await db.deletePendingScan(id);
        syncedCount++;
      } on NetworkException {
        break;
      } on TimeoutException {
        break;
      } catch (_) {
        // Server permanently rejected (e.g. expired/duplicate); drop from queue.
        await db.deletePendingScan(id);
      }
    }

    return Success(syncedCount);
  }

  Future<Result<QrScanResultEntity>> _queueOfflineScan({
    required String rawQrPayload,
    required String action,
    required int userId,
    required CapturedLocation location,
  }) async {
    final db = _localDatabase;
    if (db == null) {
      return ResultFailure(
        NetworkFailure(ErrorMessageMapper.fromFailure(const NetworkFailure(''))),
      );
    }

    final nowUtc = location.capturedAtUtc.toUtc();
    final workDate = DateTimeUtils.toDateKey(nowUtc.toLocal());
    final sessionId = _tryExtractSessionId(rawQrPayload) ?? 'offline_session';
    final locationName = _tryExtractLocationName(rawQrPayload) ?? 'Office';
    final pendingId = 'pending_${nowUtc.millisecondsSinceEpoch}_$userId';

    await db.insertPendingScan({
      'id': pendingId,
      'userId': userId,
      'workDate': workDate,
      'action': action,
      'rawQrPayload': rawQrPayload,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'accuracyMeters': location.accuracyMeters,
      'capturedAt': nowUtc.toIso8601String(),
      'locationName': locationName,
      'sessionId': sessionId,
    });

    final record = AttendanceRecordEntity(
      id: pendingId,
      userId: userId,
      workDate: workDate,
      sessionId: sessionId,
      locationName: locationName,
      status: action == 'check_out'
          ? AttendanceStatus.completed
          : AttendanceStatus.checkedIn,
      checkInAt: nowUtc,
      checkInLat: location.latitude,
      checkInLng: location.longitude,
      checkInAccuracyMeters: location.accuracyMeters,
      checkOutAt: action == 'check_out' ? nowUtc : null,
      checkOutLat: action == 'check_out' ? location.latitude : null,
      checkOutLng: action == 'check_out' ? location.longitude : null,
      checkOutAccuracyMeters:
          action == 'check_out' ? location.accuracyMeters : null,
      serverVerified: false,
      isPendingSync: true,
    );

    return Success(
      QrScanResultEntity(
        action: action,
        message: "Saved offline. Will sync when you're back online.",
        serverTimestamp: nowUtc,
        record: record,
        capturedLocation: location,
        isOfflineQueued: true,
      ),
    );
  }

  String? _tryExtractLocationName(String rawQrPayload) {
    try {
      final decoded = jsonDecode(rawQrPayload.trim());
      if (decoded is Map<String, dynamic>) {
        final loc = decoded['location'] ?? decoded['locationName'];
        if (loc is String && loc.trim().isNotEmpty) return loc.trim();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _logClientOrNetworkFailure({
    required Failure failure,
    required int userId,
    required String rawQrPayload,
    double? lat,
    double? lng,
  }) async {
    final db = _localDatabase;
    if (db == null) return;

    final reason = _mapFailureToReason(failure);
    if (reason == null) return;

    final nowUtc = DateTime.now().toUtc();
    await db.insertFailedAttempt({
      'id': 'fail_${nowUtc.millisecondsSinceEpoch}_$userId',
      'employeeId': userId,
      'timestamp': nowUtc.toIso8601String(),
      'workDate': DateTimeUtils.toDateKey(nowUtc.toLocal()),
      'reason': reason.wireValue,
      'sessionId': _tryExtractSessionId(rawQrPayload),
      'lat': lat,
      'lng': lng,
      'message': failure.message,
    });
  }

  FailedAttemptReason? _mapFailureToReason(Failure failure) {
    if (failure is NetworkFailure || failure is TimeoutFailure) {
      return FailedAttemptReason.networkError;
    }
    if (failure is LocationFailure) {
      return FailedAttemptReason.outOfRange;
    }
    if (!ApiConstants.useExternalAttendanceApi) {
      // Local mock REST adapter already persists server-side validation failures.
      return null;
    }
    if (failure is UnauthorizedFailure || failure is ForbiddenFailure) {
      return FailedAttemptReason.unauthorized;
    }
    if (failure is QrValidationFailure) {
      return switch (failure.reason) {
        QrValidationErrorCode.expired => FailedAttemptReason.expired,
        QrValidationErrorCode.duplicateCheckIn ||
        QrValidationErrorCode.alreadyCheckedOut ||
        QrValidationErrorCode.noActiveCheckIn ||
        QrValidationErrorCode.inactiveSession ||
        QrValidationErrorCode.replayDetected =>
          FailedAttemptReason.duplicate,
        QrValidationErrorCode.outsideGeofence => FailedAttemptReason.outOfRange,
        QrValidationErrorCode.malformed ||
        QrValidationErrorCode.invalidSignature =>
          FailedAttemptReason.invalidSignature,
      };
    }
    return FailedAttemptReason.networkError;
  }

  String? _tryExtractSessionId(String rawQrPayload) {
    try {
      final decoded = jsonDecode(rawQrPayload.trim());
      if (decoded is Map<String, dynamic>) {
        final sid = decoded['sessionId'] ?? decoded['sid'];
        if (sid is String && sid.trim().isNotEmpty) return sid.trim();
      }
    } catch (_) {}
    return null;
  }
}

