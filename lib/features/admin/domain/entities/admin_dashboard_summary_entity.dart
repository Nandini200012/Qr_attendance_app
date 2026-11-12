import 'package:equatable/equatable.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/employee_attendance_item_entity.dart';

class AdminDashboardSummaryEntity extends Equatable {
  const AdminDashboardSummaryEntity({
    required this.dateKey,
    required this.totalEmployees,
    required this.presentCount,
    required this.checkedInCount,
    required this.completedCount,
    required this.lateCount,
    required this.absentCount,
    required this.employees,
  });

  final String dateKey;
  final int totalEmployees;
  final int presentCount;
  final int checkedInCount;
  final int completedCount;
  final int lateCount;
  final int absentCount;
  final List<EmployeeAttendanceItemEntity> employees;

  @override
  List<Object?> get props => [
        dateKey,
        totalEmployees,
        presentCount,
        checkedInCount,
        completedCount,
        lateCount,
        absentCount,
        employees,
      ];
}

