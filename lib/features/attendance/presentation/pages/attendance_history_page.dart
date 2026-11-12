import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/core/widgets/app_error_widget.dart';
import 'package:qr_attendance_app/core/widgets/empty_state_widget.dart';
import 'package:qr_attendance_app/core/widgets/loading_widget.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_event.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_state.dart';
import 'package:qr_attendance_app/features/attendance/presentation/widgets/attendance_record_tile.dart';
import 'package:qr_attendance_app/features/attendance/presentation/widgets/attendance_summary_grid.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';

class AttendanceHistoryPage extends StatelessWidget {
  const AttendanceHistoryPage({super.key});

  Future<void> _pickDateRange(
    BuildContext context,
    int userId,
    AttendanceState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: state.startDate != null && state.endDate != null
          ? DateTimeRange(start: state.startDate!, end: state.endDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
    );
    if (picked != null && context.mounted) {
      context.read<AttendanceBloc>().add(
            AttendanceDateFilterUpdated(
              userId: userId,
              startDate: picked.start,
              endDate: picked.end,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: () => context
                .read<AttendanceBloc>()
                .add(AttendanceHistoryRequested(userId: user.id)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: BlocBuilder<AttendanceBloc, AttendanceState>(
        builder: (context, state) {
          if (state.historyStatus == AttendanceLoadStatus.initial) {
            context
                .read<AttendanceBloc>()
                .add(AttendanceHistoryRequested(userId: user.id));
            return const LoadingWidget(message: 'Loading attendance history...');
          }

          return Column(
            children: [
              _FilterToolbar(
                state: state,
                onPickDateRange: () => _pickDateRange(context, user.id, state),
                onStatusChanged: (status) => context.read<AttendanceBloc>().add(
                      AttendanceStatusFilterUpdated(
                        userId: user.id,
                        statusFilter: status,
                      ),
                    ),
                onClearFilters: () => context
                    .read<AttendanceBloc>()
                    .add(AttendanceFiltersCleared(user.id)),
              ),
              Expanded(
                child: _buildBody(context, user.id, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    int userId,
    AttendanceState state,
  ) {
    if (state.historyStatus == AttendanceLoadStatus.loading &&
        state.historyRecords.isEmpty) {
      return const LoadingWidget(message: 'Fetching attendance records...');
    }

    if (state.historyStatus == AttendanceLoadStatus.failure &&
        state.historyRecords.isEmpty) {
      return AppErrorWidget(
        message: state.historyError ?? 'Unable to load attendance history.',
        onRetry: () => context
            .read<AttendanceBloc>()
            .add(AttendanceHistoryRequested(userId: userId)),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context
            .read<AttendanceBloc>()
            .add(AttendanceHistoryRequested(userId: userId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AttendanceSummaryGrid(summary: state.historySummary),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Records (${state.historyRecords.length})',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (state.historyStatus == AttendanceLoadStatus.loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (state.historyRecords.isEmpty)
            EmptyStateWidget(
              title: state.hasActiveFilters
                  ? 'No records match your filter.'
                  : 'No attendance records yet',
              message: state.hasActiveFilters
                  ? 'Try clearing or adjusting your date and status filters.'
                  : 'Your verified attendance logs will appear here.',
              icon: Icons.history_toggle_off_rounded,
              actionLabel: state.hasActiveFilters ? 'Clear Filters' : null,
              onAction: state.hasActiveFilters
                  ? () => context
                      .read<AttendanceBloc>()
                      .add(AttendanceFiltersCleared(userId))
                  : null,
            )
          else
            ...state.historyRecords.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AttendanceRecordTile(record: record),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterToolbar extends StatelessWidget {
  const _FilterToolbar({
    required this.state,
    required this.onPickDateRange,
    required this.onStatusChanged,
    required this.onClearFilters,
  });

  final AttendanceState state;
  final VoidCallback onPickDateRange;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final dateLabel = state.startDate != null && state.endDate != null
        ? '${DateTimeUtils.formatShortDate(state.startDate!)} - ${DateTimeUtils.formatShortDate(state.endDate!)}'
        : 'Filter by Date';

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickDateRange,
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    dateLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (state.hasActiveFilters) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onClearFilters,
                  child: const Text('Reset'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: state.statusFilter == 'all',
                  onSelected: () => onStatusChanged('all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Completed',
                  selected: state.statusFilter == 'completed',
                  onSelected: () => onStatusChanged('completed'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Checked In',
                  selected: state.statusFilter == 'checked_in',
                  onSelected: () => onStatusChanged('checked_in'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

