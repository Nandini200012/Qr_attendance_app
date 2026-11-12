import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:qr_attendance_app/core/constants/storage_keys.dart';

/// Relational persistence abstraction for attendance records, QR sessions,
/// and anti-replay nonces.
///
/// Uses SQLite ([SqliteAttendanceDatabase]) on mobile/desktop/tests and a
/// [SharedPrefsAttendanceDatabase] fallback when running on Flutter Web.
abstract class AttendanceLocalDatabase {
  Future<void> saveQrSession(
    Map<String, dynamic> session, {
    int maxHistory = 25,
  });

  Future<Map<String, dynamic>?> getQrSessionById(String sessionId);

  Future<Map<String, dynamic>?> getLatestActiveQrSession(int nowMs);

  Future<bool> hasUsedNonce(String replayKey);

  Future<void> markNonceUsed(String replayKey, String usedAtIso);

  Future<List<Map<String, dynamic>>> getAttendanceRecords({
    int? userId,
    String? workDate,
    String? startDate,
    String? endDate,
    String status = 'all',
    bool sortByCheckInDesc = false,
  });

  Future<Map<String, dynamic>?> getAttendanceRecordByUserAndDate(
    int userId,
    String workDate,
  );

  Future<void> insertAttendanceRecord(Map<String, dynamic> record);

  Future<void> updateAttendanceRecord(Map<String, dynamic> record);

  Future<bool> hasAnyRecordsForUser(int userId);

  Future<bool> isSeedInitialized();

  Future<void> markSeedInitialized();

  Future<void> insertSeedRecords(List<Map<String, dynamic>> records);

  Future<void> insertFailedAttempt(Map<String, dynamic> attempt);

  Future<List<Map<String, dynamic>>> getFailedAttempts({String? dateKey});

  Future<void> insertPendingScan(Map<String, dynamic> scan);

  Future<List<Map<String, dynamic>>> getPendingScans({int? userId});

  Future<void> deletePendingScan(String id);

  Future<void> close();
}

/// SQLite-backed implementation powered by `sqflite`.
class SqliteAttendanceDatabase implements AttendanceLocalDatabase {
  SqliteAttendanceDatabase({
    DatabaseFactory? databaseFactory,
    String? databasePath,
  })  : _databaseFactory = databaseFactory,
        _customDatabasePath = databasePath;

  static const String _dbName = 'qr_attendance.db';
  static const int _dbVersion = 3;
  static const String _seedMetaKey = 'mock_api_seed_initialized_v4';

  final DatabaseFactory? _databaseFactory;
  final String? _customDatabasePath;
  Database? _db;
  Future<Database>? _openingFuture;

  Future<Database> _getDb() {
    final existing = _db;
    if (existing != null && existing.isOpen) {
      return Future.value(existing);
    }
    return _openingFuture ??= _open();
  }

