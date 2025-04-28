import 'dart:convert';

class InputSanitizer {
  // تنظيف المدخلات العامة
  static String sanitizeInput(String input) {
    if (input.isEmpty) return input;

    // إزالة المسافات الزائدة
    String sanitized = input.trim();

    // إزالة الأحرف الخاصة الخطرة
    sanitized = sanitized
        .replaceAll(RegExp(r'[<>{}\\\'";\[\]]'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // إزالة أحرف التحكم
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), ''); // إزالة الأحرف غير المرئية

        // إزالة SQL injection patterns
        sanitized = sanitized
        .replaceAll(RegExp(r'(--)|(;)|(/\*)'), '')
        .replaceAll(RegExp(r'(union\s+select)|(select\s+\*)|(drop\s+table)', caseSensitive: false), '')
        .replaceAll(RegExp(r'(insert\s+into)|(delete\s+from)|(update\s+\w+\s+set)', caseSensitive: false), '');

    // إزالة XSS patterns
    sanitized = sanitized
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'vbscript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'data:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');

    // تحويل HTML entities
    sanitized = _escapeHtml(sanitized);

    return sanitized;
  }

  // تنظيف البريد الإلكتروني
  static String sanitizeEmail(String email) {
    if (email.isEmpty) return email;

    // تحويل إلى حروف صغيرة
    String sanitized = email.toLowerCase().trim();

    // إزالة الأحرف غير المسموح بها
    sanitized = sanitized.replaceAll(RegExp(r'[^a-z0-9@._+-]'), '');

    // التحقق من الصيغة الأساسية
    if (!RegExp(r'^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$').hasMatch(sanitized)) {
      return '';
    }

    return sanitized;
  }

  // تنظيف كلمة المرور
  static String sanitizePassword(String password) {
    if (password.isEmpty) return password;

    // إزالة المسافات البيضاء من البداية والنهاية فقط
    String sanitized = password.trim();

    // إزالة أحرف التحكم
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // لا نقوم بتنظيف أكثر من ذلك للسماح بكلمات مرور قوية
    return sanitized;
  }

  // تنظيف أرقام الهاتف
  static String sanitizePhoneNumber(String phone) {
    if (phone.isEmpty) return phone;

    // إزالة كل شيء ما عدا الأرقام و + في البداية
    String sanitized = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // التأكد من أن + موجود في البداية فقط
    if (sanitized.contains('+') && !sanitized.startsWith('+')) {
      sanitized = sanitized.replaceAll(RegExp(r'\+'), '');
    }

    return sanitized;
  }

  // تنظيف الأسماء
  static String sanitizeName(String name) {
    if (name.isEmpty) return name;

    // إزالة المسافات الزائدة
    String sanitized = name.trim();

    // إزالة الأحرف غير المسموح بها (السماح بالحروف والمسافات فقط)
    sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z\u0600-\u06FF\s\'-]'), '');

    // تحويل المسافات المتعددة إلى مسافة واحدة
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    return sanitized;
  }

  // تنظيف عناوين URL
  static String sanitizeUrl(String url) {
    if (url.isEmpty) return url;

    String sanitized = url.trim();

    // التحقق من البروتوكول
    if (!sanitized.startsWith('http://') && !sanitized.startsWith('https://')) {
      sanitized = 'https://$sanitized';
    }

    // إزالة الأحرف غير الآمنة
    sanitized = Uri.encodeFull(sanitized);

    try {
      // التحقق من صحة URL
      final uri = Uri.parse(sanitized);
      if (!uri.hasScheme || !uri.hasAuthority) {
        return '';
      }
      return uri.toString();
    } catch (e) {
      return '';
    }
  }

  // تنظيف المسارات
  static String sanitizePath(String path) {
    if (path.isEmpty) return path;

    // إزالة المسافات الزائدة
    String sanitized = path.trim();

    // منع التنقل بين المجلدات
    sanitized = sanitized.replaceAll(RegExp(r'\.\.'), '');

    // إزالة الأحرف غير المسموح بها
    sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9/_\.-]'), '');

    // تحويل المسارات المتعددة إلى مسار واحد
    sanitized = sanitized.replaceAll(RegExp(r'/+'), '/');

    return sanitized;
  }

  // تنظيف رقم البطاقة الائتمانية
  static String sanitizeCreditCard(String cardNumber) {
    if (cardNumber.isEmpty) return cardNumber;

    // إزالة كل شيء ما عدا الأرقام
    String sanitized = cardNumber.replaceAll(RegExp(r'\D'), '');

    // التحقق من الطول
    if (sanitized.length < 13 || sanitized.length > 19) {
      return '';
    }

    return sanitized;
  }

  // تنظيف النصوص الطويلة
  static String sanitizeText(String text, {int? maxLength}) {
    if (text.isEmpty) return text;

    String sanitized = sanitizeInput(text);

    // تحديد الطول إذا تم تحديده
    if (maxLength != null && sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized;
  }

  // تنظيف JSON
  static String sanitizeJson(String json) {
    if (json.isEmpty) return json;

    try {
      // فك الترميز وإعادة الترميز لضمان الصحة
      final decoded = jsonDecode(json);
      return jsonEncode(_sanitizeJsonObject(decoded));
    } catch (e) {
      return '{}';
    }
  }

  // دالة مساعدة لتنظيف كائنات JSON
  static dynamic _sanitizeJsonObject(dynamic obj) {
    if (obj is String) {
      return sanitizeInput(obj);
    } else if (obj is Map) {
      return obj.map((key, value) => MapEntry(
        sanitizeInput(key.toString()),
        _sanitizeJsonObject(value),
      ));
    } else if (obj is List) {
      return obj.map((item) => _sanitizeJsonObject(item)).toList();
    } else {
      return obj;
    }
  }

  // تحويل HTML entities
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  // إزالة HTML entities
  static String unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  // تنظيف البحث
  static String sanitizeSearchQuery(String query) {
    if (query.isEmpty) return query;

    String sanitized = query.trim();

    // إزالة الأحرف الخاصة للبحث
    sanitized = sanitized.replaceAll(RegExp(r'[*?\\$^(){}|\[\]]'), '');

    // تحويل إلى حروف صغيرة
    sanitized = sanitized.toLowerCase();

    // إزالة الكلمات المحظورة
    final blockedWords = ['select', 'insert', 'update', 'delete', 'drop', 'union'];
    for (var word in blockedWords) {
      sanitized = sanitized.replaceAll(RegExp('\\b$word\\b', caseSensitive: false), '');
    }

    return sanitized.trim();
  }

  // تنظيف اسم الملف
  static String sanitizeFileName(String fileName) {
    if (fileName.isEmpty) return fileName;

    // إزالة الأحرف غير المسموح بها في أسماء الملفات
    String sanitized = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');

    // إزالة النقاط في البداية
    sanitized = sanitized.replaceAll(RegExp(r'^\.+'), '');

    // تحديد الطول
    if (sanitized.length > 255) {
      final extension = sanitized.split('.').last;
      final name = sanitized.substring(0, 255 - extension.length - 1);
      sanitized = '$name.$extension';
    }

    return sanitized;
  }

  // تنظيف عنوان IP
  static String sanitizeIpAddress(String ip) {
    if (ip.isEmpty) return ip;

    // IPv4
    if (RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(ip)) {
      final parts = ip.split('.');
      if (parts.every((part) => int.tryParse(part) != null && int.parse(part) <= 255)) {
        return ip;
      }
    }

    // IPv6
    if (RegExp(r'^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$').hasMatch(ip)) {
      return ip;
    }

    return '';
  }
}