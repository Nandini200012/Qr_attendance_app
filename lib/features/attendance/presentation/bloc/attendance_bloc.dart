import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:qr_attendance_app/core/errors/error_message_mapper.dart';
import 'package:qr_attendance_app/core/services/connectivity_service.dart';
import 'package:qr_attendance_app/features/attendance/domain/usecases/get_attendance_history_usecase.dart';
import 'package:qr_attendance_app/features/attendance/domain/usecases/get_today_attendance_usecase.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_event.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_state.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/usecases/sync_pending_scans_usecase.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  AttendanceBloc({
    required GetTodayAttendanceUseCase getTodayAttendanceUseCase,
    required GetAttendanceHistoryUseCase getAttendanceHistoryUseCase,
    ConnectivityService? connectivityService,
    SyncPendingScansUseCase? syncPendingScansUseCase,
  })  : _getTodayAttendanceUseCase = getTodayAttendanceUseCase,
        _getAttendanceHistoryUseCase = getAttendanceHistoryUseCase,
        _connectivityService = connectivityService,
        _syncPendingScansUseCase = syncPendingScansUseCase,
        super(const AttendanceState()) {
    on<AttendanceDashboardRequested>(_onDashboardRequested);
    on<AttendanceHistoryRequested>(_onHistoryRequested);
    on<AttendanceDateFilterUpdated>(_onDateFilterUpdated);
    on<AttendanceStatusFilterUpdated>(_onStatusFilterUpdated);
    on<AttendanceFiltersCleared>(_onFiltersCleared);
    on<AttendancePendingSyncRequested>(_onPendingSyncRequested);
    on<AttendanceCleared>(_onCleared);

    _connectivitySubscription =
        _connectivityService?.onConnectivityChanged.listen((isOnline) {
      final userId = _activeUserId;
      if (isOnline && userId != null && !isClosed) {
        add(AttendancePendingSyncRequested(userId));
      }
    });
  }

  final GetTodayAttendanceUseCase _getTodayAttendanceUseCase;
  final GetAttendanceHistoryUseCase _getAttendanceHistoryUseCase;
  final ConnectivityService? _connectivityService;
  final SyncPendingScansUseCase? _syncPendingScansUseCase;

  StreamSubscription<bool>? _connectivitySubscription;
  int? _activeUserId;

  Future<void> _onDashboardRequested(
    AttendanceDashboardRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    _activeUserId = event.userId;
    emit(state.copyWith(
      dashboardStatus: AttendanceLoadStatus.loading,
      clearDashboardError: true,
    ));

    final result = await _getTodayAttendanceUseCase(userId: event.userId);
    result.fold(
      onFailure: (failure) {
        emit(state.copyWith(
          dashboardStatus: AttendanceLoadStatus.failure,
          dashboardError: ErrorMessageMapper.fromFailure(failure),
        ));
      },
      onSuccess: (overview) {
        emit(state.copyWith(
          dashboardStatus: AttendanceLoadStatus.loaded,
          todayOverview: overview,
          clearDashboardError: true,
        ));
      },
    );
  }

  Future<void> _onHistoryRequested(
    AttendanceHistoryRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    _activeUserId = event.userId;
    final nextStart = event.startDate ?? state.startDate;
    final nextEnd = event.endDate ?? state.endDate;
    final nextFilter = event.statusFilter ?? state.statusFilter;

    emit(state.copyWith(
      historyStatus: AttendanceLoadStatus.loading,
      startDate: nextStart,
      endDate: nextEnd,
      statusFilter: nextFilter,
      clearHistoryError: true,
    ));

    await _loadHistory(
      userId: event.userId,
      startDate: nextStart,
      endDate: nextEnd,
      statusFilter: nextFilter,
      emit: emit,
    );
  }

  Future<void> _onPendingSyncRequested(
    AttendancePendingSyncRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    final syncUseCase = _syncPendingScansUseCase;
    if (syncUseCase == null) return;

    final result = await syncUseCase(userId: event.userId);
    result.fold(
      onFailure: (_) {},
      onSuccess: (syncedCount) {
        if (syncedCount > 0 && !isClosed) {
          add(AttendanceDashboardRequested(event.userId));
          add(AttendanceHistoryRequested(userId: event.userId));
        }
      },
    );
  }

  Future<void> _onDateFilterUpdated(
    AttendanceDateFilterUpdated event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(state.copyWith(
      historyStatus: AttendanceLoadStatus.loading,
      startDate: event.startDate,
      clearStartDate: event.startDate == null,
      endDate: event.endDate,
      clearEndDate: event.endDate == null,
      clearHistoryError: true,
    ));

    await _loadHistory(
      userId: event.userId,
      startDate: event.startDate,
      endDate: event.endDate,
      statusFilter: state.statusFilter,
      emit: emit,
    );
  }

  Future<void> _onStatusFilterUpdated(
    AttendanceStatusFilterUpdated event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(state.copyWith(
      historyStatus: AttendanceLoadStatus.loading,
      statusFilter: event.statusFilter,
      clearHistoryError: true,
    ));

    await _loadHistory(
      userId: event.userId,
      startDate: state.startDate,
      endDate: state.endDate,
      statusFilter: event.statusFilter,
      emit: emit,
    );
  }

  Future<void> _onFiltersCleared(
    AttendanceFiltersCleared event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(state.copyWith(
      historyStatus: AttendanceLoadStatus.loading,
      clearStartDate: true,
      clearEndDate: true,
      statusFilter: 'all',
      clearHistoryError: true,
    ));

    await _loadHistory(
      userId: event.userId,
      startDate: null,
      endDate: null,
      statusFilter: 'all',
      emit: emit,
    );
  }

  void _onCleared(
    AttendanceCleared event,
    Emitter<AttendanceState> emit,
  ) {
    _activeUserId = null;
    emit(const AttendanceState());
  }

  Future<void> _loadHistory({
    required int userId,
    required DateTime? startDate,
    required DateTime? endDate,
    required String statusFilter,
    required Emitter<AttendanceState> emit,
  }) async {
    final result = await _getAttendanceHistoryUseCase(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      statusFilter: statusFilter,
    );

    result.fold(
      onFailure: (failure) {
        emit(state.copyWith(
          historyStatus: AttendanceLoadStatus.failure,
          historyError: ErrorMessageMapper.fromFailure(failure),
        ));
      },
      onSuccess: (history) {
        emit(state.copyWith(
          historyStatus: AttendanceLoadStatus.loaded,
          historySummary: history.summary,
          historyRecords: history.records,
          clearHistoryError: true,
        ));
      },
    );
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}

