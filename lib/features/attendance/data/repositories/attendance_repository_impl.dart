import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/features/attendance/data/datasources/attendance_local_database.dart';
import 'package:qr_attendance_app/features/attendance/data/datasources/attendance_remote_datasource.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_summary_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/repositories/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl(
    this._remoteDataSource, {
    AttendanceLocalDatabase? localDatabase,
  }) : _localDatabase = localDatabase;

  final AttendanceRemoteDataSource _remoteDataSource;
  final AttendanceLocalDatabase? _localDatabase;

  @override
  Future<Result<TodayAttendanceOverview>> getTodayOverview({
    required int userId,
  }) async {
    try {
      final overview = await _remoteDataSource.getTodayOverview(userId: userId);
      final pending = await _loadPendingRecords(userId: userId);
      if (pending.isEmpty) {
        return Success(overview);
      }

      final mergedAll = _mergePendingIntoRecords(
        existing: overview.recentRecords,
        pending: pending,
      );
      final todayPending =
          pending.where((r) => r.workDate == overview.workDate).toList();

      var effectiveTodayRecord = overview.todayRecord;
      var effectiveStatus = overview.status;
      if (todayPending.isNotEmpty) {
        effectiveTodayRecord = _mergeDayPending(
          base: overview.todayRecord,
          pendingForDay: todayPending,
        );
        effectiveStatus = effectiveTodayRecord.status;
      }

      final updatedRecent = mergedAll.take(3).toList();
      return Success(
        TodayAttendanceOverview(
          workDate: overview.workDate,
          status: effectiveStatus,
          todayRecord: effectiveTodayRecord,
          summary: overview.summary,
          recentRecords: updatedRecent,
        ),
      );
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<AttendanceHistoryResult>> getAttendanceHistory({
    required int userId,
    DateTime? startDate,
    DateTime? endDate,
    String statusFilter = 'all',
  }) async {
    try {
      final history = await _remoteDataSource.getAttendanceHistory(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
        statusFilter: statusFilter,
      );
      final pending = await _loadPendingRecords(userId: userId);
      if (pending.isEmpty) {
        return Success(history);
      }

      final startKey =
          startDate != null ? DateTimeUtils.toDateKey(startDate) : null;
      final endKey = endDate != null ? DateTimeUtils.toDateKey(endDate) : null;

      final merged = _mergePendingIntoRecords(
        existing: history.records,
        pending: pending,
      ).where((r) {
        if (startKey != null && r.workDate.compareTo(startKey) < 0) {
          return false;
        }
        if (endKey != null && r.workDate.compareTo(endKey) > 0) {
          return false;
        }
        if (statusFilter == 'completed' &&
            r.status != AttendanceStatus.completed) {
          return false;
        }
        if (statusFilter == 'checked_in' &&
            r.status != AttendanceStatus.checkedIn) {
          return false;
        }
        if (statusFilter == 'late' && !r.isLate) {
          return false;
        }
        return true;
      }).toList();

      return Success(
        AttendanceHistoryResult(
          summary: history.summary,
          records: merged,
        ),
      );
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  Future<List<AttendanceRecordEntity>> _loadPendingRecords({
    required int userId,
  }) async {
    final db = _localDatabase;
    if (db == null) return const [];
    final rawList = await db.getPendingScans(userId: userId);
    return rawList.map((raw) {
      final capturedAt =
          DateTime.tryParse(raw['capturedAt'] as String? ?? '') ??
              DateTime.now().toUtc();
      final action = (raw['action'] as String?) ?? 'check_in';
      final lat = (raw['latitude'] as num).toDouble();
      final lng = (raw['longitude'] as num).toDouble();
      final accuracy = (raw['accuracyMeters'] as num?)?.toDouble();

      return AttendanceRecordEntity(
        id: (raw['id'] as String?) ?? '',
        userId: (raw['userId'] as num).toInt(),
        workDate: (raw['workDate'] as String?) ?? '',
        sessionId: (raw['sessionId'] as String?) ?? 'offline_session',
        locationName: (raw['locationName'] as String?) ?? 'Office',
        status: action == 'check_out'
            ? AttendanceStatus.completed
            : AttendanceStatus.checkedIn,
        checkInAt: capturedAt,
        checkInLat: lat,
        checkInLng: lng,
        checkInAccuracyMeters: accuracy,
        checkOutAt: action == 'check_out' ? capturedAt : null,
        checkOutLat: action == 'check_out' ? lat : null,
        checkOutLng: action == 'check_out' ? lng : null,
        checkOutAccuracyMeters: action == 'check_out' ? accuracy : null,
        isLate: action == 'check_in' && DateTimeUtils.isLateCheckIn(capturedAt),
        serverVerified: false,
        isPendingSync: true,
      );
    }).toList();
  }

  List<AttendanceRecordEntity> _mergePendingIntoRecords({
    required List<AttendanceRecordEntity> existing,
    required List<AttendanceRecordEntity> pending,
  }) {
    final byDate = <String, AttendanceRecordEntity>{
      for (final rec in existing) rec.workDate: rec,
    };

    final pendingByDate = <String, List<AttendanceRecordEntity>>{};
    for (final p in pending) {
      pendingByDate.putIfAbsent(p.workDate, () => []).add(p);
    }

    for (final entry in pendingByDate.entries) {
      byDate[entry.key] = _mergeDayPending(
        base: byDate[entry.key],
        pendingForDay: entry.value,
      );
    }

    final combined = byDate.values.toList()
      ..sort((a, b) {
        final dateCmp = b.workDate.compareTo(a.workDate);
        if (dateCmp != 0) return dateCmp;
        return b.checkInAt.compareTo(a.checkInAt);
      });
    return combined;
  }

  AttendanceRecordEntity _mergeDayPending({
    required AttendanceRecordEntity? base,
    required List<AttendanceRecordEntity> pendingForDay,
  }) {
    final latest = pendingForDay.last;
    if (base == null) {
      final first = pendingForDay.first;
      final duration = latest.checkOutAt?.difference(first.checkInAt).inMinutes;
      return AttendanceRecordEntity(
        id: latest.id,
        userId: first.userId,
        workDate: first.workDate,
        sessionId: latest.sessionId,
        locationName: latest.locationName,
        status: latest.status,
        checkInAt: first.checkInAt,
        checkInLat: first.checkInLat,
        checkInLng: first.checkInLng,
        checkInAccuracyMeters: first.checkInAccuracyMeters,
        checkOutAt: latest.checkOutAt,
        checkOutLat: latest.checkOutLat,
        checkOutLng: latest.checkOutLng,
        checkOutAccuracyMeters: latest.checkOutAccuracyMeters,
        durationMinutes: duration != null && duration >= 0 ? duration : null,
        isLate: first.isLate,
        serverVerified: false,
        isPendingSync: true,
      );
    }

    if (latest.checkOutAt != null) {
      final duration = latest.checkOutAt!.difference(base.checkInAt).inMinutes;
      return AttendanceRecordEntity(
        id: base.id,
        userId: base.userId,
        workDate: base.workDate,
        sessionId: base.sessionId,
        locationName: base.locationName,
        status: AttendanceStatus.completed,
        checkInAt: base.checkInAt,
        checkInLat: base.checkInLat,
        checkInLng: base.checkInLng,
        checkInAccuracyMeters: base.checkInAccuracyMeters,
        checkOutAt: latest.checkOutAt,
        checkOutLat: latest.checkOutLat,
        checkOutLng: latest.checkOutLng,
        checkOutAccuracyMeters: latest.checkOutAccuracyMeters,
        durationMinutes: duration >= 0 ? duration : base.durationMinutes,
        distanceMeters: base.distanceMeters,
        geofenceEnforced: base.geofenceEnforced,
        geofenceRadiusMeters: base.geofenceRadiusMeters,
        isLate: base.isLate,
        serverVerified: false,
        isPendingSync: true,
      );
    }

    return latest;
  }
}

