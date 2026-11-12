import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/widgets/app_error_widget.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_event.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_state.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state.startupError != null &&
              state.status != AuthStatus.checking) {
            return AppErrorWidget(
              title: 'Connection Check Failed',
              message: state.startupError!,
              onRetry: () =>
                  context.read<AuthBloc>().add(const AuthCheckRequested()),
            );
          }

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Smart QR Attendance',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Verifying your session...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

