import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import '../utils/secure_logger.dart';
import '../utils/environment_checker.dart';
import 'secure_storage_service.dart';

class AntiTamperingService {
  final SecureStorageService _storageService;
  final EnvironmentChecker _environmentChecker;
  final SecureLogger _logger;

  static const platform = MethodChannel('com.example.secure_app/anti_tampering');

  // مفاتيح التخزين
  static const String _appHashKey = 'app_integrity_hash';
  static const String _packageNameKey = 'expected_package_name';
  static const String _certificateHashKey = 'certificate_hash';
  static const String _lastCheckTimeKey = 'last_integrity_check';

  // فترة إعادة التحقق (6 ساعات)
  static const Duration _recheckInterval = Duration(hours: 6);

  // قائمة المكتبات الخطرة للاكتشاف
  static const List<String> _dangerousLibraries = [
    'frida',
    'xposed',
    'substrate',
    'substrate_hook',
    'cycript',
    'javahook',
    'hook',
    'roots',
  ];

  AntiTamperingService(
      this._storageService,
      this._environmentChecker,
      this._logger,
      );

  Future<void> initialize() async {
    try {
      // تخزين معلومات التطبيق الأصلية
      await _storeOriginalAppInfo();

      // بدء الفحص الدوري
      await _startPeriodicChecks();

      _logger.log(
        'Anti-tampering service initialized',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Anti-tampering initialization failed: $e',
        level: LogLevel.critical,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _storeOriginalAppInfo() async {
    try {
      // حفظ توقيع التطبيق الأصلي
      final appHash = await _calculateAppHash();
      await _storageService.saveSecureData(_appHashKey, appHash);

      // حفظ اسم الحزمة الأصلي
      final packageName = await _getPackageName();
      await _storageService.saveSecureData(_packageNameKey, packageName);

      // حفظ توقيع الشهادة
      final certificateHash = await _getCertificateHash();
      await _storageService.saveSecureData(_certificateHashKey, certificateHash);
    } catch (e) {
      _logger.log(
        'Failed to store original app info: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<bool> isAppIntegrityValid() async {
    try {
      // التحقق من توقيع التطبيق
      if (!await _verifyAppSignature()) {
        _logger.log(
          'App signature verification failed',
          level: LogLevel.critical,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من اسم الحزمة
      if (!await _verifyPackageName()) {
        _logger.log(
          'Package name verification failed',
          level: LogLevel.critical,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من الشهادة
      if (!await _verifyCertificate()) {
        _logger.log(
          'Certificate verification failed',
          level: LogLevel.critical,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من وجود مكتبات خطيرة
      if (await _detectDangerousLibraries()) {
        _logger.log(
          'Dangerous libraries detected',
          level: LogLevel.critical,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من سلامة الكود
      if (await _detectCodeModification()) {
        _logger.log(
          'Code modification detected',
          level: LogLevel.critical,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من وجود أدوات الهندسة العكسية
      if (await _detectReverseEngineeringTools()) {
        _logger.log(
          'Reverse engineering tools detected',
          level: LogLevel.critical,
          category: SecurityCategory.security,
        );
        return false;
      }

      return true;
    } catch (e) {
      _logger.log(
        'App integrity check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<bool> isEnvironmentSafe() async {
    try {
      // التحقق من بيئة التنفيذ
      if (await _environmentChecker.isEmulator()) {
        _logger.log(
          'Emulator detected',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من التصحيح
      if (await _environmentChecker.hasDebuggerAttached()) {
        _logger.log(
          'Debugger detected',
          level: LogLevel.critical,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من وضع المطور
      if (await _environmentChecker.isDevelopmentEnvironment()) {
        _logger.log(
          'Development environment detected',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من وجود VPN
      if (await _detectVPN()) {
        _logger.log(
          'VPN connection detected',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        // يمكن السماح بـ VPN مع تسجيل تحذير
      }

      // التحقق من وجود أدوات اختراق
      if (await _detectHackingTools()) {
        _logger.log(
          'Hacking tools detected',
          level: LogLevel.critical,
          category: SecurityCategory.security,
        );
        return false;
      }

      return true;
    } catch (e) {
      _logger.log(
        'Environment safety check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<bool> isDebuggingEnabled() async {
    try {
      // فحص متعدد الطبقات للتصحيح

      // 1. التحقق من قيمة kDebugMode
      if (Platform.isAndroid || Platform.isIOS) {
        final bool isDebugging = await platform.invokeMethod('isDebugging');
        if (isDebugging) return true;
      }

      // 2. التحقق من وجود debugger مرفق
      if (await _environmentChecker.hasDebuggerAttached()) {
        return true;
      }

      // 3. التحقق من منافذ التصحيح
      if (await _checkDebugPorts()) {
        return true;
      }

      // 4. التحقق من خصائص النظام المتعلقة بالتصحيح
      if (await _checkDebugSystemProperties()) {
        return true;
      }

      return false;
    } catch (e) {
      _logger.log(
        'Debugging check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return true; // افتراض الأسوأ في حالة الفشل
    }
  }

  Future<bool> detectCodeInjection() async {
    try {
      // 1. التحقق من تعديل الذاكرة
      if (await _detectMemoryModification()) {
        return true;
      }

      // 2. التحقق من hooks
      if (await _detectHooks()) {
        return true;
      }

      // 3. التحقق من التلاعب بالمكتبات
      if (await _detectLibraryTampering()) {
        return true;
      }

      // 4. التحقق من تعديل الكود أثناء التشغيل
      if (await _detectRuntimeCodeModification()) {
        return true;
      }

      return false;
    } catch (e) {
      _logger.log(
        'Code injection detection failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return true;
    }
  }

  Future<bool> detectFrameworkHooking() async {
    try {
      // كشف أطر العمل المستخدمة في الالتفاف على الأمان
      final frameworks = [
        'Xposed',
        'Frida',
        'Cydia Substrate',
        'Lucky Patcher',
        'GameGuardian',
      ];

      for (var framework in frameworks) {
        if (await _isFrameworkActive(framework)) {
          _logger.log(
            'Framework hooking detected: $framework',
            level: LogLevel.critical,
            category: SecurityCategory.security,
          );
          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.log(
        'Framework hooking detection failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return true;
    }
  }

  Future<String> _calculateAppHash() async {
    try {
      // حساب hash للتطبيق
      return await platform.invokeMethod('calculateAppHash');
    } catch (e) {
      _logger.log(
        'Failed to calculate app hash: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return '';
    }
  }

  Future<String> _getPackageName() async {
    try {
      return await platform.invokeMethod('getPackageName');
    } catch (e) {
      _logger.log(
        'Failed to get package name: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return '';
    }
  }

  Future<String> _getCertificateHash() async {
    try {
      return await platform.invokeMethod('getCertificateHash');
    } catch (e) {
      _logger.log(
        'Failed to get certificate hash: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return '';
    }
  }

  Future<bool> _verifyAppSignature() async {
    try {
      final currentHash = await _calculateAppHash();
      final originalHash = await _storageService.getSecureData(_appHashKey);

      return currentHash == originalHash;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _verifyPackageName() async {
    try {
      final currentPackage = await _getPackageName();
      final originalPackage = await _storageService.getSecureData(_packageNameKey);

      return currentPackage == originalPackage;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _verifyCertificate() async {
    try {
      final currentCertHash = await _getCertificateHash();
      final originalCertHash = await _storageService.getSecureData(_certificateHashKey);

      return currentCertHash == originalCertHash;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _detectDangerousLibraries() async {
    try {
      return await platform.invokeMethod('detectDangerousLibraries', _dangerousLibraries);
    } catch (e) {
      return false;
    }
  }

  Future<bool> _detectCodeModification() async {
    try {
      return await platform.invokeMethod('detectCodeModification');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _detectReverseEngineeringTools() async {
    try {
      return await platform.invokeMethod('detectReverseEngineeringTools');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _detectVPN() async {
    try {
      return await platform.invokeMethod('detectVPN');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _detectHackingTools() async {
    try {
      return await platform.invokeMethod('detectHackingTools');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkDebugPorts() async {
    try {
      return await platform.invokeMethod('checkDebugPorts');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkDebugSystemProperties() async {
    try {
      return await platform.invokeMethod('checkDebugSystemProperties');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _detectMemoryModification() async {
    try {
      return await platform.invokeMethod('detectMemoryModification');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _detectHooks() async {
    try {
      return await platform.invokeMethod('detectHooks');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _detectLibraryTampering() async {
    try {
      return await platform.invokeMethod('detectLibraryTampering');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _detectRuntimeCodeModification() async {
    try {
      return await platform.invokeMethod('detectRuntimeCodeModification');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isFrameworkActive(String framework) async {
    try {
      return await platform.invokeMethod('isFrameworkActive', framework);
    } catch (e) {
      return false;
    }
  }

  Future<void> _startPeriodicChecks() async {
    // جدولة الفحص الدوري
    Future.delayed(_recheckInterval, () async {
      await _performIntegrityCheck();
      await _startPeriodicChecks(); // إعادة الجدولة
    });
  }

  Future<void> _performIntegrityCheck() async {
    try {
      final isValid = await isAppIntegrityValid();
      if (!isValid) {
        _logger.log(
          'Integrity check failed - possible tampering detected',
          level: LogLevel.critical,
          category: SecurityCategory.security,
        );
        // يمكن اتخاذ إجراءات هنا مثل إغلاق التطبيق
      }

      // تحديث وقت آخر فحص
      await _storageService.saveSecureData(
        _lastCheckTimeKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      _logger.log(
        'Periodic integrity check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }
}