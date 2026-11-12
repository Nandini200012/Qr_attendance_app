import 'package:equatable/equatable.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';

class EmployeeAttendanceItemEntity extends Equatable {
  const EmployeeAttendanceItemEntity({
    required this.employee,
    required this.status,
    this.record,
  });

  final UserEntity employee;
  final AttendanceStatus status;
  final AttendanceRecordEntity? record;

  bool get isPresent => status != AttendanceStatus.notCheckedIn;

  @override
  List<Object?> get props => [employee, status, record];
}

