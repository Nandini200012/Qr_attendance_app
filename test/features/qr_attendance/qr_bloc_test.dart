import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/core/services/location_service.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_scan_result_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_session_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/generate_qr_session_usecase.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/submit_qr_attendance_usecase.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_bloc.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_event.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_state.dart';

class _MockGenerateQrSessionUseCase extends Mock
    implements GenerateQrSessionUseCase {}

class _MockSubmitQrAttendanceUseCase extends Mock
    implements SubmitQrAttendanceUseCase {}

class _MockLocationService extends Mock implements LocationService {}

void main() {
  late _MockGenerateQrSessionUseCase generateUseCase;
  late _MockSubmitQrAttendanceUseCase submitUseCase;
  late _MockLocationService locationService;
  late DateTime nowUtc;

  final sampleLoc = CapturedLocation(
    latitude: 12.9716,
    longitude: 77.5946,
    accuracyMeters: 10,
    capturedAtUtc: DateTime.utc(2026, 11, 12, 9, 0, 0),
  );

  setUp(() {
    generateUseCase = _MockGenerateQrSessionUseCase();
    submitUseCase = _MockSubmitQrAttendanceUseCase();
    locationService = _MockLocationService();
    nowUtc = DateTime.utc(2026, 11, 12, 9, 0, 0);
  });

  QRBloc buildBloc() => QRBloc(
        generateQrSessionUseCase: generateUseCase,
        submitQrAttendanceUseCase: submitUseCase,
        locationService: locationService,
        clock: () => nowUtc,
      );

  group('QRBloc', () {
    blocTest<QRBloc, QrState>(
      'generates active 30s QR session and marks expired when countdown finishes',
      setUp: () {
        final session = QrSessionEntity(
          sessionId: 'sess_1',
          nonce: 'n1',
          locationName: 'HQ Lobby',
          issuedAt: nowUtc,
          expiresAt: nowUtc.add(const Duration(seconds: 30)),
          validitySeconds: 30,
          rawQrPayload: '{"app":"smart_qr_attendance"}',
          isActive: true,
        );
        when(() => generateUseCase(
              locationName: 'HQ Lobby',
              createdByUserId: 1,
              userRole: 'admin',
              enforceGeofence: false,
            )).thenAnswer((_) async => Success(session));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const QrSessionGenerateRequested(
          locationName: 'HQ Lobby',
          createdByUserId: 1,
          userRole: 'admin',
        ));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        nowUtc = nowUtc.add(const Duration(seconds: 31));
        bloc.add(const QrCountdownTicked());
      },
      expect: () => [
        isA<QrState>().having(
          (s) => s.generatorStatus,
          'generatorStatus',
          QrGeneratorStatus.generating,
        ),
        isA<QrState>()
            .having(
              (s) => s.generatorStatus,
              'generatorStatus',
              QrGeneratorStatus.active,
            )
            .having((s) => s.remainingSeconds, 'remainingSeconds', 30),
        isA<QrState>()
            .having(
              (s) => s.generatorStatus,
              'generatorStatus',
              QrGeneratorStatus.expired,
            )
            .having((s) => s.remainingSeconds, 'remainingSeconds', 0),
      ],
    );

    blocTest<QRBloc, QrState>(
      'emits scan success when QR attendance submission succeeds',
      setUp: () {
        final record = AttendanceRecordEntity(
          id: 'att_1',
          userId: 26,
          workDate: '2026-11-12',
          sessionId: 'sess_1',
          locationName: 'HQ Lobby',
          status: AttendanceStatus.checkedIn,
          checkInAt: nowUtc,
          checkInLat: 12.9716,
          checkInLng: 77.5946,
        );
        final scanResult = QrScanResultEntity(
          action: 'check_in',
          message: 'Check-in verified.',
          serverTimestamp: nowUtc,
          record: record,
          capturedLocation: sampleLoc,
        );
        when(() => submitUseCase(
              rawQrPayload: 'valid-payload',
              action: 'check_in',
              userId: 26,
            )).thenAnswer((_) async => Success(scanResult));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const QrCodeScanned(rawPayload: 'valid-payload', userId: 26),
      ),
      expect: () => [
        isA<QrState>().having(
          (s) => s.scanStatus,
          'scanStatus',
          QrScanStatus.submitting,
        ),
        isA<QrState>()
            .having((s) => s.scanStatus, 'scanStatus', QrScanStatus.success)
            .having((s) => s.scanResult?.action, 'action', 'check_in'),
      ],
    );

    blocTest<QRBloc, QrState>(
      'emits scan failure with expired reason when QR is expired',
      setUp: () {
        when(() => submitUseCase(
              rawQrPayload: 'expired-payload',
              action: 'check_in',
              userId: 26,
            )).thenAnswer(
          (_) async => const ResultFailure(
            QrValidationFailure(
              reason: QrValidationErrorCode.expired,
              message: 'QR code expired.',
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const QrCodeScanned(rawPayload: 'expired-payload', userId: 26),
      ),
      expect: () => [
        isA<QrState>().having(
          (s) => s.scanStatus,
          'scanStatus',
          QrScanStatus.submitting,
        ),
        isA<QrState>()
            .having((s) => s.scanStatus, 'scanStatus', QrScanStatus.failure)
            .having(
              (s) => s.scanErrorReason,
              'scanErrorReason',
              QrValidationErrorCode.expired,
            ),
      ],
    );

    blocTest<QRBloc, QrState>(
      'initializes check_out when todayStatus is checkedIn and emits scan success',
      setUp: () {
        when(() => locationService.getCurrentLocation())
            .thenAnswer((_) async => sampleLoc);
        final record = AttendanceRecordEntity(
          id: 'att_1',
          userId: 26,
          workDate: '2026-11-12',
          sessionId: 'sess_1',
          locationName: 'HQ Lobby',
          status: AttendanceStatus.completed,
          checkInAt: nowUtc.subtract(const Duration(hours: 8)),
          checkInLat: 12.9716,
          checkInLng: 77.5946,
          checkOutAt: nowUtc,
          checkOutLat: 12.9716,
          checkOutLng: 77.5946,
          durationMinutes: 480,
        );
        when(() => submitUseCase(
              rawQrPayload: 'checkout-payload',
              action: 'check_out',
              userId: 26,
              todayStatus: AttendanceStatus.checkedIn,
            )).thenAnswer(
          (_) async => Success(
            QrScanResultEntity(
              action: 'check_out',
              message: 'Check-out verified.',
              serverTimestamp: nowUtc,
              record: record,
              capturedLocation: sampleLoc,
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(
          const QrScannerInitialized(todayStatus: AttendanceStatus.checkedIn),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const QrCodeScanned(rawPayload: 'checkout-payload', userId: 26),
        );
      },
      expect: () => [
        isA<QrState>()
            .having((s) => s.scanStatus, 'scanStatus', QrScanStatus.ready)
            .having((s) => s.selectedAction, 'selectedAction', 'check_out'),
        isA<QrState>().having(
          (s) => s.locationStatus,
          'locationStatus',
          LocationFetchStatus.loading,
        ),
        isA<QrState>().having(
          (s) => s.locationStatus,
          'locationStatus',
          LocationFetchStatus.ready,
        ),
        isA<QrState>().having(
          (s) => s.scanStatus,
          'scanStatus',
          QrScanStatus.submitting,
        ),
        isA<QrState>()
            .having((s) => s.scanStatus, 'scanStatus', QrScanStatus.success)
            .having((s) => s.scanResult?.action, 'action', 'check_out'),
      ],
    );

    blocTest<QRBloc, QrState>(
      'emits scan failure with invalidSignature when QR signature is tampered',
      setUp: () {
        when(() => submitUseCase(
              rawQrPayload: 'tampered-payload',
              action: 'check_in',
              userId: 26,
            )).thenAnswer(
          (_) async => const ResultFailure(
            QrValidationFailure(
              reason: QrValidationErrorCode.invalidSignature,
              message: 'QR signature verification failed.',
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const QrCodeScanned(rawPayload: 'tampered-payload', userId: 26),
      ),
      expect: () => [
        isA<QrState>().having(
          (s) => s.scanStatus,
          'scanStatus',
          QrScanStatus.submitting,
        ),
        isA<QrState>()
            .having((s) => s.scanStatus, 'scanStatus', QrScanStatus.failure)
            .having(
              (s) => s.scanErrorReason,
              'scanErrorReason',
              QrValidationErrorCode.invalidSignature,
            ),
      ],
    );

    blocTest<QRBloc, QrState>(
      'emits scan failure with duplicateCheckIn on duplicate check-in attempt',
      setUp: () {
        when(() => submitUseCase(
              rawQrPayload: 'dup-payload',
              action: 'check_in',
              userId: 26,
            )).thenAnswer(
          (_) async => const ResultFailure(
            QrValidationFailure(
              reason: QrValidationErrorCode.duplicateCheckIn,
              message: 'Duplicate check-in blocked.',
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const QrCodeScanned(rawPayload: 'dup-payload', userId: 26),
      ),
      expect: () => [
        isA<QrState>().having(
          (s) => s.scanStatus,
          'scanStatus',
          QrScanStatus.submitting,
        ),
        isA<QrState>()
            .having((s) => s.scanStatus, 'scanStatus', QrScanStatus.failure)
            .having(
              (s) => s.scanErrorReason,
              'scanErrorReason',
              QrValidationErrorCode.duplicateCheckIn,
            ),
      ],
    );

    blocTest<QRBloc, QrState>(
      'emits scan failure with outsideGeofence when employee is outside 250m radius',
      setUp: () {
        when(() => submitUseCase(
              rawQrPayload: 'far-payload',
              action: 'check_in',
              userId: 26,
            )).thenAnswer(
          (_) async => const ResultFailure(
            QrValidationFailure(
              reason: QrValidationErrorCode.outsideGeofence,
              message: 'Outside allowed office radius (1200m away, max 250m).',
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const QrCodeScanned(rawPayload: 'far-payload', userId: 26),
      ),
      expect: () => [
        isA<QrState>().having(
          (s) => s.scanStatus,
          'scanStatus',
          QrScanStatus.submitting,
        ),
        isA<QrState>()
            .having((s) => s.scanStatus, 'scanStatus', QrScanStatus.failure)
            .having(
              (s) => s.scanErrorReason,
              'scanErrorReason',
              QrValidationErrorCode.outsideGeofence,
            ),
      ],
    );

    blocTest<QRBloc, QrState>(
      'emits scan failure with noActiveCheckIn when checking out without check-in',
      setUp: () {
        when(() => submitUseCase(
              rawQrPayload: 'valid-payload',
              action: 'check_out',
              userId: 26,
            )).thenAnswer(
          (_) async => const ResultFailure(
            QrValidationFailure(
              reason: QrValidationErrorCode.noActiveCheckIn,
              message: 'You must complete check-in before checking out.',
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) {
        bloc.add(const QrScanActionChanged('check_out'));
        bloc.add(
          const QrCodeScanned(rawPayload: 'valid-payload', userId: 26),
        );
      },
      expect: () => [
        isA<QrState>().having((s) => s.selectedAction, 'selectedAction', 'check_out'),
        isA<QrState>().having(
          (s) => s.scanStatus,
          'scanStatus',
          QrScanStatus.submitting,
        ),
        isA<QrState>()
            .having((s) => s.scanStatus, 'scanStatus', QrScanStatus.failure)
            .having(
              (s) => s.scanErrorReason,
              'scanErrorReason',
              QrValidationErrorCode.noActiveCheckIn,
            ),
      ],
    );

    blocTest<QRBloc, QrState>(
      'emits scan failure with location flags when GPS service is disabled',
      setUp: () {
        when(() => submitUseCase(
              rawQrPayload: 'valid-payload',
              action: 'check_in',
              userId: 26,
            )).thenAnswer(
          (_) async => const ResultFailure(
            LocationFailure(
              'Location services are disabled.',
              isServiceDisabled: true,
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const QrCodeScanned(rawPayload: 'valid-payload', userId: 26),
      ),
      expect: () => [
        isA<QrState>().having(
          (s) => s.scanStatus,
          'scanStatus',
          QrScanStatus.submitting,
        ),
        isA<QrState>()
            .having((s) => s.scanStatus, 'scanStatus', QrScanStatus.failure)
            .having(
              (s) => s.locationStatus,
              'locationStatus',
              LocationFetchStatus.failure,
            )
            .having((s) => s.isLocationServiceDisabled, 'disabled', true),
      ],
    );
  });
}

