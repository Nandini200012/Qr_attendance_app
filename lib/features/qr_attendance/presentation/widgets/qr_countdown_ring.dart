import 'package:flutter/material.dart';
import 'package:qr_attendance_app/core/constants/app_constants.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';

class QrCountdownRing extends StatelessWidget {
  const QrCountdownRing({
    super.key,
    required this.remainingSeconds,
    this.totalSeconds = AppConstants.qrValiditySeconds,
  });

  final int remainingSeconds;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0
        ? (remainingSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    final Color color;
    final String label;
    if (remainingSeconds <= 0) {
      color = AppColors.error;
      label = 'Expired';
    } else if (remainingSeconds <= 10) {
      color = AppColors.warning;
      label = '${remainingSeconds}s left';
    } else {
      color = AppColors.success;
      label = '${remainingSeconds}s left';
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'QR Validity Countdown',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

