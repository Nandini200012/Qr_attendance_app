import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/widgets/status_badge.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_event.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_event.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select(
      (AuthBloc bloc) => bloc.state.user?.isAdmin ?? false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Admin Profile' : 'Employee Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh profile from API',
            onPressed: () => context
                .read<AuthBloc>()
                .add(const AuthProfileRefreshRequested()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final user = state.user;
          if (user == null) {
            return const SizedBox.shrink();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage:
                            user.image.isNotEmpty ? NetworkImage(user.image) : null,
                        onBackgroundImageError: user.image.isNotEmpty
                            ? (_, _) {}
                            : null,
                        child: user.image.isEmpty
                            ? Text(
                                user.firstName.isNotEmpty
                                    ? user.firstName[0].toUpperCase()
                                    : 'E',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user.jobTitle} • ${user.department}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          StatusBadge(
                            label: user.employeeCode,
                            foregroundColor: AppColors.primary,
                            backgroundColor: AppColors.primaryLight,
                            icon: Icons.badge_outlined,
                          ),
                          StatusBadge(
                            label: user.isAdmin ? 'Administrator' : 'Employee',
                            foregroundColor: user.isAdmin
                                ? AppColors.secondary
                                : AppColors.textSecondary,
                            backgroundColor: user.isAdmin
                                ? AppColors.secondaryLight
                                : AppColors.surfaceVariant,
                            icon: user.isAdmin
                                ? Icons.admin_panel_settings_outlined
                                : Icons.person_outline,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: Icons.email_outlined,
                      label: 'Corporate Email',
                      value: user.email,
                    ),
                    const Divider(height: 1),
                    _ProfileTile(
                      icon: Icons.alternate_email_rounded,
                      label: 'Username',
                      value: user.username,
                    ),
                    const Divider(height: 1),
                    _ProfileTile(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: user.phone.isNotEmpty ? user.phone : 'Not listed',
                    ),
                    const Divider(height: 1),
                    _ProfileTile(
                      icon: Icons.business_outlined,
                      label: 'Organization',
                      value: user.companyName,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  context.read<AttendanceBloc>().add(const AttendanceCleared());
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 14.5,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

