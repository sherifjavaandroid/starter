import 'dart:io';
import 'package:path/path.dart' as path;

class FilePathValidator {
  // قائمة المسارات المحظورة
  static const List<String> _forbiddenPaths = [
    '/etc',
    '/proc',
    '/sys',
    '/dev',
    '/root',
    '/boot',
    '/bin',
    '/sbin',
    '/usr/bin',
    '/usr/sbin',
    '/var/log',
    '/tmp',
  ];

  // قائمة الامتدادات المسموح بها
  static const List<String> _allowedExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp',
    'pdf', 'doc', 'docx', 'txt', 'csv',
    'json', 'xml', 'yaml', 'yml',
  ];

  // قائمة الامتدادات الخطرة
  static const List<String> _dangerousExtensions = [
    'exe', 'bat', 'cmd', 'sh', 'bash',
    'ps1', 'vbs', 'js', 'jar', 'msi',
    'dll', 'so', 'dylib', 'bin', 'com',
    'app', 'apk', 'ipa', 'deb', 'rpm',
  ];

  /// التحقق من صحة المسار
  static bool isValidPath(String filePath) {
    if (filePath.isEmpty) return false;

    // التحقق من التنقل بين المجلدات
    if (filePath.contains('..')) return false;

    // التحقق من الأحرف غير المسموح بها
    if (!_isValidCharacters(filePath)) return false;

    // التحقق من المسارات المحظورة
    if (_isForbiddenPath(filePath)) return false;

    // التحقق من الامتداد
    if (_hasExecutableExtension(filePath)) return false;

    return true;
  }

  /// التحقق من صحة اسم الملف
  static bool isValidFileName(String fileName) {
    if (fileName.isEmpty || fileName.length > 255) return false;

    // التحقق من الأحرف غير المسموح بها
    if (fileName.contains(RegExp(r'[<>:"/\\|?*]'))) return false;

    // التحقق من النقاط في البداية
    if (fileName.startsWith('.')) return false;

    // التحقق من الأسماء المحجوزة
    if (_isReservedFileName(fileName)) return false;

    return true;
  }

  /// التحقق من امتداد الملف
  static bool isAllowedExtension(String filePath) {
    final extension = path.extension(filePath).toLowerCase().replaceAll('.', '');
    return _allowedExtensions.contains(extension);
  }

  /// التحقق من المسار الآمن
  static Future<String?> getSafePath(String requestedPath) async {
    try {
      // الحصول على المسار المطلق
      final absolutePath = path.absolute(requestedPath);

      // التحقق من صحة المسار
      if (!isValidPath(absolutePath)) {
        return null;
      }

      // التحقق من وجود المسار داخل مجلد التطبيق
      final appDir = Directory.current.path;
      if (!absolutePath.startsWith(appDir)) {
        return null;
      }

      // التحقق من أذونات الوصول
      final file = File(absolutePath);
      if (await file.exists()) {
        try {
          await file.length(); // محاولة الوصول للملف
        } catch (e) {
          return null; // لا يمكن الوصول
        }
      }

      return absolutePath;
    } catch (e) {
      return null;
    }
  }

  /// تنظيف المسار
  static String sanitizePath(String filePath) {
    // إزالة الأحرف الخطرة
    String sanitized = filePath.replaceAll(RegExp(r'[<>:"|?*]'), '');

    // إزالة التنقل بين المجلدات
    sanitized = sanitized.replaceAll('..', '');

    // تحويل الشرطات المائلة
    sanitized = sanitized.replaceAll('\\', '/');

    // إزالة المسافات الزائدة
    sanitized = sanitized.trim();

    // إزالة المسارات المتكررة
    sanitized = sanitized.replaceAll(RegExp(r'/+'), '/');

    return sanitized;
  }

  /// التحقق من حجم الملف
  static Future<bool> isValidFileSize(String filePath, {int maxSizeInBytes = 10 * 1024 * 1024}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final size = await file.length();
      return size <= maxSizeInBytes;
    } catch (e) {
      return false;
    }
  }

  /// التحقق من نوع الملف
  static Future<bool> isValidFileType(String filePath, List<String> allowedTypes) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      // التحقق من الامتداد
      final extension = path.extension(filePath).toLowerCase().replaceAll('.', '');
      if (!allowedTypes.contains(extension)) return false;

      // يمكن إضافة التحقق من MIME type هنا

      return true;
    } catch (e) {
      return false;
    }
  }

  /// التحقق من المسار النسبي
  static String? getRelativePath(String basePath, String targetPath) {
    try {
      // التحقق من صحة المسارات
      if (!isValidPath(basePath) || !isValidPath(targetPath)) {
        return null;
      }

      // الحصول على المسارات المطلقة
      final baseAbsolute = path.absolute(basePath);
      final targetAbsolute = path.absolute(targetPath);

      // التحقق من أن المسار الهدف داخل المسار الأساسي
      if (!targetAbsolute.startsWith(baseAbsolute)) {
        return null;
      }

      // الحصول على المسار النسبي
      return path.relative(targetAbsolute, from: baseAbsolute);
    } catch (e) {
      return null;
    }
  }

  static bool _isValidCharacters(String filePath) {
    // السماح فقط بالأحرف والأرقام والرموز الآمنة
    return RegExp(r'^[a-zA-Z0-9/_.-]+$').hasMatch(filePath);
  }

  static bool _isForbiddenPath(String filePath) {
    final lowerPath = filePath.toLowerCase();
    return _forbiddenPaths.any((forbidden) => lowerPath.startsWith(forbidden));
  }

  static bool _hasExecutableExtension(String filePath) {
    final extension = path.extension(filePath).toLowerCase().replaceAll('.', '');
    return _dangerousExtensions.contains(extension);
  }

  static bool _isReservedFileName(String fileName) {
    // أسماء محجوزة في Windows
    const reservedNames = [
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
    ];

    final baseName = path.basenameWithoutExtension(fileName).toUpperCase();
    return reservedNames.contains(baseName);
  }
}