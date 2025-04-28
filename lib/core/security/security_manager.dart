import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'encryption_service.dart';
import 'ssl_pinning_service.dart';
import 'root_detection_service.dart';
import 'screenshot_prevention_service.dart';
import 'secure_storage_service.dart';
import 'token_manager.dart';
import 'anti_tampering_service.dart';
import 'rate_limiter_service.dart';
import 'obfuscation_service.dart';
import 'nonce_generator_service.dart';
import '../utils/secure_logger.dart' hide SecurityCategory;
import '../utils/secure_logger.dart' as logger_util;
import '../utils/integrity_checker.dart';
import '../utils/time_manager.dart';

// تعريف SecurityCategory محلياً لتجنب التعارض
enum SecurityCategory {
  initialization,
  security,
  session,
  encryption,
  decryption,
  integrity,
  inputValidation,
  pathValidation,
  rateLimiting,
}

class SecurityManager {
  final EncryptionService _encryptionService;
  final SSLPinningService _sslPinningService;
  final RootDetectionService _rootDetectionService;
  final ScreenshotPreventionService _screenshotPreventionService;
  final SecureStorageService _secureStorageService;
  final TokenManager _tokenManager;
  final AntiTamperingService _antiTamperingService;
  final RateLimiterService _rateLimiterService;
  final ObfuscationService _obfuscationService;
  final NonceGeneratorService _nonceGeneratorService;
  final logger_util.SecureLogger _secureLogger;
  final IntegrityChecker _integrityChecker;
  final TimeManager _timeManager;

  Timer? _sessionTimeoutTimer;
  Timer? _securityCheckTimer;
  DateTime? _lastActivityTime;

  // المفتاح الثابت المخزن في التطبيق (32 حرف)
  static const String _localKeyPart = 'A7F3K9L2M8P5Q1R6T4U9V2W8X3Y7Z5B1';

  // مدة انتهاء الجلسة (15 دقيقة)
  static const Duration _sessionTimeout = Duration(minutes: 15);

  // فترة التحقق الأمني الدوري (5 دقائق)
  static const Duration _securityCheckInterval = Duration(minutes: 5);

  SecurityManager(
      this._encryptionService,
      this._sslPinningService,
      this._rootDetectionService,
      this._screenshotPreventionService,
      this._secureStorageService,
      this._tokenManager,
      this._antiTamperingService,
      this._rateLimiterService,
      this._obfuscationService,
      this._nonceGeneratorService,
      this._secureLogger,
      this._integrityChecker,
      this._timeManager,
      );

  Future<void> initialize() async {
    try {
      // تهيئة جميع الخدمات الأمنية
      await Future.wait([
        _encryptionService.initialize(),
        _sslPinningService.initialize(),
        _screenshotPreventionService.enable(),
        _antiTamperingService.initialize(),
        _rateLimiterService.initialize(),
        _obfuscationService.initialize(),
        _integrityChecker.initialize(),
      ]);

      // بدء الفحص الأمني الدوري
      _startSecurityChecks();

      // بدء مراقبة الجلسة
      _startSessionMonitoring();

      // تسجيل التهيئة الناجحة
      await _secureLogger.log(
        'Security Manager initialized successfully',
        level: logger_util.LogLevel.info,
        category: logger_util.SecurityCategory.initialization,
      );
    } catch (e) {
      await _secureLogger.log(
        'Security Manager initialization failed: $e',
        level: logger_util.LogLevel.critical,
        category: logger_util.SecurityCategory.initialization,
      );
      rethrow;
    }
  }

  Future<String> generateSecureKey(String backendKeyPart) async {
    // دمج المفتاح من الباك إند مع المفتاح المحلي
    final combinedKey = backendKeyPart + _localKeyPart;

    // إنشاء مفتاح مشتق باستخدام PBKDF2
    final salt = await _nonceGeneratorService.generateNonce();
    final derivedKey = await _encryptionService.deriveKey(
      combinedKey,
      salt,
      iterations: 100000,
    );

    // تخزين الملح في التخزين الآمن
    await _secureStorageService.saveSecureData(
      'key_salt',
      base64.encode(salt),
    );

    return base64.encode(derivedKey);
  }

