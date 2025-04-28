import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'secure_logger.dart';

class EnvironmentChecker {
  final SecureLogger _logger;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  EnvironmentChecker(this._logger);

  Future<bool> isSecureEnvironment() async {
    try {
      // التحقق من بيئة التطوير
      if (kDebugMode) {
        _logger.log(
          'Running in debug mode',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من المحاكي
      if (await isEmulator()) {
        _logger.log(
          'Running on emulator/simulator',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من بيئة التطوير
      if (await isDevelopmentEnvironment()) {
        _logger.log(
          'Development environment detected',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من أدوات التصحيح
      if (await hasDebuggerAttached()) {
        _logger.log(
          'Debugger attached',
          level: LogLevel.critical,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من التلاعب
      if (await isAppTampered()) {
        _logger.log(
          'App tampering detected',
          level: LogLevel.critical,
          category: SecurityCategory.security,
        );
        return false;
      }

      return true;
    } catch (e) {
      _logger.log(
        'Environment check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<bool> isEmulator() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;

        // قائمة النماذج المشبوهة
        final emulatorModels = [
          'sdk_gphone',
          'emulator',
          'Android SDK built for x86',
          'Emulator',
          'Android Emulator',
          'goldfish',
        ];

        // قائمة الشركات المصنعة المشبوهة
        final emulatorManufacturers = [
          'Genymotion',
          'unknown',
          'Google',
        ];

        // قائمة العلامات التجارية المشبوهة
        final emulatorBrands = [
          'generic',
          'generic_x86',
          'generic_x86_64',
          'Android',
        ];

        // قائمة الأجهزة المشبوهة
        final emulatorDevices = [
          'generic',
          'generic_x86',
          'vbox86',
          'goldfish',
        ];

        // قائمة المنتجات المشبوهة
        final emulatorProducts = [
          'sdk',
          'google_sdk',
          'sdk_x86',
          'vbox86p',
          'emulator',
        ];

        // قائمة الأجهزة المشبوهة
        final emulatorHardware = [
          'goldfish',
          'ranchu',
          'vbox86',
        ];

        // التحقق من الخصائص
        if (emulatorModels.any((model) => androidInfo.model.toLowerCase().contains(model.toLowerCase())) ||
            emulatorManufacturers.any((manufacturer) => androidInfo.manufacturer.toLowerCase().contains(manufacturer.toLowerCase())) ||
            emulatorBrands.any((brand) => androidInfo.brand.toLowerCase().contains(brand.toLowerCase())) ||
            emulatorDevices.any((device) => androidInfo.device.toLowerCase().contains(device.toLowerCase())) ||
            emulatorProducts.any((product) => androidInfo.product.toLowerCase().contains(product.toLowerCase())) ||
            emulatorHardware.any((hardware) => androidInfo.hardware.toLowerCase().contains(hardware.toLowerCase()))) {
          return true;
        }

        // التحقق من الخصائص الإضافية
        if (androidInfo.isPhysicalDevice == false) {
          return true;
        }

        // التحقق من البصمة
        final fingerprint = androidInfo.fingerprint.toLowerCase();
        if (fingerprint.contains('generic') ||
            fingerprint.contains('unknown') ||
            fingerprint.contains('emulator') ||
            fingerprint.contains('test-keys')) {
          return true;
        }

        // التحقق من بعض الملفات
        final emulatorFiles = [
          '/system/bin/qemu-props',
          '/dev/socket/qemud',
          '/dev/qemu_pipe',
          '/system/lib/libc_malloc_debug_qemu.so',
          '/sys/qemu_trace',
          '/system/bin/qemud',
        ];

        for (var file in emulatorFiles) {
          if (await File(file).exists()) {
            return true;
          }
        }

      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;

        // التحقق من المحاكي
        if (!iosInfo.isPhysicalDevice) {
          return true;
        }

        // التحقق من الاسم
        if (iosInfo.name.toLowerCase().contains('simulator')) {
          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.log(
        'Emulator check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<bool> isDevelopmentEnvironment() async {
    try {
      // التحقق من وضع التصحيح
      if (kDebugMode) {
        return true;
      }

      // التحقق من المتغيرات البيئية
      final devEnvironmentVars = [
        'FLUTTER_TEST',
        'FLUTTER_TOOL',
        'FLUTTER_DEBUG',
        'DART_VM_OPTIONS',
      ];

      for (var envVar in devEnvironmentVars) {
        if (Platform.environment.containsKey(envVar)) {
          return true;
        }
      }

      // التحقق من وجود ملفات التطوير
      final devFiles = [
        'pubspec.yaml',
        'analysis_options.yaml',
        '.packages',
        '.dart_tool',
      ];

      for (var file in devFiles) {
        if (await File(file).exists() || await Directory(file).exists()) {
          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.log(
        'Development environment check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<bool> hasDebuggerAttached() async {
    // استخدام assert للتحقق من وجود debugger
    bool debuggerAttached = false;
    assert(() {
      debuggerAttached = true;
      return true;
    }());

    return debuggerAttached;
  }

  Future<bool> isAppTampered() async {
    try {
      // التحقق من سلامة التطبيق
      // هذا يتم عادة من خلال التحقق من التوقيع وhash الملفات
      // يتم تنفيذه بشكل أفضل في الكود الأصلي

      // التحقق من التعديلات في الذاكرة
      if (await _checkMemoryIntegrity()) {
        return true;
      }

      // التحقق من hooks
      if (await _checkForHooks()) {
        return true;
      }

      return false;
    } catch (e) {
      _logger.log(
        'Tampering check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return true; // افتراض التلاعب في حالة الفشل
    }
  }

  Future<bool> _checkMemoryIntegrity() async {
    // التحقق من سلامة الذاكرة
    // يتم تنفيذه عادة باستخدام قناة platform
    return false;
  }

  Future<bool> _checkForHooks() async {
    // التحقق من وجود hooks
    // يتم تنفيذه عادة باستخدام قناة platform
    return false;
  }

  Future<bool> isDebuggable() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;

        // التحقق من إعدادات التصحيح
        return androidInfo.tags.contains('test-keys');
      } else if (Platform.isIOS) {
        // iOS لا يوفر معلومات مباشرة عن التصحيح
        // نستخدم طرق أخرى للتحقق
        return kDebugMode;
      }

      return kDebugMode;
    } catch (e) {
      _logger.log(
        'Debuggable check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> getEnvironmentInfo() async {
    try {
      final baseInfo = await _deviceInfo.deviceInfo;

      return {
        'isEmulator': await isEmulator(),
        'isDevelopment': await isDevelopmentEnvironment(),
        'isDebuggable': await isDebuggable(),
        'hasDebugger': await hasDebuggerAttached(),
        'isTampered': await isAppTampered(),
        'platform': Platform.operatingSystem,
        'platformVersion': Platform.operatingSystemVersion,
        'deviceInfo': baseInfo.toMap(),
        'isSecure': await isSecureEnvironment(),
      };
    } catch (e) {
      _logger.log(
        'Failed to get environment info: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return {};
    }
  }
}