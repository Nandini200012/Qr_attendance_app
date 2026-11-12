import 'package:equatable/equatable.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/admin_dashboard_summary_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/employee_attendance_item_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/failed_attempt_entity.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';

enum AdminLoadStatus { initial, loading, loaded, failure }

enum AdminDetailStatus { idle, loading, loaded, failure }

class AdminState extends Equatable {
  AdminState({
    this.status = AdminLoadStatus.initial,
    DateTime? selectedDate,
    this.summary,
    this.searchQuery = '',
    this.statusFilter = 'all',
    this.filteredEmployees = const [],
    this.errorMessage,
    this.detailStatus = AdminDetailStatus.idle,
    this.selectedItem,
    this.selectedEmployeeProfile,
    this.detailError,
    this.failedAttemptsStatus = AdminLoadStatus.initial,
    this.failedAttempts = const [],
    this.failedAttemptsError,
  }) : selectedDate = selectedDate ?? DateTime.now();

  final AdminLoadStatus status;
  final DateTime selectedDate;
  final AdminDashboardSummaryEntity? summary;
  final String searchQuery;
  final String statusFilter;
  final List<EmployeeAttendanceItemEntity> filteredEmployees;
  final String? errorMessage;

  final AdminDetailStatus detailStatus;
  final EmployeeAttendanceItemEntity? selectedItem;
  final UserEntity? selectedEmployeeProfile;
  final String? detailError;

  final AdminLoadStatus failedAttemptsStatus;
  final List<FailedAttemptEntity> failedAttempts;
  final String? failedAttemptsError;

  AdminState copyWith({
    AdminLoadStatus? status,
    DateTime? selectedDate,
    AdminDashboardSummaryEntity? summary,
    String? searchQuery,
    String? statusFilter,
    List<EmployeeAttendanceItemEntity>? filteredEmployees,
    String? errorMessage,
    bool clearError = false,
    AdminDetailStatus? detailStatus,
    EmployeeAttendanceItemEntity? selectedItem,
    bool clearSelectedItem = false,
    UserEntity? selectedEmployeeProfile,
    bool clearSelectedProfile = false,
    String? detailError,
    bool clearDetailError = false,
    AdminLoadStatus? failedAttemptsStatus,
    List<FailedAttemptEntity>? failedAttempts,
    String? failedAttemptsError,
    bool clearFailedAttemptsError = false,
  }) {
    return AdminState(
      status: status ?? this.status,
      selectedDate: selectedDate ?? this.selectedDate,
      summary: summary ?? this.summary,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      filteredEmployees: filteredEmployees ?? this.filteredEmployees,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      detailStatus: detailStatus ?? this.detailStatus,
      selectedItem:
          clearSelectedItem ? null : (selectedItem ?? this.selectedItem),
      selectedEmployeeProfile: clearSelectedProfile
          ? null
          : (selectedEmployeeProfile ?? this.selectedEmployeeProfile),
      detailError:
          clearDetailError ? null : (detailError ?? this.detailError),
      failedAttemptsStatus:
          failedAttemptsStatus ?? this.failedAttemptsStatus,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      failedAttemptsError: clearFailedAttemptsError
          ? null
          : (failedAttemptsError ?? this.failedAttemptsError),
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedDate,
        summary,
        searchQuery,
        statusFilter,
        filteredEmployees,
        errorMessage,
        detailStatus,
        selectedItem,
        selectedEmployeeProfile,
        detailError,
        failedAttemptsStatus,
        failedAttempts,
        failedAttemptsError,
      ];
}

