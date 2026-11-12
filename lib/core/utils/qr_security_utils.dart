import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:qr_attendance_app/core/constants/app_constants.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';

class DecodedQrPayload extends Equatable {
  const DecodedQrPayload({
    required this.app,
    required this.sessionId,
    required this.nonce,
    required this.locationName,
    required this.issuedAtMs,
    required this.expiresAtMs,
    required this.signature,
    this.geofenceLat,
    this.geofenceLng,
    this.geofenceRadiusMeters,
  });

  final String app;
  final String sessionId;
  final String nonce;
  final String locationName;
  final int issuedAtMs;
  final int expiresAtMs;
  final String signature;
  final double? geofenceLat;
  final double? geofenceLng;
  final double? geofenceRadiusMeters;

  DateTime get issuedAt =>
      DateTime.fromMillisecondsSinceEpoch(issuedAtMs, isUtc: true);

  DateTime get expiresAt =>
      DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true);

  bool isExpiredAt(
    DateTime referenceTime, {
    int graceSeconds = 0,
  }) {
    final referenceMs = referenceTime.toUtc().millisecondsSinceEpoch;
    return referenceMs > expiresAtMs + (graceSeconds * 1000);
  }

  int remainingSecondsAt(DateTime referenceTime) {
    final diffMs = expiresAtMs - referenceTime.toUtc().millisecondsSinceEpoch;
    if (diffMs <= 0) return 0;
    return (diffMs / 1000).ceil();
  }

  Map<String, dynamic> toJson() => {
        'app': app,
        'sessionId': sessionId,
        'nonce': nonce,
        'location': locationName,
        'issuedAt': issuedAtMs,
        'expiresAt': expiresAtMs,
        if (geofenceLat != null && geofenceLng != null) ...{
          'lat': geofenceLat,
          'lng': geofenceLng,
          if (geofenceRadiusMeters != null) 'radiusM': geofenceRadiusMeters,
        },
        'signature': signature,
      };

  String toRawQrString() => jsonEncode(toJson());

  @override
  List<Object?> get props => [
        app,
        sessionId,
        nonce,
        locationName,
        issuedAtMs,
        expiresAtMs,
        signature,
        geofenceLat,
        geofenceLng,
        geofenceRadiusMeters,
      ];
}

class QrSecurityUtils {
  const QrSecurityUtils._();

  static String computeSignature({
    required String app,
    required String sessionId,
    required String nonce,
    required String locationName,
    required int issuedAtMs,
    required int expiresAtMs,
    double? geofenceLat,
    double? geofenceLng,
    double? geofenceRadiusMeters,
    String secret = AppConstants.qrServiceSecret,
  }) {
    final latPart = geofenceLat?.toStringAsFixed(6) ?? '';
    final lngPart = geofenceLng?.toStringAsFixed(6) ?? '';
    final radiusPart = geofenceRadiusMeters?.toStringAsFixed(1) ?? '';
    final canonical =
        '$app|$sessionId|$nonce|$locationName|$issuedAtMs|$expiresAtMs|$latPart|$lngPart|$radiusPart';
    final hmac = Hmac(sha256, utf8.encode(secret));
    return hmac.convert(utf8.encode(canonical)).toString();
  }

  static DecodedQrPayload createSignedPayload({
    required String sessionId,
    required String nonce,
    required String locationName,
    required DateTime issuedAt,
    int validitySeconds = AppConstants.qrValiditySeconds,
    double? geofenceLat,
    double? geofenceLng,
    double? geofenceRadiusMeters,
    String secret = AppConstants.qrServiceSecret,
  }) {
    final issuedAtMs = issuedAt.toUtc().millisecondsSinceEpoch;
    final expiresAtMs = issuedAtMs + (validitySeconds * 1000);
    final signature = computeSignature(
      app: AppConstants.qrAppIdentifier,
      sessionId: sessionId,
      nonce: nonce,
      locationName: locationName,
      issuedAtMs: issuedAtMs,
      expiresAtMs: expiresAtMs,
      geofenceLat: geofenceLat,
      geofenceLng: geofenceLng,
      geofenceRadiusMeters: geofenceRadiusMeters,
      secret: secret,
    );

    return DecodedQrPayload(
      app: AppConstants.qrAppIdentifier,
      sessionId: sessionId,
      nonce: nonce,
      locationName: locationName,
      issuedAtMs: issuedAtMs,
      expiresAtMs: expiresAtMs,
      signature: signature,
      geofenceLat: geofenceLat,
      geofenceLng: geofenceLng,
      geofenceRadiusMeters: geofenceRadiusMeters,
    );
  }

