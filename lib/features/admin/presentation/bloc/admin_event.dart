import 'package:equatable/equatable.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/employee_attendance_item_entity.dart';

sealed class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

final class AdminDashboardRequested extends AdminEvent {
  const AdminDashboardRequested({
    required this.userRole,
    this.date,
  });

  final String userRole;
  final DateTime? date;

  @override
  List<Object?> get props => [userRole, date];
}

final class AdminDateChanged extends AdminEvent {
  const AdminDateChanged({
    required this.date,
    required this.userRole,
  });

  final DateTime date;
  final String userRole;

  @override
  List<Object?> get props => [date, userRole];
}

final class AdminSearchQueryChanged extends AdminEvent {
  const AdminSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class AdminStatusFilterChanged extends AdminEvent {
  const AdminStatusFilterChanged(this.filter);

  final String filter;

  @override
  List<Object?> get props => [filter];
}

final class AdminEmployeeDetailRequested extends AdminEvent {
  const AdminEmployeeDetailRequested(this.item);

  final EmployeeAttendanceItemEntity item;

  @override
  List<Object?> get props => [item];
}

final class AdminEmployeeDetailClosed extends AdminEvent {
  const AdminEmployeeDetailClosed();
}

final class AdminFailedAttemptsRequested extends AdminEvent {
  const AdminFailedAttemptsRequested({
    required this.userRole,
    this.date,
  });

  final String userRole;
  final DateTime? date;

  @override
  List<Object?> get props => [userRole, date];
}

