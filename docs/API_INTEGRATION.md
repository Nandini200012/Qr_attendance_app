# API Integration Documentation

## 1. DummyJSON REST API (Live)

Used by `AuthRemoteDataSourceImpl` and `AdminRemoteDataSourceImpl` via `DioClient.dummyJsonDio` (`https://dummyjson.com`):

| Feature | Method & Endpoint | Notes |
| --- | --- | --- |
| Resolve Email to Username | `GET /users/filter?key=email&value=<email>` | Maps corporate email input to DummyJSON `username` before login |
| Authenticate User | `POST /auth/login` | Sends `{ username, password, expiresInMins: 60 }`; receives `accessToken` & `refreshToken` |
| Fetch Authenticated Profile | `GET /auth/me` | Protected by `Authorization: Bearer <token>`; returns `id`, `role`, `company`, `image`, `phone` |
| Fetch Employee Directory | `GET /users?limit=30&skip=0` | Populates Admin Attendance Console without hardcoding employees |
| Fetch Individual Employee | `GET /users/:id` | Loads full employee profile when tapping an employee row in Admin Console |

### 401 Unauthorized Handling
`AuthInterceptor` attaches `Authorization: Bearer <accessToken>` to outgoing requests and monitors responses. Any `401` on a protected endpoint emits an event on `AuthSessionEvents.onUnauthorized`, causing `AuthBloc` to purge tokens from `FlutterSecureStorage` and redirect via `go_router` to `/login`.

---

## 2. Attendance & QR REST API (`AttendanceRemoteDataSource` & `QrRemoteDataSource`)

DummyJSON and JSONPlaceholder do not provide persistent attendance or QR session endpoints. To keep the data layer genuinely REST-driven:

- All attendance and QR calls execute through `DioClient.attendanceDio`.
- When `--dart-define=ATTENDANCE_API_URL=<url>` is supplied (e.g. a MockAPI.io project URL), `attendanceDio` sends live HTTP requests directly to that base URL.
- When `ATTENDANCE_API_URL` is unset (default out-of-the-box setup), `AttendanceMockRestInterceptor` routes `attendanceDio` calls to the clearly separated `AttendanceLocalMockService`, which persists sessions, used QR nonces, and attendance records in SQLite (`SqliteAttendanceDatabase` via `sqflite`, with a `SharedPreferences` fallback on Web).

### Attendance REST Endpoints Contract

| Endpoint | Purpose | Success | Validation / Error Codes |
| --- | --- | --- | --- |
| `POST /qr-sessions` | Create 30s signed QR session (Admin only) | `201 Created` | `401 UNAUTHORIZED`, `403 FORBIDDEN` |
| `GET /qr-sessions/active` | Retrieve active unexpired QR session (Admin only) | `200 OK` | `401 UNAUTHORIZED`, `403 FORBIDDEN` |
| `POST /attendance/scan` | Validate QR, GPS & record check-in / check-out (Employee only) | `200 / 201` | `400 QR_MALFORMED`, `400 QR_INVALID_SIGNATURE`, `400 NO_ACTIVE_CHECK_IN`, `403 FORBIDDEN`, `403 OUTSIDE_GEOFENCE`, `409 DUPLICATE_CHECK_IN`, `409 ALREADY_CHECKED_OUT`, `409 QR_REPLAY`, `410 QR_EXPIRED`, `410 SESSION_INACTIVE` |
| `GET /attendance/today?userId=` | Today's attendance status + summary + recent records | `200 OK` | `400 BAD_REQUEST`, `401 UNAUTHORIZED` |
| `GET /attendance?userId=&startDate=&endDate=&status=` | Filtered individual attendance history | `200 OK` | `400 BAD_REQUEST`, `401 UNAUTHORIZED` |
| `GET /admin/attendance?date=` | All attendance records for selected date (Admin only) | `200 OK` | `401 UNAUTHORIZED`, `403 FORBIDDEN` |

