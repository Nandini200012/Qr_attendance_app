import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_attendance_app/core/constants/app_constants.dart';
import 'package:qr_attendance_app/core/di/injection_container.dart';
import 'package:qr_attendance_app/core/errors/error_message_mapper.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/services/location_service.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/core/utils/geo_utils.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_event.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_scan_result_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_bloc.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_event.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_state.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/widgets/scanner_overlay_widget.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({
    super.key,
    this.preferredAction,
  });

  final String? preferredAction;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manualPayloadController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    final todayStatus =
        context.read<AttendanceBloc>().state.todayOverview?.status ??
            AttendanceStatus.notCheckedIn;
    context.read<QRBloc>().add(
          QrScannerInitialized(
            todayStatus: todayStatus,
            preferredAction: widget.preferredAction,
          ),
        );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualPayloadController.dispose();
    super.dispose();
  }

  void _handleDetected(BuildContext context, BarcodeCapture capture) {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        context.read<QRBloc>().add(
              QrCodeScanned(rawPayload: raw.trim(), userId: user.id),
            );
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Attendance QR'),
        actions: [
          BlocBuilder<QRBloc, QrState>(
            buildWhen: (prev, curr) =>
                prev.isTorchOn != curr.isTorchOn ||
                prev.showManualInput != curr.showManualInput ||
                prev.isCameraUnavailable != curr.isCameraUnavailable,
            builder: (context, state) {
              return Row(
                children: [
                  // Hide torch control on Web and when camera is unavailable.
                  if (!kIsWeb &&
                      !state.showManualInput &&
                      !state.isCameraUnavailable)
                    IconButton(
                      tooltip:
                          state.isTorchOn ? 'Turn off flash' : 'Turn on flash',
                      onPressed: () {
                        _scannerController.toggleTorch();
                        context.read<QRBloc>().add(const QrTorchToggled());
                      },
                      icon: Icon(
                        state.isTorchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                      ),
                    ),
                  if (AppConstants.enableManualPayloadEntry)
                    IconButton(
                      tooltip: state.showManualInput
                          ? 'Use Camera Scanner'
                          : 'Paste QR Payload',
                      onPressed: () => context
                          .read<QRBloc>()
                          .add(const QrManualInputToggled()),
                      icon: Icon(
                        state.showManualInput
                            ? Icons.camera_alt_outlined
                            : Icons.keyboard_alt_outlined,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<QRBloc, QrState>(
        listenWhen: (prev, curr) => prev.scanStatus != curr.scanStatus,
        listener: (context, state) {
          if (state.scanStatus == QrScanStatus.success) {
            context
                .read<AttendanceBloc>()
                .add(AttendanceDashboardRequested(user.id));
            context
                .read<AttendanceBloc>()
                .add(AttendanceHistoryRequested(userId: user.id));
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              _ScannerControlHeader(
                state: state,
                onActionChanged: (action) =>
                    context.read<QRBloc>().add(QrScanActionChanged(action)),
                onRetryLocation: () =>
                    context.read<QRBloc>().add(const QrLocationRequested()),
              ),
              Expanded(
                child: _buildMainViewport(context, user.id, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainViewport(
    BuildContext context,
    int userId,
    QrState state,
  ) {
    if (state.scanStatus == QrScanStatus.success && state.scanResult != null) {
      return _ScanSuccessView(
        result: state.scanResult!,
        onDone: () {
          context.read<QRBloc>().add(const QrScanReset());
          context.pop();
        },
      );
    }

    if (state.scanStatus == QrScanStatus.failure && state.scanError != null) {
      final isLocationError = state.scanFailure is LocationFailure;
      return _ScanFailureView(
        message: state.scanError!,
        reason: state.scanErrorReason,
        failure: state.scanFailure,
        onRetryScan: () {
          if (isLocationError) {
            context.read<QRBloc>().add(const QrLocationRequested());
          }
          context.read<QRBloc>().add(const QrScanReset());
        },
      );
    }

    if (AppConstants.enableManualPayloadEntry && state.showManualInput) {
      return _ManualQrInputView(
        controller: _manualPayloadController,
        isSubmitting: state.scanStatus == QrScanStatus.submitting,
        onSubmit: () {
          final raw = _manualPayloadController.text.trim();
          if (raw.isEmpty) return;
          context
              .read<QRBloc>()
              .add(QrCodeScanned(rawPayload: raw, userId: userId));
        },
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            context.read<QRBloc>().add(const QrCameraAvailabilityChanged(true));
            _handleDetected(context, capture);
          },
          errorBuilder: (context, error) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context
                    .read<QRBloc>()
                    .add(const QrCameraAvailabilityChanged(false));
              }
            });
            final friendlyCameraError =
                ErrorMessageMapper.fromCameraError(error);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.videocam_off_rounded,
                          size: 44,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Camera Unavailable',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          friendlyCameraError,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (AppConstants.enableManualPayloadEntry) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'You can paste a signed QR payload directly to test attendance validation.',
                            softWrap: true,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => context
                                  .read<QRBloc>()
                                  .add(const QrManualInputToggled()),
                              icon: const Icon(Icons.paste_rounded),
                              label: const Text('Enter QR Payload'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (!state.isCameraUnavailable) const ScannerOverlayWidget(),
        if (state.scanStatus == QrScanStatus.submitting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text(
                        'Validating QR & GPS location...',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ScannerControlHeader extends StatelessWidget {
  const _ScannerControlHeader({
    required this.state,
    required this.onActionChanged,
    required this.onRetryLocation,
  });

  final QrState state;
  final ValueChanged<String> onActionChanged;
  final VoidCallback onRetryLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'check_in',
                enabled: state.canCheckIn,
                label: const Text('Check In'),
                icon: const Icon(Icons.login_rounded, size: 18),
              ),
              ButtonSegment<String>(
                value: 'check_out',
                enabled: state.canCheckOut,
                label: const Text('Check Out'),
                icon: const Icon(Icons.logout_rounded, size: 18),
              ),
            ],
            selected: {state.selectedAction},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                onActionChanged(selection.first);
              }
            },
          ),
          const SizedBox(height: 6),
          Text(
            switch (state.todayStatus ?? AttendanceStatus.notCheckedIn) {
              AttendanceStatus.notCheckedIn =>
                'Check Out unlocks after today\'s check-in is recorded.',
              AttendanceStatus.checkedIn =>
                'Check In is disabled because you are already checked in today.',
              AttendanceStatus.completed =>
                'Today\'s shift is completed. Check In and Check Out are disabled.',
            },
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          _LocationStatusBar(
            state: state,
            onRetry: onRetryLocation,
          ),
        ],
      ),
    );
  }
}

class _LocationStatusBar extends StatelessWidget {
  const _LocationStatusBar({
    required this.state,
    required this.onRetry,
  });

  final QrState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (bgColor, fgColor, icon, text) = switch (state.locationStatus) {
      LocationFetchStatus.loading || LocationFetchStatus.initial => (
          AppColors.infoBg,
          AppColors.info,
          Icons.gps_fixed_rounded,
          'Acquiring GPS coordinates...',
        ),
      LocationFetchStatus.ready => (
          AppColors.successBg,
          AppColors.success,
          Icons.location_on_rounded,
          'GPS Ready: ${GeoUtils.formatCoordinates(state.capturedLocation!.latitude, state.capturedLocation!.longitude)} (±${state.capturedLocation!.accuracyMeters.round()}m)',
        ),
      LocationFetchStatus.failure => (
          AppColors.errorBg,
          AppColors.error,
          Icons.location_off_rounded,
          state.locationError ?? 'GPS coordinates unavailable. Please retry.',
        ),
    };

    final needsSettings = state.isLocationServiceDisabled ||
        state.isLocationPermissionPermanent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fgColor,
                  ),
                ),
              ),
              if (state.locationStatus == LocationFetchStatus.failure &&
                  (!kIsWeb || !needsSettings))
                TextButton(
                  onPressed: () {
                    if (!kIsWeb && state.isLocationServiceDisabled) {
                      sl<LocationService>().openLocationSettings();
                    } else if (!kIsWeb && state.isLocationPermissionPermanent) {
                      sl<LocationService>().openAppSettings();
                    } else {
                      onRetry();
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: fgColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                  ),
                  child: Text(
                    !kIsWeb && needsSettings ? 'Settings' : 'Retry',
                  ),
                ),
            ],
          ),
          if (state.locationStatus == LocationFetchStatus.failure &&
              kIsWeb &&
              needsSettings)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4),
              child: Text(
                'Click the lock icon next to the address bar, allow Location, then reload.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManualQrInputView extends StatelessWidget {
  const _ManualQrInputView({
    required this.controller,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Paste Signed QR Payload',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Submit a QR JSON payload copied from the Admin QR Generator (useful on emulators/desktops or to test expired/invalid QR validation).',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLines: 5,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      hintText: '{"app":"smart_qr_attendance", ...}',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: isSubmitting ? null : onSubmit,
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_outlined),
                    label: const Text('Validate & Submit Attendance'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanSuccessView extends StatelessWidget {
  const _ScanSuccessView({
    required this.result,
    required this.onDone,
  });

  final QrScanResultEntity result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: result.isOfflineQueued
                          ? AppColors.warningBg
                          : AppColors.successBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      result.isOfflineQueued
                          ? Icons.cloud_upload_outlined
                          : Icons.check_circle_rounded,
                      color: result.isOfflineQueued
                          ? AppColors.warning
                          : AppColors.success,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    result.isOfflineQueued
                        ? 'Saved Offline (Pending Sync)'
                        : result.isCheckIn
                            ? 'Check-In Recorded'
                            : 'Check-Out Recorded',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _ResultRow(
                          label: 'Location',
                          value: result.record.locationName,
                        ),
                        const SizedBox(height: 8),
                        _ResultRow(
                          label: 'Verified Time',
                          value: DateTimeUtils.formatTimeWithSeconds(
                            result.serverTimestamp,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ResultRow(
                          label: 'GPS Coordinates',
                          value: GeoUtils.formatCoordinates(
                            result.capturedLocation.latitude,
                            result.capturedLocation.longitude,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ResultRow(
                          label: 'Session ID',
                          value: result.record.sessionId,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onDone,
                      child: const Text('Back to Dashboard'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanFailureView extends StatelessWidget {
  const _ScanFailureView({
    required this.message,
    required this.reason,
    required this.failure,
    required this.onRetryScan,
  });

  final String message;
  final QrValidationErrorCode? reason;
  final Failure? failure;
  final VoidCallback onRetryScan;

  @override
  Widget build(BuildContext context) {
    final (title, icon) = _resolveFailureDisplay();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.errorBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.error,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onRetryScan,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  (String, IconData) _resolveFailureDisplay() {
    if (reason != null) {
      return switch (reason!) {
        QrValidationErrorCode.expired =>
          ('QR Code Expired', Icons.timer_off_outlined),
        QrValidationErrorCode.invalidSignature =>
          ('Invalid or Tampered QR', Icons.gpp_bad_rounded),
        QrValidationErrorCode.malformed =>
          ('Unrecognized QR Payload', Icons.qr_code_2_rounded),
        QrValidationErrorCode.duplicateCheckIn =>
          ('Already Checked In Today', Icons.event_busy_rounded),
        QrValidationErrorCode.noActiveCheckIn =>
          ('Check-In Required First', Icons.login_rounded),
        QrValidationErrorCode.alreadyCheckedOut =>
          ('Already Checked Out', Icons.done_all_rounded),
        QrValidationErrorCode.outsideGeofence =>
          ('Outside 250m Geofence', Icons.wrong_location_rounded),
        QrValidationErrorCode.replayDetected =>
          ('Duplicate QR Scan', Icons.content_copy_rounded),
        QrValidationErrorCode.inactiveSession =>
          ('QR Session Inactive', Icons.block_rounded),
      };
    }

    if (failure is NetworkFailure) {
      return ('No Internet Connection', Icons.wifi_off_rounded);
    }
    if (failure is TimeoutFailure) {
      return ('Request Timed Out', Icons.hourglass_disabled_rounded);
    }
    if (failure is UnauthorizedFailure || failure is ForbiddenFailure) {
      return ('Unauthorized Access', Icons.lock_outline_rounded);
    }
    if (failure is LocationFailure) {
      return ('GPS Location Required', Icons.location_off_rounded);
    }
    return ('Attendance Validation Failed', Icons.gpp_bad_rounded);
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

