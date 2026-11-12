import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_summary_entity.dart';

class AttendanceSummaryModel extends AttendanceSummaryEntity {
  const AttendanceSummaryModel({
    required super.totalPresentDays,
    required super.completedDays,
    required super.activeCheckIns,
    required super.totalWorkedMinutes,
    required super.averageWorkedMinutes,
  });

  factory AttendanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSummaryModel(
      totalPresentDays: (json['totalPresentDays'] as num?)?.toInt() ?? 0,
      completedDays: (json['completedDays'] as num?)?.toInt() ?? 0,
      activeCheckIns: (json['activeCheckIns'] as num?)?.toInt() ?? 0,
      totalWorkedMinutes: (json['totalWorkedMinutes'] as num?)?.toInt() ?? 0,
      averageWorkedMinutes:
          (json['averageWorkedMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalPresentDays': totalPresentDays,
        'completedDays': completedDays,
        'activeCheckIns': activeCheckIns,
        'totalWorkedMinutes': totalWorkedMinutes,
        'averageWorkedMinutes': averageWorkedMinutes,
      };
}

