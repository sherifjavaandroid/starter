import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../security/security_manager.dart';
import '../security/encryption_service.dart';
import '../security/ssl_pinning_service.dart';
import '../security/root_detection_service.dart';
import '../security/screenshot_prevention_service.dart';
import '../security/secure_storage_service.dart';
import '../security/token_manager.dart';
import '../security/anti_tampering_service.dart';
import '../security/rate_limiter_service.dart';
import '../security/obfuscation_service.dart';
import '../security/nonce_generator_service.dart';
import '../security/package_validation_service.dart';
import '../network/certificate_pinning/certificate_manager.dart';
import '../network/certificate_pinning/public_key_store.dart';
import '../utils/secure_logger.dart' as logger_util;
import '../utils/integrity_checker.dart';
import '../utils/device_info_service.dart';
import '../utils/environment_checker.dart';
import '../utils/time_manager.dart';
import '../utils/key_generator_service.dart';
import '../utils/session_manager.dart';

class SecurityModule {
  static final GetIt sl = GetIt.instance;

  static Future<void> configureSecurityInjection() async {
    // تهيئة خدمات الأمان الأساسية
    await _registerSecurityServices();

    // تهيئة خدمات الشبكة الآمنة
    await _registerNetworkSecurity();

    // تهيئة خدمات التخزين الآمن
    await _registerSecureStorage();

    // تهيئة خدمات التشفير
    await _registerCryptographyServices();

    // تهيئة خدمات الحماية
    await _registerProtectionServices();

    // تهيئة خدمات التحقق
    await _registerValidationServices();

    // تهيئة خدمات المراقبة
    await _registerMonitoringServices();
  }

  static Future<void> _registerSecurityServices() async {
    // تسجيل السجل الآمن
    sl.registerLazySingleton(() => logger_util.SecureLogger());

    // تسجيل خدمة معلومات الجهاز
    sl.registerLazySingleton(() => DeviceInfoService());

    // تسجيل مدقق البيئة
    sl.registerLazySingleton(() => EnvironmentChecker(sl()));

    // تسجيل مدير الوقت
    sl.registerLazySingleton(() => TimeManager());

    // تسجيل فاحص السلامة
    sl.registerLazySingleton(() => IntegrityChecker(sl()));
  }

  static Future<void> _registerNetworkSecurity() async {
    // تسجيل مدير الشهادات
    sl.registerLazySingleton(() => CertificateManager(sl(), sl()));

    // تسجيل مخزن المفاتيح العامة
    sl.registerLazySingleton(() => PublicKeyStore(sl(), sl()));

    // تسجيل خدمة تثبيت SSL
    sl.registerLazySingleton(() => SSLPinningService(sl(), sl()));
  }

