import 'dart:convert';

class Validators {
  // التحقق من صحة البريد الإلكتروني
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      caseSensitive: false,
    );

    if (!emailRegex.hasMatch(email)) return false;

    // التحقق من طول أجزاء البريد الإلكتروني
    final parts = email.split('@');
    if (parts.length != 2) return false;

    final localPart = parts[0];
    final domainPart = parts[1];

    if (localPart.length > 64 || domainPart.length > 255) return false;

    // التحقق من النطاقات المحظورة
    final blockedDomains = ['tempmail.com', 'throwaway.com', 'guerrillamail.com'];
    if (blockedDomains.any((domain) => domainPart.endsWith(domain))) return false;

    return true;
  }

  // التحقق من قوة كلمة المرور
  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;

    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    return hasUppercase && hasLowercase && hasDigits && hasSpecialCharacters;
  }

  // حساب قوة كلمة المرور
  static double calculatePasswordStrength(String password) {
    double strength = 0.0;

    if (password.length >= 8) strength += 0.2;
    if (password.length >= 12) strength += 0.1;
    if (password.length >= 16) strength += 0.1;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.15;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.15;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.15;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.15;
    if (password.contains(RegExp(r'[^A-Za-z0-9]'))) strength += 0.1;

    // تقليل القوة للأنماط الشائعة
    if (hasCommonPatterns(password)) strength -= 0.2;
    if (hasDictionaryWords(password)) strength -= 0.2;

    return strength.clamp(0.0, 1.0);
  }

  // التحقق من الأنماط الشائعة
  static bool hasCommonPatterns(String password) {
    final commonPatterns = [
      '12345', '123456', '123456789', 'password', 'qwerty', 'abc123',
      '111111', '123123', 'admin', 'letmein', 'welcome', 'monkey',
      'password1', '1234567', 'sunshine', 'master', 'hello', 'freedom',
    ];

    final lowerPassword = password.toLowerCase();
    return commonPatterns.any((pattern) => lowerPassword.contains(pattern));
  }

  // التحقق من كلمات القاموس
  static bool hasDictionaryWords(String password) {
    // في تطبيق حقيقي، يمكن استخدام قاموس أكبر
    final dictionaryWords = [
      'password', 'computer', 'internet', 'security', 'login',
      'access', 'system', 'network', 'database', 'admin',
    ];

    final lowerPassword = password.toLowerCase();
    return dictionaryWords.any((word) => lowerPassword.contains(word));
  }

  // التحقق من صحة اسم المستخدم
  static bool isValidUsername(String username) {
    if (username.length < 3 || username.length > 20) return false;

    // يجب أن يبدأ بحرف
    if (!RegExp(r'^[a-zA-Z]').hasMatch(username)) return false;

    // يسمح فقط بالحروف والأرقام والشرطة السفلية
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) return false;

    // منع الأسماء المحجوزة
    final reservedUsernames = ['admin', 'root', 'system', 'administrator'];
    if (reservedUsernames.contains(username.toLowerCase())) return false;

    return true;
  }

  // التحقق من صحة رقم الهاتف
  static bool isValidPhoneNumber(String phone) {
    // إزالة المسافات والشرطات
    String cleanPhone = phone.replaceAll(RegExp(r'[-\s]'), '');

    // التحقق من الصيغة الدولية
    if (cleanPhone.startsWith('+')) {
      return RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(cleanPhone);
    }

    // التحقق من الصيغة المحلية
    return RegExp(r'^[0-9]{10,15}$').hasMatch(cleanPhone);
  }

  // التحقق من صحة عنوان URL
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // التحقق من صحة عنوان IP
  static bool isValidIpAddress(String ip) {
    // IPv4
    if (RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(ip)) {
      final parts = ip.split('.');
      return parts.every((part) {
        final num = int.tryParse(part);
        return num != null && num >= 0 && num <= 255;
      });
    }

    // IPv6
    return RegExp(r'^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$').hasMatch(ip);
  }

  // التحقق من صحة بطاقة الائتمان
  static bool isValidCreditCard(String cardNumber) {
    // إزالة المسافات والشرطات
    String cleanNumber = cardNumber.replaceAll(RegExp(r'[-\s]'), '');

    // التحقق من أن الرقم يحتوي على أرقام فقط
    if (!RegExp(r'^\d+$').hasMatch(cleanNumber)) return false;

    // التحقق من الطول
    if (cleanNumber.length < 13 || cleanNumber.length > 19) return false;

    // خوارزمية Luhn
    int sum = 0;
    bool alternate = false;

    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cleanNumber[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  // التحقق من صحة رمز CVV
  static bool isValidCVV(String cvv) {
    return RegExp(r'^\d{3,4}$').hasMatch(cvv);
  }

  // التحقق من صحة تاريخ انتهاء البطاقة
  static bool isValidExpiryDate(String expiryDate) {
    // تنسيق MM/YY أو MM/YYYY
    final regex = RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2}|[0-9]{4})$');
    if (!regex.hasMatch(expiryDate)) return false;

    final parts = expiryDate.split('/');
    final month = int.parse(parts[0]);
    var year = int.parse(parts[1]);

    // تحويل السنة إلى 4 أرقام إذا كانت سنتين
    if (year < 100) {
      year += 2000;
    }

    final now = DateTime.now();
    final expiry = DateTime(year, month + 1, 0); // آخر يوم في الشهر

    return expiry.isAfter(now);
  }

  // التحقق من صحة المسار
  static bool isValidPath(String path) {
    // منع المسارات الفارغة
    if (path.isEmpty) return false;

    // منع التنقل بين المجلدات
    if (path.contains('..')) return false;

    // منع الأحرف غير المسموح بها
    if (!RegExp(r'^[a-zA-Z0-9/_.-]+$').hasMatch(path)) return false;

    // منع المسارات المطلقة
    if (path.startsWith('/')) return false;

    // منع المسارات الخطرة
    final dangerousPaths = [
      'etc/passwd',
      'etc/shadow',
      'windows/system32',
      'boot.ini',
      'autoexec.bat',
      'config.sys',
    ];

    if (dangerousPaths.any((dangerous) => path.toLowerCase().contains(dangerous))) {
      return false;
    }

    return true;
  }

  // التحقق من صحة اسم الملف
  static bool isValidFileName(String fileName) {
    if (fileName.isEmpty || fileName.length > 255) return false;

    // منع الأحرف غير المسموح بها
    if (RegExp(r'[<>:"/\\|?*]').hasMatch(fileName)) return false;

    // منع النقاط في البداية
    if (fileName.startsWith('.')) return false;

    // منع الأسماء المحجوزة في Windows
    final reservedNames = [
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
    ];

    if (reservedNames.contains(fileName.toUpperCase())) return false;

    return true;
  }

  // التحقق من صحة الامتداد
  static bool isValidFileExtension(String fileName, List<String> allowedExtensions) {
    final extension = fileName.split('.').last.toLowerCase();
    return allowedExtensions.contains(extension);
  }

  // التحقق من حجم الملف
  static bool isValidFileSize(int size, int maxSizeInBytes) {
    return size > 0 && size <= maxSizeInBytes;
  }

  // التحقق من صحة التاريخ
  static bool isValidDate(String date) {
    try {
      DateTime.parse(date);
      return true;
    } catch (e) {
      return false;
    }
  }

  // التحقق من أن التاريخ في المستقبل
  static bool isFutureDate(String date) {
    try {
      final dateTime = DateTime.parse(date);
      return dateTime.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // التحقق من أن التاريخ في الماضي
  static bool isPastDate(String date) {
    try {
      final dateTime = DateTime.parse(date);
      return dateTime.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // التحقق من نطاق التاريخ
  static bool isDateInRange(String date, DateTime start, DateTime end) {
    try {
      final dateTime = DateTime.parse(date);
      return dateTime.isAfter(start) && dateTime.isBefore(end);
    } catch (e) {
      return false;
    }
  }

  // التحقق من صحة الاسم
  static bool isValidName(String name) {
    if (name.length < 2 || name.length > 50) {
      return false;
    }

    // السماح بالحروف العربية والإنجليزية والمسافات والشرط فقط
    final pattern = RegExp(r'^[a-zA-Z\u0600-\u0600FF\s\-]+$');
    return pattern.hasMatch(name);
  }


  // التحقق من صحة الرمز البريدي
  static bool isValidPostalCode(String postalCode, String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'US':
        return RegExp(r'^\d{5}(-\d{4})?$').hasMatch(postalCode);
      case 'CA':
        return RegExp(r'^[A-Z]\d[A-Z]\s?\d[A-Z]\d$').hasMatch(postalCode);
      case 'UK':
      case 'GB':
        return RegExp(r'^[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}$').hasMatch(postalCode);
      case 'SA':
        return RegExp(r'^\d{5}$').hasMatch(postalCode);
      default:
        return RegExp(r'^[A-Z0-9\s-]{3,10}$').hasMatch(postalCode);
    }
  }

  // التحقق من صحة كلمة المرور المؤقتة
  static bool isValidOTP(String otp) {
    return RegExp(r'^\d{4,6}$').hasMatch(otp);
  }

  // التحقق من صحة UUID
  static bool isValidUUID(String uuid) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(uuid);
  }

  // التحقق من صحة JSON
  static bool isValidJson(String json) {
    try {
      jsonDecode(json);
      return true;
    } catch (e) {
      return false;
    }
  }

  // التحقق من صحة Base64
  static bool isValidBase64(String base64String) {
    try {
      base64Decode(base64String);
      return true;
    } catch (e) {
      return false;
    }
  }

  // التحقق من صحة JWT
  static bool isValidJWT(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return false;

    try {
      base64Url.decode(base64Url.normalize(parts[0]));
      base64Url.decode(base64Url.normalize(parts[1]));
      return true;
    } catch (e) {
      return false;
    }
  }

  // التحقق من صحة العملة
  static bool isValidCurrency(String amount) {
    return RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(amount);
  }

  // التحقق من صحة العنوان MAC
  static bool isValidMacAddress(String mac) {
    return RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$').hasMatch(mac);
  }

  // التحقق من صحة عنوان Bitcoin
  static bool isValidBitcoinAddress(String address) {
    // P2PKH
    if (RegExp(r'^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$').hasMatch(address)) return true;
    // P2SH
    if (RegExp(r'^3[a-km-zA-HJ-NP-Z1-9]{25,34}$').hasMatch(address)) return true;
    // Bech32
    if (RegExp(r'^bc1[a-z0-9]{39,59}$').hasMatch(address)) return true;

    return false;
  }

  // التحقق من صحة IBAN
  static bool isValidIBAN(String iban) {
    // إزالة المسافات والأحرف غير الضرورية
    String cleanIBAN = iban.replaceAll(RegExp(r'\s+'), '').toUpperCase();

    // التحقق من الطول (يختلف حسب الدولة)
    if (cleanIBAN.length < 15 || cleanIBAN.length > 34) return false;

    // التحقق من أن أول حرفين هما رمز الدولة
    if (!RegExp(r'^[A-Z]{2}').hasMatch(cleanIBAN)) return false;

    // التحقق من أن الحرفين 3 و 4 هما أرقام
    if (!RegExp(r'^[A-Z]{2}\d{2}').hasMatch(cleanIBAN)) return false;

    // خوارزمية التحقق من IBAN
    try {
      // نقل أول 4 أحرف إلى النهاية
      String rearranged = cleanIBAN.substring(4) + cleanIBAN.substring(0, 4);

      // تحويل الحروف إلى أرقام (A=10, B=11, ..., Z=35)
      String numericString = '';
      for (int i = 0; i < rearranged.length; i++) {
        int char = rearranged.codeUnitAt(i);
        if (char >= 65 && char <= 90) { // A-Z
          numericString += (char - 55).toString();
        } else {
          numericString += rearranged[i];
        }
      }

      // التحقق باستخدام mod 97
      BigInt numericIBAN = BigInt.parse(numericString);
      return numericIBAN % BigInt.from(97) == BigInt.one;
    } catch (e) {
      return false;
    }
  }

  // التحقق من صحة رقم الضمان الاجتماعي (SSN)
  static bool isValidSSN(String ssn) {
    // تنسيق XXX-XX-XXXX
    return RegExp(r'^\d{3}-\d{2}-\d{4}$').hasMatch(ssn);
  }

  // التحقق من صحة رقم جواز السفر
  static bool isValidPassportNumber(String passport, String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'US':
        return RegExp(r'^[0-9]{9}$').hasMatch(passport);
      case 'GB':
        return RegExp(r'^[0-9]{9}$').hasMatch(passport);
      case 'DE':
        return RegExp(r'^[A-Z0-9]{9}$').hasMatch(passport);
      default:
        return RegExp(r'^[A-Z0-9]{6,9}$').hasMatch(passport);
    }
  }

  // التحقق من صحة رمز الأمان (PIN)
  static bool isValidPIN(String pin) {
    return RegExp(r'^\d{4,6}$').hasMatch(pin);
  }

  // التحقق من صحة مفتاح API
  static bool isValidAPIKey(String apiKey) {
    // عادة ما تكون مفاتيح API بطول 32-128 حرف
    if (apiKey.length < 32 || apiKey.length > 128) return false;

    // التحقق من أنها تحتوي على أحرف وأرقام فقط
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(apiKey);
  }

  // التحقق من قوة مفتاح التشفير
  static bool isStrongEncryptionKey(String key) {
    // يجب أن يكون المفتاح على الأقل 256 بت (32 بايت)
    return key.length >= 32;
  }

  // التحقق من صحة نقطة النهاية (Endpoint)
  static bool isValidEndpoint(String endpoint) {
    // يجب أن يبدأ بـ /
    if (!endpoint.startsWith('/')) return false;

    // منع التنقل بين المجلدات
    if (endpoint.contains('..')) return false;

    // السماح فقط بالأحرف والأرقام والشرطة السفلية والشرطة
    return RegExp(r'^/[a-zA-Z0-9_/-]*$').hasMatch(endpoint);
  }
}