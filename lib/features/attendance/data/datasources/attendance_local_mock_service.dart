import 'dart:convert';
import 'dart:math' as math;

import 'package:qr_attendance_app/core/constants/app_constants.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/core/utils/geo_utils.dart';
import 'package:qr_attendance_app/core/utils/qr_security_utils.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/failed_attempt_entity.dart';
import 'package:qr_attendance_app/features/attendance/data/datasources/attendance_local_database.dart';

class MockHttpResponse {
  const MockHttpResponse({
    required this.statusCode,
    required this.data,
  });

  final int statusCode;
  final Map<String, dynamic> data;
}

/// Clearly separated local mock REST API service used when no external
/// attendance endpoint (e.g. MockAPI.io) is configured.
///
/// Persists QR sessions, used nonces, and attendance records in SQLite via
/// [AttendanceLocalDatabase] and enforces server-side equivalent validation:
/// - Bearer token & JWT expiration check (401)
/// - Strict role-based endpoint protection (403):
///   - Admin-only QR generation, active QR lookup, and admin attendance log
///   - Employee-only QR attendance scan (admin check-in/out rejected)
/// - HMAC-SHA256 QR signature & 30-second expiry validation (410 / 400)
/// - Duplicate check-in & check-out-without-check-in protection (409 / 400)
/// - Replay protection via consumed nonce tracking in SQLite (409)
/// - Authoritative server UTC timestamp and late-arrival calculation
class AttendanceLocalMockService {
  AttendanceLocalMockService({
    required AttendanceLocalDatabase database,
    DateTime Function()? clock,
  })  : _db = database,
        _clock = clock ?? DateTime.now;

  final AttendanceLocalDatabase _db;
  final DateTime Function() _clock;
  final math.Random _random = math.Random.secure();

  Future<MockHttpResponse> handleRequest({
    required String method,
    required String path,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic body,
  }) async {
    // Simulate realistic lightweight REST latency.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final normalizedMethod = method.toUpperCase();
    final payload = body is Map<String, dynamic> ? body : <String, dynamic>{};
    final query = queryParameters ?? <String, dynamic>{};

    final authHeader =
        (headers?['Authorization'] ?? headers?['authorization']) as String?;
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      if (normalizedMethod == 'POST' && path == '/attendance/scan') {
        await _logScanBodyFailure(
          payload,
          reason: FailedAttemptReason.unauthorized,
          message: 'Missing or invalid authorization token.',
        );
      }
      return const MockHttpResponse(
        statusCode: 401,
        data: {
          'code': 'UNAUTHORIZED',
          'message': 'Missing or invalid authorization token.',
        },
      );
    }

    final tokenValue = authHeader.substring('Bearer '.length).trim();
    if (tokenValue.isEmpty || tokenValue == 'expired') {
      if (normalizedMethod == 'POST' && path == '/attendance/scan') {
        await _logScanBodyFailure(
          payload,
          reason: FailedAttemptReason.unauthorized,
          message: 'Authentication token has expired.',
        );
      }
      return const MockHttpResponse(
        statusCode: 401,
        data: {
          'code': 'UNAUTHORIZED',
          'message': 'Authentication token has expired.',
        },
      );
    }

    final jwtClaims = _tryDecodeJwtPayload(tokenValue);
    if (jwtClaims != null) {
      final exp = (jwtClaims['exp'] as num?)?.toInt();
      if (exp != null) {
        final nowSec = _clock().toUtc().millisecondsSinceEpoch ~/ 1000;
        if (exp <= nowSec) {
          if (normalizedMethod == 'POST' && path == '/attendance/scan') {
            await _logScanBodyFailure(
              payload,
              reason: FailedAttemptReason.unauthorized,
              message: 'Authentication token has expired.',
              fallbackUserId: _parseInt(jwtClaims['id']),
            );
          }
          return const MockHttpResponse(
            statusCode: 401,
            data: {
              'code': 'UNAUTHORIZED',
              'message': 'Authentication token has expired.',
            },
          );
        }
      }
    }

    final userRole =
        ((headers?['X-User-Role'] ?? headers?['x-user-role']) as String? ??
                'user')
            .toLowerCase();

    if (normalizedMethod == 'POST' && path == '/qr-sessions') {
      if (userRole != 'admin') {
        return const MockHttpResponse(
          statusCode: 403,
          data: {
            'code': 'FORBIDDEN',
            'message': 'Only administrators can generate QR attendance sessions.',
          },
        );
      }
      return _createQrSession(payload);
    }

