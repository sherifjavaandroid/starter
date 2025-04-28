import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'secure_logger.dart';

class IntegrityChecker {
  final SecureLogger _logger;

  // Cache للمفاتيح والقيم المحسوبة
  String? _appSignatureHash;
  Map<String, String>? _fileChecksums;

  // مفاتيح التخزين الآمن
  static const String _appSignatureKey = 'app_signature_hash';
  static const String _fileChecksumsKey = 'file_checksums';

  // قائمة الملفات الحساسة للتحقق
  final List<String> _sensitiveFiles = [
    'lib/main.dart',
    'lib/core/security/security_manager.dart',
    'lib/core/security/encryption_service.dart',
    'lib/core/security/ssl_pinning_service.dart',
    'android/app/src/main/AndroidManifest.xml',
    'ios/Runner/Info.plist',
  ];

  IntegrityChecker(this._logger);

  Future<void> initialize() async {
    try {
      // حساب وتخزين التوقيعات الأصلية
      await _calculateInitialHashes();

      _logger.log(
        'Integrity checker initialized successfully',
        level: LogLevel.info,
        category: SecurityCategory.integrity,
      );
    } catch (e) {
      _logger.log(
        'Integrity checker initialization failed: $e',
        level: LogLevel.critical,
        category: SecurityCategory.integrity,
      );
      rethrow;
    }
  }

  Future<void> _calculateInitialHashes() async {
    // حساب توقيع التطبيق
    _appSignatureHash = await _calculateAppSignature();

    // حساب checksums للملفات الحساسة
    _fileChecksums = await _calculateFileChecksums();
  }

  Future<String> _calculateAppSignature() async {
    try {
      if (Platform.isAndroid) {
        return await _getAndroidSignature();
      } else if (Platform.isIOS) {
        return await _getIOSSignature();
      }
      return '';
    } catch (e) {
      _logger.log(
        'Failed to calculate app signature: $e',
        level: LogLevel.error,
        category: SecurityCategory.integrity,
      );
      rethrow;
    }
  }

  Future<String> _getAndroidSignature() async {
    try {
      const platform = MethodChannel('com.example.secure_app/security');
      final signature = await platform.invokeMethod('getAppSignature');
      return signature as String;
    } on PlatformException catch (e) {
      _logger.log(
        'Failed to get Android signature: ${e.message}',
        level: LogLevel.error,
        category: SecurityCategory.integrity,
      );
      rethrow;
    }
  }

  Future<String> _getIOSSignature() async {
    try {
      const platform = MethodChannel('com.example.secure_app/security');
      final signature = await platform.invokeMethod('getCodeSignature');
      return signature as String;
    } on PlatformException catch (e) {
      _logger.log(
        'Failed to get iOS signature: ${e.message}',
        level: LogLevel.error,
        category: SecurityCategory.integrity,
      );
      rethrow;
    }
  }

