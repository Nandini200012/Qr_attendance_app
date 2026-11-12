import 'package:equatable/equatable.dart';

sealed class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => [];
}

final class AttendanceDashboardRequested extends AttendanceEvent {
  const AttendanceDashboardRequested(this.userId);

  final int userId;

  @override
  List<Object?> get props => [userId];
}

final class AttendanceHistoryRequested extends AttendanceEvent {
  const AttendanceHistoryRequested({
    required this.userId,
    this.startDate,
    this.endDate,
    this.statusFilter,
  });

  final int userId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? statusFilter;

  @override
  List<Object?> get props => [userId, startDate, endDate, statusFilter];
}

final class AttendanceDateFilterUpdated extends AttendanceEvent {
  const AttendanceDateFilterUpdated({
    required this.userId,
    this.startDate,
    this.endDate,
  });

  final int userId;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [userId, startDate, endDate];
}

final class AttendanceStatusFilterUpdated extends AttendanceEvent {
  const AttendanceStatusFilterUpdated({
    required this.userId,
    required this.statusFilter,
  });

  final int userId;
  final String statusFilter;

  @override
  List<Object?> get props => [userId, statusFilter];
}

final class AttendanceFiltersCleared extends AttendanceEvent {
  const AttendanceFiltersCleared(this.userId);

  final int userId;

  @override
  List<Object?> get props => [userId];
}

final class AttendanceCleared extends AttendanceEvent {
  const AttendanceCleared();
}

final class AttendancePendingSyncRequested extends AttendanceEvent {
  const AttendancePendingSyncRequested(this.userId);

  final int userId;

  @override
  List<Object?> get props => [userId];
}