  static Future<void> _registerSecureStorage() async {
    // تسجيل التخزين الآمن
    sl.registerLazySingleton(() => const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
        storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        accountName: 'com.example.secure_app',
        synchronizable: false,
      ),
    ));

    // تسجيل خدمة التخزين الآمن
    sl.registerLazySingleton(() => SecureStorageService(sl()));
  }

  static Future<void> _registerCryptographyServices() async {
    // تسجيل خدمة توليد المفاتيح
    sl.registerLazySingleton(() => KeyGeneratorService());

    // تسجيل خدمة التشفير
    sl.registerLazySingleton(() => EncryptionService(sl(), sl()));

    // تسجيل خدمة التعتيم
    sl.registerLazySingleton(() => ObfuscationService(sl()));

    // تسجيل مولد nonce
    sl.registerLazySingleton(() => NonceGeneratorService());
  }

  static Future<void> _registerProtectionServices() async {
    // تسجيل خدمة منع لقطات الشاشة
    sl.registerLazySingleton(() => ScreenshotPreventionService(sl()));

    // تسجيل خدمة الكشف عن الجذر
    sl.registerLazySingleton(() => RootDetectionService(sl(), sl()));

    // تسجيل خدمة مكافحة التلاعب
    sl.registerLazySingleton(() => AntiTamperingService(sl(), sl(), sl()));

    // تسجيل خدمة تحديد المعدل
    sl.registerLazySingleton(() => RateLimiterService(sl(), sl(), sl()));
  }

  static Future<void> _registerValidationServices() async {
    // تسجيل خدمة التحقق من الحزم
    sl.registerLazySingleton(() => PackageValidationService(sl()));

    // تسجيل مدير الرموز
    sl.registerLazySingleton(() => TokenManager(sl(), sl(), sl(), sl()));

    // تسجيل مدير الجلسات
    sl.registerLazySingleton(() => SessionManager(sl(), sl(), sl(), sl(), sl()));
  }

  static Future<void> _registerMonitoringServices() async {
    // تسجيل مدير الأمان
    sl.registerLazySingleton(() => SecurityManager(
      sl(), // EncryptionService
      sl(), // SSLPinningService
      sl(), // RootDetectionService
      sl(), // ScreenshotPreventionService
      sl(), // SecureStorageService
      sl(), // TokenManager
      sl(), // AntiTamperingService
      sl(), // RateLimiterService
      sl(), // ObfuscationService
      sl(), // NonceGeneratorService
      sl(), // SecureLogger
      sl(), // IntegrityChecker
      sl(), // TimeManager
    ));
  }

  static Future<void> initializeSecurityServices() async {
    // تهيئة جميع الخدمات
    final logger = sl<logger_util.SecureLogger>();

    try {
      // تهيئة التخزين الآمن
      final secureStorage = sl<SecureStorageService>();
      await secureStorage.initialize();

      // تهيئة خدمة التشفير
      final encryption = sl<EncryptionService>();
      await encryption.initialize();

      // تهيئة توليد المفاتيح
      final keyGenerator = sl<KeyGeneratorService>();
      await keyGenerator.initialize();

      // تهيئة SSL Pinning
      final sslPinning = sl<SSLPinningService>();
      await sslPinning.initialize();

      // تهيئة خدمة مكافحة التلاعب
      final antiTampering = sl<AntiTamperingService>();
      await antiTampering.initialize();

      // تهيئة معدل التحديد
      final rateLimiter = sl<RateLimiterService>();
      await rateLimiter.initialize();

      // تهيئة فاحص السلامة
      final integrityChecker = sl<IntegrityChecker>();
      await integrityChecker.initialize();

      // تهيئة مدير الوقت
      final timeManager = sl<TimeManager>();
      await timeManager.initialize();

      // تهيئة مدير الأمان
      final securityManager = sl<SecurityManager>();
      await securityManager.initialize();

      logger.log(
        'All security services initialized successfully',
        level: logger_util.LogLevel.info,
        category: logger_util.SecurityCategory.initialization,
      );
    } catch (e) {
      logger.log(
        'Security services initialization failed: $e',
        level: logger_util.LogLevel.critical,
        category: logger_util.SecurityCategory.initialization,
      );
      rethrow;
    }
  }

  static Future<void> performSecurityHealthCheck() async {
    final logger = sl<logger_util.SecureLogger>();
    final securityManager = sl<SecurityManager>();
    final integrityChecker = sl<IntegrityChecker>();

    try {
      // فحص الأمان العام
      await securityManager.performSecurityCheck();

      // فحص سلامة التطبيق
      final isIntegrityValid = await integrityChecker.performFullIntegrityCheck();
      if (!isIntegrityValid) {
        throw SecurityException('App integrity check failed');
      }

      logger.log(
        'Security health check completed successfully',
        level: logger_util.LogLevel.info,
        category: logger_util.SecurityCategory.security,
      );
    } catch (e) {
      logger.log(
        'Security health check failed: $e',
        level: logger_util.LogLevel.critical,
        category: logger_util.SecurityCategory.security,
      );
      rethrow;
    }
  }

  static Future<void> disposeSecurityServices() async {
    final logger = sl<logger_util.SecureLogger>();

    try {
      // تنظيف الخدمات
      await sl<SecurityManager>().dispose();
      await sl<ScreenshotPreventionService>().disable();
      sl<IntegrityChecker>().dispose();
      sl<TimeManager>().dispose();

      logger.log(
        'Security services disposed successfully',
        level: logger_util.LogLevel.info,
        category: logger_util.SecurityCategory.security,
      );
    } catch (e) {
      logger.log(
        'Security services disposal failed: $e',
        level: logger_util.LogLevel.error,
        category: logger_util.SecurityCategory.security,
      );
      rethrow;
    }
  }

  // إعدادات الأمان للبيئات المختلفة
  static SecurityConfig getSecurityConfig(Environment environment) {
    switch (environment) {
      case Environment.production:
        return SecurityConfig(
          enableRootDetection: true,
          enableSSLPinning: true,
          enableAntiTampering: true,
          enableScreenshotPrevention: true,
          enableSecureLogging: true,
          enableIntegrityChecks: true,
          debuggingAllowed: false,
        );
      case Environment.staging:
        return SecurityConfig(
          enableRootDetection: true,
          enableSSLPinning: true,
          enableAntiTampering: true,
          enableScreenshotPrevention: true,
          enableSecureLogging: true,
          enableIntegrityChecks: true,
          debuggingAllowed: false,
        );
      case Environment.development:
        return SecurityConfig(
          enableRootDetection: false,
          enableSSLPinning: false,
          enableAntiTampering: false,
          enableScreenshotPrevention: false,
          enableSecureLogging: true,
          enableIntegrityChecks: false,
          debuggingAllowed: true,
        );
    }
  }
}

class SecurityConfig {
  final bool enableRootDetection;
  final bool enableSSLPinning;
  final bool enableAntiTampering;
  final bool enableScreenshotPrevention;
  final bool enableSecureLogging;
  final bool enableIntegrityChecks;
  final bool debuggingAllowed;

  SecurityConfig({
    required this.enableRootDetection,
    required this.enableSSLPinning,
    required this.enableAntiTampering,
    required this.enableScreenshotPrevention,
    required this.enableSecureLogging,
    required this.enableIntegrityChecks,
    required this.debuggingAllowed,
  });
}

enum Environment {
  production,
  staging,
  development,
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}