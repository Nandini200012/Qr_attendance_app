import 'package:equatable/equatable.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_summary_entity.dart';

enum AttendanceLoadStatus { initial, loading, loaded, failure }

class AttendanceState extends Equatable {
  const AttendanceState({
    this.dashboardStatus = AttendanceLoadStatus.initial,
    this.historyStatus = AttendanceLoadStatus.initial,
    this.todayOverview,
    this.historySummary = const AttendanceSummaryEntity.empty(),
    this.historyRecords = const [],
    this.startDate,
    this.endDate,
    this.statusFilter = 'all',
    this.dashboardError,
    this.historyError,
  });

  final AttendanceLoadStatus dashboardStatus;
  final AttendanceLoadStatus historyStatus;
  final TodayAttendanceOverview? todayOverview;
  final AttendanceSummaryEntity historySummary;
  final List<AttendanceRecordEntity> historyRecords;
  final DateTime? startDate;
  final DateTime? endDate;
  final String statusFilter;
  final String? dashboardError;
  final String? historyError;

  bool get hasActiveFilters =>
      startDate != null || endDate != null || statusFilter != 'all';

  AttendanceState copyWith({
    AttendanceLoadStatus? dashboardStatus,
    AttendanceLoadStatus? historyStatus,
    TodayAttendanceOverview? todayOverview,
    AttendanceSummaryEntity? historySummary,
    List<AttendanceRecordEntity>? historyRecords,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    String? statusFilter,
    String? dashboardError,
    bool clearDashboardError = false,
    String? historyError,
    bool clearHistoryError = false,
  }) {
    return AttendanceState(
      dashboardStatus: dashboardStatus ?? this.dashboardStatus,
      historyStatus: historyStatus ?? this.historyStatus,
      todayOverview: todayOverview ?? this.todayOverview,
      historySummary: historySummary ?? this.historySummary,
      historyRecords: historyRecords ?? this.historyRecords,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      statusFilter: statusFilter ?? this.statusFilter,
      dashboardError:
          clearDashboardError ? null : (dashboardError ?? this.dashboardError),
      historyError:
          clearHistoryError ? null : (historyError ?? this.historyError),
    );
  }

  @override
  List<Object?> get props => [
        dashboardStatus,
        historyStatus,
        todayOverview,
        historySummary,
        historyRecords,
        startDate,
        endDate,
        statusFilter,
        dashboardError,
        historyError,
      ];
}

