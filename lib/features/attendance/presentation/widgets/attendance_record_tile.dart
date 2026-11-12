import 'package:flutter/material.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/core/utils/geo_utils.dart';
import 'package:qr_attendance_app/core/widgets/status_badge.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';

class AttendanceRecordTile extends StatelessWidget {
  const AttendanceRecordTile({
    super.key,
    required this.record,
  });

  final AttendanceRecordEntity record;

  @override
  Widget build(BuildContext context) {
    final isCompleted = record.status == AttendanceStatus.completed;
    final parsedDate = DateTime.tryParse(record.workDate) ?? record.checkInAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateTimeUtils.formatFullDate(parsedDate),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              record.locationName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    if (record.isPendingSync)
                      const StatusBadge(
                        label: 'Pending sync',
                        foregroundColor: AppColors.warning,
                        backgroundColor: AppColors.warningBg,
                        icon: Icons.cloud_upload_outlined,
                      ),
                    StatusBadge(
                      label: record.status.label,
                      foregroundColor:
                          isCompleted ? AppColors.success : AppColors.info,
                      backgroundColor:
                          isCompleted ? AppColors.successBg : AppColors.infoBg,
                      icon: isCompleted
                          ? Icons.check_circle_outline
                          : Icons.timelapse_rounded,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DetailCell(
                    icon: Icons.login_rounded,
                    iconColor: AppColors.success,
                    label: 'Check-In',
                    primary: DateTimeUtils.formatTime(record.checkInAt),
                    secondary: GeoUtils.formatCoordinates(
                      record.checkInLat,
                      record.checkInLng,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DetailCell(
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.warning,
                    label: 'Check-Out',
                    primary: record.checkOutAt != null
                        ? DateTimeUtils.formatTime(record.checkOutAt!)
                        : 'Active Shift',
                    secondary: record.checkOutLat != null &&
                            record.checkOutLng != null
                        ? GeoUtils.formatCoordinates(
                            record.checkOutLat!,
                            record.checkOutLng!,
                          )
                        : 'Pending',
                  ),
                ),
                const SizedBox(width: 10),
                _DurationPill(
                  minutes: record.effectiveDurationMinutes,
                  isCompleted: isCompleted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCell extends StatelessWidget {
  const _DetailCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.primary,
    required this.secondary,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          primary,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          secondary,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _DurationPill extends StatelessWidget {
  const _DurationPill({
    required this.minutes,
    required this.isCompleted,
  });

  final int minutes;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text(
            'Duration',
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateTimeUtils.formatDurationMinutes(minutes),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isCompleted ? AppColors.textPrimary : AppColors.info,
            ),
          ),
        ],
      ),
    );
  }
}

