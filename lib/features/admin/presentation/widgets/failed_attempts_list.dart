import 'package:flutter/material.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/core/utils/geo_utils.dart';
import 'package:qr_attendance_app/core/widgets/app_error_widget.dart';
import 'package:qr_attendance_app/core/widgets/empty_state_widget.dart';
import 'package:qr_attendance_app/core/widgets/loading_widget.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/failed_attempt_entity.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_state.dart';

class FailedAttemptsList extends StatelessWidget {
  const FailedAttemptsList({
    super.key,
    required this.status,
    required this.attempts,
    required this.errorMessage,
    required this.onRefresh,
  });

  final AdminLoadStatus status;
  final List<FailedAttemptEntity> attempts;
  final String? errorMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (status == AdminLoadStatus.initial ||
        (status == AdminLoadStatus.loading && attempts.isEmpty)) {
      return const LoadingWidget(
        message: 'Loading rejected attendance attempts...',
      );
    }

    if (status == AdminLoadStatus.failure && attempts.isEmpty) {
      return AppErrorWidget(
        message: errorMessage ?? 'Unable to load failed attendance attempts.',
        onRetry: () {
          onRefresh();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: attempts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 48),
                EmptyStateWidget(
                  title: 'No Rejected Attempts',
                  message:
                      'All QR attendance scans have passed validation checks.',
                  icon: Icons.verified_user_outlined,
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: attempts.length,
              itemBuilder: (context, index) => _FailedAttemptCard(
                attempt: attempts[index],
              ),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
            ),
    );
  }
}

class _FailedAttemptCard extends StatelessWidget {
  const _FailedAttemptCard({required this.attempt});

  final FailedAttemptEntity attempt;

  @override
  Widget build(BuildContext context) {
    final badgeStyle = _reasonBadgeStyle(attempt.reason);
    final hasGps = GeoUtils.isValidCoordinate(attempt.lat, attempt.lng);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: badgeStyle.background,
                child: Icon(
                  badgeStyle.icon,
                  size: 18,
                  color: badgeStyle.foreground,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attempt.displayEmployeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateTimeUtils.formatShortDate(attempt.timestamp)} • ${DateTimeUtils.formatTime(attempt.timestamp)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeStyle.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  attempt.reason.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: badgeStyle.foreground,
                  ),
                ),
              ),
            ],
          ),
          if (attempt.message != null && attempt.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              attempt.message!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if ((attempt.sessionId != null && attempt.sessionId!.isNotEmpty) ||
              hasGps) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (attempt.sessionId != null && attempt.sessionId!.isNotEmpty)
                  Text(
                    'Session: ${attempt.sessionId}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (hasGps)
                  InkWell(
                    onTap: () => GeoUtils.openOnMap(attempt.lat!, attempt.lng!),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          GeoUtils.formatCoordinates(
                            attempt.lat!,
                            attempt.lng!,
                          ),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  ({Color foreground, Color background, IconData icon}) _reasonBadgeStyle(
    FailedAttemptReason reason,
  ) {
    return switch (reason) {
      FailedAttemptReason.expired => (
          foreground: AppColors.warning,
          background: AppColors.warningBg,
          icon: Icons.timer_off_outlined,
        ),
      FailedAttemptReason.duplicate => (
          foreground: AppColors.warning,
          background: AppColors.warningBg,
          icon: Icons.copy_all_rounded,
        ),
      FailedAttemptReason.invalidSignature => (
          foreground: AppColors.error,
          background: AppColors.errorBg,
          icon: Icons.gpp_bad_outlined,
        ),
      FailedAttemptReason.outOfRange => (
          foreground: AppColors.error,
          background: AppColors.errorBg,
          icon: Icons.location_off_outlined,
        ),
      FailedAttemptReason.unauthorized => (
          foreground: AppColors.error,
          background: AppColors.errorBg,
          icon: Icons.lock_outline_rounded,
        ),
      FailedAttemptReason.networkError => (
          foreground: AppColors.info,
          background: AppColors.infoBg,
          icon: Icons.wifi_off_rounded,
        ),
    };
  }
}
