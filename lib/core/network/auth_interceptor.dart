import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:qr_attendance_app/core/constants/api_constants.dart';
import 'package:qr_attendance_app/core/services/secure_storage_service.dart';

class AuthSessionEvents {
  final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast();

  Stream<void> get onUnauthorized => _unauthorizedController.stream;

  void notifyUnauthorized() {
    if (!_unauthorizedController.isClosed) {
      _unauthorizedController.add(null);
    }
  }

  Future<void> dispose() => _unauthorizedController.close();
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required SecureStorageService storageService,
    required AuthSessionEvents sessionEvents,
  })  : _storageService = storageService,
        _sessionEvents = sessionEvents;

  final SecureStorageService _storageService;
  final AuthSessionEvents _sessionEvents;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isLoginRequest = options.path.endsWith(ApiConstants.loginEndpoint);
    if (!isLoginRequest) {
      try {
        final token = await _storageService.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        final isDummyJson =
            options.uri.toString().startsWith(ApiConstants.dummyJsonBaseUrl);
        if (!isDummyJson && options.headers['X-User-Role'] == null) {
          final cachedProfile = await _storageService.getUserProfileJson();
          if (cachedProfile != null && cachedProfile.isNotEmpty) {
            final decoded = jsonDecode(cachedProfile);
            if (decoded is Map<String, dynamic>) {
              final role = decoded['role'];
              if (role is String && role.isNotEmpty) {
                options.headers['X-User-Role'] = role;
              }
            }
          }
        }
      } catch (_) {
        // Proceed without header; protected endpoints will return 401/403 cleanly.
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final isLoginRequest =
        err.requestOptions.path.endsWith(ApiConstants.loginEndpoint);
    if (err.response?.statusCode == 401 && !isLoginRequest) {
      _sessionEvents.notifyUnauthorized();
    }
    handler.next(err);
  }
}

