import 'package:qr_attendance_app/core/errors/error_message_mapper.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/attendance/domain/entities/attendance_record_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_scan_result_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/repositories/qr_attendance_repository.dart';

class SubmitQrAttendanceUseCase {
  const SubmitQrAttendanceUseCase(this._repository);

  final QrAttendanceRepository _repository;

  Future<Result<QrScanResultEntity>> call({
    required String rawQrPayload,
    required String action,
    required int userId,
    AttendanceStatus? todayStatus,
  }) {
    if (todayStatus != null) {
      if (action == 'check_in' && todayStatus == AttendanceStatus.checkedIn) {
        return Future.value(
          ResultFailure(
            QrValidationFailure(
              reason: QrValidationErrorCode.duplicateCheckIn,
              message: ErrorMessageMapper.fromQrReason(
                QrValidationErrorCode.duplicateCheckIn,
              ),
            ),
          ),
        );
      }
      if (action == 'check_in' && todayStatus == AttendanceStatus.completed) {
        return Future.value(
          ResultFailure(
            QrValidationFailure(
              reason: QrValidationErrorCode.alreadyCheckedOut,
              message: ErrorMessageMapper.fromQrReason(
                QrValidationErrorCode.alreadyCheckedOut,
              ),
            ),
          ),
        );
      }
      if (action == 'check_out' &&
          todayStatus == AttendanceStatus.notCheckedIn) {
        return Future.value(
          ResultFailure(
            QrValidationFailure(
              reason: QrValidationErrorCode.noActiveCheckIn,
              message: ErrorMessageMapper.fromQrReason(
                QrValidationErrorCode.noActiveCheckIn,
              ),
            ),
          ),
        );
      }
      if (action == 'check_out' && todayStatus == AttendanceStatus.completed) {
        return Future.value(
          ResultFailure(
            QrValidationFailure(
              reason: QrValidationErrorCode.alreadyCheckedOut,
              message: ErrorMessageMapper.fromQrReason(
                QrValidationErrorCode.alreadyCheckedOut,
              ),
            ),
          ),
        );
      }
    }

    return _repository.submitQrAttendance(
      rawQrPayload: rawQrPayload,
      action: action,
      userId: userId,
    );
  }
}

