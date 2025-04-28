import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/secure_logger.dart';
import '../utils/environment_checker.dart';

class RootDetectionService {
  final SecureLogger _logger;
  final EnvironmentChecker _environmentChecker;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static const platform = MethodChannel('com.example.secure_app/root_detection');

  // قائمة التطبيقات المشبوهة على Android
  static const List<String> _suspiciousApps = [
    'com.noshufou.android.su',
    'com.noshufou.android.su.elite',
    'eu.chainfire.supersu',
    'com.koushikdutta.superuser',
    'com.thirdparty.superuser',
    'com.yellowes.su',
    'com.topjohnwu.magisk',
    'com.kingroot.kinguser',
    'com.kingo.root',
    'com.smedialink.oneclickroot',
    'com.zhiqupk.root.global',
    'com.alephzain.framaroot',
  ];

  // قائمة الملفات المشبوهة على Android
  static const List<String> _suspiciousFiles = [
    '/system/app/Superuser.apk',
    '/sbin/su',
    '/system/bin/su',
    '/system/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su',
    '/su/bin/su',
    '/system/xbin/daemonsu',
    '/system/etc/init.d/99SuperSUDaemon',
    '/system/bin/.ext/.su',
    '/system/usr/we-need-root/su-backup',
    '/system/xbin/mu',
    '/magisk/.core/bin/su',
  ];

  // قائمة المسارات المشبوهة على iOS
  static const List<String> _cydiaPaths = [
    '/Applications/Cydia.app',
    '/Library/MobileSubstrate/MobileSubstrate.dylib',
    '/bin/bash',
    '/usr/sbin/sshd',
    '/etc/apt',
    '/private/var/lib/apt/',
    '/private/var/lib/cydia',
    '/private/var/mobile/Library/SBSettings/Themes',
    '/private/var/stash',
    '/private/var/tmp/cydia.log',
    '/usr/libexec/cydia',
    '/usr/bin/sshd',
    '/usr/sbin/sshd',
    '/Applications/RockApp.app',
    '/Applications/Icy.app',
    '/Applications/WinterBoard.app',
    '/Applications/SBSettings.app',
    '/Applications/MxTube.app',
    '/Applications/IntelliScreen.app',
    '/Applications/FakeCarrier.app',
    '/Applications/blackra1n.app',
  ];

  RootDetectionService(this._logger, this._environmentChecker);

