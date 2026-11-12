import 'package:bloc/bloc.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/employee_attendance_item_entity.dart';
import 'package:qr_attendance_app/features/admin/domain/usecases/get_admin_dashboard_usecase.dart';
import 'package:qr_attendance_app/features/admin/domain/usecases/get_employee_detail_usecase.dart';
import 'package:qr_attendance_app/features/admin/domain/usecases/get_failed_attempts_usecase.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_event.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_state.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  AdminBloc({
    required GetAdminDashboardUseCase getAdminDashboardUseCase,
    required GetEmployeeDetailUseCase getEmployeeDetailUseCase,
    required GetFailedAttemptsUseCase getFailedAttemptsUseCase,
  })  : _getAdminDashboardUseCase = getAdminDashboardUseCase,
        _getEmployeeDetailUseCase = getEmployeeDetailUseCase,
        _getFailedAttemptsUseCase = getFailedAttemptsUseCase,
        super(AdminState()) {
    on<AdminDashboardRequested>(_onDashboardRequested);
    on<AdminDateChanged>(_onDateChanged);
    on<AdminSearchQueryChanged>(_onSearchQueryChanged);
    on<AdminStatusFilterChanged>(_onStatusFilterChanged);
    on<AdminEmployeeDetailRequested>(_onEmployeeDetailRequested);
    on<AdminEmployeeDetailClosed>(_onEmployeeDetailClosed);
    on<AdminFailedAttemptsRequested>(_onFailedAttemptsRequested);
  }

  final GetAdminDashboardUseCase _getAdminDashboardUseCase;
  final GetEmployeeDetailUseCase _getEmployeeDetailUseCase;
  final GetFailedAttemptsUseCase _getFailedAttemptsUseCase;

  Future<void> _onDashboardRequested(
    AdminDashboardRequested event,
    Emitter<AdminState> emit,
  ) async {
    final targetDate = event.date ?? state.selectedDate;
    emit(state.copyWith(
      status: AdminLoadStatus.loading,
      selectedDate: targetDate,
      clearError: true,
    ));

    final result = await _getAdminDashboardUseCase(
      date: targetDate,
      userRole: event.userRole,
    );

    result.fold(
      onFailure: (failure) {
        emit(state.copyWith(
          status: AdminLoadStatus.failure,
          errorMessage: failure.message,
        ));
      },
      onSuccess: (summary) {
        emit(state.copyWith(
          status: AdminLoadStatus.loaded,
          summary: summary,
          filteredEmployees: _applyFilters(
            employees: summary.employees,
            query: state.searchQuery,
            statusFilter: state.statusFilter,
          ),
          clearError: true,
        ));
      },
    );
  }

  Future<void> _onDateChanged(
    AdminDateChanged event,
    Emitter<AdminState> emit,
  ) async {
    add(AdminDashboardRequested(userRole: event.userRole, date: event.date));
  }

  void _onSearchQueryChanged(
    AdminSearchQueryChanged event,
    Emitter<AdminState> emit,
  ) {
    final employees = state.summary?.employees ?? [];
    emit(state.copyWith(
      searchQuery: event.query,
      filteredEmployees: _applyFilters(
        employees: employees,
        query: event.query,
        statusFilter: state.statusFilter,
      ),
    ));
  }

  void _onStatusFilterChanged(
    AdminStatusFilterChanged event,
    Emitter<AdminState> emit,
  ) {
    final employees = state.summary?.employees ?? [];
    emit(state.copyWith(
      statusFilter: event.filter,
      filteredEmployees: _applyFilters(
        employees: employees,
        query: state.searchQuery,
        statusFilter: event.filter,
      ),
    ));
  }

  Future<void> _onEmployeeDetailRequested(
    AdminEmployeeDetailRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(
      detailStatus: AdminDetailStatus.loading,
      selectedItem: event.item,
      selectedEmployeeProfile: event.item.employee,
      clearDetailError: true,
    ));

    final result = await _getEmployeeDetailUseCase(event.item.employee.id);
    result.fold(
      onFailure: (failure) {
        emit(state.copyWith(
          detailStatus: AdminDetailStatus.failure,
          detailError: failure.message,
        ));
      },
      onSuccess: (profile) {
        emit(state.copyWith(
          detailStatus: AdminDetailStatus.loaded,
          selectedEmployeeProfile: profile,
          clearDetailError: true,
        ));
      },
    );
  }

  void _onEmployeeDetailClosed(
    AdminEmployeeDetailClosed event,
    Emitter<AdminState> emit,
  ) {
    emit(state.copyWith(
      detailStatus: AdminDetailStatus.idle,
      clearSelectedItem: true,
      clearSelectedProfile: true,
      clearDetailError: true,
    ));
  }

  Future<void> _onFailedAttemptsRequested(
    AdminFailedAttemptsRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(
      failedAttemptsStatus: AdminLoadStatus.loading,
      clearFailedAttemptsError: true,
    ));

    final result = await _getFailedAttemptsUseCase(
      userRole: event.userRole,
      date: event.date,
    );

    result.fold(
      onFailure: (failure) {
        emit(state.copyWith(
          failedAttemptsStatus: AdminLoadStatus.failure,
          failedAttemptsError: failure.message,
        ));
      },
      onSuccess: (attempts) {
        emit(state.copyWith(
          failedAttemptsStatus: AdminLoadStatus.loaded,
          failedAttempts: attempts,
          clearFailedAttemptsError: true,
        ));
      },
    );
  }

  List<EmployeeAttendanceItemEntity> _applyFilters({
    required List<EmployeeAttendanceItemEntity> employees,
    required String query,
    required String statusFilter,
  }) {
    final q = query.trim().toLowerCase();
    return employees.where((item) {
      final matchesStatus = switch (statusFilter) {
        'present' => item.isPresent,
        'late' => item.isPresent && (item.record?.isLate ?? false),
        'checked_in' => item.status == AttendanceStatus.checkedIn,
        'completed' => item.status == AttendanceStatus.completed,
        'absent' => item.status == AttendanceStatus.notCheckedIn,
        _ => true,
      };
      if (!matchesStatus) return false;

      if (q.isEmpty) return true;
      final emp = item.employee;
      return emp.fullName.toLowerCase().contains(q) ||
          emp.email.toLowerCase().contains(q) ||
          emp.employeeCode.toLowerCase().contains(q) ||
          emp.department.toLowerCase().contains(q) ||
          emp.jobTitle.toLowerCase().contains(q);
    }).toList();
  }
}

