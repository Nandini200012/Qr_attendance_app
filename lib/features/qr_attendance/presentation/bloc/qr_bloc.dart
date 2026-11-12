import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:qr_attendance_app/core/errors/error_message_mapper.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/services/location_service.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/generate_qr_session_usecase.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/submit_qr_attendance_usecase.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_event.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_state.dart';

class QRBloc extends Bloc<QrEvent, QrState> {
  QRBloc({
    required GenerateQrSessionUseCase generateQrSessionUseCase,
    required SubmitQrAttendanceUseCase submitQrAttendanceUseCase,
    required LocationService locationService,
    DateTime Function()? clock,
  })  : _generateQrSessionUseCase = generateQrSessionUseCase,
        _submitQrAttendanceUseCase = submitQrAttendanceUseCase,
        _locationService = locationService,
        _clock = clock ?? DateTime.now,
        super(const QrState()) {
    on<QrGeneratorStarted>(_onGeneratorStarted);
    on<QrSessionGenerateRequested>(_onSessionGenerateRequested);
    on<QrCountdownTicked>(_onCountdownTicked);
    on<QrAutoRegenerateToggled>(_onAutoRegenerateToggled);
    on<QrGeofenceToggled>(_onGeofenceToggled);
    on<QrGeneratorStopped>(_onGeneratorStopped);
    on<QrScannerInitialized>(_onScannerInitialized);
    on<QrScanActionChanged>(_onScanActionChanged);
    on<QrLocationRequested>(_onLocationRequested);
    on<QrTorchToggled>(_onTorchToggled);
    on<QrManualInputToggled>(_onManualInputToggled);
    on<QrCameraAvailabilityChanged>(_onCameraAvailabilityChanged);
    on<QrCodeScanned>(_onCodeScanned);
    on<QrScanReset>(_onScanReset);
  }

  final GenerateQrSessionUseCase _generateQrSessionUseCase;
  final SubmitQrAttendanceUseCase _submitQrAttendanceUseCase;
  final LocationService _locationService;
  final DateTime Function() _clock;

  Timer? _countdownTimer;

  Future<void> _onGeneratorStarted(
    QrGeneratorStarted event,
    Emitter<QrState> emit,
  ) async {
    final result = await _generateQrSessionUseCase.getActiveSession();
    result.fold(
      onFailure: (_) {},
      onSuccess: (session) {
        if (session == null) return;
        final remaining = session.remainingSecondsAt(_clock().toUtc());
        if (remaining > 0) {
          emit(state.copyWith(
            generatorStatus: QrGeneratorStatus.active,
            activeSession: session,
            remainingSeconds: remaining,
            lastLocationName: session.locationName,
            clearGeneratorError: true,
          ));
          _startCountdown();
        }
      },
    );
  }

  Future<void> _onSessionGenerateRequested(
    QrSessionGenerateRequested event,
    Emitter<QrState> emit,
  ) async {
    _countdownTimer?.cancel();
    final useGeofence = event.enforceGeofence ?? state.enforceGeofence;
    emit(state.copyWith(
      generatorStatus: QrGeneratorStatus.generating,
      lastLocationName: event.locationName,
      lastUserId: event.createdByUserId,
      lastUserRole: event.userRole,
      enforceGeofence: useGeofence,
      clearGeneratorError: true,
    ));

    final result = await _generateQrSessionUseCase(
      locationName: event.locationName,
      createdByUserId: event.createdByUserId,
      userRole: event.userRole,
      enforceGeofence: useGeofence,
    );

    result.fold(
      onFailure: (failure) {
        emit(state.copyWith(
          generatorStatus: QrGeneratorStatus.failure,
          generatorError: failure.message,
        ));
      },
      onSuccess: (session) {
        final remaining = session.remainingSecondsAt(_clock().toUtc());
        emit(state.copyWith(
          generatorStatus: remaining > 0
              ? QrGeneratorStatus.active
              : QrGeneratorStatus.expired,
          activeSession: session,
          remainingSeconds: remaining,
          clearGeneratorError: true,
        ));
        if (remaining > 0) {
          _startCountdown();
        }
      },
    );
  }

