import 'package:intl/intl.dart';
import 'package:qr_attendance_app/core/constants/app_constants.dart';

class DateTimeUtils {
  const DateTimeUtils._();

  static bool isLateCheckIn(DateTime checkInAt) {
    final local = checkInAt.toLocal();
    return local.hour > AppConstants.shiftStartHour ||
        (local.hour == AppConstants.shiftStartHour &&
            local.minute > AppConstants.shiftLateGraceMinutes);
  }

  static String toDateKey(DateTime dt) {
    final local = dt.toLocal();
    return DateFormat('yyyy-MM-dd').format(local);
  }

  static String formatFullDate(DateTime dt) {
    return DateFormat('EEE, dd MMM yyyy').format(dt.toLocal());
  }

  static String formatShortDate(DateTime dt) {
    return DateFormat('dd MMM yyyy').format(dt.toLocal());
  }

  static String formatTime(DateTime dt) {
    return DateFormat('hh:mm a').format(dt.toLocal());
  }

  static String formatTimeWithSeconds(DateTime dt) {
    return DateFormat('hh:mm:ss a').format(dt.toLocal());
  }

  static String formatDurationMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}

