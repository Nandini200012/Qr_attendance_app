import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/features/admin/domain/repositories/admin_repository.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';

class GetEmployeeDetailUseCase {
  const GetEmployeeDetailUseCase(this._repository);

  final AdminRepository _repository;

  Future<Result<UserEntity>> call(int userId) {
    return _repository.getEmployeeDetail(userId);
  }
}

