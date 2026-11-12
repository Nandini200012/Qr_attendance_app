import 'package:flutter/material.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/core/utils/geo_utils.dart';
import 'package:qr_attendance_app/core/widgets/status_badge.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';

class TodayStatusBanner extends StatelessWidget {
  const TodayStatusBanner({
    super.key,
    required this.status,
    this.todayRecord,
  });

  final AttendanceStatus status;
  final AttendanceRecordEntity? todayRecord;

  @override
  Widget build(BuildContext context) {
    final (badgeColor, badgeBg, icon, subtitle) = switch (status) {
      AttendanceStatus.notCheckedIn => (
          AppColors.warning,
          AppColors.warningBg,
          Icons.schedule_rounded,
          'You have not checked in yet today. Scan an active session QR code to start your shift.',
        ),
      AttendanceStatus.checkedIn => (
          AppColors.info,
          AppColors.infoBg,
          Icons.login_rounded,
          todayRecord != null
              ? 'Checked in at ${DateTimeUtils.formatTime(todayRecord!.checkInAt)} • ${todayRecord!.locationName}. Scan QR to check out when done.'
              : 'Checked in for today. Scan QR to check out when done.',
        ),
      AttendanceStatus.completed => (
          AppColors.success,
          AppColors.successBg,
          Icons.verified_rounded,
          todayRecord != null
              ? 'Completed at ${todayRecord!.locationName} • ${DateTimeUtils.formatDurationMinutes(todayRecord!.effectiveDurationMinutes)} worked.'
              : 'Shift completed for today.',
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Status",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateTimeUtils.formatFullDate(DateTime.now()),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: status.label,
                  foregroundColor: badgeColor,
                  backgroundColor: badgeBg,
                  icon: icon,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (todayRecord != null) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimeGpsColumn(
                      label: 'Check-In',
                      time: DateTimeUtils.formatTime(todayRecord!.checkInAt),
                      coords: GeoUtils.formatCoordinates(
                        todayRecord!.checkInLat,
                        todayRecord!.checkInLng,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeGpsColumn(
                      label: 'Check-Out',
                      time: todayRecord!.checkOutAt != null
                          ? DateTimeUtils.formatTime(todayRecord!.checkOutAt!)
                          : 'Pending',
                      coords: todayRecord!.checkOutLat != null &&
                              todayRecord!.checkOutLng != null
                          ? GeoUtils.formatCoordinates(
                              todayRecord!.checkOutLat!,
                              todayRecord!.checkOutLng!,
                            )
                          : 'Not recorded',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeGpsColumn extends StatelessWidget {
  const _TimeGpsColumn({
    required this.label,
    required this.time,
    required this.coords,
  });

  final String label;
  final String time;
  final String coords;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            time,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            coords,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

