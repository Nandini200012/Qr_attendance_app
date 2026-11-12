import 'package:dio/dio.dart';
import 'package:qr_attendance_app/core/constants/api_constants.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';
import 'package:qr_attendance_app/core/network/network_exceptions.dart';
import 'package:qr_attendance_app/features/authentication/data/models/auth_session_model.dart';
import 'package:qr_attendance_app/features/authentication/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  });

  Future<UserModel> getCurrentUser({String? overrideToken});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final resolvedUsername = await _resolveUsername(email.trim());

      final loginResponse = await _dio.post<Map<String, dynamic>>(
        ApiConstants.loginEndpoint,
        data: {
          'username': resolvedUsername,
          'password': password,
          'expiresInMins': 60,
        },
      );

      final data = loginResponse.data;
      if (data == null) {
        throw const ServerException('Empty response from authentication server.');
      }

      final accessToken = (data['accessToken'] ?? data['token']) as String?;
      final refreshToken = (data['refreshToken'] as String?) ?? '';
      if (accessToken == null || accessToken.isEmpty) {
        throw const ServerException('Authentication token missing in response.');
      }

      // Fetch full profile via GET /auth/me to get role, department, and title.
      final fullUser = await getCurrentUser(overrideToken: accessToken);

      return AuthSessionModel(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: fullUser,
      );
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkExceptionMapper.fromDioException(e);
    } catch (e) {
      throw ServerException('Login failed: $e');
    }
  }

  Future<String> _resolveUsername(String emailOrUsername) async {
    if (!emailOrUsername.contains('@')) {
      return emailOrUsername;
    }

    final normalizedEmail = emailOrUsername.toLowerCase();
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.usersFilterEndpoint,
      queryParameters: {
        'key': 'email',
        'value': normalizedEmail,
      },
    );

    final users = response.data?['users'];
    if (users is List && users.isNotEmpty) {
      final first = users.first;
      if (first is Map<String, dynamic>) {
        final username = first['username'];
        if (username is String && username.isNotEmpty) {
          return username;
        }
      }
    }

    throw const ServerException(
      'No employee account found for this email address.',
      code: 'USER_NOT_FOUND',
      statusCode: 404,
    );
  }

  @override
  Future<UserModel> getCurrentUser({String? overrideToken}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.meEndpoint,
        options: overrideToken != null
            ? Options(headers: {'Authorization': 'Bearer $overrideToken'})
            : null,
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Empty profile response from server.');
      }
      return UserModel.fromJson(data);
    } on AppException {
      rethrow;
    } on DioException catch (e) {
      throw NetworkExceptionMapper.fromDioException(e);
    } catch (e) {
      throw ServerException('Unable to load user profile: $e');
    }
  }
}

