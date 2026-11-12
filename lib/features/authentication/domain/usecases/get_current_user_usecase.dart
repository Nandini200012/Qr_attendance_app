import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';
import 'package:qr_attendance_app/features/authentication/domain/repositories/auth_repository.dart';

class GetCurrentUserUseCase {
  const GetCurrentUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<UserEntity?>> checkSession() => _repository.checkAuthStatus();

  Future<Result<UserEntity>> fetchProfile() => _repository.getCurrentUser();
}

