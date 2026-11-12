import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/core/utils/validators.dart';
import 'package:qr_attendance_app/core/widgets/status_badge.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_bloc.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_event.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/bloc/qr_state.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/widgets/qr_countdown_ring.dart';

class AdminQrGeneratorPage extends StatefulWidget {
  const AdminQrGeneratorPage({super.key});

  @override
  State<AdminQrGeneratorPage> createState() => _AdminQrGeneratorPageState();
}

class _AdminQrGeneratorPageState extends State<AdminQrGeneratorPage> {
  final TextEditingController _locationController =
      TextEditingController(text: 'HQ Main Campus - Gate A');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    context.read<QRBloc>().add(const QrGeneratorStarted());
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _generate(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;

    context.read<QRBloc>().add(
          QrSessionGenerateRequested(
            locationName: _locationController.text.trim(),
            createdByUserId: user.id,
            userRole: user.role,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dynamic QR Generator')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Administrator access is required to generate attendance QR codes.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic QR Generator'),
      ),
      body: BlocBuilder<QRBloc, QrState>(
        builder: (context, state) {
          final session = state.activeSession;
          final isGenerating =
              state.generatorStatus == QrGeneratorStatus.generating;
          final isExpired = state.generatorStatus == QrGeneratorStatus.expired;
          final isActive = state.generatorStatus == QrGeneratorStatus.active;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Attendance Session Configuration',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _locationController,
                                enabled: !isGenerating,
                                validator: (val) => Validators.validateNonEmpty(
                                  val,
                                  'Session location',
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Office / Shift Location',
                                  prefixIcon: Icon(Icons.location_city_outlined),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Auto-Regenerate Every 30s',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Continuously rotate QR code for unattended kiosk mode',
                                  style: TextStyle(fontSize: 12),
                                ),
                                value: state.autoRegenerate,
                                onChanged: (val) => context
                                    .read<QRBloc>()
                                    .add(QrAutoRegenerateToggled(val)),
                              ),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Enforce Office Geofence (250m)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Embed current GPS coordinates into QR signature',
                                  style: TextStyle(fontSize: 12),
                                ),
                                value: state.enforceGeofence,
                                onChanged: (val) => context
                                    .read<QRBloc>()
                                    .add(QrGeofenceToggled(val)),
                              ),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: isGenerating
                                    ? null
                                    : () => _generate(context),
                                icon: isGenerating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        session == null
                                            ? Icons.qr_code_2_rounded
                                            : Icons.refresh_rounded,
                                      ),
                                label: Text(
                                  session == null
                                      ? 'Generate 30s Attendance QR'
                                      : 'Regenerate Fresh QR Code',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (state.generatorError != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          state.generatorError!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (session != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      session.locationName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  StatusBadge(
                                    label: isActive ? 'LIVE QR' : 'EXPIRED',
                                    foregroundColor: isActive
                                        ? AppColors.success
                                        : AppColors.error,
                                    backgroundColor: isActive
                                        ? AppColors.successBg
                                        : AppColors.errorBg,
                                    icon: isActive
                                        ? Icons.verified_user_outlined
                                        : Icons.timer_off_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              QrCountdownRing(
                                remainingSeconds: state.remainingSeconds,
                                totalSeconds: session.validitySeconds,
                              ),
                              const SizedBox(height: 20),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedOpacity(
                                    opacity: isExpired ? 0.18 : 1.0,
                                    duration: const Duration(milliseconds: 250),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isActive
                                              ? AppColors.primary
                                              : AppColors.error,
                                          width: 2,
                                        ),
                                      ),
                                      child: QrImageView(
                                        data: session.rawQrPayload,
                                        version: QrVersions.auto,
                                        size: 220,
                                        backgroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (isExpired)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.error,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.timer_off_rounded,
                                            color: AppColors.error,
                                            size: 32,
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'QR Code Expired',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: AppColors.error,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          FilledButton.icon(
                                            onPressed: () => _generate(context),
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                              size: 18,
                                            ),
                                            label: const Text('Regenerate QR'),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    _SessionMetaRow(
                                      label: 'Session ID',
                                      value: session.sessionId,
                                    ),
                                    const SizedBox(height: 6),
                                    _SessionMetaRow(
                                      label: 'Issued At',
                                      value: DateTimeUtils.formatTimeWithSeconds(
                                        session.issuedAt,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _SessionMetaRow(
                                      label: 'Expires At',
                                      value: DateTimeUtils.formatTimeWithSeconds(
                                        session.expiresAt,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _SessionMetaRow(
                                      label: 'Security',
                                      value: session.hasGeofence
                                          ? 'HMAC-SHA256 + Geofence'
                                          : 'HMAC-SHA256 Signed',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: session.rawQrPayload),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Signed QR payload copied to clipboard for scanner testing.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Copy Signed QR Payload'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SessionMetaRow extends StatelessWidget {
  const _SessionMetaRow({
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
          '$label:',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12.5,
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

