import 'package:flutter/material.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';

class ScannerOverlayWidget extends StatelessWidget {
  const ScannerOverlayWidget({
    super.key,
    this.isCameraActive = true,
  });

  final bool isCameraActive;

  @override
  Widget build(BuildContext context) {
    if (!isCameraActive) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryLight, width: 3),
          ),
          child: const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    'Align Attendance QR inside frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

