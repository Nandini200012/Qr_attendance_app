import 'package:equatable/equatable.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';

class AttendanceSummaryEntity extends Equatable {
  const AttendanceSummaryEntity({
    required this.totalPresentDays,
    required this.completedDays,
    required this.activeCheckIns,
    required this.totalWorkedMinutes,
    required this.averageWorkedMinutes,
  });

  const AttendanceSummaryEntity.empty()
      : totalPresentDays = 0,
        completedDays = 0,
        activeCheckIns = 0,
        totalWorkedMinutes = 0,
        averageWorkedMinutes = 0;

  final int totalPresentDays;
  final int completedDays;
  final int activeCheckIns;
  final int totalWorkedMinutes;
  final int averageWorkedMinutes;

  @override
  List<Object?> get props => [
        totalPresentDays,
        completedDays,
        activeCheckIns,
        totalWorkedMinutes,
        averageWorkedMinutes,
      ];
}

class TodayAttendanceOverview extends Equatable {
  const TodayAttendanceOverview({
    required this.workDate,
    required this.status,
    required this.summary,
    required this.recentRecords,
    this.todayRecord,
  });

  final String workDate;
  final AttendanceStatus status;
  final AttendanceRecordEntity? todayRecord;
  final AttendanceSummaryEntity summary;
  final List<AttendanceRecordEntity> recentRecords;

  @override
  List<Object?> get props => [
        workDate,
        status,
        todayRecord,
        summary,
        recentRecords,
      ];
}

class AttendanceHistoryResult extends Equatable {
  const AttendanceHistoryResult({
    required this.summary,
    required this.records,
  });

  final AttendanceSummaryEntity summary;
  final List<AttendanceRecordEntity> records;

  @override
  List<Object?> get props => [summary, records];
}