  void _onCountdownTicked(
    QrCountdownTicked event,
    Emitter<QrState> emit,
  ) {
    final session = state.activeSession;
    if (session == null) {
      _countdownTimer?.cancel();
      return;
    }

    final remaining = session.remainingSecondsAt(_clock().toUtc());
    if (remaining <= 0) {
      _countdownTimer?.cancel();
      if (state.autoRegenerate) {
        emit(state.copyWith(
          generatorStatus: QrGeneratorStatus.expired,
          remainingSeconds: 0,
        ));
        add(QrSessionGenerateRequested(
          locationName: state.lastLocationName,
          createdByUserId: state.lastUserId,
          userRole: state.lastUserRole,
          enforceGeofence: state.enforceGeofence,
        ));
      } else {
        emit(state.copyWith(
          generatorStatus: QrGeneratorStatus.expired,
          remainingSeconds: 0,
        ));
      }
    } else {
      emit(state.copyWith(
        generatorStatus: QrGeneratorStatus.active,
        remainingSeconds: remaining,
      ));
    }
  }

  void _onAutoRegenerateToggled(
    QrAutoRegenerateToggled event,
    Emitter<QrState> emit,
  ) {
    emit(state.copyWith(autoRegenerate: event.enabled));
  }

  void _onGeofenceToggled(
    QrGeofenceToggled event,
    Emitter<QrState> emit,
  ) {
    emit(state.copyWith(enforceGeofence: event.enabled));
  }

