import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/core/utils/qr_security_utils.dart';

class ValidateQrPayloadUseCase {
  const ValidateQrPayloadUseCase();

  Result<DecodedQrPayload> call(
    String rawQrData, {
    DateTime? referenceTime,
    int graceSeconds = 0,
  }) {
    try {
      final decoded = QrSecurityUtils.validateComplete(
        rawQrData,
        referenceTime: referenceTime,
        graceSeconds: graceSeconds,
      );
      return Success(decoded);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }
}

