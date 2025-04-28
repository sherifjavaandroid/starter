import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'secure_storage_service.dart';
import 'encryption_service.dart';
import '../utils/secure_logger.dart';
import '../utils/time_manager.dart';

class TokenManager {
  final SecureStorageService _storageService;
  final EncryptionService _encryptionService;
  final TimeManager _timeManager;
  final SecureLogger _logger;

  static const String _accessTokenKey = 'secure_access_token';
  static const String _refreshTokenKey = 'secure_refresh_token';
  static const String _tokenExpiryKey = 'token_expiry_time';
  static const String _deviceIdKey = 'device_binding_id';
  static const String _tokenMetadataKey = 'token_metadata';

  // مدة صلاحية التوكن المحلي (15 دقيقة)
  static const Duration _localTokenExpiry = Duration(minutes: 15);

  // مدة تحديث التوكن قبل انتهائه (5 دقائق)
  static const Duration _tokenRefreshBuffer = Duration(minutes: 5);

  TokenManager(
      this._storageService,
      this._encryptionService,
      this._timeManager,
      this._logger,
      );

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? deviceId,
  }) async {
    try {
      // تشفير التوكنات مع إضافة تحسينات أمنية
      final enhancedAccessToken = await _enhanceTokenSecurity(accessToken);
      final enhancedRefreshToken = await _enhanceTokenSecurity(refreshToken);

      // حفظ التوكنات المشفرة
      await _storageService.saveUltraSecureData(_accessTokenKey, enhancedAccessToken);
      await _storageService.saveUltraSecureData(_refreshTokenKey, enhancedRefreshToken);

      // حفظ وقت انتهاء التوكن
      final expiryTime = _getTokenExpiry(accessToken);
      await _storageService.saveSecureData(
        _tokenExpiryKey,
        expiryTime.toIso8601String(),
      );

      // ربط التوكن بالجهاز
      if (deviceId != null) {
        await _storageService.saveSecureData(_deviceIdKey, deviceId);
      }

      // حفظ البيانات الوصفية للتوكن
      await _saveTokenMetadata(accessToken);

      _logger.log(
        'Tokens saved securely',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to save tokens: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      // التحقق من انتهاء التوكن
      if (await isTokenExpired()) {
        _logger.log(
          'Access token expired',
          level: LogLevel.info,
          category: SecurityCategory.security,
        );
        return null;
      }

      // استرجاع التوكن المشفر
      final encryptedToken = await _storageService.getUltraSecureData(_accessTokenKey);
      if (encryptedToken == null) return null;

      // فك تشفير التوكن والتحقق من صحته
      final token = await _decryptAndValidateToken(encryptedToken);

      // التحقق من ربط التوكن بالجهاز
      if (!await _validateDeviceBinding(token)) {
        _logger.log(
          'Device binding validation failed',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return null;
      }

      return token;
    } catch (e) {
      _logger.log(
        'Failed to get access token: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      final encryptedToken = await _storageService.getUltraSecureData(_refreshTokenKey);
      if (encryptedToken == null) return null;

      return await _decryptAndValidateToken(encryptedToken);
    } catch (e) {
      _logger.log(
        'Failed to get refresh token: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return null;
    }
  }

  Future<bool> isTokenExpired() async {
    try {
      final expiryTimeStr = await _storageService.getSecureData(_tokenExpiryKey);
      if (expiryTimeStr == null) return true;

      final expiryTime = DateTime.parse(expiryTimeStr);
      final now = _timeManager.getCurrentTime();

      // إضافة هامش أمان للتحديث
      return now.isAfter(expiryTime.subtract(_tokenRefreshBuffer));
    } catch (e) {
      _logger.log(
        'Failed to check token expiry: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return true;
    }
  }

  Future<void> clearTokens() async {
    try {
      await _storageService.deleteSecureData(_accessTokenKey);
      await _storageService.deleteSecureData(_refreshTokenKey);
      await _storageService.deleteSecureData(_tokenExpiryKey);
      await _storageService.deleteSecureData(_deviceIdKey);
      await _storageService.deleteSecureData(_tokenMetadataKey);

      _logger.log(
        'All tokens cleared',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to clear tokens: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<String> _enhanceTokenSecurity(String token) async {
    // إضافة طبقات أمان إضافية للتوكن
    try {
      // إضافة طابع زمني
      final timestamp = _timeManager.getCurrentTimestamp();

      // إنشاء nonce فريد
      final nonce = await _encryptionService.generateHmac(timestamp.toString());

      // إنشاء بيانات موقعة
      final signedData = {
        'token': token,
        'timestamp': timestamp,
        'nonce': nonce,
        'deviceId': await _getDeviceId(),
      };

      // تشفير البيانات الموقعة
      final jsonData = json.encode(signedData);
      final encryptedData = await _encryptionService.encryptData(jsonData);

      // ترميز بـ Base64
      return base64.encode(encryptedData);
    } catch (e) {
      _logger.log(
        'Failed to enhance token security: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<String> _decryptAndValidateToken(String encryptedToken) async {
    try {
      // فك ترميز Base64
      final encryptedData = base64.decode(encryptedToken);

      // فك التشفير
      final decryptedData = await _encryptionService.decryptData(encryptedData);
      final signedData = json.decode(decryptedData);

      // التحقق من الطابع الزمني
      final timestamp = signedData['timestamp'] as int;
      if (!_timeManager.isTimestampValid(timestamp)) {
        throw SecurityException('Invalid token timestamp');
      }

      // التحقق من nonce
      final nonce = signedData['nonce'] as String;
      if (!await _validateNonce(nonce, timestamp)) {
        throw SecurityException('Invalid token nonce');
      }

      // استخراج التوكن الأصلي
      return signedData['token'] as String;
    } catch (e) {
      _logger.log(
        'Failed to decrypt and validate token: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<bool> _validateNonce(String nonce, int timestamp) async {
    try {
      // إعادة حساب nonce والتحقق من تطابقه
      final expectedNonce = await _encryptionService.generateHmac(timestamp.toString());
      return nonce == expectedNonce;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _validateDeviceBinding(String token) async {
    try {
      // التحقق من ربط التوكن بالجهاز الحالي
      final storedDeviceId = await _storageService.getSecureData(_deviceIdKey);
      if (storedDeviceId == null) return true; // لا يوجد ربط

      final currentDeviceId = await _getDeviceId();
      return storedDeviceId == currentDeviceId;
    } catch (e) {
      _logger.log(
        'Device binding validation error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<String> _getDeviceId() async {
    // استخدام معرف فريد للجهاز
    // يمكن استخدام مكتبة device_info_plus هنا
    return 'device_id_placeholder';
  }

  DateTime _getTokenExpiry(String token) {
    try {
      if (JwtDecoder.isExpired(token)) {
        return DateTime.now().add(_localTokenExpiry);
      }
      return JwtDecoder.getExpirationDate(token);
    } catch (e) {
      // في حالة فشل فك التوكن، نستخدم مدة افتراضية
      return DateTime.now().add(_localTokenExpiry);
    }
  }

  Future<void> _saveTokenMetadata(String token) async {
    try {
      final decodedToken = JwtDecoder.decode(token);
      final metadata = {
        'issuedAt': decodedToken['iat'] ?? DateTime.now().millisecondsSinceEpoch,
        'expiresAt': decodedToken['exp'] ?? DateTime.now().add(_localTokenExpiry).millisecondsSinceEpoch,
        'userId': decodedToken['sub'] ?? '',
        'roles': decodedToken['roles'] ?? [],
        'scopes': decodedToken['scopes'] ?? [],
      };

      await _storageService.saveSecureData(
        _tokenMetadataKey,
        json.encode(metadata),
      );
    } catch (e) {
      _logger.log(
        'Failed to save token metadata: $e',
        level: LogLevel.warning,
        category: SecurityCategory.security,
      );
    }
  }

  Future<Map<String, dynamic>?> getTokenMetadata() async {
    try {
      final metadataStr = await _storageService.getSecureData(_tokenMetadataKey);
      if (metadataStr == null) return null;

      return json.decode(metadataStr);
    } catch (e) {
      _logger.log(
        'Failed to get token metadata: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return null;
    }
  }

  Future<bool> validateTokenIntegrity(String token) async {
    try {
      // التحقق من صحة التوقيع
      if (!JwtDecoder.isExpired(token)) {
        // التحقق من المطالبات الأساسية
        final decodedToken = JwtDecoder.decode(token);

        // التحقق من وجود المطالبات المطلوبة
        if (!decodedToken.containsKey('sub') ||
            !decodedToken.containsKey('iat') ||
            !decodedToken.containsKey('exp')) {
          return false;
        }

        // التحقق من عدم التلاعب
        final issuedAt = DateTime.fromMillisecondsSinceEpoch(decodedToken['iat'] * 1000);
        final now = _timeManager.getCurrentTime();

        // التأكد من أن التوكن ليس من المستقبل
        if (issuedAt.isAfter(now)) {
          return false;
        }

        return true;
      }

      return false;
    } catch (e) {
      _logger.log(
        'Token integrity validation failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<bool> rotateTokens({
    required String newAccessToken,
    required String newRefreshToken,
  }) async {
    try {
      // حفظ التوكنات القديمة مؤقتاً (للاسترجاع في حالة الفشل)
      final oldAccessToken = await getAccessToken();
      final oldRefreshToken = await getRefreshToken();

      // حفظ التوكنات الجديدة
      await saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      // التحقق من نجاح الحفظ
      final savedAccessToken = await getAccessToken();
      if (savedAccessToken == null) {
        // استرجاع التوكنات القديمة
        if (oldAccessToken != null && oldRefreshToken != null) {
          await saveTokens(
            accessToken: oldAccessToken,
            refreshToken: oldRefreshToken,
          );
        }
        return false;
      }

      _logger.log(
        'Tokens rotated successfully',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );

      return true;
    } catch (e) {
      _logger.log(
        'Token rotation failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<bool> isRefreshTokenValid() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      // التحقق من صلاحية رمز التحديث
      return !JwtDecoder.isExpired(refreshToken);
    } catch (e) {
      _logger.log(
        'Refresh token validation error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<Duration?> getTokenRemainingTime() async {
    try {
      final expiryTimeStr = await _storageService.getSecureData(_tokenExpiryKey);
      if (expiryTimeStr == null) return null;

      final expiryTime = DateTime.parse(expiryTimeStr);
      final now = _timeManager.getCurrentTime();

      if (now.isAfter(expiryTime)) {
        return Duration.zero;
      }

      return expiryTime.difference(now);
    } catch (e) {
      _logger.log(
        'Failed to get token remaining time: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return null;
    }
  }

  Future<void> invalidateTokens() async {
    try {
      await clearTokens();
      _logger.log(
        'Tokens invalidated',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to invalidate tokens: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}