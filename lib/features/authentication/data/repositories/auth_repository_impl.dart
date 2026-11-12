import 'dart:convert';

import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/errors/failures.dart';
import 'package:qr_attendance_app/core/errors/result.dart';
import 'package:qr_attendance_app/core/services/secure_storage_service.dart';
import 'package:qr_attendance_app/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:qr_attendance_app/features/authentication/data/models/user_model.dart';
import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';
import 'package:qr_attendance_app/features/authentication/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService storageService,
  })  : _remoteDataSource = remoteDataSource,
        _storageService = storageService;

  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _storageService;

  @override
  Future<Result<UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final session = await _remoteDataSource.login(
        email: email,
        password: password,
      );
      await _storageService.saveAccessToken(session.accessToken);
      if (session.refreshToken.isNotEmpty) {
        await _storageService.saveRefreshToken(session.refreshToken);
      }
      await _storageService.saveUserProfileJson(
        jsonEncode(session.user.toJson()),
      );
      return Success(session.user);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<UserEntity?>> checkAuthStatus() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null || token.isEmpty) {
        return const Success(null);
      }
      try {
        final user = await _remoteDataSource.getCurrentUser();
        await _storageService.saveUserProfileJson(jsonEncode(user.toJson()));
        return Success(user);
      } on UnauthorizedException {
        await _storageService.clearAll();
        return const Success(null);
      } on NetworkException {
        // If offline on launch, allow cached verified profile if available,
        // otherwise surface network error so user can retry.
        final cachedJson = await _storageService.getUserProfileJson();
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final decoded = jsonDecode(cachedJson);
          if (decoded is Map<String, dynamic>) {
            return Success(UserModel.fromJson(decoded));
          }
        }
        rethrow;
      }
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<UserEntity>> getCurrentUser() async {
    try {
      final user = await _remoteDataSource.getCurrentUser();
      await _storageService.saveUserProfileJson(jsonEncode(user.toJson()));
      return Success(user);
    } on UnauthorizedException {
      await _storageService.clearAll();
      return ResultFailure(mapExceptionToFailure(const UnauthorizedException()));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _storageService.clearAll();
      return const Success(null);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }
}