  /// Parses raw QR JSON, validates required fields, and verifies HMAC-SHA256
  /// signature. Throws [QrValidationException] on malformed or tampered data.
  static DecodedQrPayload parseAndVerify(
    String rawQrData, {
    String secret = AppConstants.qrServiceSecret,
  }) {
    final trimmed = rawQrData.trim();
    if (trimmed.isEmpty) {
      throw const QrValidationException(
        reason: QrValidationErrorCode.malformed,
        message: 'QR code payload is empty.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      throw const QrValidationException(
        reason: QrValidationErrorCode.malformed,
        message:
            'Unrecognized QR code. Please scan an official Smart QR Attendance code.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const QrValidationException(
        reason: QrValidationErrorCode.malformed,
        message: 'Invalid QR code payload structure.',
      );
    }

    final app = decoded['app'];
    final sessionId = decoded['sessionId'];
    final nonce = decoded['nonce'];
    final location = decoded['location'];
    final issuedAt = decoded['issuedAt'];
    final expiresAt = decoded['expiresAt'];
    final signature = decoded['signature'];

    if (app != AppConstants.qrAppIdentifier ||
        sessionId is! String ||
        sessionId.trim().isEmpty ||
        nonce is! String ||
        nonce.trim().isEmpty ||
        location is! String ||
        issuedAt is! int ||
        expiresAt is! int ||
        signature is! String ||
        signature.trim().isEmpty) {
      throw const QrValidationException(
        reason: QrValidationErrorCode.malformed,
        message: 'QR code is missing required attendance verification fields.',
      );
    }

    if (expiresAt <= issuedAt) {
      throw const QrValidationException(
        reason: QrValidationErrorCode.malformed,
        message: 'QR code contains an invalid expiry timestamp.',
      );
    }

    final latVal = decoded['lat'];
    final lngVal = decoded['lng'];
    final radiusVal = decoded['radiusM'];
    final geofenceLat = latVal is num ? latVal.toDouble() : null;
    final geofenceLng = lngVal is num ? lngVal.toDouble() : null;
    final geofenceRadiusMeters =
        radiusVal is num ? radiusVal.toDouble() : null;

    final expectedSig = computeSignature(
      app: app as String,
      sessionId: sessionId,
      nonce: nonce,
      locationName: location,
      issuedAtMs: issuedAt,
      expiresAtMs: expiresAt,
      geofenceLat: geofenceLat,
      geofenceLng: geofenceLng,
      geofenceRadiusMeters: geofenceRadiusMeters,
      secret: secret,
    );

    if (!_constantTimeEquals(signature, expectedSig)) {
      throw const QrValidationException(
        reason: QrValidationErrorCode.invalidSignature,
        message:
            'QR signature verification failed. This QR code may be forged or tampered with.',
      );
    }

    return DecodedQrPayload(
      app: app,
      sessionId: sessionId,
      nonce: nonce,
      locationName: location,
      issuedAtMs: issuedAt,
      expiresAtMs: expiresAt,
      signature: signature,
      geofenceLat: geofenceLat,
      geofenceLng: geofenceLng,
      geofenceRadiusMeters: geofenceRadiusMeters,
    );
  }

  static DecodedQrPayload validateComplete(
    String rawQrData, {
    DateTime? referenceTime,
    int graceSeconds = 0,
    String secret = AppConstants.qrServiceSecret,
  }) {
    final payload = parseAndVerify(rawQrData, secret: secret);
    final now = (referenceTime ?? DateTime.now()).toUtc();
    if (payload.isExpiredAt(now, graceSeconds: graceSeconds)) {
      final expiredBy =
          ((now.millisecondsSinceEpoch - payload.expiresAtMs) / 1000).ceil();
      throw QrValidationException(
        reason: QrValidationErrorCode.expired,
        message:
            'This QR code expired ${expiredBy <= 1 ? 'just now' : '${expiredBy}s ago'}. Please ask your admin to regenerate a fresh QR code.',
      );
    }
    return payload;
  }

  static bool _constantTimeEquals(String a, String b) {
    final bytesA = utf8.encode(a);
    final bytesB = utf8.encode(b);
    if (bytesA.length != bytesB.length) return false;
    var diff = 0;
    for (var i = 0; i < bytesA.length; i++) {
      diff |= bytesA[i] ^ bytesB[i];
    }
    return diff == 0;
  }
}

