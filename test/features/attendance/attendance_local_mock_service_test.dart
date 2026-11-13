import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qr_attendance_app/core/utils/geo_utils.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/failed_attempt_entity.dart';
import 'package:qr_attendance_app/features/attendance/data/datasources/attendance_local_database.dart';
import 'package:qr_attendance_app/features/attendance/data/datasources/attendance_local_mock_service.dart';

void main() {
  sqfliteFfiInit();

  late DateTime currentClock;
  late SqliteAttendanceDatabase database;
  late AttendanceLocalMockService service;

  setUp(() {
    currentClock = DateTime(2026, 11, 12, 9, 0, 0);
    database = SqliteAttendanceDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    service = AttendanceLocalMockService(
      database: database,
      clock: () => currentClock,
    );
  });

  tearDown(() async {
    await database.close();
  });

  String buildJwt({required int id, required int expSeconds}) {
    final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
    final payload = base64Url.encode(
      utf8.encode(jsonEncode({'id': id, 'exp': expSeconds})),
    );
    return '$header.$payload.sig';
  }

  group('AttendanceLocalMockService SQLite & REST validation', () {
    test('rejects unauthenticated requests and expired JWTs with 401',
        () async {
      final missingAuth = await service.handleRequest(
        method: 'GET',
        path: '/attendance/today',
        queryParameters: {'userId': 26},
      );
      expect(missingAuth.statusCode, 401);
      expect(missingAuth.data['code'], 'UNAUTHORIZED');

      final expiredJwt = buildJwt(
        id: 26,
        expSeconds:
            currentClock.toUtc().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch ~/
                1000,
      );
      final expiredRes = await service.handleRequest(
        method: 'GET',
        path: '/attendance/today',
        headers: {'Authorization': 'Bearer $expiredJwt'},
        queryParameters: {'userId': 26},
      );
      expect(expiredRes.statusCode, 401);
      expect(expiredRes.data['code'], 'UNAUTHORIZED');
    });

    test('enforces role-based access for admin and employee endpoints',
        () async {
      final nonAdminQrGen = await service.handleRequest(
        method: 'POST',
        path: '/qr-sessions',
        headers: {
          'Authorization': 'Bearer valid-token',
          'X-User-Role': 'user',
        },
        body: {'locationName': 'HQ Gate', 'createdByUserId': 26},
      );
      expect(nonAdminQrGen.statusCode, 403);
      expect(nonAdminQrGen.data['code'], 'FORBIDDEN');

      final nonAdminActiveQr = await service.handleRequest(
        method: 'GET',
        path: '/qr-sessions/active',
        headers: {
          'Authorization': 'Bearer valid-token',
          'X-User-Role': 'user',
        },
      );
      expect(nonAdminActiveQr.statusCode, 403);
      expect(nonAdminActiveQr.data['code'], 'FORBIDDEN');

      final nonAdminRecords = await service.handleRequest(
        method: 'GET',
        path: '/admin/attendance',
        headers: {
          'Authorization': 'Bearer valid-token',
          'X-User-Role': 'user',
        },
      );
      expect(nonAdminRecords.statusCode, 403);
      expect(nonAdminRecords.data['code'], 'FORBIDDEN');

      // Admin generates QR
      final qrRes = await service.handleRequest(
        method: 'POST',
        path: '/qr-sessions',
        headers: {
          'Authorization': 'Bearer admin-token',
          'X-User-Role': 'admin',
        },
        body: {'locationName': 'HQ Gate', 'createdByUserId': 1},
      );
      expect(qrRes.statusCode, 201);
      final qrPayload = qrRes.data['rawQrPayload'] as String;

      // Admin cannot perform employee check-in/check-out
      final adminScan = await service.handleRequest(
        method: 'POST',
        path: '/attendance/scan',
        headers: {
          'Authorization': 'Bearer admin-token',
          'X-User-Role': 'admin',
        },
        body: {
          'qrPayload': qrPayload,
          'action': 'check_in',
          'userId': 1,
          'latitude': 12.9716,
          'longitude': 77.5946,
        },
      );
      expect(adminScan.statusCode, 403);
      expect(adminScan.data['code'], 'FORBIDDEN');
    });

    test(
        'blocks check-out before check-in, allows check-in -> check-out, blocks duplicates in SQLite',
        () async {
      // Admin generates QR #1
      final qrRes1 = await service.handleRequest(
        method: 'POST',
        path: '/qr-sessions',
        headers: {
          'Authorization': 'Bearer admin-token',
          'X-User-Role': 'admin',
        },
        body: {'locationName': 'HQ Gate', 'createdByUserId': 1},
      );
      expect(qrRes1.statusCode, 201);
      final qrPayload1 = qrRes1.data['rawQrPayload'] as String;

      // Check-out without check-in should fail
      final earlyOut = await service.handleRequest(
        method: 'POST',
        path: '/attendance/scan',
        headers: {
          'Authorization': 'Bearer emp-token',
          'X-User-Role': 'user',
        },
        body: {
          'qrPayload': qrPayload1,
          'action': 'check_out',
          'userId': 26,
          'latitude': 12.9716,
          'longitude': 77.5946,
          'accuracyMeters': 10.0,
        },
      );
      expect(earlyOut.statusCode, 400);
      expect(earlyOut.data['code'], 'NO_ACTIVE_CHECK_IN');

      // Valid on-time check-in at 09:00 succeeds
      final checkIn = await service.handleRequest(
        method: 'POST',
        path: '/attendance/scan',
        headers: {
          'Authorization': 'Bearer emp-token',
          'X-User-Role': 'user',
        },
        body: {
          'qrPayload': qrPayload1,
          'action': 'check_in',
          'userId': 26,
          'latitude': 12.9716,
          'longitude': 77.5946,
          'accuracyMeters': 10.0,
        },
      );
      expect(checkIn.statusCode, 201);
      expect(checkIn.data['action'], 'check_in');
      expect((checkIn.data['record'] as Map<String, dynamic>)['isLate'], false);

      // Admin generates fresh QR #2 after 4 hours
      currentClock = currentClock.add(const Duration(hours: 4));
      final qrRes2 = await service.handleRequest(
        method: 'POST',
        path: '/qr-sessions',
        headers: {
          'Authorization': 'Bearer admin-token',
          'X-User-Role': 'admin',
        },
        body: {'locationName': 'HQ Gate', 'createdByUserId': 1},
      );
      final qrPayload2 = qrRes2.data['rawQrPayload'] as String;

      // Duplicate check-in must be rejected
      final dupIn = await service.handleRequest(
        method: 'POST',
        path: '/attendance/scan',
        headers: {
          'Authorization': 'Bearer emp-token',
          'X-User-Role': 'user',
        },
        body: {
          'qrPayload': qrPayload2,
          'action': 'check_in',
          'userId': 26,
          'latitude': 12.9716,
          'longitude': 77.5946,
          'accuracyMeters': 10.0,
        },
      );
      expect(dupIn.statusCode, 409);
      expect(dupIn.data['code'], 'DUPLICATE_CHECK_IN');

      // Valid check-out succeeds and records 240 minutes
      final checkOut = await service.handleRequest(
        method: 'POST',
        path: '/attendance/scan',
        headers: {
          'Authorization': 'Bearer emp-token',
          'X-User-Role': 'user',
        },
        body: {
          'qrPayload': qrPayload2,
          'action': 'check_out',
          'userId': 26,
          'latitude': 12.9718,
          'longitude': 77.5949,
          'accuracyMeters': 10.0,
        },
      );
      expect(checkOut.statusCode, 200);
      final record = checkOut.data['record'] as Map<String, dynamic>;
      expect(record['status'], 'completed');
      expect(record['durationMinutes'], 240);
      expect(record['checkOutLat'], 12.9718);
      expect(record['checkOutLng'], 77.5949);
    });

    test('marks check-ins after 09:15 AM local time as late in SQLite',
        () async {
      currentClock = DateTime(2026, 11, 12, 9, 25, 0);
      final qrRes = await service.handleRequest(
        method: 'POST',
        path: '/qr-sessions',
        headers: {
          'Authorization': 'Bearer admin-token',
          'X-User-Role': 'admin',
        },
        body: {'locationName': 'HQ Gate', 'createdByUserId': 1},
      );
      final qrPayload = qrRes.data['rawQrPayload'] as String;

      final lateCheckIn = await service.handleRequest(
        method: 'POST',
        path: '/attendance/scan',
        headers: {
          'Authorization': 'Bearer emp-token',
          'X-User-Role': 'user',
        },
        body: {
          'qrPayload': qrPayload,
          'action': 'check_in',
          'userId': 26,
          'latitude': 12.9716,
          'longitude': 77.5946,
        },
      );
      expect(lateCheckIn.statusCode, 201);
      final rec = lateCheckIn.data['record'] as Map<String, dynamic>;
      expect(rec['isLate'], true);
    });

    test('rejects expired QR after 30 seconds and enforces geofence', () async {
      final qrRes = await service.handleRequest(
        method: 'POST',
        path: '/qr-sessions',
        headers: {
          'Authorization': 'Bearer admin-token',
          'X-User-Role': 'admin',
        },
        body: {
          'locationName': 'Secure Lab',
          'createdByUserId': 1,
          'geofenceLat': 12.9716,
          'geofenceLng': 77.5946,
          'geofenceRadiusMeters': 150.0,
        },
      );
      final qrPayload = qrRes.data['rawQrPayload'] as String;

      // Out-of-geofence coordinates (~1.1 km away) rejected
      final farScan = await service.handleRequest(
        method: 'POST',
        path: '/attendance/scan',
        headers: {
          'Authorization': 'Bearer emp-token',
          'X-User-Role': 'user',
        },
        body: {
          'qrPayload': qrPayload,
          'action': 'check_in',
          'userId': 26,
          'latitude': 12.9816,
          'longitude': 77.5946,
        },
      );
      expect(farScan.statusCode, 403);
      expect(farScan.data['code'], 'OUTSIDE_GEOFENCE');

      // Advance clock past 30s expiry
      currentClock = currentClock.add(const Duration(seconds: 31));
      final expiredScan = await service.handleRequest(
        method: 'POST',
        path: '/attendance/scan',
        headers: {
          'Authorization': 'Bearer emp-token',
          'X-User-Role': 'user',
        },
        body: {
          'qrPayload': qrPayload,
          'action': 'check_in',
          'userId': 26,
          'latitude': 12.9716,
          'longitude': 77.5946,
        },
      );
      expect(expiredScan.statusCode, 410);
      expect(expiredScan.data['code'], 'QR_EXPIRED');

      // Tampered QR payload signature is rejected and logged
      final decodedMap = jsonDecode(qrPayload) as Map<String, dynamic>;
      decodedMap['signature'] = 'forged_signature';
      final tamperedScan = await service.handleRequest(
        method: 'POST',
        path: '/attendance/scan',
        headers: {
          'Authorization': 'Bearer emp-token',
          'X-User-Role': 'user',
        },
        body: {
          'qrPayload': jsonEncode(decodedMap),
          'action': 'check_in',
          'userId': 26,
          'latitude': 12.9716,
          'longitude': 77.5946,
        },
      );
      expect(tamperedScan.statusCode, 400);
      expect(tamperedScan.data['code'], 'QR_INVALID_SIGNATURE');

      // Failed attempts (out_of_range + expired + invalid_signature) are logged in SQLite
      final nonAdminFailed = await service.handleRequest(
        method: 'GET',
        path: '/admin/failed-attempts',
        headers: {
          'Authorization': 'Bearer emp-token',
          'X-User-Role': 'user',
        },
      );
      expect(nonAdminFailed.statusCode, 403);

      final adminFailed = await service.handleRequest(
        method: 'GET',
        path: '/admin/failed-attempts',
        headers: {
          'Authorization': 'Bearer admin-token',
          'X-User-Role': 'admin',
        },
      );
      expect(adminFailed.statusCode, 200);
      final attempts = adminFailed.data['attempts'] as List<dynamic>;
      expect(attempts.length, 3);
      final reasons =
          attempts.map((e) => (e as Map<String, dynamic>)['reason']).toSet();
      expect(
        reasons,
        containsAll([
          FailedAttemptReason.outOfRange.wireValue,
          FailedAttemptReason.expired.wireValue,
          FailedAttemptReason.invalidSignature.wireValue,
        ]),
      );
    });

    test('builds valid Google Maps URI from coordinates', () {
      final uri = GeoUtils.buildGoogleMapsUri(12.9716, 77.5946);
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], '12.971600,77.594600');
    });

    test(
        'seeds weekday-only history with varied coordinates and caps today recentRecords at 3',
        () async {
      final empJwt = buildJwt(
        id: 26,
        expSeconds:
            currentClock.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
      );

      final todayRes = await service.handleRequest(
        method: 'GET',
        path: '/attendance/today',
        queryParameters: {'userId': 26},
        headers: {
          'Authorization': 'Bearer $empJwt',
          'X-User-Role': 'employee',
        },
      );
      expect(todayRes.statusCode, 200);
      final recent = todayRes.data['recentRecords'] as List<dynamic>;
      expect(recent.length, lessThanOrEqualTo(3));

      final historyRes = await service.handleRequest(
        method: 'GET',
        path: '/attendance',
        queryParameters: {'userId': 26},
        headers: {
          'Authorization': 'Bearer $empJwt',
          'X-User-Role': 'employee',
        },
      );
      expect(historyRes.statusCode, 200);
      final records = historyRes.data['records'] as List<dynamic>;
      expect(records, isNotEmpty);

      for (final item in records) {
        final r = item as Map<String, dynamic>;
        final day = DateTime.parse(r['workDate'] as String);
        expect(day.weekday, isNot(DateTime.saturday));
        expect(day.weekday, isNot(DateTime.sunday));

        final inLat = (r['checkInLat'] as num).toDouble();
        final inLng = (r['checkInLng'] as num).toDouble();
        final outLat = (r['checkOutLat'] as num).toDouble();
        final outLng = (r['checkOutLng'] as num).toDouble();
        expect(outLat, isNot(equals(inLat)));
        expect(outLng, isNot(equals(inLng)));

        final distFromHq = GeoUtils.calculateDistanceMeters(
          lat1: 12.9716,
          lng1: 77.5946,
          lat2: inLat,
          lng2: inLng,
        );
        expect(distFromHq, lessThan(250));
      }
    });
  });
}
