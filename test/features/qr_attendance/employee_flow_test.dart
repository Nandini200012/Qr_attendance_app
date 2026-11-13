import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_attendance_app/core/errors/error_message_mapper.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/core/services/connectivity_service.dart';
import 'package:qr_attendance_app/core/services/location_service.dart';
import 'package:qr_attendance_app/features/attendance/data/datasources/attendance_local_database.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_summary_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/usecases/get_attendance_history_usecase.dart';
import 'package:qr_attendance_app/features/attendance/domain/usecases/get_today_attendance_usecase.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_event.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_state.dart';
import 'package:qr_attendance_app/features/qr_attendance/data/datasources/qr_remote_datasource.dart';
import 'package:qr_attendance_app/features/qr_attendance/data/repositories/qr_attendance_repository_impl.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/repositories/qr_attendance_repository.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/generate_qr_session_usecase.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/submit_qr_attendance_usecase.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/sync_pending_scans_usecase.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_bloc.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_event.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockQrRepo extends Mock implements QrAttendanceRepository {}

class _MockGenerateQrUseCase extends Mock implements GenerateQrSessionUseCase {}

class _MockSubmitQrUseCase extends Mock implements SubmitQrAttendanceUseCase {}

class _MockLocationService extends Mock implements LocationService {}

class _MockQrRemoteDataSource extends Mock implements QrRemoteDataSource {}

class _FakeConnectivityService implements ConnectivityService {
  bool online = true;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => online;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void emitOnline(bool value) {
    online = value;
    _controller.add(value);
  }

  Future<void> dispose() => _controller.close();
}

class _MockGetTodayAttendanceUseCase extends Mock
    implements GetTodayAttendanceUseCase {}

class _MockGetAttendanceHistoryUseCase extends Mock
    implements GetAttendanceHistoryUseCase {}

class _MockSyncPendingScansUseCase extends Mock
    implements SyncPendingScansUseCase {}

