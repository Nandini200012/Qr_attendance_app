import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_summary_entity.dart';
import 'package:qr_attendance_app/features/attendance/domain/usecases/get_attendance_history_usecase.dart';
import 'package:qr_attendance_app/features/attendance/domain/usecases/get_today_attendance_usecase.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_event.dart';
import 'package:qr_attendance_app/features/attendance/presentation/bloc/attendance_state.dart';

class _MockGetTodayAttendanceUseCase extends Mock
    implements GetTodayAttendanceUseCase {}

class _MockGetAttendanceHistoryUseCase extends Mock
    implements GetAttendanceHistoryUseCase {}

void main() {
  late _MockGetTodayAttendanceUseCase todayUseCase;
  late _MockGetAttendanceHistoryUseCase historyUseCase;

  final sampleRecord = AttendanceRecordEntity(
    id: 'att_1',
    userId: 26,
    workDate: '2026-11-12',
    sessionId: 'sess_1',
    locationName: 'HQ Campus',
    status: AttendanceStatus.completed,
    checkInAt: DateTime.utc(2026, 11, 12, 9, 0),
    checkInLat: 12.9716,
    checkInLng: 77.5946,
    checkOutAt: DateTime.utc(2026, 11, 12, 17, 30),
    checkOutLat: 12.9716,
    checkOutLng: 77.5946,
    durationMinutes: 510,
  );

  const sampleSummary = AttendanceSummaryEntity(
    totalPresentDays: 1,
    completedDays: 1,
    activeCheckIns: 0,
    totalWorkedMinutes: 510,
    averageWorkedMinutes: 510,
  );

  setUp(() {
    todayUseCase = _MockGetTodayAttendanceUseCase();
    historyUseCase = _MockGetAttendanceHistoryUseCase();
  });

  AttendanceBloc buildBloc() => AttendanceBloc(
        getTodayAttendanceUseCase: todayUseCase,
        getAttendanceHistoryUseCase: historyUseCase,
      );

  group('AttendanceBloc', () {
    blocTest<AttendanceBloc, AttendanceState>(
      'emits [loading, loaded] when today overview loads successfully',
      setUp: () {
        when(() => todayUseCase(userId: 26)).thenAnswer(
          (_) async => Success(
            TodayAttendanceOverview(
              workDate: '2026-11-12',
              status: AttendanceStatus.completed,
              todayRecord: sampleRecord,
              summary: sampleSummary,
              recentRecords: [sampleRecord],
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AttendanceDashboardRequested(26)),
      expect: () => [
        isA<AttendanceState>().having(
          (s) => s.dashboardStatus,
          'dashboardStatus',
          AttendanceLoadStatus.loading,
        ),
        isA<AttendanceState>()
            .having(
              (s) => s.dashboardStatus,
              'dashboardStatus',
              AttendanceLoadStatus.loaded,
            )
            .having(
              (s) => s.todayOverview?.status,
              'todayStatus',
              AttendanceStatus.completed,
            ),
      ],
    );

    blocTest<AttendanceBloc, AttendanceState>(
      'updates statusFilter and loads filtered history',
      setUp: () {
        when(() => historyUseCase(
              userId: 26,
              startDate: null,
              endDate: null,
              statusFilter: 'completed',
            )).thenAnswer(
          (_) async => Success(
            AttendanceHistoryResult(
              summary: sampleSummary,
              records: [sampleRecord],
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AttendanceStatusFilterUpdated(
          userId: 26,
          statusFilter: 'completed',
        ),
      ),
      expect: () => [
        isA<AttendanceState>()
            .having(
              (s) => s.historyStatus,
              'historyStatus',
              AttendanceLoadStatus.loading,
            )
            .having((s) => s.statusFilter, 'statusFilter', 'completed'),
        isA<AttendanceState>()
            .having(
              (s) => s.historyStatus,
              'historyStatus',
              AttendanceLoadStatus.loaded,
            )
            .having((s) => s.historyRecords.length, 'recordsLength', 1),
      ],
    );

    blocTest<AttendanceBloc, AttendanceState>(
      'emits failure when dashboard fails due to network timeout',
      setUp: () {
        when(() => todayUseCase(userId: 26))
            .thenAnswer((_) async => const ResultFailure(TimeoutFailure()));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AttendanceDashboardRequested(26)),
      expect: () => [
        isA<AttendanceState>().having(
          (s) => s.dashboardStatus,
          'dashboardStatus',
          AttendanceLoadStatus.loading,
        ),
        isA<AttendanceState>()
            .having(
              (s) => s.dashboardStatus,
              'dashboardStatus',
              AttendanceLoadStatus.failure,
            )
            .having(
              (s) => s.dashboardError,
              'dashboardError',
              'The server took too long to respond. Please retry.',
            ),
      ],
    );
  });
}

