import 'package:flutter/material.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_summary_entity.dart';

class AttendanceSummaryGrid extends StatelessWidget {
  const AttendanceSummaryGrid({
    super.key,
    required this.summary,
  });

  final AttendanceSummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        label: 'Present Days',
        value: '${summary.totalPresentDays}',
        icon: Icons.event_available_rounded,
        color: AppColors.primary,
        bgColor: AppColors.primaryLight,
      ),
      _MetricData(
        label: 'Completed Shifts',
        value: '${summary.completedDays}',
        icon: Icons.task_alt_rounded,
        color: AppColors.success,
        bgColor: AppColors.successBg,
      ),
      _MetricData(
        label: 'Total Hours',
        value: DateTimeUtils.formatDurationMinutes(summary.totalWorkedMinutes),
        icon: Icons.access_time_filled_rounded,
        color: AppColors.secondary,
        bgColor: AppColors.secondaryLight,
      ),
      _MetricData(
        label: 'Avg Shift',
        value:
            DateTimeUtils.formatDurationMinutes(summary.averageWorkedMinutes),
        icon: Icons.timelapse_rounded,
        color: AppColors.warning,
        bgColor: AppColors.warningBg,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 600 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 4 ? 1.55 : 1.75,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: item.bgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon, size: 16, color: item.color),
                        ),
                      ],
                    ),
                    Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
}

