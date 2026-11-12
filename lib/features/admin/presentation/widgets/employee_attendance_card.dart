import 'package:flutter/material.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/core/utils/geo_utils.dart';
import 'package:qr_attendance_app/core/widgets/status_badge.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/employee_attendance_item_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';

class EmployeeAttendanceCard extends StatelessWidget {
  const EmployeeAttendanceCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final EmployeeAttendanceItemEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final emp = item.employee;
    final rec = item.record;

    final (label, fgColor, bgColor, icon) = switch (item.status) {
      AttendanceStatus.completed => (
          'Completed',
          AppColors.success,
          AppColors.successBg,
          Icons.check_circle_outline,
        ),
      AttendanceStatus.checkedIn => (
          'Checked In',
          AppColors.info,
          AppColors.infoBg,
          Icons.login_rounded,
        ),
      AttendanceStatus.notCheckedIn => (
          'Absent',
          AppColors.error,
          AppColors.errorBg,
          Icons.person_off_outlined,
        ),
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage:
                        emp.image.isNotEmpty ? NetworkImage(emp.image) : null,
                    onBackgroundImageError:
                        emp.image.isNotEmpty ? (_, _) {} : null,
                    child: emp.image.isEmpty
                        ? Text(
                            emp.firstName.isNotEmpty
                                ? emp.firstName[0].toUpperCase()
                                : 'E',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.fullName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${emp.employeeCode} • ${emp.department}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(
                        label: label,
                        foregroundColor: fgColor,
                        backgroundColor: bgColor,
                        icon: icon,
                      ),
                      if (rec != null &&
                          (rec.isLate || rec.isInsideGeofence != null)) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: [
                            if (rec.isLate)
                              const StatusBadge(
                                label: 'Late',
                                foregroundColor: AppColors.warning,
                                backgroundColor: AppColors.warningBg,
                              ),
                            if (rec.isInsideGeofence != null)
                              StatusBadge(
                                label: rec.isInsideGeofence!
                                    ? 'Inside geofence'
                                    : 'Outside geofence',
                                foregroundColor: rec.isInsideGeofence!
                                    ? AppColors.success
                                    : AppColors.error,
                                backgroundColor: rec.isInsideGeofence!
                                    ? AppColors.successBg
                                    : AppColors.errorBg,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (rec != null) ...[
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'In: ${DateTimeUtils.formatTime(rec.checkInAt)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      rec.checkOutAt != null
                          ? 'Out: ${DateTimeUtils.formatTime(rec.checkOutAt!)}'
                          : 'Out: Active',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateTimeUtils.formatDurationMinutes(
                        rec.effectiveDurationMinutes,
                      ),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rec.checkOutLat != null && rec.checkOutLng != null
                            ? 'In: ${GeoUtils.formatCoordinates(rec.checkInLat, rec.checkInLng)} • Out: ${GeoUtils.formatCoordinates(rec.checkOutLat!, rec.checkOutLng!)}'
                            : 'GPS: ${GeoUtils.formatCoordinates(rec.checkInLat, rec.checkInLng)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => GeoUtils.openOnMap(
                        rec.checkInLat,
                        rec.checkInLng,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'View on map',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