  Future<bool> validateRequest({
    required String path,
    required Map<String, dynamic> params,
    required String method,
  }) async {
    // التحقق من معدل الطلبات
    if (!await _rateLimiterService.checkRateLimit(path, method)) {
      await _secureLogger.log(
        'Rate limit exceeded for $method $path',
        level: logger_util.LogLevel.warning,
        category: logger_util.SecurityCategory.rateLimiting,
      );
      return false;
    }

    // التحقق من صحة المسار (حماية من LFI)
    if (!_validatePath(path)) {
      await _secureLogger.log(
        'Invalid path detected: $path',
        level: logger_util.LogLevel.warning,
        category: logger_util.SecurityCategory.pathValidation,
      );
      return false;
    }

    // التحقق من المعاملات (حماية من Mass Assignment)
    if (!_validateParams(params)) {
      await _secureLogger.log(
        'Invalid parameters detected',
        level: logger_util.LogLevel.warning,
        category: logger_util.SecurityCategory.inputValidation,
      );
      return false;
    }

    return true;
  }

  bool _validatePath(String path) {
    // منع المسارات التي تحتوي على أحرف خاصة
    final RegExp pathRegex = RegExp(r'^[a-zA-Z0-9/_-]+$');
    if (!pathRegex.hasMatch(path)) {
      return false;
    }

    // منع التنقل بين المجلدات
    if (path.contains('..') || path.contains('//')) {
      return false;
    }

    // منع الوصول للملفات الحساسة
    final List<String> restrictedPaths = [
      '/etc/',
      '/proc/',
      '/sys/',
      '/dev/',
      '/root/',
      '.env',
      'password',
      'secret',
      'config',
    ];

    for (var restricted in restrictedPaths) {
      if (path.toLowerCase().contains(restricted)) {
        return false;
      }
    }

    return true;
  }

  bool _validateParams(Map<String, dynamic> params) {
    // التحقق من عدم وجود حقول غير مسموح بها
    final List<String> forbiddenKeys = [
      'id',
      'role',
      'admin',
      'isAdmin',
      'privilege',
      'permission',
      '__proto__',
      'constructor',
      'prototype',
    ];

    bool containsDeep(Map<String, dynamic> map, List<String> forbidden) {
      for (var key in map.keys) {
        if (forbidden.contains(key.toLowerCase())) {
          return true;
        }

        var value = map[key];
        if (value is Map<String, dynamic>) {
          if (containsDeep(value, forbidden)) {
            return true;
          }
        }
      }
      return false;
    }

    return !containsDeep(params, forbiddenKeys);
  }

  void updateLastActivity() {
    _lastActivityTime = DateTime.now();
  }

  Future<void> performSecurityCheck() async {
    try {
      // التحقق من الجذر/الجيلبريك
      if (await _rootDetectionService.isDeviceRooted()) {
        await _handleSecurityViolation('Root/Jailbreak detected');
        return;
      }

      // التحقق من سلامة التطبيق
      if (!await _antiTamperingService.isAppIntegrityValid()) {
        await _handleSecurityViolation('App integrity compromised');
        return;
      }

      // التحقق من بيئة التشغيل
      if (!await _antiTamperingService.isEnvironmentSafe()) {
        await _handleSecurityViolation('Unsafe environment detected');
        return;
      }

      // التحقق من التصحيح
      if (await _antiTamperingService.isDebuggingEnabled()) {
        await _handleSecurityViolation('Debugging detected');
        return;
      }

      // التحقق من حقن الكود
      if (await _antiTamperingService.detectCodeInjection()) {
        await _handleSecurityViolation('Code injection detected');
        return;
      }

      // التحقق من سلامة الشهادات
      if (!await _sslPinningService.validateCertificates()) {
        await _handleSecurityViolation('SSL certificate validation failed');
        return;
      }

      // التحقق من الوقت الحالي
      if (!await _timeManager.isTimeValid()) {
        await _handleSecurityViolation('Time manipulation detected');
        return;
      }

    } catch (e) {
      await _secureLogger.log(
        'Security check failed: $e',
        level: logger_util.LogLevel.error,
        category: logger_util.SecurityCategory.security,
      );
    }
  }

  void _startSecurityChecks() {
    _securityCheckTimer = Timer.periodic(_securityCheckInterval, (_) {
      performSecurityCheck();
    });
  }

