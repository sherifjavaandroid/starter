import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import '../utils/secure_logger.dart';

class ScreenshotPreventionService {
  final SecureLogger _logger;

  static const platform = MethodChannel('com.example.secure_app/screenshot_prevention');

  bool _isEnabled = false;

  ScreenshotPreventionService(this._logger);

  Future<void> enable() async {
    if (_isEnabled) return;

    try {
      if (Platform.isAndroid) {
        await _enableAndroid();
      } else if (Platform.isIOS) {
        await _enableiOS();
      }

      _isEnabled = true;

      _logger.log(
        'Screenshot prevention enabled',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to enable screenshot prevention: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> disable() async {
    if (!_isEnabled) return;

    try {
      if (Platform.isAndroid) {
        await _disableAndroid();
      } else if (Platform.isIOS) {
        await _disableiOS();
      }

      _isEnabled = false;

      _logger.log(
        'Screenshot prevention disabled',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to disable screenshot prevention: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _enableAndroid() async {
    try {
      // استخدام FLAG_SECURE لمنع لقطات الشاشة
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);

      // استدعاء الكود الأصلي للتحقق الإضافي
      await platform.invokeMethod('enableScreenshotPrevention');

      // إضافة حماية إضافية ضد تسجيل الشاشة
      await _enableScreenRecordingPrevention();

    } catch (e) {
      _logger.log(
        'Android screenshot prevention error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _disableAndroid() async {
    try {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      await platform.invokeMethod('disableScreenshotPrevention');
      await _disableScreenRecordingPrevention();
    } catch (e) {
      _logger.log(
        'Android screenshot prevention disable error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _enableiOS() async {
    try {
      // iOS لا يدعم منع لقطات الشاشة مباشرة
      // لكن يمكننا اكتشاف محاولات التقاط الشاشة
      await platform.invokeMethod('enableScreenshotPrevention');

      // إضافة مراقب لاكتشاف لقطات الشاشة
      await _setupScreenshotObserver();

      // تطبيق تشويش على المحتوى الحساس
      await _enableContentObfuscation();

    } catch (e) {
      _logger.log(
        'iOS screenshot prevention error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _disableiOS() async {
    try {
      await platform.invokeMethod('disableScreenshotPrevention');
      await _removeScreenshotObserver();
      await _disableContentObfuscation();
    } catch (e) {
      _logger.log(
        'iOS screenshot prevention disable error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _enableScreenRecordingPrevention() async {
    try {
      // منع تسجيل الشاشة على Android
      await platform.invokeMethod('enableScreenRecordingPrevention');

      // إضافة طبقة حماية إضافية
      await FlutterWindowManager.addFlags(
          FlutterWindowManager.FLAG_SECURE |
          FlutterWindowManager.FLAG_KEEP_SCREEN_ON
      );
    } catch (e) {
      _logger.log(
        'Screen recording prevention error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<void> _disableScreenRecordingPrevention() async {
    try {
      await platform.invokeMethod('disableScreenRecordingPrevention');
      await FlutterWindowManager.clearFlags(
          FlutterWindowManager.FLAG_KEEP_SCREEN_ON
      );
    } catch (e) {
      _logger.log(
        'Screen recording prevention disable error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<void> _setupScreenshotObserver() async {
    try {
      platform.setMethodCallHandler((call) async {
        if (call.method == 'onScreenshotDetected') {
          await _handleScreenshotDetected();
        }
      });

      await platform.invokeMethod('setupScreenshotObserver');
    } catch (e) {
      _logger.log(
        'Screenshot observer setup error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<void> _removeScreenshotObserver() async {
    try {
      await platform.invokeMethod('removeScreenshotObserver');
      platform.setMethodCallHandler(null);
    } catch (e) {
      _logger.log(
        'Screenshot observer removal error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<void> _handleScreenshotDetected() async {
    _logger.log(
      'Screenshot attempt detected',
      level: LogLevel.warning,
      category: SecurityCategory.security,
    );

    // يمكن إضافة إجراءات إضافية هنا مثل:
    // - مسح البيانات الحساسة من الشاشة
    // - تنبيه المستخدم
    // - تسجيل خروج المستخدم في حالة الكشف المتكرر
  }

  Future<void> _enableContentObfuscation() async {
    try {
      // تطبيق تشويش على المحتوى الحساس
      await platform.invokeMethod('enableContentObfuscation');
    } catch (e) {
      _logger.log(
        'Content obfuscation error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<void> _disableContentObfuscation() async {
    try {
      await platform.invokeMethod('disableContentObfuscation');
    } catch (e) {
      _logger.log(
        'Content obfuscation disable error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  bool get isEnabled => _isEnabled;

  // تفعيل حماية مؤقتة لصفحة محددة
  Future<void> enableForPage() async {
    if (!_isEnabled) {
      await enable();
    }
  }

  // تعطيل الحماية المؤقتة بعد مغادرة الصفحة
  Future<void> disableForPage() async {
    // يمكن إضافة منطق هنا للتحقق إذا كانت الصفحة تتطلب الحماية الدائمة
  }

  // التحقق من حالة الأمان عند دخول الخلفية
  Future<void> onAppLifecycleStateChanged(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // تعزيز الحماية عند دخول الخلفية
      if (_isEnabled && Platform.isAndroid) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      }
    } else if (state == AppLifecycleState.resumed) {
      // إعادة تطبيق الإعدادات عند العودة
      if (_isEnabled) {
        await enable();
      }
    }
  }

  // حماية محتوى محدد
  Future<void> protectContent(String contentId) async {
    try {
      await platform.invokeMethod('protectContent', {'contentId': contentId});
    } catch (e) {
      _logger.log(
        'Content protection error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  // إزالة الحماية عن محتوى محدد
  Future<void> unprotectContent(String contentId) async {
    try {
      await platform.invokeMethod('unprotectContent', {'contentId': contentId});
    } catch (e) {
      _logger.log(
        'Content unprotection error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  // تطبيق تشويش على النص الحساس
  Future<void> obfuscateSensitiveText(String textId) async {
    try {
      await platform.invokeMethod('obfuscateText', {'textId': textId});
    } catch (e) {
      _logger.log(
        'Text obfuscation error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  // إزالة التشويش عن النص
  Future<void> deobfuscateSensitiveText(String textId) async {
    try {
      await platform.invokeMethod('deobfuscateText', {'textId': textId});
    } catch (e) {
      _logger.log(
        'Text deobfuscation error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  // التحقق من محاولات الالتقاط المتكررة
  Future<bool> detectRepeatedScreenshotAttempts() async {
    try {
      return await platform.invokeMethod('detectRepeatedScreenshots');
    } catch (e) {
      _logger.log(
        'Screenshot attempt detection error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  // تطبيق حماية الواجهة الرسومية
  Future<void> enableUIProtection() async {
    try {
      await platform.invokeMethod('enableUIProtection');
    } catch (e) {
      _logger.log(
        'UI protection error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  // تعطيل حماية الواجهة الرسومية
  Future<void> disableUIProtection() async {
    try {
      await platform.invokeMethod('disableUIProtection');
    } catch (e) {
      _logger.log(
        'UI protection disable error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }
}