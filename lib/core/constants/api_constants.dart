class ApiConstants {
  const ApiConstants._();

  static const String dummyJsonBaseUrl = 'https://dummyjson.com';
  static const String loginEndpoint = '/auth/login';
  static const String meEndpoint = '/auth/me';
  static const String usersEndpoint = '/users';
  static const String usersFilterEndpoint = '/users/filter';

  static const String jsonPlaceholderPostsUrl =
      'https://jsonplaceholder.typicode.com/posts';

  /// Optional external mock REST endpoint (e.g., MockAPI.io project URL).
  /// Supply via `--dart-define=ATTENDANCE_API_URL=https://<id>.mockapi.io/api/v1`
  static const String attendanceBaseUrl = String.fromEnvironment(
    'ATTENDANCE_API_URL',
    defaultValue: '',
  );

  static const String attendanceTodayEndpoint = '/attendance/today';
  static const String attendanceHistoryEndpoint = '/attendance';
  static const String attendanceScanEndpoint = '/attendance/scan';
  static const String qrSessionsEndpoint = '/qr-sessions';
  static const String activeQrSessionEndpoint = '/qr-sessions/active';
  static const String adminAttendanceEndpoint = '/admin/attendance';
  static const String adminFailedAttemptsEndpoint = '/admin/failed-attempts';

  static bool get useExternalAttendanceApi => attendanceBaseUrl.trim().isNotEmpty;
}

