import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_attendance_app/core/constants/storage_keys.dart';
import 'package:qr_attendance_app/core/errors/exceptions.dart';

abstract class SecureStorageService {
  Future<void> saveAccessToken(String token);
  Future<String?> getAccessToken();
  Future<void> saveRefreshToken(String token);
  Future<String?> getRefreshToken();
  Future<void> saveUserProfileJson(String json);
  Future<String?> getUserProfileJson();
  Future<void> clearAll();
}

class FlutterSecureStorageService implements SecureStorageService {
  FlutterSecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: StorageKeys.accessToken, value: token);
    } catch (e) {
      throw CacheException('Unable to securely store access token: $e');
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: StorageKeys.accessToken);
    } catch (e) {
      throw CacheException('Unable to read access token: $e');
    }
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: StorageKeys.refreshToken, value: token);
    } catch (e) {
      throw CacheException('Unable to securely store refresh token: $e');
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: StorageKeys.refreshToken);
    } catch (e) {
      throw CacheException('Unable to read refresh token: $e');
    }
  }

  @override
  Future<void> saveUserProfileJson(String json) async {
    try {
      await _storage.write(key: StorageKeys.userProfileJson, value: json);
    } catch (e) {
      throw CacheException('Unable to store cached profile: $e');
    }
  }

  @override
  Future<String?> getUserProfileJson() async {
    try {
      return await _storage.read(key: StorageKeys.userProfileJson);
    } catch (e) {
      throw CacheException('Unable to read cached profile: $e');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await _storage.delete(key: StorageKeys.accessToken);
      await _storage.delete(key: StorageKeys.refreshToken);
      await _storage.delete(key: StorageKeys.userId);
      await _storage.delete(key: StorageKeys.userProfileJson);
    } catch (e) {
      throw CacheException('Unable to clear secure storage: $e');
    }
  }
}

