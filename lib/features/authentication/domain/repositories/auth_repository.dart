import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<Result<UserEntity>> login({
    required String email,
    required String password,
  });

  Future<Result<UserEntity?>> checkAuthStatus();

  Future<Result<UserEntity>> getCurrentUser();

  Future<Result<void>> logout();
}

