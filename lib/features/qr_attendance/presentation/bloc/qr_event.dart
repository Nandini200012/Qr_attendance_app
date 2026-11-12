import 'package:equatable/equatable.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';

sealed class QrEvent extends Equatable {
  const QrEvent();

  @override
  List<Object?> get props => [];
}

final class QrGeneratorStarted extends QrEvent {
  const QrGeneratorStarted();
}

final class QrSessionGenerateRequested extends QrEvent {
  const QrSessionGenerateRequested({
    required this.locationName,
    required this.createdByUserId,
    required this.userRole,
    this.enforceGeofence,
  });

  final String locationName;
  final int createdByUserId;
  final String userRole;
  final bool? enforceGeofence;

  @override
  List<Object?> get props =>
      [locationName, createdByUserId, userRole, enforceGeofence];
}

final class QrCountdownTicked extends QrEvent {
  const QrCountdownTicked();
}

final class QrAutoRegenerateToggled extends QrEvent {
  const QrAutoRegenerateToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

final class QrGeofenceToggled extends QrEvent {
  const QrGeofenceToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

final class QrScannerInitialized extends QrEvent {
  const QrScannerInitialized({
    required this.todayStatus,
    this.preferredAction,
  });

  final AttendanceStatus todayStatus;
  final String? preferredAction;

  @override
  List<Object?> get props => [todayStatus, preferredAction];
}

final class QrScanActionChanged extends QrEvent {
  const QrScanActionChanged(this.action);

  final String action;

  @override
  List<Object?> get props => [action];
}

final class QrLocationRequested extends QrEvent {
  const QrLocationRequested();
}

final class QrTorchToggled extends QrEvent {
  const QrTorchToggled();
}

final class QrManualInputToggled extends QrEvent {
  const QrManualInputToggled();
}

final class QrCameraAvailabilityChanged extends QrEvent {
  const QrCameraAvailabilityChanged(this.isAvailable);

  final bool isAvailable;

  @override
  List<Object?> get props => [isAvailable];
}

final class QrCodeScanned extends QrEvent {
  const QrCodeScanned({
    required this.rawPayload,
    required this.userId,
  });

  final String rawPayload;
  final int userId;

  @override
  List<Object?> get props => [rawPayload, userId];
}

final class QrScanReset extends QrEvent {
  const QrScanReset();
}

final class QrGeneratorStopped extends QrEvent {
  const QrGeneratorStopped();
}

