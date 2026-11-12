import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';
import 'package:qr_attendance_app/features/authentication/domain/repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<UserEntity>> call({
    required String email,
    required String password,
  }) {
    return _repository.login(email: email.trim(), password: password);
  }
}

