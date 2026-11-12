import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/core/utils/date_time_utils.dart';
import 'package:qr_attendance_app/core/widgets/app_error_widget.dart';
import 'package:qr_attendance_app/core/widgets/empty_state_widget.dart';
import 'package:qr_attendance_app/core/widgets/loading_widget.dart';
import 'package:qr_attendance_app/features/admin/domain/entities/employee_attendance_item_entity.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_event.dart';
import 'package:qr_attendance_app/features/admin/presentation/bloc/admin_state.dart';
import 'package:qr_attendance_app/features/admin/presentation/widgets/admin_metrics_grid.dart';
import 'package:qr_attendance_app/features/admin/presentation/widgets/employee_attendance_card.dart';
import 'package:qr_attendance_app/features/admin/presentation/widgets/employee_detail_modal.dart';
import 'package:qr_attendance_app/features/admin/presentation/widgets/failed_attempts_list.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime currentDate,
    String userRole,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null && context.mounted) {
      context.read<AdminBloc>().add(
            AdminDateChanged(date: picked, userRole: userRole),
          );
    }
  }

  Future<void> _openEmployeeDetail(
    BuildContext context,
    EmployeeAttendanceItemEntity item,
  ) async {
    final adminBloc = context.read<AdminBloc>();
    adminBloc.add(AdminEmployeeDetailRequested(item));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: adminBloc,
        child: const EmployeeDetailModal(),
      ),
    );
    adminBloc.add(const AdminEmployeeDetailClosed());
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null) return const SizedBox.shrink();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Attendance Console'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () => context.go('/admin/qr-generator'),
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text('QR Kiosk'),
              ),
            ),
            IconButton(
              tooltip: 'Refresh records',
              onPressed: () {
                final bloc = context.read<AdminBloc>();
                bloc.add(AdminDashboardRequested(userRole: user.role));
                bloc.add(AdminFailedAttemptsRequested(userRole: user.role));
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Attendance'),
              Tab(text: 'Failed Attempts'),
            ],
          ),
        ),
        body: BlocBuilder<AdminBloc, AdminState>(
          builder: (context, state) {
            if (state.status == AdminLoadStatus.initial) {
              context.read<AdminBloc>().add(
                    AdminDashboardRequested(userRole: user.role),
                  );
            }
            if (state.failedAttemptsStatus == AdminLoadStatus.initial) {
              context.read<AdminBloc>().add(
                    AdminFailedAttemptsRequested(userRole: user.role),
                  );
            }

            return TabBarView(
              children: [
                _buildAttendanceTab(context, state, user.role),
                FailedAttemptsList(
                  status: state.failedAttemptsStatus,
                  attempts: state.failedAttempts,
                  errorMessage: state.failedAttemptsError,
                  onRefresh: () async {
                    context.read<AdminBloc>().add(
                          AdminFailedAttemptsRequested(userRole: user.role),
                        );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAttendanceTab(
    BuildContext context,
    AdminState state,
    String userRole,
  ) {
    if (state.status == AdminLoadStatus.initial ||
        (state.status == AdminLoadStatus.loading && state.summary == null)) {
      return const LoadingWidget(
        message: 'Fetching employee directory & attendance...',
      );
    }

    if (state.status == AdminLoadStatus.failure && state.summary == null) {
      return AppErrorWidget(
        message: state.errorMessage ?? 'Unable to load admin dashboard.',
        onRetry: () => context.read<AdminBloc>().add(
              AdminDashboardRequested(userRole: userRole),
            ),
      );
    }

    final summary = state.summary!;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<AdminBloc>().add(
              AdminDashboardRequested(userRole: userRole),
            );
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(
                    context,
                    state.selectedDate,
                    userRole,
                  ),
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    DateTimeUtils.formatFullDate(state.selectedDate),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (state.status == AdminLoadStatus.loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AdminMetricsGrid(summary: summary),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => context
                .read<AdminBloc>()
                .add(AdminSearchQueryChanged(value)),
            decoration: InputDecoration(
              hintText: 'Search by name, EMP ID, email, or department',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: state.searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        context
                            .read<AdminBloc>()
                            .add(const AdminSearchQueryChanged(''));
                      },
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusChip(
                  label: 'All (${summary.totalEmployees})',
                  selected: state.statusFilter == 'all',
                  onTap: () => context
                      .read<AdminBloc>()
                      .add(const AdminStatusFilterChanged('all')),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'Present (${summary.presentCount})',
                  selected: state.statusFilter == 'present',
                  onTap: () => context
                      .read<AdminBloc>()
                      .add(const AdminStatusFilterChanged('present')),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'Late (${summary.lateCount})',
                  selected: state.statusFilter == 'late',
                  onTap: () => context
                      .read<AdminBloc>()
                      .add(const AdminStatusFilterChanged('late')),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'Checked In (${summary.checkedInCount})',
                  selected: state.statusFilter == 'checked_in',
                  onTap: () => context
                      .read<AdminBloc>()
                      .add(const AdminStatusFilterChanged('checked_in')),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'Completed (${summary.completedCount})',
                  selected: state.statusFilter == 'completed',
                  onTap: () => context
                      .read<AdminBloc>()
                      .add(const AdminStatusFilterChanged('completed')),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'Absent (${summary.absentCount})',
                  selected: state.statusFilter == 'absent',
                  onTap: () => context
                      .read<AdminBloc>()
                      .add(const AdminStatusFilterChanged('absent')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Employees (${state.filteredEmployees.length})',
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (state.filteredEmployees.isEmpty)
            const EmptyStateWidget(
              title: 'No Employees Found',
              message: 'Try adjusting your search query or status filter.',
              icon: Icons.person_search_rounded,
            )
          else
            ...state.filteredEmployees.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: EmployeeAttendanceCard(
                  item: item,
                  onTap: () => _openEmployeeDetail(context, item),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

