import 'package:equatable/equatable.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/services/location_service.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_scan_result_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_session_entity.dart';

enum QrGeneratorStatus { initial, generating, active, expired, failure }

enum QrScanStatus { ready, submitting, success, failure }

enum LocationFetchStatus { initial, loading, ready, failure }

class QrState extends Equatable {
  const QrState({
    this.generatorStatus = QrGeneratorStatus.initial,
    this.activeSession,
    this.remainingSeconds = 0,
    this.autoRegenerate = false,
    this.enforceGeofence = false,
    this.generatorError,
    this.lastLocationName = 'HQ Main Campus',
    this.lastUserId = 1,
    this.lastUserRole = 'admin',
    this.scanStatus = QrScanStatus.ready,
    this.todayStatus,
    this.selectedAction = 'check_in',
    this.locationStatus = LocationFetchStatus.initial,
    this.capturedLocation,
    this.locationError,
    this.isLocationPermissionPermanent = false,
    this.isLocationServiceDisabled = false,
    this.isTorchOn = false,
    this.showManualInput = false,
    this.isCameraUnavailable = false,
    this.scanResult,
    this.scanError,
    this.scanErrorReason,
    this.scanFailure,
  });

  // Generator state
  final QrGeneratorStatus generatorStatus;
  final QrSessionEntity? activeSession;
  final int remainingSeconds;
  final bool autoRegenerate;
  final bool enforceGeofence;
  final String? generatorError;
  final String lastLocationName;
  final int lastUserId;
  final String lastUserRole;

  // Scanner state
  final QrScanStatus scanStatus;
  final AttendanceStatus? todayStatus;
  final String selectedAction;
  final LocationFetchStatus locationStatus;
  final CapturedLocation? capturedLocation;
  final String? locationError;
  final bool isLocationPermissionPermanent;
  final bool isLocationServiceDisabled;
  final bool isTorchOn;
  final bool showManualInput;
  final bool isCameraUnavailable;
  final QrScanResultEntity? scanResult;
  final String? scanError;
  final QrValidationErrorCode? scanErrorReason;
  final Failure? scanFailure;

  bool get canCheckIn =>
      todayStatus == null || todayStatus == AttendanceStatus.notCheckedIn;

  bool get canCheckOut =>
      todayStatus == null || todayStatus == AttendanceStatus.checkedIn;

  QrState copyWith({
    QrGeneratorStatus? generatorStatus,
    QrSessionEntity? activeSession,
    int? remainingSeconds,
    bool? autoRegenerate,
    bool? enforceGeofence,
    String? generatorError,
    bool clearGeneratorError = false,
    String? lastLocationName,
    int? lastUserId,
    String? lastUserRole,
    QrScanStatus? scanStatus,
    AttendanceStatus? todayStatus,
    String? selectedAction,
    LocationFetchStatus? locationStatus,
    CapturedLocation? capturedLocation,
    String? locationError,
    bool clearLocationError = false,
    bool? isLocationPermissionPermanent,
    bool? isLocationServiceDisabled,
    bool? isTorchOn,
    bool? showManualInput,
    bool? isCameraUnavailable,
    QrScanResultEntity? scanResult,
    bool clearScanResult = false,
    String? scanError,
    bool clearScanError = false,
    QrValidationErrorCode? scanErrorReason,
    bool clearScanErrorReason = false,
    Failure? scanFailure,
    bool clearScanFailure = false,
  }) {
    return QrState(
      generatorStatus: generatorStatus ?? this.generatorStatus,
      activeSession: activeSession ?? this.activeSession,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      autoRegenerate: autoRegenerate ?? this.autoRegenerate,
      enforceGeofence: enforceGeofence ?? this.enforceGeofence,
      generatorError:
          clearGeneratorError ? null : (generatorError ?? this.generatorError),
      lastLocationName: lastLocationName ?? this.lastLocationName,
      lastUserId: lastUserId ?? this.lastUserId,
      lastUserRole: lastUserRole ?? this.lastUserRole,
      scanStatus: scanStatus ?? this.scanStatus,
      todayStatus: todayStatus ?? this.todayStatus,
      selectedAction: selectedAction ?? this.selectedAction,
      locationStatus: locationStatus ?? this.locationStatus,
      capturedLocation: capturedLocation ?? this.capturedLocation,
      locationError:
          clearLocationError ? null : (locationError ?? this.locationError),
      isLocationPermissionPermanent:
          isLocationPermissionPermanent ?? this.isLocationPermissionPermanent,
      isLocationServiceDisabled:
          isLocationServiceDisabled ?? this.isLocationServiceDisabled,
      isTorchOn: isTorchOn ?? this.isTorchOn,
      showManualInput: showManualInput ?? this.showManualInput,
      isCameraUnavailable: isCameraUnavailable ?? this.isCameraUnavailable,
      scanResult: clearScanResult ? null : (scanResult ?? this.scanResult),
      scanError: clearScanError ? null : (scanError ?? this.scanError),
      scanErrorReason: clearScanErrorReason
          ? null
          : (scanErrorReason ?? this.scanErrorReason),
      scanFailure: clearScanFailure ? null : (scanFailure ?? this.scanFailure),
    );
  }

  @override
  List<Object?> get props => [
        generatorStatus,
        activeSession,
        remainingSeconds,
        autoRegenerate,
        enforceGeofence,
        generatorError,
        lastLocationName,
        lastUserId,
        lastUserRole,
        scanStatus,
        todayStatus,
        selectedAction,
        locationStatus,
        capturedLocation,
        locationError,
        isLocationPermissionPermanent,
        isLocationServiceDisabled,
        isTorchOn,
        showManualInput,
        isCameraUnavailable,
        scanResult,
        scanError,
        scanErrorReason,
        scanFailure,
      ];
}

