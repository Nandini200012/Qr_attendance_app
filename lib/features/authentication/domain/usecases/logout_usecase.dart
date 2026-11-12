import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/authentication/domain/repositories/auth_repository.dart';

class LogoutUseCase {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.logout();
}

