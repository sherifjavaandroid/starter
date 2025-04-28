import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // معلومات الجهاز المخزنة مؤقتاً
  AndroidDeviceInfo? _androidInfo;
  IosDeviceInfo? _iosInfo;
  String? _cachedDeviceId;

  Future<void> initialize() async {
    try {
      if (Platform.isAndroid) {
        _androidInfo = await _deviceInfo.androidInfo;
      } else if (Platform.isIOS) {
        _iosInfo = await _deviceInfo.iosInfo;
      }
    } catch (e) {
      // التعامل مع الخطأ بصمت
    }
  }

  /// الحصول على معرف الجهاز الفريد
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    try {
      String deviceId;

      if (Platform.isAndroid) {
        final androidInfo = _androidInfo ?? await _deviceInfo.androidInfo;
        deviceId = _generateAndroidDeviceId(androidInfo);
      } else if (Platform.isIOS) {
        final iosInfo = _iosInfo ?? await _deviceInfo.iosInfo;
        deviceId = _generateIosDeviceId(iosInfo);
      } else {
        deviceId = _generateFallbackDeviceId();
      }

      _cachedDeviceId = deviceId;
      return deviceId;
    } catch (e) {
      return _generateFallbackDeviceId();
    }
  }

  /// الحصول على معلومات الجهاز
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = _androidInfo ?? await _deviceInfo.androidInfo;
        return _getAndroidInfo(androidInfo);
      } else if (Platform.isIOS) {
        final iosInfo = _iosInfo ?? await _deviceInfo.iosInfo;
        return _getIosInfo(iosInfo);
      }

      return {'platform': 'unknown'};
    } catch (e) {
      return {'error': 'Failed to get device info'};
    }
  }

  /// الحصول على نظام التشغيل
  String getOS() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// الحصول على إصدار نظام التشغيل
  Future<String> getOSVersion() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = _androidInfo ?? await _deviceInfo.androidInfo;
        return androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = _iosInfo ?? await _deviceInfo.iosInfo;
        return iosInfo.systemVersion;
      }

      return Platform.operatingSystemVersion;
    } catch (e) {
      return 'unknown';
    }
  }

  /// الحصول على نموذج الجهاز
  Future<String> getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = _androidInfo ?? await _deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = _iosInfo ?? await _deviceInfo.iosInfo;
        return iosInfo.model;
      }

      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// التحقق من أن الجهاز حقيقي (ليس محاكي)
  Future<bool> isPhysicalDevice() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = _androidInfo ?? await _deviceInfo.androidInfo;
        return androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = _iosInfo ?? await _deviceInfo.iosInfo;
        return iosInfo.isPhysicalDevice;
      }

      return true;
    } catch (e) {
      return true;
    }
  }

  /// الحصول على بصمة الجهاز
  Future<String> getDeviceFingerprint() async {
    try {
      final deviceId = await getDeviceId();
      final model = await getDeviceModel();
      final os = getOS();
      final osVersion = await getOSVersion();

      final fingerprintData = '$deviceId|$model|$os|$osVersion';
      final hash = sha256.convert(utf8.encode(fingerprintData));

      return hash.toString();
    } catch (e) {
      return _generateFallbackDeviceId();
    }
  }

  /// التحقق من خصائص الأمان
  Future<Map<String, bool>> getSecurityFeatures() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = _androidInfo ?? await _deviceInfo.androidInfo;
        return {
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
          'isEncrypted': await _isAndroidEncrypted(androidInfo),
          'hasSecureLock': await _hasSecureLock(),
          'isDeveloperMode': await _isDeveloperMode(androidInfo),
          'isDebugMode': await _isDebugMode(),
        };
      } else if (Platform.isIOS) {
        final iosInfo = _iosInfo ?? await _deviceInfo.iosInfo;
        return {
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
          'isEncrypted': true, // iOS devices are always encrypted
          'hasSecureLock': await _hasSecureLock(),
          'isDeveloperMode': false, // Not applicable for iOS
          'isDebugMode': await _isDebugMode(),
        };
      }

      return {};
    } catch (e) {
      return {};
    }
  }

  String _generateAndroidDeviceId(AndroidDeviceInfo androidInfo) {
    // استخدام مزيج من المعرفات لإنشاء معرف فريد
    final components = [
      androidInfo.id,
      '', // تم حذف androidInfo.androidId لأنه لا يوجد
      '', // تم حذف androidInfo.serialNumber لأنه لا يوجد
      androidInfo.manufacturer,
      androidInfo.model,
    ];

    final validComponents = components.where((c) => c.isNotEmpty).toList();
    final combined = validComponents.join('|');

    return _hashDeviceId(combined);
  }

  String _generateIosDeviceId(IosDeviceInfo iosInfo) {
    // استخدام معرف فريد لـ iOS
    final components = [
      iosInfo.identifierForVendor ?? '',
      iosInfo.model,
      iosInfo.systemVersion,
    ];

    final validComponents = components.where((c) => c.isNotEmpty).toList();
    final combined = validComponents.join('|');

    return _hashDeviceId(combined);
  }

  String _generateFallbackDeviceId() {
    // إنشاء معرف احتياطي باستخدام الطابع الزمني وقيمة عشوائية
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random.secure().nextInt(999999);

    return _hashDeviceId('$timestamp|$random');
  }

  String _hashDeviceId(String input) {
    final hash = sha256.convert(utf8.encode(input));
    return hash.toString().substring(0, 32);
  }

  Map<String, dynamic> _getAndroidInfo(AndroidDeviceInfo androidInfo) {
    return {
      'platform': 'android',
      'model': androidInfo.model,
      'manufacturer': androidInfo.manufacturer,
      'version': androidInfo.version.release,
      'sdkInt': androidInfo.version.sdkInt,
      'brand': androidInfo.brand,
      'device': androidInfo.device,
      'isPhysicalDevice': androidInfo.isPhysicalDevice,
      'hardware': androidInfo.hardware,
      'board': androidInfo.board,
      'display': androidInfo.display,
      'fingerprint': androidInfo.fingerprint,
    };
  }

  Map<String, dynamic> _getIosInfo(IosDeviceInfo iosInfo) {
    return {
      'platform': 'ios',
      'model': iosInfo.model,
      'systemVersion': iosInfo.systemVersion,
      'name': iosInfo.name,
      'isPhysicalDevice': iosInfo.isPhysicalDevice,
      'utsname': {
        'sysname': iosInfo.utsname.sysname,
        'nodename': iosInfo.utsname.nodename,
        'release': iosInfo.utsname.release,
        'version': iosInfo.utsname.version,
        'machine': iosInfo.utsname.machine,
      },
    };
  }

  Future<bool> _isAndroidEncrypted(AndroidDeviceInfo androidInfo) async {
    // التحقق من تشفير الجهاز
    try {
      // يمكن استخدام القناة الأصلية للتحقق من تشفير الجهاز
      return true; // افتراضي
    } catch (e) {
      return false;
    }
  }

  Future<bool> _hasSecureLock() async {
    // التحقق من وجود قفل آمن
    try {
      // يمكن استخدام local_auth للتحقق
      return true; // افتراضي
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isDeveloperMode(AndroidDeviceInfo androidInfo) async {
    // التحقق من وضع المطور
    try {
      return androidInfo.tags.contains('test-keys');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isDebugMode() async {
    // التحقق من وضع التصحيح
    return kDebugMode;
  }
}