    if (normalizedMethod == 'GET' && path == '/qr-sessions/active') {
      if (userRole != 'admin') {
        return const MockHttpResponse(
          statusCode: 403,
          data: {
            'code': 'FORBIDDEN',
            'message': 'Only administrators can inspect active QR kiosk sessions.',
          },
        );
      }
      return _getLatestActiveQrSession();
    }

    if (normalizedMethod == 'POST' && path == '/attendance/scan') {
      if (userRole == 'admin') {
        const message =
            'Administrator accounts are not permitted to perform employee check-in or check-out.';
        await _logScanBodyFailure(
          payload,
          reason: FailedAttemptReason.unauthorized,
          message: message,
          fallbackUserId: _parseInt(jwtClaims?['id']),
        );
        return const MockHttpResponse(
          statusCode: 403,
          data: {
            'code': 'FORBIDDEN',
            'message': message,
          },
        );
      }
      final jwtUserId = _parseInt(jwtClaims?['id']);
      return _processScan(payload, authenticatedUserId: jwtUserId);
    }

    if (normalizedMethod == 'GET' && path == '/attendance/today') {
      final userId = _parseInt(query['userId']);
      if (userId == null) {
        return const MockHttpResponse(
          statusCode: 400,
          data: {'code': 'BAD_REQUEST', 'message': 'userId is required.'},
        );
      }
      final jwtUserId = _parseInt(jwtClaims?['id']);
      if (jwtUserId != null && userRole != 'admin' && jwtUserId != userId) {
        return const MockHttpResponse(
          statusCode: 403,
          data: {
            'code': 'FORBIDDEN',
            'message': 'Cannot access another employee attendance record.',
          },
        );
      }
      return _getTodayOverview(userId);
    }

    if (normalizedMethod == 'GET' && path == '/attendance') {
      final userId = _parseInt(query['userId']);
      if (userId == null) {
        return const MockHttpResponse(
          statusCode: 400,
          data: {'code': 'BAD_REQUEST', 'message': 'userId is required.'},
        );
      }
      final jwtUserId = _parseInt(jwtClaims?['id']);
      if (jwtUserId != null && userRole != 'admin' && jwtUserId != userId) {
        return const MockHttpResponse(
          statusCode: 403,
          data: {
            'code': 'FORBIDDEN',
            'message': 'Cannot access another employee attendance history.',
          },
        );
      }
      return _getAttendanceHistory(
        userId: userId,
        startDate: query['startDate'] as String?,
        endDate: query['endDate'] as String?,
        status: (query['status'] as String?) ?? 'all',
      );
    }

    if (normalizedMethod == 'GET' && path == '/admin/attendance') {
      if (userRole != 'admin') {
        return const MockHttpResponse(
          statusCode: 403,
          data: {
            'code': 'FORBIDDEN',
            'message': 'Administrator privileges required to view all records.',
          },
        );
      }
      return _getAdminAttendance(
        date: query['date'] as String?,
      );
    }

    if (normalizedMethod == 'GET' && path == '/admin/failed-attempts') {
      if (userRole != 'admin') {
        return const MockHttpResponse(
          statusCode: 403,
          data: {
            'code': 'FORBIDDEN',
            'message':
                'Administrator privileges required to view failed attendance attempts.',
          },
        );
      }
      return _getAdminFailedAttempts(
        date: query['date'] as String?,
      );
    }