void main() {
  sqfliteFfiInit();

  group('ErrorMessageMapper', () {
    test('never leaks raw enum or exception names', () {
      const cameraErr = MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
      final cameraMsg = ErrorMessageMapper.fromCameraError(cameraErr);
      expect(cameraMsg.toLowerCase(), isNot(contains('permissiondenied')));
      expect(cameraMsg.toLowerCase(), contains('camera'));

      const locFailure = LocationFailure(
        'LocationPermission.denied',
        errorType: LocationErrorType.permissionDenied,
      );
      final locMsg = ErrorMessageMapper.fromFailure(locFailure);
      expect(locMsg.toLowerCase(), isNot(contains('permissiondenied')));
      expect(locMsg.toLowerCase(), contains('location'));

      const netMsg = ErrorMessageMapper.fromFailure;
      expect(
        netMsg(const NetworkFailure('')).toLowerCase(),
        contains('internet'),
      );
      expect(
        netMsg(const QrValidationFailure(
          reason: QrValidationErrorCode.expired,
          message: '',
        )).toLowerCase(),
        contains('expired'),
      );
      expect(
        netMsg(const UnauthorizedFailure('')).toLowerCase(),
        contains('session'),
      );
    });
  });

  group('SubmitQrAttendanceUseCase domain check-in/out rules', () {
    late _MockQrRepo repo;
    late SubmitQrAttendanceUseCase useCase;

    setUp(() {
      repo = _MockQrRepo();
      useCase = SubmitQrAttendanceUseCase(repo);
    });

    test('blocks check_out when notCheckedIn without calling repository',
        () async {
      final result = await useCase(
        rawQrPayload: 'payload',
        action: 'check_out',
        userId: 26,
        todayStatus: AttendanceStatus.notCheckedIn,
      );
      expect(result.failureOrNull, isA<QrValidationFailure>());
      expect(
        (result.failureOrNull! as QrValidationFailure).reason,
        QrValidationErrorCode.noActiveCheckIn,
      );
      verifyZeroInteractions(repo);
    });

    test('blocks check_in when already checkedIn without calling repository',
        () async {
      final result = await useCase(
        rawQrPayload: 'payload',
        action: 'check_in',
        userId: 26,
        todayStatus: AttendanceStatus.checkedIn,
      );
      expect(result.failureOrNull, isA<QrValidationFailure>());
      expect(
        (result.failureOrNull! as QrValidationFailure).reason,
        QrValidationErrorCode.duplicateCheckIn,
      );
      verifyZeroInteractions(repo);
    });
  });

  group('QRBloc GPS block, state rules & camera flag', () {
    late _MockGenerateQrUseCase generateUseCase;
    late _MockSubmitQrUseCase submitUseCase;
    late _MockLocationService locationService;

    setUp(() {
      generateUseCase = _MockGenerateQrUseCase();
      submitUseCase = _MockSubmitQrUseCase();
      locationService = _MockLocationService();
    });

    QRBloc buildBloc() => QRBloc(
          generateQrSessionUseCase: generateUseCase,
          submitQrAttendanceUseCase: submitUseCase,
          locationService: locationService,
        );

    blocTest<QRBloc, QrState>(
      'blocks scan when GPS is unavailable without submitting QR',
      setUp: () {
        when(() => locationService.getCurrentLocation()).thenThrow(
          const LocationException(
            'permissionDenied',
            errorType: LocationErrorType.permissionDenied,
          ),
        );
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const QrScannerInitialized(
          todayStatus: AttendanceStatus.notCheckedIn,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const QrCodeScanned(rawPayload: 'valid', userId: 26));
      },
      verify: (_) {
        verifyNever(() => submitUseCase(
              rawQrPayload: any(named: 'rawQrPayload'),
              action: any(named: 'action'),
              userId: any(named: 'userId'),
              todayStatus: any(named: 'todayStatus'),
            ));
      },
      expect: () => [
        isA<QrState>().having(
          (s) => s.todayStatus,
          'todayStatus',
          AttendanceStatus.notCheckedIn,
        ),
        isA<QrState>().having(
          (s) => s.locationStatus,
          'locationStatus',
          LocationFetchStatus.loading,
        ),
        isA<QrState>()
            .having(
              (s) => s.locationStatus,
              'locationStatus',
              LocationFetchStatus.failure,
            )
            .having(
              (s) => s.locationError?.contains('permissionDenied') ?? false,
              'raw enum leak',
              isFalse,
            ),
        isA<QrState>()
            .having((s) => s.scanStatus, 'scanStatus', QrScanStatus.failure)
            .having((s) => s.scanFailure, 'scanFailure', isA<LocationFailure>()),
      ],
    );

    blocTest<QRBloc, QrState>(
      'prevents toggling to check_out when notCheckedIn and tracks camera state',
      setUp: () {
        when(() => locationService.getCurrentLocation()).thenAnswer(
          (_) async => CapturedLocation(
            latitude: 12.9716,
            longitude: 77.5946,
            accuracyMeters: 5,
            capturedAtUtc: DateTime.utc(2026, 11, 12, 9, 0),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const QrScannerInitialized(
          todayStatus: AttendanceStatus.notCheckedIn,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const QrScanActionChanged('check_out'));
        bloc.add(const QrCameraAvailabilityChanged(false));
      },
      expect: () => [
        isA<QrState>()
            .having((s) => s.selectedAction, 'selectedAction', 'check_in')
            .having((s) => s.canCheckIn, 'canCheckIn', true)
            .having((s) => s.canCheckOut, 'canCheckOut', false),
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
        isA<QrState>()
            .having((s) => s.isCameraUnavailable, 'isCameraUnavailable', true)
            .having((s) => s.selectedAction, 'selectedAction', 'check_in'),
      ],
    );
  });

  group('Offline queuing & auto-sync', () {
    test('saves pending scan in SQLite when offline and reports queued result',
        () async {
      final db = SqliteAttendanceDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final connectivity = _FakeConnectivityService()..online = false;
      final locationService = _MockLocationService();
      final remote = _MockQrRemoteDataSource();

      when(() => locationService.getCurrentLocation()).thenAnswer(
        (_) async => CapturedLocation(
          latitude: 12.9716,
          longitude: 77.5946,
          accuracyMeters: 6,
          capturedAtUtc: DateTime.utc(2026, 11, 12, 9, 0),
        ),
      );

      final repo = QrAttendanceRepositoryImpl(
        remoteDataSource: remote,
        locationService: locationService,
        localDatabase: db,
        connectivityService: connectivity,
      );

      final res = await repo.submitQrAttendance(
        rawQrPayload: '{"sid":"sess_1","loc":"HQ"}',
        action: 'check_in',
        userId: 26,
      );

      expect(res.isSuccess, isTrue);
      final value = res.dataOrNull!;
      expect(value.isOfflineQueued, isTrue);
      expect(
        value.message,
        "Saved offline. Will sync when you're back online.",
      );
      expect(value.record.isPendingSync, isTrue);

      final pending = await db.getPendingScans(userId: 26);
      expect(pending.length, 1);
      verifyZeroInteractions(remote);

      await db.close();
      await connectivity.dispose();
    });

    blocTest<AttendanceBloc, AttendanceState>(
      'auto-syncs pending scans and refreshes Dashboard and History when online',
      setUp: () {},
      build: () {
        final todayUseCase = _MockGetTodayAttendanceUseCase();
        final historyUseCase = _MockGetAttendanceHistoryUseCase();
        final syncUseCase = _MockSyncPendingScansUseCase();
        final connectivity = _FakeConnectivityService()..online = false;

        when(() => todayUseCase(userId: 26)).thenAnswer(
          (_) async => const ResultFailure(NetworkFailure()),
        );
        when(() => syncUseCase(userId: 26))
            .thenAnswer((_) async => const Success(1));
        when(() => historyUseCase(
              userId: 26,
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
              statusFilter: any(named: 'statusFilter'),
            )).thenAnswer(
          (_) async => Success(
            AttendanceHistoryResult(
              summary: AttendanceSummaryEntity.empty(),
              records: const [],
            ),
          ),
        );

        final bloc = AttendanceBloc(
          getTodayAttendanceUseCase: todayUseCase,
          getAttendanceHistoryUseCase: historyUseCase,
          connectivityService: connectivity,
          syncPendingScansUseCase: syncUseCase,
        );

        Future<void>.delayed(const Duration(milliseconds: 20), () {
          when(() => todayUseCase(userId: 26)).thenAnswer(
            (_) async => Success(
              TodayAttendanceOverview(
                workDate: '2026-11-12',
                status: AttendanceStatus.checkedIn,
                summary: AttendanceSummaryEntity.empty(),
                recentRecords: const [],
              ),
            ),
          );
          connectivity.emitOnline(true);
        });

        return bloc;
      },
      act: (bloc) async {
        bloc.add(const AttendanceDashboardRequested(26));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      },
      expect: () => [
        isA<AttendanceState>()
            .having((s) => s.dashboardStatus, 'dash1', AttendanceLoadStatus.loading),
        isA<AttendanceState>()
            .having((s) => s.dashboardStatus, 'dash2', AttendanceLoadStatus.failure),
        isA<AttendanceState>()
            .having((s) => s.dashboardStatus, 'dash3', AttendanceLoadStatus.loading),
        isA<AttendanceState>()
            .having((s) => s.dashboardStatus, 'dash4', AttendanceLoadStatus.loaded)
            .having((s) => s.todayOverview?.status, 'status', AttendanceStatus.checkedIn),
        isA<AttendanceState>()
            .having((s) => s.historyStatus, 'hist1', AttendanceLoadStatus.loading),
        isA<AttendanceState>()
            .having((s) => s.historyStatus, 'hist2', AttendanceLoadStatus.loaded),
      ],
    );
  });
}
