import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_attendance_app/core/constants/app_constants.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/utils/qr_security_utils.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/validate_qr_payload_usecase.dart';

void main() {
  group('QrSecurityUtils', () {
    test('creates and verifies valid 30-second signed QR payload', () {
      final issuedAt = DateTime.utc(2026, 11, 12, 10, 0, 0);
      final payload = QrSecurityUtils.createSignedPayload(
        sessionId: 'sess_abc123',
        nonce: 'nonce_001',
        locationName: 'HQ Lobby',
        issuedAt: issuedAt,
      );

      expect(
        payload.expiresAt.difference(payload.issuedAt).inSeconds,
        AppConstants.qrValiditySeconds,
      );

      final verified = QrSecurityUtils.validateComplete(
        payload.toRawQrString(),
        referenceTime: issuedAt.add(const Duration(seconds: 15)),
      );

      expect(verified.sessionId, 'sess_abc123');
      expect(verified.locationName, 'HQ Lobby');
    });

    test('rejects expired QR code after 30 seconds', () {
      final issuedAt = DateTime.utc(2026, 11, 12, 10, 0, 0);
      final payload = QrSecurityUtils.createSignedPayload(
        sessionId: 'sess_abc123',
        nonce: 'nonce_002',
        locationName: 'HQ Lobby',
        issuedAt: issuedAt,
      );

      expect(
        () => QrSecurityUtils.validateComplete(
          payload.toRawQrString(),
          referenceTime: issuedAt.add(const Duration(seconds: 31)),
        ),
        throwsA(
          isA<QrValidationException>().having(
            (e) => e.reason,
            'reason',
            QrValidationErrorCode.expired,
          ),
        ),
      );
    });

    test('rejects tampered QR payload with invalidSignature', () {
      final issuedAt = DateTime.utc(2026, 11, 12, 10, 0, 0);
      final payload = QrSecurityUtils.createSignedPayload(
        sessionId: 'sess_abc123',
        nonce: 'nonce_003',
        locationName: 'HQ Lobby',
        issuedAt: issuedAt,
      );

      final tamperedMap = payload.toJson();
      tamperedMap['expiresAt'] =
          issuedAt.add(const Duration(hours: 2)).millisecondsSinceEpoch;

      expect(
        () => QrSecurityUtils.validateComplete(
          jsonEncode(tamperedMap),
          referenceTime: issuedAt.add(const Duration(seconds: 5)),
        ),
        throwsA(
          isA<QrValidationException>().having(
            (e) => e.reason,
            'reason',
            QrValidationErrorCode.invalidSignature,
          ),
        ),
      );
    });

    test('rejects tampered location or geofence coordinates with invalidSignature',
        () {
      final issuedAt = DateTime.utc(2026, 11, 12, 10, 0, 0);
      final payload = QrSecurityUtils.createSignedPayload(
        sessionId: 'sess_geo_1',
        nonce: 'nonce_004',
        locationName: 'HQ Lobby',
        issuedAt: issuedAt,
        geofenceLat: 12.9716,
        geofenceLng: 77.5946,
        geofenceRadiusMeters: 250.0,
      );

      final tamperedLoc = payload.toJson()..['location'] = 'Fake Office';
      expect(
        () => QrSecurityUtils.validateComplete(
          jsonEncode(tamperedLoc),
          referenceTime: issuedAt.add(const Duration(seconds: 5)),
        ),
        throwsA(
          isA<QrValidationException>().having(
            (e) => e.reason,
            'reason',
            QrValidationErrorCode.invalidSignature,
          ),
        ),
      );

      final tamperedLat = payload.toJson()..['lat'] = 13.0000;
      expect(
        () => QrSecurityUtils.validateComplete(
          jsonEncode(tamperedLat),
          referenceTime: issuedAt.add(const Duration(seconds: 5)),
        ),
        throwsA(
          isA<QrValidationException>().having(
            (e) => e.reason,
            'reason',
            QrValidationErrorCode.invalidSignature,
          ),
        ),
      );
    });

    test('rejects unrelated or malformed QR strings', () {
      expect(
        () => QrSecurityUtils.validateComplete('https://example.com/menu'),
        throwsA(
          isA<QrValidationException>().having(
            (e) => e.reason,
            'reason',
            QrValidationErrorCode.malformed,
          ),
        ),
      );
    });
  });

  group('ValidateQrPayloadUseCase', () {
    const validator = ValidateQrPayloadUseCase();

    test('returns Success for valid QR within 30s window', () {
      final issuedAt = DateTime.utc(2026, 11, 12, 10, 0, 0);
      final payload = QrSecurityUtils.createSignedPayload(
        sessionId: 'sess_val_1',
        nonce: 'nonce_val_1',
        locationName: 'HQ Main Campus',
        issuedAt: issuedAt,
        geofenceLat: 12.9716,
        geofenceLng: 77.5946,
        geofenceRadiusMeters: 250.0,
      );

      final result = validator(
        payload.toRawQrString(),
        referenceTime: issuedAt.add(const Duration(seconds: 10)),
      );

      expect(result.isSuccess, true);
      expect(result.dataOrNull?.sessionId, 'sess_val_1');
    });

    test('returns ResultFailure with expired code when QR is expired', () {
      final issuedAt = DateTime.utc(2026, 11, 12, 10, 0, 0);
      final payload = QrSecurityUtils.createSignedPayload(
        sessionId: 'sess_val_2',
        nonce: 'nonce_val_2',
        locationName: 'HQ Main Campus',
        issuedAt: issuedAt,
      );

      final result = validator(
        payload.toRawQrString(),
        referenceTime: issuedAt.add(const Duration(seconds: 31)),
      );

      expect(result.isFailure, true);
      expect(
        result.failureOrNull,
        isA<QrValidationFailure>().having(
          (f) => f.reason,
          'reason',
          QrValidationErrorCode.expired,
        ),
      );
    });

    test('returns ResultFailure with invalidSignature when signature is forged',
        () {
      final issuedAt = DateTime.utc(2026, 11, 12, 10, 0, 0);
      final payload = QrSecurityUtils.createSignedPayload(
        sessionId: 'sess_val_3',
        nonce: 'nonce_val_3',
        locationName: 'HQ Main Campus',
        issuedAt: issuedAt,
      );
      final tampered = payload.toJson()..['signature'] = 'tampered_sig';

      final result = validator(
        jsonEncode(tampered),
        referenceTime: issuedAt.add(const Duration(seconds: 5)),
      );

      expect(result.isFailure, true);
      expect(
        result.failureOrNull,
        isA<QrValidationFailure>().having(
          (f) => f.reason,
          'reason',
          QrValidationErrorCode.invalidSignature,
        ),
      );
    });
  });
}