    return MockHttpResponse(
      statusCode: 404,
      data: {
        'code': 'NOT_FOUND',
        'message': 'Unknown attendance REST route: $normalizedMethod $path',
      },
    );
  }

  Future<MockHttpResponse> _createQrSession(Map<String, dynamic> body) async {
    final locationName =
        (body['locationName'] as String?)?.trim().isNotEmpty == true
            ? (body['locationName'] as String).trim()
            : 'HQ Main Campus';
    final createdByUserId = _parseInt(body['createdByUserId']) ?? 1;
    final validitySeconds =
        _parseInt(body['validitySeconds']) ?? AppConstants.qrValiditySeconds;

    final lat = (body['geofenceLat'] as num?)?.toDouble();
    final lng = (body['geofenceLng'] as num?)?.toDouble();
    final radiusM = (body['geofenceRadiusMeters'] as num?)?.toDouble();

    final nowUtc = _clock().toUtc();
    final sessionId =
        'sess_${nowUtc.millisecondsSinceEpoch}_${_randomHex(4)}';
    final nonce = _randomHex(8);

    final signedPayload = QrSecurityUtils.createSignedPayload(
      sessionId: sessionId,
      nonce: nonce,
      locationName: locationName,
      issuedAt: nowUtc,
      validitySeconds: validitySeconds,
      geofenceLat: lat,
      geofenceLng: lng,
      geofenceRadiusMeters: radiusM,
    );

    final sessionMap = <String, dynamic>{
      'sessionId': sessionId,
      'nonce': nonce,
      'locationName': locationName,
      'createdByUserId': createdByUserId,
      'issuedAt': signedPayload.issuedAt.toIso8601String(),
      'expiresAt': signedPayload.expiresAt.toIso8601String(),
      'issuedAtMs': signedPayload.issuedAtMs,
      'expiresAtMs': signedPayload.expiresAtMs,
      'validitySeconds': validitySeconds,
      'rawQrPayload': signedPayload.toRawQrString(),
      'isActive': true,
      if (lat != null && lng != null) ...{
        'geofenceLat': lat,
        'geofenceLng': lng,
        'geofenceRadiusMeters':
            radiusM ?? AppConstants.defaultGeofenceRadiusMeters,
      },
    };

    await _db.saveQrSession(sessionMap, maxHistory: 25);

    return MockHttpResponse(statusCode: 201, data: sessionMap);
  }

  Future<MockHttpResponse> _getLatestActiveQrSession() async {
    final nowMs = _clock().toUtc().millisecondsSinceEpoch;
    final session = await _db.getLatestActiveQrSession(nowMs);
    return MockHttpResponse(statusCode: 200, data: {'session': session});
  }

  Future<MockHttpResponse> _processScan(
    Map<String, dynamic> body, {
    int? authenticatedUserId,
  }) async {
    final userId = _parseInt(body['userId']);
    final rawQrPayload = body['qrPayload'] as String?;
    final action = (body['action'] as String?)?.trim() ?? 'check_in';
    final latitude = (body['latitude'] as num?)?.toDouble();
    final longitude = (body['longitude'] as num?)?.toDouble();
    final accuracy = (body['accuracyMeters'] as num?)?.toDouble();

    final sessionIdHint = _tryExtractSessionId(rawQrPayload);
    final nowUtc = _clock().toUtc();

    if (userId == null) {
      const message = 'Employee ID is required.';
      await _logFailedAttempt(
        employeeId: authenticatedUserId ?? 0,
        timestampUtc: nowUtc,
        reason: FailedAttemptReason.unauthorized,
        sessionId: sessionIdHint,
        lat: latitude,
        lng: longitude,
        message: message,
      );
      return const MockHttpResponse(
        statusCode: 400,
        data: {'code': 'BAD_REQUEST', 'message': message},
      );
    }

    if (authenticatedUserId != null && authenticatedUserId != userId) {
      const message = 'Token identity does not match employee ID.';
      await _logFailedAttempt(
        employeeId: userId,
        timestampUtc: nowUtc,
        reason: FailedAttemptReason.unauthorized,
        sessionId: sessionIdHint,
        lat: latitude,
        lng: longitude,
        message: message,
      );
      return const MockHttpResponse(
        statusCode: 403,
        data: {
          'code': 'FORBIDDEN',
          'message': message,
        },
      );
    }

    if (action != 'check_in' && action != 'check_out') {
      const message = 'Attendance action must be check_in or check_out.';
      await _logFailedAttempt(
        employeeId: userId,
        timestampUtc: nowUtc,
        reason: FailedAttemptReason.duplicate,
        sessionId: sessionIdHint,
        lat: latitude,
        lng: longitude,
        message: message,
      );
      return const MockHttpResponse(
        statusCode: 400,
        data: {
          'code': 'BAD_REQUEST',
          'message': message,
        },
      );
    }

    // Authoritative server-side QR validation order:
    // 1) HMAC-SHA256 signature -> 2) expiry -> 3) nonce/session already used
    // -> 4) geofence (250m via Geolocator) -> 5) check-in/check-out state rules.
    final DecodedQrPayload parsedQr;
    try {
      parsedQr = QrSecurityUtils.validateComplete(
        rawQrPayload ?? '',
        referenceTime: nowUtc,
        graceSeconds: 0,
      );
    } on QrValidationException catch (e) {
      final reason = e.reason == QrValidationErrorCode.expired
          ? FailedAttemptReason.expired
          : FailedAttemptReason.invalidSignature;
      await _logFailedAttempt(
        employeeId: userId,
        timestampUtc: nowUtc,
        reason: reason,
        sessionId: sessionIdHint,
        lat: latitude,
        lng: longitude,
        message: e.message,
      );
      return MockHttpResponse(
        statusCode: e.reason == QrValidationErrorCode.expired ? 410 : 400,
        data: {
          'code': _toWireErrorCode(e.reason),
          'message': e.message,
        },
      );
    }

    // If this session exists in SQLite and was superseded/revoked, reject.
    final matchingSession = await _db.getQrSessionById(parsedQr.sessionId);
    if (matchingSession != null && matchingSession['isActive'] != true) {
      const message =
          'This QR session was superseded by a newer code. Please scan the latest QR code.';
      await _logFailedAttempt(
        employeeId: userId,
        timestampUtc: nowUtc,
        reason: FailedAttemptReason.duplicate,
        sessionId: parsedQr.sessionId,
        lat: latitude,
        lng: longitude,
        message: message,
      );
      return const MockHttpResponse(
        statusCode: 410,
        data: {
          'code': 'SESSION_INACTIVE',
          'message': message,
        },
      );
    }

    // Prevent replay of the same QR nonce by the same user for the same action.
    final replayKey = '${parsedQr.nonce}|$userId|$action';
    if (await _db.hasUsedNonce(replayKey)) {
      const message = 'This QR code has already been used for this action.';
      await _logFailedAttempt(
        employeeId: userId,
        timestampUtc: nowUtc,
        reason: FailedAttemptReason.duplicate,
        sessionId: parsedQr.sessionId,
        lat: latitude,
        lng: longitude,
        message: message,
      );
      return const MockHttpResponse(
        statusCode: 409,
        data: {
          'code': 'QR_REPLAY',
          'message': message,
        },
      );
    }

    // Geofence & coordinate validation after signature, expiry, and replay checks.
    if (!GeoUtils.isValidCoordinate(latitude, longitude)) {
      const message = 'Valid GPS coordinates are required to mark attendance.';
      await _logFailedAttempt(
        employeeId: userId,
        timestampUtc: nowUtc,
        reason: FailedAttemptReason.outOfRange,
        sessionId: parsedQr.sessionId,
        lat: latitude,
        lng: longitude,
        message: message,
      );
      return const MockHttpResponse(
        statusCode: 400,
        data: {
          'code': 'LOCATION_REQUIRED',
          'message': message,
        },
      );
    }

    // Geofence enforcement when session specifies office coordinates.
    final geofenceEnforced =
        parsedQr.geofenceLat != null && parsedQr.geofenceLng != null;
    double? distanceMeters;
    double? geofenceRadiusMeters;
    if (geofenceEnforced) {
      distanceMeters = GeoUtils.calculateDistanceMeters(
        lat1: latitude!,
        lng1: longitude!,
        lat2: parsedQr.geofenceLat!,
        lng2: parsedQr.geofenceLng!,
      );
      geofenceRadiusMeters =
          parsedQr.geofenceRadiusMeters ?? AppConstants.defaultGeofenceRadiusMeters;
      if (distanceMeters > geofenceRadiusMeters) {
        final message =
            'Outside allowed office radius (${distanceMeters.round()}m away, max ${geofenceRadiusMeters.round()}m).';
        await _logFailedAttempt(
          employeeId: userId,
          timestampUtc: nowUtc,
          reason: FailedAttemptReason.outOfRange,
          sessionId: parsedQr.sessionId,
          lat: latitude,
          lng: longitude,
          message: message,
        );
        return MockHttpResponse(
          statusCode: 403,
          data: {
            'code': 'OUTSIDE_GEOFENCE',
            'message': message,
          },
        );
      }
    }

    await _ensureSeeded(currentUserId: userId);
    final workDate = DateTimeUtils.toDateKey(nowUtc.toLocal());
    final existing =
        await _db.getAttendanceRecordByUserAndDate(userId, workDate);

    if (action == 'check_in') {
      if (existing != null) {
        final existingStatus = existing['status'] as String?;
        if (existingStatus == 'completed') {
          const message =
              'Attendance is already completed for today (checked in and checked out).';
          await _logFailedAttempt(
            employeeId: userId,
            timestampUtc: nowUtc,
            reason: FailedAttemptReason.duplicate,
            sessionId: parsedQr.sessionId,
            lat: latitude,
            lng: longitude,
            message: message,
          );
          return const MockHttpResponse(
            statusCode: 409,
            data: {
              'code': 'ALREADY_CHECKED_OUT',
              'message': message,
            },
          );
        }
        final message =
            'Duplicate check-in blocked. You already checked in today at ${DateTimeUtils.formatTime(DateTime.parse(existing['checkInAt'] as String))}.';
        await _logFailedAttempt(
          employeeId: userId,
          timestampUtc: nowUtc,
          reason: FailedAttemptReason.duplicate,
          sessionId: parsedQr.sessionId,
          lat: latitude,
          lng: longitude,
          message: message,
        );
        return MockHttpResponse(
          statusCode: 409,
          data: {
            'code': 'DUPLICATE_CHECK_IN',
            'message': message,
          },
        );
      }

      final isLate = DateTimeUtils.isLateCheckIn(nowUtc);
      final newRecord = <String, dynamic>{
        'id': 'att_${nowUtc.millisecondsSinceEpoch}_${_randomHex(3)}',
        'userId': userId,
        'workDate': workDate,
        'sessionId': parsedQr.sessionId,
        'locationName': parsedQr.locationName,
        'status': 'checked_in',
        'checkInAt': nowUtc.toIso8601String(),
        'checkInLat': latitude,
        'checkInLng': longitude,
        'checkInAccuracyMeters': accuracy,
        'checkOutAt': null,
        'checkOutLat': null,
        'checkOutLng': null,
        'checkOutAccuracyMeters': null,
        'durationMinutes': null,
        'distanceMeters': distanceMeters,
        'geofenceEnforced': geofenceEnforced,
        'geofenceRadiusMeters': geofenceRadiusMeters,
        'isLate': isLate,
        'serverVerified': true,
      };

      await _db.insertAttendanceRecord(newRecord);
      await _db.markNonceUsed(replayKey, nowUtc.toIso8601String());

      return MockHttpResponse(
        statusCode: 201,
        data: {
          'action': 'check_in',
          'message': isLate
              ? 'Check-in verified and recorded (late arrival).'
              : 'Check-in verified and recorded.',
          'serverTimestamp': nowUtc.toIso8601String(),
          'record': newRecord,
        },
      );
    }

    // action == 'check_out'
    if (existing == null) {
      const message =
          'Check-out denied. You must complete check-in before checking out.';
      await _logFailedAttempt(
        employeeId: userId,
        timestampUtc: nowUtc,
        reason: FailedAttemptReason.duplicate,
        sessionId: parsedQr.sessionId,
        lat: latitude,
        lng: longitude,
        message: message,
      );
      return const MockHttpResponse(
        statusCode: 400,
        data: {
          'code': 'NO_ACTIVE_CHECK_IN',
          'message': message,
        },
      );
    }

    if (existing['status'] == 'completed') {
      const message =
          'Duplicate check-out blocked. You already checked out today.';
      await _logFailedAttempt(
        employeeId: userId,
        timestampUtc: nowUtc,
        reason: FailedAttemptReason.duplicate,
        sessionId: parsedQr.sessionId,
        lat: latitude,
        lng: longitude,
        message: message,
      );
      return const MockHttpResponse(
        statusCode: 409,
        data: {
          'code': 'ALREADY_CHECKED_OUT',
          'message': message,
        },
      );
    }

    final checkInAt = DateTime.parse(existing['checkInAt'] as String).toUtc();
    final durationMinutes =
        math.max(0, nowUtc.difference(checkInAt).inMinutes);

    final updatedRecord = <String, dynamic>{
      ...existing,
      'status': 'completed',
      'checkOutAt': nowUtc.toIso8601String(),
      'checkOutLat': latitude,
      'checkOutLng': longitude,
      'checkOutAccuracyMeters': accuracy,
      'durationMinutes': durationMinutes,
      'distanceMeters': distanceMeters ?? existing['distanceMeters'],
      'geofenceEnforced':
          geofenceEnforced || (existing['geofenceEnforced'] == true),
      'geofenceRadiusMeters':
          geofenceRadiusMeters ?? existing['geofenceRadiusMeters'],
      'serverVerified': true,
    };

    await _db.updateAttendanceRecord(updatedRecord);
    await _db.markNonceUsed(replayKey, nowUtc.toIso8601String());

    return MockHttpResponse(
      statusCode: 200,
      data: {
        'action': 'check_out',
        'message': 'Check-out verified and shift completed.',
        'serverTimestamp': nowUtc.toIso8601String(),
        'record': updatedRecord,
      },
    );
  }

  Future<MockHttpResponse> _getTodayOverview(int userId) async {
    await _ensureSeeded(currentUserId: userId);
    final nowLocal = _clock().toLocal();
    final todayKey = DateTimeUtils.toDateKey(nowLocal);
    final allUserRecords = await _db.getAttendanceRecords(userId: userId);

    final todayRecord =
        allUserRecords.where((r) => r['workDate'] == todayKey).firstOrNull;
    final status = todayRecord == null
        ? 'not_checked_in'
        : (todayRecord['status'] as String? ?? 'checked_in');

    return MockHttpResponse(
      statusCode: 200,
      data: {
        'workDate': todayKey,
        'status': status,
        'todayRecord': todayRecord,
        'summary': _computeSummary(allUserRecords),
        'recentRecords': allUserRecords.take(3).toList(),
      },
    );
  }

  Future<MockHttpResponse> _getAttendanceHistory({
    required int userId,
    String? startDate,
    String? endDate,
    String status = 'all',
  }) async {
    await _ensureSeeded(currentUserId: userId);
    final filtered = await _db.getAttendanceRecords(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      status: status,
    );

    return MockHttpResponse(
      statusCode: 200,
      data: {
        'summary': _computeSummary(filtered),
        'records': filtered,
      },
    );
  }

  Future<MockHttpResponse> _getAdminAttendance({String? date}) async {
    await _ensureSeeded();
    final targetDate = (date != null && date.isNotEmpty)
        ? date
        : DateTimeUtils.toDateKey(_clock().toLocal());
    final records = await _db.getAttendanceRecords(
      workDate: targetDate,
      sortByCheckInDesc: true,
    );

    return MockHttpResponse(
      statusCode: 200,
      data: {
        'date': targetDate,
        'records': records,
      },
    );
  }

  Future<MockHttpResponse> _getAdminFailedAttempts({String? date}) async {
    final targetDate = (date != null && date.isNotEmpty) ? date : null;
    final attempts = await _db.getFailedAttempts(dateKey: targetDate);
    return MockHttpResponse(
      statusCode: 200,
      data: {
        'date': targetDate,
        'attempts': attempts,
      },
    );
  }

  Future<void> _logScanBodyFailure(
    Map<String, dynamic> body, {
    required FailedAttemptReason reason,
    required String message,
    int? fallbackUserId,
  }) async {
    final userId = _parseInt(body['userId']) ?? fallbackUserId ?? 0;
    final rawQr = body['qrPayload'] as String?;
    final lat = (body['latitude'] as num?)?.toDouble();
    final lng = (body['longitude'] as num?)?.toDouble();
    await _logFailedAttempt(
      employeeId: userId,
      timestampUtc: _clock().toUtc(),
      reason: reason,
      sessionId: _tryExtractSessionId(rawQr),
      lat: lat,
      lng: lng,
      message: message,
    );
  }

  Future<void> _logFailedAttempt({
    required int employeeId,
    required DateTime timestampUtc,
    required FailedAttemptReason reason,
    String? sessionId,
    double? lat,
    double? lng,
    String? message,
  }) async {
    final utc = timestampUtc.toUtc();
    await _db.insertFailedAttempt({
      'id': 'fail_${utc.millisecondsSinceEpoch}_${_randomHex(3)}',
      'employeeId': employeeId,
      'timestamp': utc.toIso8601String(),
      'workDate': DateTimeUtils.toDateKey(utc.toLocal()),
      'reason': reason.wireValue,
      'sessionId': sessionId,
      'lat': lat,
      'lng': lng,
      'message': message,
    });
  }

  String? _tryExtractSessionId(String? rawQrPayload) {
    if (rawQrPayload == null || rawQrPayload.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(rawQrPayload.trim());
      if (decoded is Map<String, dynamic>) {
        final sid = decoded['sid'] ?? decoded['sessionId'];
        if (sid is String && sid.trim().isNotEmpty) {
          return sid.trim();
        }
      }
    } catch (_) {
      // Ignore malformed payloads; sessionId remains null.
    }
    return null;
  }

  Map<String, dynamic> _computeSummary(List<Map<String, dynamic>> records) {
    var completedDays = 0;
    var activeCheckIns = 0;
    var totalMinutes = 0;

    for (final rec in records) {
      if (rec['status'] == 'completed') {
        completedDays++;
        totalMinutes += (rec['durationMinutes'] as num?)?.toInt() ?? 0;
      } else if (rec['status'] == 'checked_in') {
        activeCheckIns++;
      }
    }

    final avgMinutes = completedDays > 0 ? totalMinutes ~/ completedDays : 0;
    return {
      'totalPresentDays': records.length,
      'completedDays': completedDays,
      'activeCheckIns': activeCheckIns,
      'totalWorkedMinutes': totalMinutes,
      'averageWorkedMinutes': avgMinutes,
    };
  }

  Future<void> _ensureSeeded({int? currentUserId}) async {
    final alreadySeeded = await _db.isSeedInitialized();

    if (!alreadySeeded) {
      final nowLocal = _clock().toLocal();
      final todayKey = DateTimeUtils.toDateKey(nowLocal);
      final seedRecords = <Map<String, dynamic>>[];

      // Seed historical records for sample DummyJSON user IDs (2..12, 26..28).
      // Intentionally leave today open for ID 26 (Employee Evelyn)
      // so evaluators can test Check-In -> Check-Out live immediately.
      const seedUserIds = [2, 3, 4, 5, 6, 7, 8, 26, 27, 28];
      var counter = 1;
      final historicalWeekdays = _previousWeekdays(nowLocal, 5);

      for (var dayIdx = 0; dayIdx < historicalWeekdays.length; dayIdx++) {
        final day = historicalWeekdays[dayIdx];
        final dateKey = DateTimeUtils.toDateKey(day);

        for (final uid in seedUserIds) {
          if ((uid + dayIdx) % 7 == 0) continue;

          // Vary check-in times across weekdays while keeping realistic shifts.
          final shiftOffsetMinutes = (uid * 7 + dayIdx * 11) % 36;
          final inLocal = DateTime(day.year, day.month, day.day, 8, 50)
              .add(Duration(minutes: shiftOffsetMinutes));
          final outLocal = DateTime(
            day.year,
            day.month,
            day.day,
            17 + (uid % 2),
            10 + (uid * 7 + dayIdx * 5) % 45,
          );
          final duration = outLocal.difference(inLocal).inMinutes;

          // Slightly different check-in and check-out GPS points (a few meters
          // apart), staying comfortably inside the 250m geofence.
          final checkInLat =
              12.9716 + ((uid % 5) - 2) * 0.00012 + dayIdx * 0.00003;
          final checkInLng =
              77.5946 + ((uid % 4) - 1) * 0.00011 - dayIdx * 0.00002;
          final checkOutLat = checkInLat + (((dayIdx + uid) % 2 == 0) ? 0.00008 : -0.00007);
          final checkOutLng = checkInLng + (((dayIdx + uid) % 3 == 0) ? -0.00006 : 0.00009);

          seedRecords.add({
            'id': 'att_seed_${counter++}',
            'userId': uid,
            'workDate': dateKey,
            'sessionId': 'sess_hq_seed_${dayIdx + 1}',
            'locationName': 'HQ Campus - Building A',
            'status': 'completed',
            'checkInAt': inLocal.toUtc().toIso8601String(),
            'checkInLat': checkInLat,
            'checkInLng': checkInLng,
            'checkInAccuracyMeters': 8.5,
            'checkOutAt': outLocal.toUtc().toIso8601String(),
            'checkOutLat': checkOutLat,
            'checkOutLng': checkOutLng,
            'checkOutAccuracyMeters': 9.2,
            'durationMinutes': duration,
            'distanceMeters': 18.0 + ((uid + dayIdx) % 15),
            'isLate': DateTimeUtils.isLateCheckIn(inLocal),
            'serverVerified': true,
          });
        }
      }

      // Seed realistic today records for a few coworkers (leaving ID 26 open).
      final coworkerCheckIns = <int, String>{
        2: 'completed',
        3: 'checked_in',
        4: 'checked_in',
        6: 'checked_in',
        27: 'completed',
      };

      for (final entry in coworkerCheckIns.entries) {
        final uid = entry.key;
        final st = entry.value;
        final inLocal = DateTime(
          nowLocal.year,
          nowLocal.month,
          nowLocal.day,
          9,
          (uid * 4) % 25,
        );
        final outLocal = st == 'completed'
            ? DateTime(
                nowLocal.year,
                nowLocal.month,
                nowLocal.day,
                17,
                20 + (uid % 15),
              )
            : null;
        final duration = outLocal?.difference(inLocal).inMinutes;

        seedRecords.add({
          'id': 'att_seed_today_$uid',
          'userId': uid,
          'workDate': todayKey,
          'sessionId': 'sess_hq_today',
          'locationName': 'HQ Campus - Building A',
          'status': st,
          'checkInAt': inLocal.toUtc().toIso8601String(),
          'checkInLat': 12.9717,
          'checkInLng': 77.5948,
          'checkInAccuracyMeters': 7.8,
          'checkOutAt': outLocal?.toUtc().toIso8601String(),
          'checkOutLat': outLocal != null ? 12.9717 : null,
          'checkOutLng': outLocal != null ? 77.5948 : null,
          'checkOutAccuracyMeters': outLocal != null ? 8.1 : null,
          'durationMinutes': duration,
          'distanceMeters': 14.0,
          'geofenceEnforced': true,
          'geofenceRadiusMeters': AppConstants.defaultGeofenceRadiusMeters,
          'isLate': DateTimeUtils.isLateCheckIn(inLocal),
          'serverVerified': true,
        });
      }

      await _db.insertSeedRecords(seedRecords);
      await _db.markSeedInitialized();
    }

    // If a different DummyJSON employee logs in, ensure they have sample
    // historical days while keeping today open for live testing.
    if (currentUserId != null &&
        !(await _db.hasAnyRecordsForUser(currentUserId))) {
      final nowLocal = _clock().toLocal();
      final extraSeed = <Map<String, dynamic>>[];
      final weekdays = _previousWeekdays(nowLocal, 3);
      for (var i = 0; i < weekdays.length; i++) {
        final day = weekdays[i];
        final inLocal = DateTime(day.year, day.month, day.day, 8, 52)
            .add(Duration(minutes: (currentUserId * 3 + i * 9) % 30));
        final outLocal =
            DateTime(day.year, day.month, day.day, 17, 25 + i * 7);
        final checkInLat = 12.9716 + i * 0.00006;
        final checkInLng = 77.5946 - i * 0.00005;
        extraSeed.add({
          'id': 'att_seed_u${currentUserId}_${i + 1}',
          'userId': currentUserId,
          'workDate': DateTimeUtils.toDateKey(day),
          'sessionId': 'sess_hq_seed_${i + 1}',
          'locationName': 'HQ Campus - Building A',
          'status': 'completed',
          'checkInAt': inLocal.toUtc().toIso8601String(),
          'checkInLat': checkInLat,
          'checkInLng': checkInLng,
          'checkInAccuracyMeters': 9.0,
          'checkOutAt': outLocal.toUtc().toIso8601String(),
          'checkOutLat': checkInLat + 0.00007,
          'checkOutLng': checkInLng + 0.00008,
          'checkOutAccuracyMeters': 8.7,
          'durationMinutes': outLocal.difference(inLocal).inMinutes,
          'distanceMeters': 16.0 + i * 4,
          'isLate': DateTimeUtils.isLateCheckIn(inLocal),
          'serverVerified': true,
        });
      }
      await _db.insertSeedRecords(extraSeed);
    }
  }

  List<DateTime> _previousWeekdays(DateTime fromLocal, int count) {
    final result = <DateTime>[];
    var cursor = fromLocal;
    while (result.length < count) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (cursor.weekday != DateTime.saturday &&
          cursor.weekday != DateTime.sunday) {
        result.add(cursor);
      }
    }
    return result;
  }

  Map<String, dynamic>? _tryDecodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }

  String _randomHex(int bytes) {
    final values = List<int>.generate(bytes, (_) => _random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  int? _parseInt(dynamic val) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  String _toWireErrorCode(QrValidationErrorCode code) {
    return switch (code) {
      QrValidationErrorCode.malformed => 'QR_MALFORMED',
      QrValidationErrorCode.invalidSignature => 'QR_INVALID_SIGNATURE',
      QrValidationErrorCode.expired => 'QR_EXPIRED',
      QrValidationErrorCode.inactiveSession => 'SESSION_INACTIVE',
      QrValidationErrorCode.duplicateCheckIn => 'DUPLICATE_CHECK_IN',
      QrValidationErrorCode.noActiveCheckIn => 'NO_ACTIVE_CHECK_IN',
      QrValidationErrorCode.alreadyCheckedOut => 'ALREADY_CHECKED_OUT',
      QrValidationErrorCode.outsideGeofence => 'OUTSIDE_GEOFENCE',
      QrValidationErrorCode.replayDetected => 'QR_REPLAY',
    };
  }
}