  void _startSessionMonitoring() {
    _lastActivityTime = DateTime.now();
    _sessionTimeoutTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_lastActivityTime != null) {
        final elapsed = DateTime.now().difference(_lastActivityTime!);
        if (elapsed > _sessionTimeout) {
          _handleSessionTimeout();
        }
      }
    });
  }

  Future<void> _handleSessionTimeout() async {
    try {
      await _secureLogger.log(
        'Session timeout occurred',
        level: logger_util.LogLevel.info,
        category: logger_util.SecurityCategory.session,
      );

      // مسح الرموز والبيانات الحساسة
      await _tokenManager.clearTokens();
      await _secureStorageService.clearAll();

      // إيقاف جميع المؤقتات
      _sessionTimeoutTimer?.cancel();
      _securityCheckTimer?.cancel();

      // إبلاغ التطبيق بانتهاء الجلسة
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    } catch (e) {
      await _secureLogger.log(
        'Session timeout handling failed: $e',
        level: logger_util.LogLevel.error,
        category: logger_util.SecurityCategory.session,
      );
    }
  }

  Future<void> _handleSecurityViolation(String reason) async {
    try {
      await _secureLogger.log(
        'Security violation detected: $reason',
        level: logger_util.LogLevel.critical,
        category: logger_util.SecurityCategory.security,
      );

      // مسح جميع البيانات الحساسة
      await _tokenManager.clearTokens();
      await _secureStorageService.clearAll();

      // إيقاف جميع المؤقتات
      _sessionTimeoutTimer?.cancel();
      _securityCheckTimer?.cancel();

      // إغلاق التطبيق بطريقة آمنة
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    } catch (e) {
      await _secureLogger.log(
        'Security violation handling failed: $e',
        level: logger_util.LogLevel.critical,
        category: logger_util.SecurityCategory.security,
      );
    }
  }

  Future<Map<String, String>> prepareSecureRequest(Map<String, dynamic> data) async {
    try {
      // إنشاء nonce جديد لكل طلب
      final nonce = await _nonceGeneratorService.generateNonce();

      // تشفير البيانات
      final jsonString = json.encode(data);
      final encryptedData = await _encryptionService.encryptData(
        jsonString,
        nonce: nonce,
      );

      // تشفير بـ Base64
      final base64Data = base64.encode(encryptedData);

      // إضافة توقيع للتحقق من سلامة البيانات
      final signature = await _encryptionService.generateHmac(base64Data);

      // إضافة الطابع الزمني
      final timestamp = _timeManager.getCurrentTimestamp();

      return {
        'data': base64Data,
        'nonce': base64.encode(nonce),
        'signature': signature,
        'timestamp': timestamp.toString(),
      };
    } catch (e) {
      await _secureLogger.log(
        'Failed to prepare secure request: $e',
        level: logger_util.LogLevel.error,
        category: logger_util.SecurityCategory.encryption,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> processSecureResponse(Map<String, String> response) async {
    try {
      // التحقق من الطابع الزمني
      final timestamp = int.parse(response['timestamp'] ?? '0');
      if (!_timeManager.isTimestampValid(timestamp)) {
        throw SecurityException('Invalid timestamp');
      }

      // التحقق من التوقيع
      final signature = response['signature'] ?? '';
      final data = response['data'] ?? '';

      if (!await _encryptionService.verifyHmac(data, signature)) {
        throw SecurityException('Invalid signature');
      }

      // فك التشفير
      final encryptedData = base64.decode(data);
      final nonce = base64.decode(response['nonce'] ?? '');

      final decryptedData = await _encryptionService.decryptData(
        encryptedData,
        nonce: nonce,
      );

      // تحويل من JSON
      return json.decode(decryptedData);
    } catch (e) {
      await _secureLogger.log(
        'Failed to process secure response: $e',
        level: logger_util.LogLevel.error,
        category: logger_util.SecurityCategory.decryption,
      );
      rethrow;
    }
  }

  Future<void> performAppIntegrityCheck() async {
    try {
      // التحقق من توقيع التطبيق
      if (!await _integrityChecker.verifyAppSignature()) {
        await _handleSecurityViolation('App signature validation failed');
        return;
      }

      // التحقق من checksum للملفات المهمة
      if (!await _integrityChecker.verifyFilesChecksum()) {
        await _handleSecurityViolation('File integrity check failed');
        return;
      }

      // التحقق من سلامة الشهادات
      if (!await _integrityChecker.verifyCertificatesIntegrity()) {
        await _handleSecurityViolation('Certificate integrity check failed');
        return;
      }

    } catch (e) {
      await _secureLogger.log(
        'App integrity check failed: $e',
        level: logger_util.LogLevel.critical,
        category: logger_util.SecurityCategory.integrity,
      );
      await _handleSecurityViolation('App integrity check exception');
    }
  }

  Future<void> dispose() async {
    _sessionTimeoutTimer?.cancel();
    _securityCheckTimer?.cancel();
    await _screenshotPreventionService.disable();
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}