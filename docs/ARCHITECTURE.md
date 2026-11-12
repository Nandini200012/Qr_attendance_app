# Architecture Overview

## 1. Clean Architecture Layers

Each feature (`authentication`, `attendance`, `qr_attendance`, `admin`) is isolated into three strict layers:

- **Domain Layer (`domain/`)**
  - Pure Dart entities (`UserEntity`, `AttendanceRecordEntity`, `QrSessionEntity`, `AdminDashboardSummaryEntity`).
  - Abstract repository contracts (`AuthRepository`, `AttendanceRepository`, `QrAttendanceRepository`, `AdminRepository`).
  - Single-responsibility use cases (`LoginUseCase`, `GetTodayAttendanceUseCase`, `SubmitQrAttendanceUseCase`, `GetAdminDashboardUseCase`, etc.).
  - Zero dependencies on Flutter UI packages or Dio.

- **Data Layer (`data/`)**
  - JSON-serializable models extending domain entities.
  - Remote data sources communicating exclusively over `Dio`.
  - Repository implementations mapping exceptions (`NetworkException`, `TimeoutException`, `UnauthorizedException`, `QrValidationException`, `LocationException`) into sealed `Failure` objects wrapped in `Result<T>`.
  - Clearly separated `AttendanceLocalMockService` paired with `AttendanceMockRestInterceptor` when no external MockAPI.io endpoint is configured.

- **Presentation Layer (`presentation/`)**
  - Strictly uses `flutter_bloc` (`AuthBloc`, `AttendanceBloc`, `QRBloc`, `AdminBloc`) with explicit `Equatable` events and states.
  - Zero `setState` calls for application state; all user interactions (password visibility toggle, demo prefill, search, filters, countdown ticks, torch toggle, manual QR toggle) are dispatched as BLoC events.
  - Declarative `go_router` navigation reacting to `AuthBloc.stream` with role-based access control on `/admin` and `/admin/qr-generator`.

---

## 2. State Management Data Flow

```text
UI Event (Tap / Scan / Filter)
        │
        ▼
      BLoC  ──▶  UseCase  ──▶  Repository  ──▶  RemoteDataSource (Dio)
        ▲                                              │
        └──────── Result<T> (Success / Failure) ◀──────┘
```

---

## 3. QR Security & Validation Pipeline

1. **QR Generation (Admin Only)**
   - Verifies caller role (`admin`) before issuing a session (`POST /qr-sessions`).
   - Generates a unique `sessionId`, cryptographically random `nonce`, `issuedAt` (UTC), and `expiresAt = issuedAt + 30s`.
   - Signs canonical string `app|sessionId|nonce|issuedAtMs|expiresAtMs` using **HMAC-SHA256**.
   - Optional geofence coordinates (`lat`, `lng`, `radiusM`) can be embedded when Admin enables geofencing.

2. **QR Scanning & Service-Layer Verification**
   - Captures fresh GPS location via `LocationService` (`Geolocator`) with explicit handling for disabled GPS and denied permissions.
   - Submits `{ qrPayload, action, userId, latitude, longitude, accuracyMeters, clientTimestamp }` to `POST /attendance/scan`.
   - Service layer validates **authoritatively** (never trusting client timestamps):
     1. Authorization header (`401 Unauthorized` if missing/expired).
     2. Coordinate validity (`400 LOCATION_REQUIRED`).
     3. Payload structure & constant-time HMAC-SHA256 verification (`400 QR_MALFORMED` / `400 QR_INVALID_SIGNATURE`).
     4. Expiry against authoritative UTC clock (`410 QR_EXPIRED`).
     5. Active session check (`410 SESSION_INACTIVE`).
     6. Nonce replay check per `(nonce, userId, action)` (`409 QR_REPLAY`).
     7. Haversine distance check when geofence is enabled (`403 OUTSIDE_GEOFENCE`).
     8. Shift state transitions:
        - Blocks duplicate check-in (`409 DUPLICATE_CHECK_IN`).
        - Blocks check-out without an active check-in (`400 NO_ACTIVE_CHECK_IN`).
        - Blocks actions after shift completion (`409 ALREADY_CHECKED_OUT`).
     9. Records authoritative server UTC timestamp and late-arrival status, persisting attendance in SQLite (`SqliteAttendanceDatabase` / `sqflite`, with `SharedPreferences` fallback on Web).