  void _onGeneratorStopped(
    QrGeneratorStopped event,
    Emitter<QrState> emit,
  ) {
    _countdownTimer?.cancel();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!isClosed) {
          add(const QrCountdownTicked());
        }
      },
    );
  }

  Future<void> _onScannerInitialized(
    QrScannerInitialized event,
    Emitter<QrState> emit,
  ) async {
    final preferred = event.preferredAction;
    final defaultAction = switch (event.todayStatus) {
      AttendanceStatus.checkedIn => 'check_out',
      AttendanceStatus.notCheckedIn => 'check_in',
      AttendanceStatus.completed =>
        preferred == 'check_out' ? 'check_out' : 'check_in',
    };
    emit(state.copyWith(
      scanStatus: QrScanStatus.ready,
      todayStatus: event.todayStatus,
      selectedAction: defaultAction,
      showManualInput: false,
      isTorchOn: false,
      isCameraUnavailable: false,
      clearScanResult: true,
      clearScanError: true,
      clearScanErrorReason: true,
      clearScanFailure: true,
    ));
    add(const QrLocationRequested());
  }

  void _onScanActionChanged(
    QrScanActionChanged event,
    Emitter<QrState> emit,
  ) {
    if (event.action == 'check_in' && !state.canCheckIn) return;
    if (event.action == 'check_out' && !state.canCheckOut) return;

    emit(state.copyWith(
      selectedAction: event.action,
      scanStatus: QrScanStatus.ready,
      clearScanResult: true,
      clearScanError: true,
      clearScanErrorReason: true,
      clearScanFailure: true,
    ));
  }

  Future<void> _onLocationRequested(
    QrLocationRequested event,
    Emitter<QrState> emit,
  ) async {
    emit(state.copyWith(
      locationStatus: LocationFetchStatus.loading,
      clearLocationError: true,
      isLocationPermissionPermanent: false,
      isLocationServiceDisabled: false,
    ));

    try {
      final location = await _locationService.getCurrentLocation();
      emit(state.copyWith(
        locationStatus: LocationFetchStatus.ready,
        capturedLocation: location,
        clearLocationError: true,
      ));
    } catch (e) {
      final failure = mapExceptionToFailure(e);
      final friendlyMessage = ErrorMessageMapper.fromFailure(failure);
      if (failure is LocationFailure) {
        emit(state.copyWith(
          locationStatus: LocationFetchStatus.failure,
          locationError: friendlyMessage,
          isLocationPermissionPermanent: failure.isPermissionDeniedForever,
          isLocationServiceDisabled: failure.isServiceDisabled,
        ));
      } else {
        emit(state.copyWith(
          locationStatus: LocationFetchStatus.failure,
          locationError: friendlyMessage,
        ));
      }
    }
  }

  void _onTorchToggled(
    QrTorchToggled event,
    Emitter<QrState> emit,
  ) {
    emit(state.copyWith(isTorchOn: !state.isTorchOn));
  }

  void _onManualInputToggled(
    QrManualInputToggled event,
    Emitter<QrState> emit,
  ) {
    emit(state.copyWith(showManualInput: !state.showManualInput));
  }

  void _onCameraAvailabilityChanged(
    QrCameraAvailabilityChanged event,
    Emitter<QrState> emit,
  ) {
    final unavailable = !event.isAvailable;
    if (state.isCameraUnavailable == unavailable) return;
    emit(state.copyWith(isCameraUnavailable: unavailable));
  }

  Future<void> _onCodeScanned(
    QrCodeScanned event,
    Emitter<QrState> emit,
  ) async {
    if (state.scanStatus == QrScanStatus.submitting ||
        state.scanStatus == QrScanStatus.success) {
      return;
    }

    // Block scan submission if GPS capture is currently unavailable.
    if (state.locationStatus == LocationFetchStatus.failure) {
      final locationFailure = LocationFailure(
        state.locationError ??
            ErrorMessageMapper.fromFailure(
              const LocationFailure(
                '',
                errorType: LocationErrorType.unavailable,
              ),
            ),
        errorType: state.isLocationServiceDisabled
            ? LocationErrorType.servicesDisabled
            : state.isLocationPermissionPermanent
                ? LocationErrorType.permissionDeniedForever
                : LocationErrorType.unavailable,
      );
      emit(state.copyWith(
        scanStatus: QrScanStatus.failure,
        scanError: ErrorMessageMapper.fromFailure(locationFailure),
        scanFailure: locationFailure,
        clearScanErrorReason: true,
      ));
      return;
    }

    emit(state.copyWith(
      scanStatus: QrScanStatus.submitting,
      clearScanError: true,
      clearScanErrorReason: true,
      clearScanFailure: true,
      clearScanResult: true,
    ));

    final result = await _submitQrAttendanceUseCase(
      rawQrPayload: event.rawPayload,
      action: state.selectedAction,
      userId: event.userId,
      todayStatus: state.todayStatus,
    );

    result.fold(
      onFailure: (failure) {
        final friendlyMessage = ErrorMessageMapper.fromFailure(failure);
        if (failure is QrValidationFailure) {
          emit(state.copyWith(
            scanStatus: QrScanStatus.failure,
            scanError: friendlyMessage,
            scanErrorReason: failure.reason,
            scanFailure: failure,
          ));
        } else if (failure is LocationFailure) {
          emit(state.copyWith(
            scanStatus: QrScanStatus.failure,
            scanError: friendlyMessage,
            scanFailure: failure,
            locationStatus: LocationFetchStatus.failure,
            locationError: friendlyMessage,
            isLocationPermissionPermanent: failure.isPermissionDeniedForever,
            isLocationServiceDisabled: failure.isServiceDisabled,
          ));
        } else {
          emit(state.copyWith(
            scanStatus: QrScanStatus.failure,
            scanError: friendlyMessage,
            scanFailure: failure,
            clearScanErrorReason: true,
          ));
        }
      },
      onSuccess: (scanResult) {
        emit(state.copyWith(
          scanStatus: QrScanStatus.success,
          todayStatus: scanResult.isCheckIn
              ? AttendanceStatus.checkedIn
              : AttendanceStatus.completed,
          scanResult: scanResult,
          capturedLocation: scanResult.capturedLocation,
          locationStatus: LocationFetchStatus.ready,
          clearScanError: true,
          clearScanErrorReason: true,
          clearScanFailure: true,
        ));
      },
    );
  }

  void _onScanReset(
    QrScanReset event,
    Emitter<QrState> emit,
  ) {
    emit(state.copyWith(
      scanStatus: QrScanStatus.ready,
      clearScanResult: true,
      clearScanError: true,
      clearScanErrorReason: true,
      clearScanFailure: true,
    ));
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }
}

