import 'dart:convert';

class InputSanitizer {
  // تنظيف المدخلات العامة
  static String sanitizeInput(String input) {
    if (input.isEmpty) return input;

    String sanitized = input.trim();

    // إزالة الأحرف الخاصة الخطرة وأحرف التحكم والأحرف غير المرئية
    sanitized = sanitized
        .replaceAll(RegExp(r"[<>{}\\'\"[]]"), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // أحرف التحكم
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), ''); // أحرف غير مرئية


        // إزالة أنماط SQL Injection
        sanitized = sanitized
        .replaceAll(RegExp(r'(--)|(;)|(/\*)'), '')
        .replaceAll(RegExp(r'(union\s+select)|(select\s+\*)|(drop\s+table)', caseSensitive: false), '')
        .replaceAll(RegExp(r'(insert\s+into)|(delete\s+from)|(update\s+\w+\s+set)', caseSensitive: false), '');

    // إزالة أنماط XSS
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

    String sanitized = email.toLowerCase().trim();
    sanitized = sanitized.replaceAll(RegExp(r'[^a-z0-9@._+-]'), '');

    if (!RegExp(r'^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$').hasMatch(sanitized)) {
      return '';
    }

    return sanitized;
  }

  // تنظيف كلمة المرور
  static String sanitizePassword(String password) {
    if (password.isEmpty) return password;

    String sanitized = password.trim();
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    return sanitized;
  }

  // تنظيف رقم الهاتف
  static String sanitizePhoneNumber(String phone) {
    if (phone.isEmpty) return phone;

    String sanitized = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (sanitized.contains('+') && !sanitized.startsWith('+')) {
      sanitized = sanitized.replaceAll(RegExp(r'\+'), '');
    }

    return sanitized;
  }

  // تنظيف الأسماء
  static String sanitizeName(String name) {
    if (name.isEmpty) return name;

    String sanitized = name.trim();
    sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z\u0600-\u06FF\s]'), '');
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    return sanitized;
  }

  // تنظيف الروابط URL
  static String sanitizeUrl(String url) {
    if (url.isEmpty) return url;

    String sanitized = url.trim();

    if (!sanitized.startsWith('http://') && !sanitized.startsWith('https://')) {
      sanitized = 'https://$sanitized';
    }

    sanitized = Uri.encodeFull(sanitized);

    try {
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

    String sanitized = path.trim();
    sanitized = sanitized.replaceAll(RegExp(r'\.\.'), '');
    sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9/_\.-]'), '');
    sanitized = sanitized.replaceAll(RegExp(r'/+'), '/');

    return sanitized;
  }

  // تنظيف رقم البطاقة الائتمانية
  static String sanitizeCreditCard(String cardNumber) {
    if (cardNumber.isEmpty) return cardNumber;

    String sanitized = cardNumber.replaceAll(RegExp(r'\D'), '');

    if (sanitized.length < 13 || sanitized.length > 19) {
      return '';
    }

    return sanitized;
  }

  // تنظيف النصوص الطويلة
  static String sanitizeText(String text, {int? maxLength}) {
    if (text.isEmpty) return text;

    String sanitized = sanitizeInput(text);

    if (maxLength != null && sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized;
  }

  // تنظيف JSON
  static String sanitizeJson(String json) {
    if (json.isEmpty) return json;

    try {
      final decoded = jsonDecode(json);
      return jsonEncode(_sanitizeJsonObject(decoded));
    } catch (e) {
      return '{}';
    }
  }

  static dynamic _sanitizeJsonObject(dynamic obj) {
    if (obj is String) {
      return sanitizeInput(obj);
    } else if (obj is Map) {
      return obj.map((key, value) => MapEntry(
        key is String ? sanitizeInput(key) : key,
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

  // تنظيف استعلامات البحث
  static String sanitizeSearchQuery(String query) {
    if (query.isEmpty) return query;

    String sanitized = query.trim();
    sanitized = sanitized.replaceAll(RegExp(r'[*?\\$^(){}|\[\]]'), '');
    sanitized = sanitized.toLowerCase();

    final blockedWords = ['select', 'insert', 'update', 'delete', 'drop', 'union'];
    for (var word in blockedWords) {
      sanitized = sanitized.replaceAll(RegExp('\\b$word\\b', caseSensitive: false), '');
    }

    return sanitized.trim();
  }

  // تنظيف أسماء الملفات
  static String sanitizeFileName(String fileName) {
    if (fileName.isEmpty) return fileName;

    String sanitized = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    sanitized = sanitized.replaceAll(RegExp(r'^\.+'), '');

    if (sanitized.length > 255) {
      final parts = sanitized.split('.');
      final extension = parts.length > 1 ? parts.last : '';
      final name = parts.length > 1
          ? sanitized.substring(0, sanitized.length - extension.length - 1)
          : sanitized;

      if (extension.isNotEmpty) {
        final newName = name.substring(0, 254 - extension.length);
        sanitized = '$newName.$extension';
      } else {
        sanitized = name.substring(0, 255);
      }
    }

    return sanitized;
  }

  // تنظيف عنوان IP
  static String sanitizeIpAddress(String ip) {
    if (ip.isEmpty) return ip;

    if (RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(ip)) {
      final parts = ip.split('.');
      if (parts.every((part) => int.tryParse(part) != null && int.parse(part) <= 255)) {
        return ip;
      }
    }

    if (RegExp(r'^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$').hasMatch(ip)) {
      return ip;
    }

    return '';
  }
}
