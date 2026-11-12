import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/entities/qr_session_entity.dart';
import 'package:qr_attendance_app/features/qr_attendance/domain/repositories/qr_attendance_repository.dart';

class GenerateQrSessionUseCase {
  const GenerateQrSessionUseCase(this._repository);

  final QrAttendanceRepository _repository;

  Future<Result<QrSessionEntity>> call({
    required String locationName,
    required int createdByUserId,
    required String userRole,
    bool enforceGeofence = false,
  }) {
    if (userRole.toLowerCase() != 'admin') {
      return Future.value(
        const ResultFailure(
          UnauthorizedFailure(
            'Only administrators can generate dynamic QR attendance sessions.',
          ),
        ),
      );
    }
    return _repository.generateQrSession(
      locationName: locationName,
      createdByUserId: createdByUserId,
      userRole: userRole,
      enforceGeofence: enforceGeofence,
    );
  }

  Future<Result<QrSessionEntity?>> getActiveSession() {
    return _repository.getActiveQrSession();
  }
}