  Future<bool> isDeviceRooted() async {
    try {
      if (Platform.isAndroid) {
        return await _checkAndroidRoot();
      } else if (Platform.isIOS) {
        return await _checkiOSJailbreak();
      }

      return false;
    } catch (e) {
      _logger.log(
        'Root detection error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      // في حالة حدوث خطأ، نعتبر الجهاز مشبوهاً
      return true;
    }
  }

  Future<bool> _checkAndroidRoot() async {
    try {
      // استخدام مكتبة flutter_jailbreak_detection
      bool isJailbroken = await FlutterJailbreakDetection.jailbroken;
      bool isDeveloperMode = await FlutterJailbreakDetection.developerMode;

      if (isJailbroken || isDeveloperMode) {
        _logger.log(
          'Android root detected: jailbroken=$isJailbroken, developerMode=$isDeveloperMode',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      // فحص إضافي باستخدام القناة الأصلية
      bool nativeRootCheck = await _performNativeRootCheck();
      if (nativeRootCheck) {
        _logger.log(
          'Android root detected via native check',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      // فحص التطبيقات المشبوهة
      if (await _checkSuspiciousApps()) {
        _logger.log(
          'Suspicious root apps detected',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      // فحص الملفات المشبوهة
      if (await _checkSuspiciousFiles()) {
        _logger.log(
          'Suspicious root files detected',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      // فحص الخصائص المشبوهة
      if (await _checkSuspiciousProperties()) {
        _logger.log(
          'Suspicious system properties detected',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      // فحص أوامر su
      if (await _checkSuCommand()) {
        _logger.log(
          'Su command available - device is rooted',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      // فحص SELinux
      if (await _checkSELinuxEnforcement()) {
        _logger.log(
          'SELinux not enforcing - possible root',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      // فحص بيئة التنفيذ
      if (await _checkExecutionEnvironment()) {
        _logger.log(
          'Suspicious execution environment detected',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      return false;
    } catch (e) {
      _logger.log(
        'Android root check error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return true;
    }
  }

  Future<bool> _checkiOSJailbreak() async {
    try {
      // استخدام مكتبة flutter_jailbreak_detection
      bool isJailbroken = await FlutterJailbreakDetection.jailbroken;

      if (isJailbroken) {
        _logger.log(
          'iOS jailbreak detected via library',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      // فحص إضافي باستخدام القناة الأصلية
      bool nativeJailbreakCheck = await _performNativeJailbreakCheck();
      if (nativeJailbreakCheck) {
        _logger.log(
          'iOS jailbreak detected via native check',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      // فحص مسارات Cydia
      if (await _checkCydiaPaths()) {
        _logger.log(
          'Cydia paths detected - device is jailbroken',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      // فحص الكتابة خارج sandbox
      if (await _checkWriteOutsideSandbox()) {
        _logger.log(
          'Write outside sandbox possible - device is jailbroken',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      // فحص fork
      if (await _checkForkAbility()) {
        _logger.log(
          'Fork ability detected - device is jailbroken',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      // فحص المخططات المشبوهة
      if (await _checkSuspiciousSchemes()) {
        _logger.log(
          'Suspicious URL schemes detected - device is jailbroken',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
        return true;
      }

      return false;
    } catch (e) {
      _logger.log(
        'iOS jailbreak check error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return true;
    }
  }

  Future<bool> _performNativeRootCheck() async {
    try {
      final bool result = await platform.invokeMethod('checkRoot');
      return result;
    } on PlatformException catch (e) {
      _logger.log(
        'Native root check error: ${e.message}',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return true;
    }
  }

  Future<bool> _performNativeJailbreakCheck() async {
    try {
      final bool result = await platform.invokeMethod('checkJailbreak');
      return result;
    } on PlatformException catch (e) {
      _logger.log(
        'Native jailbreak check error: ${e.message}',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return true;
    }
  }

  Future<bool> _checkSuspiciousApps() async {
    for (var app in _suspiciousApps) {
      if (await _isAppInstalled(app)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _isAppInstalled(String packageName) async {
    try {
      return await platform.invokeMethod('isAppInstalled', packageName);
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkSuspiciousFiles() async {
    for (var path in _suspiciousFiles) {
      if (await _fileExists(path)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _fileExists(String path) async {
    try {
      final file = File(path);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkSuspiciousProperties() async {
    try {
      return await platform.invokeMethod('checkSuspiciousProperties');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkSuCommand() async {
    try {
      return await platform.invokeMethod('checkSuCommand');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkSELinuxEnforcement() async {
    try {
      return await platform.invokeMethod('checkSELinuxEnforcement');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkExecutionEnvironment() async {
    try {
      // التحقق من المحاكي
      if (await _environmentChecker.isEmulator()) {
        return true;
      }

      // التحقق من أدوات التطوير
      if (await _environmentChecker.isDevelopmentEnvironment()) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkCydiaPaths() async {
    for (var path in _cydiaPaths) {
      if (await _fileExists(path)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _checkWriteOutsideSandbox() async {
    try {
      return await platform.invokeMethod('checkWriteOutsideSandbox');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkForkAbility() async {
    try {
      return await platform.invokeMethod('checkForkAbility');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkSuspiciousSchemes() async {
    try {
      return await platform.invokeMethod('checkSuspiciousSchemes');
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getDeviceSecurityInfo() async {
    try {
      final baseInfo = await _deviceInfo.deviceInfo;

      return {
        'isRooted': await isDeviceRooted(),
        'developerMode': await FlutterJailbreakDetection.developerMode,
        'deviceInfo': baseInfo.toMap(),
        'isEmulator': await _environmentChecker.isEmulator(),
        'isDebuggable': await _environmentChecker.isDebuggable(),
        'hasDebugger': await _environmentChecker.hasDebuggerAttached(),
        'isTampered': await _environmentChecker.isAppTampered(),
      };
    } catch (e) {
      _logger.log(
        'Failed to get device security info: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return {};
    }
  }
}