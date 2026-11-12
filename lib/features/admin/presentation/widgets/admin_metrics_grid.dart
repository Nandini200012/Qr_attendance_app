import 'package:flutter/material.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/admin_dashboard_summary_entity.dart';

class AdminMetricsGrid extends StatelessWidget {
  const AdminMetricsGrid({
    super.key,
    required this.summary,
  });

  final AdminDashboardSummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _AdminKpi(
        label: 'Total Employees',
        value: '${summary.totalEmployees}',
        icon: Icons.groups_rounded,
        color: AppColors.primary,
        bgColor: AppColors.primaryLight,
      ),
      _AdminKpi(
        label: 'Present',
        value: '${summary.presentCount}',
        icon: Icons.verified_rounded,
        color: AppColors.success,
        bgColor: AppColors.successBg,
      ),
      _AdminKpi(
        label: 'Late',
        value: '${summary.lateCount}',
        icon: Icons.schedule_rounded,
        color: AppColors.warning,
        bgColor: AppColors.warningBg,
      ),
      _AdminKpi(
        label: 'Absent',
        value: '${summary.absentCount}',
        icon: Icons.person_off_outlined,
        color: AppColors.error,
        bgColor: AppColors.errorBg,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 600 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 4 ? 1.55 : 1.8,
          ),
          itemBuilder: (context, index) {
            final item = cards[index];
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
                        fontSize: 22,
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

class _AdminKpi {
  const _AdminKpi({
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