  Future<Database> _open() async {
    final factory = _databaseFactory;
    final String path;
    if (_customDatabasePath != null) {
      path = _customDatabasePath;
    } else {
      final baseDir = factory != null
          ? await factory.getDatabasesPath()
          : await getDatabasesPath();
      path = p.join(baseDir, _dbName);
    }

    final options = OpenDatabaseOptions(
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE qr_sessions (
            session_id TEXT PRIMARY KEY,
            nonce TEXT NOT NULL,
            location_name TEXT NOT NULL,
            created_by_user_id INTEGER NOT NULL,
            issued_at TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            issued_at_ms INTEGER NOT NULL,
            expires_at_ms INTEGER NOT NULL,
            validity_seconds INTEGER NOT NULL,
            raw_qr_payload TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            geofence_lat REAL,
            geofence_lng REAL,
            geofence_radius_meters REAL
          )
        ''');

        await db.execute('''
          CREATE TABLE attendance_records (
            id TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            work_date TEXT NOT NULL,
            session_id TEXT NOT NULL,
            location_name TEXT NOT NULL,
            status TEXT NOT NULL,
            check_in_at TEXT NOT NULL,
            check_in_lat REAL NOT NULL,
            check_in_lng REAL NOT NULL,
            check_in_accuracy_meters REAL,
            check_out_at TEXT,
            check_out_lat REAL,
            check_out_lng REAL,
            check_out_accuracy_meters REAL,
            duration_minutes INTEGER,
            distance_meters REAL,
            geofence_enforced INTEGER NOT NULL DEFAULT 0,
            geofence_radius_meters REAL,
            is_late INTEGER NOT NULL DEFAULT 0,
            server_verified INTEGER NOT NULL DEFAULT 1,
            UNIQUE(user_id, work_date)
          )
        ''');

        await db.execute('''
          CREATE TABLE used_nonces (
            replay_key TEXT PRIMARY KEY,
            used_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE failed_attempts (
            id TEXT PRIMARY KEY,
            employee_id INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            work_date TEXT NOT NULL,
            reason TEXT NOT NULL,
            session_id TEXT,
            lat REAL,
            lng REAL,
            message TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE app_metadata (
            meta_key TEXT PRIMARY KEY,
            meta_value TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS pending_scans (
            id TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            work_date TEXT NOT NULL,
            action TEXT NOT NULL,
            raw_qr_payload TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy_meters REAL,
            captured_at TEXT NOT NULL,
            location_name TEXT,
            session_id TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_attendance_user_date ON attendance_records (user_id, work_date DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_attendance_work_date ON attendance_records (work_date, check_in_at DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_sessions_active ON qr_sessions (is_active, expires_at_ms DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_failed_attempts_date ON failed_attempts (work_date, timestamp DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_pending_scans_user ON pending_scans (user_id, captured_at ASC)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE attendance_records ADD COLUMN geofence_enforced INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE attendance_records ADD COLUMN geofence_radius_meters REAL',
          );
          await db.execute('''
            CREATE TABLE IF NOT EXISTS failed_attempts (
              id TEXT PRIMARY KEY,
              employee_id INTEGER NOT NULL,
              timestamp TEXT NOT NULL,
              work_date TEXT NOT NULL,
              reason TEXT NOT NULL,
              session_id TEXT,
              lat REAL,
              lng REAL,
              message TEXT
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_failed_attempts_date ON failed_attempts (work_date, timestamp DESC)',
          );
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pending_scans (
              id TEXT PRIMARY KEY,
              user_id INTEGER NOT NULL,
              work_date TEXT NOT NULL,
              action TEXT NOT NULL,
              raw_qr_payload TEXT NOT NULL,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              accuracy_meters REAL,
              captured_at TEXT NOT NULL,
              location_name TEXT,
              session_id TEXT
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_pending_scans_user ON pending_scans (user_id, captured_at ASC)',
          );
        }
      },
    );

    final db = factory != null
        ? await factory.openDatabase(path, options: options)
        : await openDatabase(
            path,
            version: options.version,
            onCreate: options.onCreate,
            onUpgrade: options.onUpgrade,
          );
    _db = db;
    _openingFuture = null;
    return db;
  }

  @override
  Future<void> saveQrSession(
    Map<String, dynamic> session, {
    int maxHistory = 25,
  }) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.update('qr_sessions', {'is_active': 0});
      await txn.insert(
        'qr_sessions',
        _sessionToRow(session),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.rawDelete(
        '''
        DELETE FROM qr_sessions
        WHERE session_id NOT IN (
          SELECT session_id FROM qr_sessions
          ORDER BY issued_at_ms DESC
          LIMIT ?
        )
        ''',
        [maxHistory],
      );
    });
  }

  @override
  Future<Map<String, dynamic>?> getQrSessionById(String sessionId) async {
    final db = await _getDb();
    final rows = await db.query(
      'qr_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToSession(rows.first);
  }

  @override
  Future<Map<String, dynamic>?> getLatestActiveQrSession(int nowMs) async {
    final db = await _getDb();
    final rows = await db.query(
      'qr_sessions',
      where: 'is_active = 1 AND expires_at_ms > ?',
      whereArgs: [nowMs],
      orderBy: 'issued_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToSession(rows.first);
  }

  @override
  Future<bool> hasUsedNonce(String replayKey) async {
    final db = await _getDb();
    final rows = await db.query(
      'used_nonces',
      columns: ['replay_key'],
      where: 'replay_key = ?',
      whereArgs: [replayKey],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> markNonceUsed(String replayKey, String usedAtIso) async {
    final db = await _getDb();
    await db.insert(
      'used_nonces',
      {'replay_key': replayKey, 'used_at': usedAtIso},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getAttendanceRecords({
    int? userId,
    String? workDate,
    String? startDate,
    String? endDate,
    String status = 'all',
    bool sortByCheckInDesc = false,
  }) async {
    final db = await _getDb();
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (userId != null) {
      whereClauses.add('user_id = ?');
      whereArgs.add(userId);
    }
    if (workDate != null && workDate.isNotEmpty) {
      whereClauses.add('work_date = ?');
      whereArgs.add(workDate);
    }
    if (startDate != null && startDate.isNotEmpty) {
      whereClauses.add('work_date >= ?');
      whereArgs.add(startDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      whereClauses.add('work_date <= ?');
      whereArgs.add(endDate);
    }
    if (status != 'all' && status.isNotEmpty) {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }

    final rows = await db.query(
      'attendance_records',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: sortByCheckInDesc
          ? 'check_in_at DESC'
          : 'work_date DESC, check_in_at DESC',
    );

    return rows.map(_rowToRecord).toList();
  }

  @override
  Future<Map<String, dynamic>?> getAttendanceRecordByUserAndDate(
    int userId,
    String workDate,
  ) async {
    final db = await _getDb();
    final rows = await db.query(
      'attendance_records',
      where: 'user_id = ? AND work_date = ?',
      whereArgs: [userId, workDate],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToRecord(rows.first);
  }

  @override
  Future<void> insertAttendanceRecord(Map<String, dynamic> record) async {
    final db = await _getDb();
    await db.insert(
      'attendance_records',
      _recordToRow(record),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> updateAttendanceRecord(Map<String, dynamic> record) async {
    final db = await _getDb();
    await db.update(
      'attendance_records',
      _recordToRow(record),
      where: 'id = ?',
      whereArgs: [record['id']],
    );
  }

  @override
  Future<bool> hasAnyRecordsForUser(int userId) async {
    final db = await _getDb();
    final rows = await db.query(
      'attendance_records',
      columns: ['id'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<bool> isSeedInitialized() async {
    final db = await _getDb();
    final rows = await db.query(
      'app_metadata',
      columns: ['meta_value'],
      where: 'meta_key = ?',
      whereArgs: [_seedMetaKey],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['meta_value'] == 'true';
  }

  @override
  Future<void> markSeedInitialized() async {
    final db = await _getDb();
    await db.insert(
      'app_metadata',
      {'meta_key': _seedMetaKey, 'meta_value': 'true'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertSeedRecords(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    final db = await _getDb();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final record in records) {
        batch.insert(
          'attendance_records',
          _recordToRow(record),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> insertFailedAttempt(Map<String, dynamic> attempt) async {
    final db = await _getDb();
    await db.insert(
      'failed_attempts',
      _failedAttemptToRow(attempt),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getFailedAttempts({
    String? dateKey,
  }) async {
    final db = await _getDb();
    final rows = await db.query(
      'failed_attempts',
      where: dateKey != null && dateKey.isNotEmpty ? 'work_date = ?' : null,
      whereArgs: dateKey != null && dateKey.isNotEmpty ? [dateKey] : null,
      orderBy: 'timestamp DESC',
    );
    return rows.map(_rowToFailedAttempt).toList();
  }

  @override
  Future<void> insertPendingScan(Map<String, dynamic> scan) async {
    final db = await _getDb();
    await db.insert(
      'pending_scans',
      _pendingScanToRow(scan),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingScans({int? userId}) async {
    final db = await _getDb();
    final rows = await db.query(
      'pending_scans',
      where: userId != null ? 'user_id = ?' : null,
      whereArgs: userId != null ? [userId] : null,
      orderBy: 'captured_at ASC',
    );
    return rows.map(_rowToPendingScan).toList();
  }

  @override
  Future<void> deletePendingScan(String id) async {
    final db = await _getDb();
    await db.delete(
      'pending_scans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  Map<String, Object?> _pendingScanToRow(Map<String, dynamic> s) => {
        'id': s['id'],
        'user_id': s['userId'],
        'work_date': s['workDate'],
        'action': s['action'],
        'raw_qr_payload': s['rawQrPayload'],
        'latitude': s['latitude'],
        'longitude': s['longitude'],
        'accuracy_meters': s['accuracyMeters'],
        'captured_at': s['capturedAt'],
        'location_name': s['locationName'],
        'session_id': s['sessionId'],
      };

  Map<String, dynamic> _rowToPendingScan(Map<String, Object?> row) => {
        'id': row['id'] as String,
        'userId': (row['user_id'] as num).toInt(),
        'workDate': row['work_date'] as String,
        'action': row['action'] as String,
        'rawQrPayload': row['raw_qr_payload'] as String,
        'latitude': (row['latitude'] as num).toDouble(),
        'longitude': (row['longitude'] as num).toDouble(),
        'accuracyMeters': (row['accuracy_meters'] as num?)?.toDouble(),
        'capturedAt': row['captured_at'] as String,
        'locationName': row['location_name'] as String?,
        'sessionId': row['session_id'] as String?,
      };

  Map<String, Object?> _sessionToRow(Map<String, dynamic> s) => {
        'session_id': s['sessionId'],
        'nonce': s['nonce'],
        'location_name': s['locationName'],
        'created_by_user_id': s['createdByUserId'],
        'issued_at': s['issuedAt'],
        'expires_at': s['expiresAt'],
        'issued_at_ms': s['issuedAtMs'],
        'expires_at_ms': s['expiresAtMs'],
        'validity_seconds': s['validitySeconds'],
        'raw_qr_payload': s['rawQrPayload'],
        'is_active': (s['isActive'] == true) ? 1 : 0,
        'geofence_lat': s['geofenceLat'],
        'geofence_lng': s['geofenceLng'],
        'geofence_radius_meters': s['geofenceRadiusMeters'],
      };

  Map<String, dynamic> _rowToSession(Map<String, Object?> row) => {
        'sessionId': row['session_id'] as String,
        'nonce': row['nonce'] as String,
        'locationName': row['location_name'] as String,
        'createdByUserId': (row['created_by_user_id'] as num).toInt(),
        'issuedAt': row['issued_at'] as String,
        'expiresAt': row['expires_at'] as String,
        'issuedAtMs': (row['issued_at_ms'] as num).toInt(),
        'expiresAtMs': (row['expires_at_ms'] as num).toInt(),
        'validitySeconds': (row['validity_seconds'] as num).toInt(),
        'rawQrPayload': row['raw_qr_payload'] as String,
        'isActive': (row['is_active'] as num).toInt() == 1,
        if (row['geofence_lat'] != null && row['geofence_lng'] != null) ...{
          'geofenceLat': (row['geofence_lat'] as num).toDouble(),
          'geofenceLng': (row['geofence_lng'] as num).toDouble(),
          'geofenceRadiusMeters':
              (row['geofence_radius_meters'] as num?)?.toDouble(),
        },
      };

  Map<String, Object?> _recordToRow(Map<String, dynamic> r) => {
        'id': r['id'],
        'user_id': r['userId'],
        'work_date': r['workDate'],
        'session_id': r['sessionId'],
        'location_name': r['locationName'],
        'status': r['status'],
        'check_in_at': r['checkInAt'],
        'check_in_lat': r['checkInLat'],
        'check_in_lng': r['checkInLng'],
        'check_in_accuracy_meters': r['checkInAccuracyMeters'],
        'check_out_at': r['checkOutAt'],
        'check_out_lat': r['checkOutLat'],
        'check_out_lng': r['checkOutLng'],
        'check_out_accuracy_meters': r['checkOutAccuracyMeters'],
        'duration_minutes': r['durationMinutes'],
        'distance_meters': r['distanceMeters'],
        'geofence_enforced':
            (r['geofenceEnforced'] == true || r['geofenceEnforced'] == 1)
                ? 1
                : 0,
        'geofence_radius_meters': r['geofenceRadiusMeters'],
        'is_late': (r['isLate'] == true || r['isLate'] == 1) ? 1 : 0,
        'server_verified':
            (r['serverVerified'] == false || r['serverVerified'] == 0) ? 0 : 1,
      };

  Map<String, dynamic> _rowToRecord(Map<String, Object?> row) => {
        'id': row['id'] as String,
        'userId': (row['user_id'] as num).toInt(),
        'workDate': row['work_date'] as String,
        'sessionId': row['session_id'] as String,
        'locationName': row['location_name'] as String,
        'status': row['status'] as String,
        'checkInAt': row['check_in_at'] as String,
        'checkInLat': (row['check_in_lat'] as num).toDouble(),
        'checkInLng': (row['check_in_lng'] as num).toDouble(),
        'checkInAccuracyMeters':
            (row['check_in_accuracy_meters'] as num?)?.toDouble(),
        'checkOutAt': row['check_out_at'] as String?,
        'checkOutLat': (row['check_out_lat'] as num?)?.toDouble(),
        'checkOutLng': (row['check_out_lng'] as num?)?.toDouble(),
        'checkOutAccuracyMeters':
            (row['check_out_accuracy_meters'] as num?)?.toDouble(),
        'durationMinutes': (row['duration_minutes'] as num?)?.toInt(),
        'distanceMeters': (row['distance_meters'] as num?)?.toDouble(),
        'geofenceEnforced': ((row['geofence_enforced'] as num?)?.toInt() ?? 0) == 1,
        'geofenceRadiusMeters':
            (row['geofence_radius_meters'] as num?)?.toDouble(),
        'isLate': ((row['is_late'] as num?)?.toInt() ?? 0) == 1,
        'serverVerified': ((row['server_verified'] as num?)?.toInt() ?? 1) == 1,
      };

  Map<String, Object?> _failedAttemptToRow(Map<String, dynamic> a) => {
        'id': a['id'],
        'employee_id': a['employeeId'],
        'timestamp': a['timestamp'],
        'work_date': a['workDate'],
        'reason': a['reason'],
        'session_id': a['sessionId'],
        'lat': a['lat'],
        'lng': a['lng'],
        'message': a['message'],
      };

  Map<String, dynamic> _rowToFailedAttempt(Map<String, Object?> row) => {
        'id': row['id'] as String,
        'employeeId': (row['employee_id'] as num).toInt(),
        'timestamp': row['timestamp'] as String,
        'workDate': row['work_date'] as String,
        'reason': row['reason'] as String,
        'sessionId': row['session_id'] as String?,
        'lat': (row['lat'] as num?)?.toDouble(),
        'lng': (row['lng'] as num?)?.toDouble(),
        'message': row['message'] as String?,
      };
}

/// Web-only persistence fallback implementing [AttendanceLocalDatabase].
class SharedPrefsAttendanceDatabase implements AttendanceLocalDatabase {
  SharedPrefsAttendanceDatabase(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<void> saveQrSession(
    Map<String, dynamic> session, {
    int maxHistory = 25,
  }) async {
    final sessions = _readSessions();
    for (var i = 0; i < sessions.length; i++) {
      sessions[i] = {...sessions[i], 'isActive': false};
    }
    sessions.insert(0, session);
    if (sessions.length > maxHistory) {
      sessions.removeRange(maxHistory, sessions.length);
    }
    await _prefs.setString(StorageKeys.mockQrSessions, jsonEncode(sessions));
  }

  @override
  Future<Map<String, dynamic>?> getQrSessionById(String sessionId) async {
    return _readSessions()
        .where((s) => s['sessionId'] == sessionId)
        .firstOrNull;
  }

  @override
  Future<Map<String, dynamic>?> getLatestActiveQrSession(int nowMs) async {
    for (final session in _readSessions()) {
      final isActive = session['isActive'] == true;
      final expiresAtMs = (session['expiresAtMs'] as num?)?.toInt() ?? 0;
      if (isActive && expiresAtMs > nowMs) {
        return session;
      }
    }
    return null;
  }

  @override
  Future<bool> hasUsedNonce(String replayKey) async {
    return _readUsedNonces().contains(replayKey);
  }

  @override
  Future<void> markNonceUsed(String replayKey, String usedAtIso) async {
    final next = {..._readUsedNonces(), replayKey};
    await _prefs.setString(
      StorageKeys.mockUsedNonces,
      jsonEncode(next.toList()),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getAttendanceRecords({
    int? userId,
    String? workDate,
    String? startDate,
    String? endDate,
    String status = 'all',
    bool sortByCheckInDesc = false,
  }) async {
    final filtered = _readRecords().where((r) {
      if (userId != null && r['userId'] != userId) return false;
      final date = r['workDate'] as String? ?? '';
      if (workDate != null && workDate.isNotEmpty && date != workDate) {
        return false;
      }
      if (startDate != null &&
          startDate.isNotEmpty &&
          date.compareTo(startDate) < 0) {
        return false;
      }
      if (endDate != null &&
          endDate.isNotEmpty &&
          date.compareTo(endDate) > 0) {
        return false;
      }
      if (status != 'all' && r['status'] != status) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (sortByCheckInDesc) {
        return (b['checkInAt'] as String).compareTo(a['checkInAt'] as String);
      }
      return (b['workDate'] as String).compareTo(a['workDate'] as String);
    });
    return filtered;
  }

  @override
  Future<Map<String, dynamic>?> getAttendanceRecordByUserAndDate(
    int userId,
    String workDate,
  ) async {
    return _readRecords()
        .where((r) => r['userId'] == userId && r['workDate'] == workDate)
        .firstOrNull;
  }

  @override
  Future<void> insertAttendanceRecord(Map<String, dynamic> record) async {
    final records = _readRecords();
    final duplicate = records.any(
      (r) =>
          r['userId'] == record['userId'] &&
          r['workDate'] == record['workDate'],
    );
    if (duplicate) {
      throw StateError('Duplicate attendance record for user and date.');
    }
    records.insert(0, record);
    await _writeRecords(records);
  }

  @override
  Future<void> updateAttendanceRecord(Map<String, dynamic> record) async {
    final records = _readRecords();
    final idx = records.indexWhere((r) => r['id'] == record['id']);
    if (idx != -1) {
      records[idx] = record;
      await _writeRecords(records);
    }
  }

  @override
  Future<bool> hasAnyRecordsForUser(int userId) async {
    return _readRecords().any((r) => r['userId'] == userId);
  }

  @override
  Future<bool> isSeedInitialized() async {
    return _prefs.getBool(StorageKeys.mockSeedMarker) ?? false;
  }

  @override
  Future<void> markSeedInitialized() async {
    await _prefs.setBool(StorageKeys.mockSeedMarker, true);
  }

  @override
  Future<void> insertSeedRecords(List<Map<String, dynamic>> records) async {
    final existing = _readRecords();
    final keys = existing.map((r) => '${r['userId']}|${r['workDate']}').toSet();
    for (final rec in records) {
      final key = '${rec['userId']}|${rec['workDate']}';
      if (!keys.contains(key)) {
        existing.add(rec);
        keys.add(key);
      }
    }
    await _writeRecords(existing);
  }

  @override
  Future<void> insertFailedAttempt(Map<String, dynamic> attempt) async {
    final attempts = _readFailedAttempts();
    attempts.insert(0, attempt);
    await _prefs.setString(
      StorageKeys.mockFailedAttempts,
      jsonEncode(attempts),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getFailedAttempts({
    String? dateKey,
  }) async {
    final attempts = _readFailedAttempts();
    final filtered = (dateKey != null && dateKey.isNotEmpty)
        ? attempts.where((a) => a['workDate'] == dateKey).toList()
        : attempts;
    filtered.sort(
      (a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String),
    );
    return filtered;
  }

  @override
  Future<void> insertPendingScan(Map<String, dynamic> scan) async {
    final scans = _readPendingScans()
      ..removeWhere((s) => s['id'] == scan['id'])
      ..add(scan);
    await _prefs.setString(StorageKeys.mockPendingScans, jsonEncode(scans));
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingScans({int? userId}) async {
    final scans = _readPendingScans();
    final filtered = userId != null
        ? scans.where((s) => (s['userId'] as num?)?.toInt() == userId).toList()
        : scans;
    filtered.sort(
      (a, b) =>
          (a['capturedAt'] as String).compareTo(b['capturedAt'] as String),
    );
    return filtered;
  }

  @override
  Future<void> deletePendingScan(String id) async {
    final scans = _readPendingScans()..removeWhere((s) => s['id'] == id);
    await _prefs.setString(StorageKeys.mockPendingScans, jsonEncode(scans));
  }

  @override
  Future<void> close() async {}

  List<Map<String, dynamic>> _readPendingScans() {
    final raw = _prefs.getString(StorageKeys.mockPendingScans);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _readRecords() {
    final raw = _prefs.getString(StorageKeys.mockAttendanceRecords);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _writeRecords(List<Map<String, dynamic>> records) {
    return _prefs.setString(
      StorageKeys.mockAttendanceRecords,
      jsonEncode(records),
    );
  }

  List<Map<String, dynamic>> _readSessions() {
    final raw = _prefs.getString(StorageKeys.mockQrSessions);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Set<String> _readUsedNonces() {
    final raw = _prefs.getString(StorageKeys.mockUsedNonces);
    if (raw == null || raw.isEmpty) return <String>{};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>{};
    return decoded.whereType<String>().toSet();
  }

  List<Map<String, dynamic>> _readFailedAttempts() {
    final raw = _prefs.getString(StorageKeys.mockFailedAttempts);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }
}

