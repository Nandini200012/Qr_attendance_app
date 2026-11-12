import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/widgets/app_error_widget.dart';
import 'package:qr_attendance_app/core/widgets/empty_state_widget.dart';
import 'package:qr_attendance_app/core/widgets/loading_widget.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_event.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_state.dart';
import 'package:qr_attendance_app/features/attendance/presentation/widgets/attendance_record_tile.dart';
import 'package:qr_attendance_app/features/attendance/presentation/widgets/today_status_banner.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';

class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: () => context
                .read<AttendanceBloc>()
                .add(AttendanceDashboardRequested(user.id)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: BlocBuilder<AttendanceBloc, AttendanceState>(
        builder: (context, state) {
          if (state.dashboardStatus == AttendanceLoadStatus.initial) {
            context
                .read<AttendanceBloc>()
                .add(AttendanceDashboardRequested(user.id));
            return const LoadingWidget(message: 'Loading your attendance...');
          }

          if (state.dashboardStatus == AttendanceLoadStatus.loading &&
              state.todayOverview == null) {
            return const LoadingWidget(message: 'Loading your attendance...');
          }

          if (state.dashboardStatus == AttendanceLoadStatus.failure &&
              state.todayOverview == null) {
            return AppErrorWidget(
              message: state.dashboardError ??
                  'Unable to load attendance dashboard.',
              onRetry: () => context
                  .read<AttendanceBloc>()
                  .add(AttendanceDashboardRequested(user.id)),
            );
          }

          final overview = state.todayOverview!;
          final status = overview.status;
          final canCheckIn = status == AttendanceStatus.notCheckedIn;
          final canCheckOut = status == AttendanceStatus.checkedIn;
          final recentRecords = overview.recentRecords.take(3).toList();

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<AttendanceBloc>()
                  .add(AttendanceDashboardRequested(user.id));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _EmployeeHeaderCard(user: user),
                const SizedBox(height: 16),
                TodayStatusBanner(
                  status: status,
                  todayRecord: overview.todayRecord,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionScanCard(
                        title: 'Check In',
                        subtitle: canCheckIn
                            ? 'Scan session QR'
                            : status == AttendanceStatus.checkedIn
                                ? 'Already checked in'
                                : 'Shift completed',
                        icon: Icons.login_rounded,
                        accentColor: AppColors.success,
                        bgColor: AppColors.successBg,
                        enabled: canCheckIn,
                        isRecommended: canCheckIn,
                        onTap: canCheckIn
                            ? () => context.push('/scan?action=check_in')
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionScanCard(
                        title: 'Check Out',
                        subtitle: canCheckOut
                            ? 'Scan to end shift'
                            : status == AttendanceStatus.completed
                                ? 'Shift completed'
                                : 'Check in first',
                        icon: Icons.logout_rounded,
                        accentColor: AppColors.primary,
                        bgColor: AppColors.primaryLight,
                        enabled: canCheckOut,
                        isRecommended: canCheckOut,
                        onTap: canCheckOut
                            ? () => context.push('/scan?action=check_out')
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Attendance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/history'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (recentRecords.isEmpty)
                  const EmptyStateWidget(
                    title: 'No attendance records yet',
                    message:
                        'Scan a session QR code to record your first check-in.',
                    icon: Icons.qr_code_2_rounded,
                  )
                else
                  ...recentRecords.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AttendanceRecordTile(record: record),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmployeeHeaderCard extends StatelessWidget {
  const _EmployeeHeaderCard({required this.user});

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage:
                user.image.isNotEmpty ? NetworkImage(user.image) : null,
            onBackgroundImageError:
                user.image.isNotEmpty ? (_, _) {} : null,
            child: user.image.isEmpty
                ? Text(
                    user.firstName.isNotEmpty
                        ? user.firstName[0].toUpperCase()
                        : 'E',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user.fullName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.employeeCode} • ${user.department}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.jobTitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionScanCard extends StatelessWidget {
  const _ActionScanCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.enabled,
    required this.isRecommended,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final bool enabled;
  final bool isRecommended;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = enabled ? accentColor : AppColors.textMuted;
    final effectiveBg = enabled ? bgColor : AppColors.surfaceVariant;

    return Opacity(
      opacity: enabled ? 1.0 : 0.62,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRecommended && enabled ? accentColor : AppColors.border,
              width: isRecommended && enabled ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: effectiveBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: effectiveAccent, size: 22),
                  ),
                  Icon(
                    enabled
                        ? Icons.qr_code_scanner_rounded
                        : Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

