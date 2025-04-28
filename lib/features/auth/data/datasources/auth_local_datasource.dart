import 'dart:convert';
import '../../../../core/error/exceptions.dart';
import '../../../../core/security/encryption_service.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../models/user_model.dart';
import '../models/token_model.dart';
import '../models/biometric_auth_model.dart';

abstract class AuthLocalDataSource {
  Future<UserModel?> getCachedUser();
  Future<void> cacheUser(UserModel user);
  Future<TokenModel?> getCachedTokens();
  Future<void> cacheTokens(TokenModel tokens);
  Future<void> clearCache();
  Future<BiometricAuthModel?> getBiometricAuth();
  Future<void> cacheBiometricAuth(BiometricAuthModel biometricAuth);
  Future<bool> isSessionValid();
  Future<void> updateLastActivity();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SecureStorageService _secureStorage;
  final EncryptionService _encryptionService;

  static const String _userKey = 'cached_user';
  static const String _tokenKey = 'cached_token';
  static const String _biometricKey = 'biometric_auth';
  static const String _lastActivityKey = 'last_activity';
  static const int _sessionTimeoutMinutes = 15;

  AuthLocalDataSourceImpl({
    required SecureStorageService secureStorage,
    required EncryptionService encryptionService,
  })  : _secureStorage = secureStorage,
        _encryptionService = encryptionService;

  @override
  Future<UserModel?> getCachedUser() async {
    try {
      final encryptedData = await _secureStorage.read(_userKey);
      if (encryptedData == null) return null;

      final decryptedData = await _encryptionService.decrypt(encryptedData);
      return UserModel.fromJson(json.decode(decryptedData));
    } catch (e) {
      throw CacheException('Failed to get cached user: $e');
    }
  }

  @override
  Future<void> cacheUser(UserModel user) async {
    try {
      final jsonString = json.encode(user.toJson());
      final encryptedData = await _encryptionService.encrypt(jsonString);
      await _secureStorage.write(_userKey, encryptedData);
    } catch (e) {
      throw CacheException('Failed to cache user: $e');
    }
  }

  @override
  Future<TokenModel?> getCachedTokens() async {
    try {
      final encryptedData = await _secureStorage.read(_tokenKey);
      if (encryptedData == null) return null;

      final decryptedData = await _encryptionService.decrypt(encryptedData);
      return TokenModel.fromJson(json.decode(decryptedData));
    } catch (e) {
      throw CacheException('Failed to get cached tokens: $e');
    }
  }

  @override
  Future<void> cacheTokens(TokenModel tokens) async {
    try {
      final jsonString = json.encode(tokens.toJson());
      final encryptedData = await _encryptionService.encrypt(jsonString);
      await _secureStorage.write(_tokenKey, encryptedData);
    } catch (e) {
      throw CacheException('Failed to cache tokens: $e');
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      await _secureStorage.delete(_userKey);
      await _secureStorage.delete(_tokenKey);
      await _secureStorage.delete(_biometricKey);
      await _secureStorage.delete(_lastActivityKey);
    } catch (e) {
      throw CacheException('Failed to clear cache: $e');
    }
  }

  @override
  Future<BiometricAuthModel?> getBiometricAuth() async {
    try {
      final encryptedData = await _secureStorage.read(_biometricKey);
      if (encryptedData == null) return null;

      final decryptedData = await _encryptionService.decrypt(encryptedData);
      return BiometricAuthModel.fromJson(json.decode(decryptedData));
    } catch (e) {
      throw CacheException('Failed to get biometric auth: $e');
    }
  }

  @override
  Future<void> cacheBiometricAuth(BiometricAuthModel biometricAuth) async {
    try {
      final jsonString = json.encode(biometricAuth.toJson());
      final encryptedData = await _encryptionService.encrypt(jsonString);
      await _secureStorage.write(_biometricKey, encryptedData);
    } catch (e) {
      throw CacheException('Failed to cache biometric auth: $e');
    }
  }

  @override
  Future<bool> isSessionValid() async {
    try {
      final lastActivityStr = await _secureStorage.read(_lastActivityKey);
      if (lastActivityStr == null) return false;

      final lastActivity = DateTime.parse(lastActivityStr);
      final now = DateTime.now();
      final difference = now.difference(lastActivity);

      return difference.inMinutes < _sessionTimeoutMinutes;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> updateLastActivity() async {
    try {
      final now = DateTime.now().toIso8601String();
      await _secureStorage.write(_lastActivityKey, now);
    } catch (e) {
      throw CacheException('Failed to update last activity: $e');
    }
  }
}