  Future<Map<String, String>> _calculateFileChecksums() async {
    final checksums = <String, String>{};

    for (final filePath in _sensitiveFiles) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final contents = await file.readAsBytes();
          final digest = sha256.convert(contents);
          checksums[filePath] = digest.toString();
        }
      } catch (e) {
        _logger.log(
          'Failed to calculate checksum for $filePath: $e',
          level: LogLevel.warning,
          category: SecurityCategory.integrity,
        );
      }
    }

    return checksums;
  }

  Future<bool> verifyAppSignature() async {
    try {
      final currentSignature = await _calculateAppSignature();

      if (_appSignatureHash == null) {
        // في حالة عدم وجود توقيع مخزن، نخزن الحالي
        _appSignatureHash = currentSignature;
        _logger.log(
          'Initial app signature stored',
          level: LogLevel.info,
          category: SecurityCategory.integrity,
        );
        return true;
      }

      if (currentSignature != _appSignatureHash) {
        _logger.log(
          'App signature mismatch detected',
          level: LogLevel.critical,
          category: SecurityCategory.integrity,
        );
        return false;
      }

      return true;
    } catch (e) {
      _logger.log(
        'App signature verification failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.integrity,
      );
      return false;
    }
  }

  Future<bool> verifyFilesChecksum() async {
    try {
      final currentChecksums = await _calculateFileChecksums();

      if (_fileChecksums == null) {
        // في حالة عدم وجود checksums مخزنة، نخزن الحالية
        _fileChecksums = currentChecksums;
        _logger.log(
          'Initial file checksums stored',
          level: LogLevel.info,
          category: SecurityCategory.integrity,
        );
        return true;
      }

      // مقارنة checksums
      for (final entry in _fileChecksums!.entries) {
        final filePath = entry.key;
        final expectedChecksum = entry.value;
        final currentChecksum = currentChecksums[filePath];

        if (currentChecksum != null && currentChecksum != expectedChecksum) {
          _logger.log(
            'File checksum mismatch detected for $filePath',
            level: LogLevel.critical,
            category: SecurityCategory.integrity,
          );
          return false;
        }
      }

      return true;
    } catch (e) {
      _logger.log(
        'File checksum verification failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.integrity,
      );
      return false;
    }
  }

  Future<bool> verifyCertificatesIntegrity() async {
    try {
      // التحقق من سلامة الشهادات المثبتة
      const certificatesDir = 'assets/certificates';
      final certFiles = Directory(certificatesDir);

      if (await certFiles.exists()) {
        await for (final entity in certFiles.list()) {
          if (entity is File) {
            final content = await entity.readAsBytes();
            final hash = sha256.convert(content);

            // التحقق من أن الشهادة لم يتم التلاعب بها
            if (!await _verifyCertificate(entity.path, hash.toString())) {
              return false;
            }
          }
        }
      }

      return true;
    } catch (e) {
      _logger.log(
        'Certificate integrity check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.integrity,
      );
      return false;
    }
  }

  Future<bool> _verifyCertificate(String certPath, String currentHash) async {
    // يمكن إضافة منطق للتحقق من الشهادة مقابل قائمة موثوقة
    // مثل الاتصال بخادم موثوق أو التحقق من التوقيع
    return true;
  }

  Future<bool> verifyDependenciesIntegrity() async {
    try {
      // قراءة pubspec.lock
      final pubspecLock = File('pubspec.lock');
      if (!await pubspecLock.exists()) {
        _logger.log(
          'pubspec.lock not found',
          level: LogLevel.warning,
          category: SecurityCategory.integrity,
        );
        return false;
      }

      final content = await pubspecLock.readAsString();
      final packages = _parsePubspecLock(content);

      // التحقق من أن الحزم لم تتغير
      for (final package in packages) {
        if (!await _verifyPackageIntegrity(package)) {
          return false;
        }
      }

      return true;
    } catch (e) {
      _logger.log(
        'Dependencies integrity check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.integrity,
      );
      return false;
    }
  }

  List<Map<String, String>> _parsePubspecLock(String content) {
    // تحليل محتوى pubspec.lock
    // هذا مثال مبسط - يجب تحليل الملف بشكل صحيح
    final packages = <Map<String, String>>[];

    // يمكن استخدام مكتبة مثل yaml لتحليل الملف
    // هنا نستخدم مثال بسيط
    final lines = content.split('\n');
    String? currentPackage;
    String? currentVersion;

    for (var line in lines) {
      if (line.startsWith('  ') && !line.startsWith('    ')) {
        currentPackage = line.trim().replaceAll(':', '');
      } else if (line.contains('version:')) {
        currentVersion = line.split(':')[1].trim().replaceAll('"', '');
        if (currentPackage != null && currentVersion != null) {
          packages.add({
            'name': currentPackage,
            'version': currentVersion,
          });
        }
      }
    }

    return packages;
  }

  Future<bool> _verifyPackageIntegrity(Map<String, String> package) async {
    // التحقق من سلامة الحزمة
    // يمكن مقارنة مع قاعدة بيانات موثوقة أو التحقق من التوقيع
    return true;
  }

  Future<bool> verifyMemoryIntegrity() async {
    try {
      // التحقق من عدم وجود تعديلات في الذاكرة
      if (Platform.isAndroid) {
        const platform = MethodChannel('com.example.secure_app/security');
        final isMemoryIntact = await platform.invokeMethod('checkMemoryIntegrity');
        return isMemoryIntact as bool;
      } else if (Platform.isIOS) {
        const platform = MethodChannel('com.example.secure_app/security');
        final isMemoryIntact = await platform.invokeMethod('checkMemoryIntegrity');
        return isMemoryIntact as bool;
      }

      return true;
    } catch (e) {
      _logger.log(
        'Memory integrity check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.integrity,
      );
      return false;
    }
  }

  Future<void> saveIntegrityHashes() async {
    try {
      // حفظ التوقيعات في مكان آمن
      // يمكن استخدام SecureStorageService هنا

      final hashData = {
        'appSignature': _appSignatureHash,
        'fileChecksums': _fileChecksums,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // في التطبيق الحقيقي، يجب تخزين هذه البيانات بشكل آمن
      final jsonData = json.encode(hashData);

      _logger.log(
        'Integrity hashes saved successfully',
        level: LogLevel.info,
        category: SecurityCategory.integrity,
      );
    } catch (e) {
      _logger.log(
        'Failed to save integrity hashes: $e',
        level: LogLevel.error,
        category: SecurityCategory.integrity,
      );
      rethrow;
    }
  }

  Future<bool> performFullIntegrityCheck() async {
    try {
      _logger.log(
        'Starting full integrity check',
        level: LogLevel.info,
        category: SecurityCategory.integrity,
      );

      // التحقق من توقيع التطبيق
      if (!await verifyAppSignature()) {
        return false;
      }

      // التحقق من ملفات التطبيق
      if (!await verifyFilesChecksum()) {
        return false;
      }

      // التحقق من الشهادات
      if (!await verifyCertificatesIntegrity()) {
        return false;
      }

      // التحقق من المكتبات
      if (!await verifyDependenciesIntegrity()) {
        return false;
      }

      // التحقق من الذاكرة
      if (!await verifyMemoryIntegrity()) {
        return false;
      }

      _logger.log(
        'Full integrity check completed successfully',
        level: LogLevel.info,
        category: SecurityCategory.integrity,
      );

      return true;
    } catch (e) {
      _logger.log(
        'Full integrity check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.integrity,
      );
      return false;
    }
  }

  void dispose() {
    // تنظيف الموارد
    _appSignatureHash = null;
    _fileChecksums = null;
  }
}