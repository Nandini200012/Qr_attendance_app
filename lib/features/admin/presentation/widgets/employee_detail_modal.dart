import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/core/utils/geo_utils.dart';
import 'package:qr_attendance_app/core/widgets/status_badge.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_state.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';

class EmployeeDetailModal extends StatelessWidget {
  const EmployeeDetailModal({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        final item = state.selectedItem;
        final profile = state.selectedEmployeeProfile ?? item?.employee;
        if (profile == null || item == null) {
          return const SizedBox.shrink();
        }

        final rec = item.record;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: profile.image.isNotEmpty
                          ? NetworkImage(profile.image)
                          : null,
                      onBackgroundImageError:
                          profile.image.isNotEmpty ? (_, _) {} : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${profile.employeeCode} • ${profile.jobTitle}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (state.detailStatus == AdminDetailStatus.loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _MetaRow(label: 'Email', value: profile.email),
                      const SizedBox(height: 6),
                      _MetaRow(label: 'Department', value: profile.department),
                      const SizedBox(height: 6),
                      _MetaRow(
                        label: 'Phone',
                        value: profile.phone.isNotEmpty
                            ? profile.phone
                            : 'Not available',
                      ),
                      const SizedBox(height: 6),
                      _MetaRow(label: 'Role', value: profile.role.toUpperCase()),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (rec != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Attendance Details',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            StatusBadge(
                              label: rec.status.label,
                              foregroundColor:
                                  rec.status == AttendanceStatus.completed
                                      ? AppColors.success
                                      : AppColors.info,
                              backgroundColor:
                                  rec.status == AttendanceStatus.completed
                                      ? AppColors.successBg
                                      : AppColors.infoBg,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _MetaRow(label: 'Location', value: rec.locationName),
                        const SizedBox(height: 6),
                        _MetaRow(
                          label: 'Arrival',
                          value: rec.isLate ? 'Late (after 09:15 AM)' : 'On Time',
                        ),
                        const SizedBox(height: 6),
                        _MetaRow(
                          label: 'Check-In',
                          value: DateTimeUtils.formatTimeWithSeconds(
                            rec.checkInAt,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _MetaRow(
                          label: 'Check-In GPS',
                          value: GeoUtils.formatCoordinates(
                            rec.checkInLat,
                            rec.checkInLng,
                          ),
                          trailing: _MapActionLink(
                            onTap: () => GeoUtils.openOnMap(
                              rec.checkInLat,
                              rec.checkInLng,
                            ),
                          ),
                        ),
                        if (rec.checkOutAt != null) ...[
                          const SizedBox(height: 6),
                          _MetaRow(
                            label: 'Check-Out',
                            value: DateTimeUtils.formatTimeWithSeconds(
                              rec.checkOutAt!,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _MetaRow(
                            label: 'Check-Out GPS',
                            value: rec.checkOutLat != null &&
                                    rec.checkOutLng != null
                                ? GeoUtils.formatCoordinates(
                                    rec.checkOutLat!,
                                    rec.checkOutLng!,
                                  )
                                : 'Not recorded',
                            trailing: rec.checkOutLat != null &&
                                    rec.checkOutLng != null
                                ? _MapActionLink(
                                    onTap: () => GeoUtils.openOnMap(
                                      rec.checkOutLat!,
                                      rec.checkOutLng!,
                                    ),
                                  )
                                : null,
                          ),
                        ],
                        if (rec.isInsideGeofence != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: StatusBadge(
                              label: rec.isInsideGeofence!
                                  ? 'Inside geofence'
                                  : 'Outside geofence',
                              foregroundColor: rec.isInsideGeofence!
                                  ? AppColors.success
                                  : AppColors.error,
                              backgroundColor: rec.isInsideGeofence!
                                  ? AppColors.successBg
                                  : AppColors.errorBg,
                              icon: rec.isInsideGeofence!
                                  ? Icons.gps_fixed_rounded
                                  : Icons.location_off_rounded,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        _MetaRow(
                          label: 'Worked Duration',
                          value: DateTimeUtils.formatDurationMinutes(
                            rec.effectiveDurationMinutes,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No attendance record logged for this date.',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (state.detailError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.detailError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

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
        const SizedBox(width: 12),
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
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class _MapActionLink extends StatelessWidget {
  const _MapActionLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 13, color: AppColors.primary),
            SizedBox(width: 4),
            Text(
              'View on map',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

