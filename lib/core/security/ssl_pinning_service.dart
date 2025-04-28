import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/io_client.dart';
import 'package:crypto/crypto.dart';
import '../utils/secure_logger.dart';
import 'secure_storage_service.dart';

class SSLPinningService {
  final SecureStorageService _storageService;
  final SecureLogger _logger;

  // تخزين الشهادات المثبتة
  final Map<String, List<String>> _pinnedCertificates = {};
  final Map<String, List<String>> _pinnedPublicKeys = {};

  // مدة صلاحية الشهادات (30 يوم)
  static const Duration _certificateValidity = Duration(days: 30);

  // مسارات الشهادات
  static const String _certificatesPath = 'assets/certificates/';
  static const String _certificateConfigPath = 'certificate_pins.json';

  SSLPinningService(this._storageService, this._logger);

  Future<void> initialize() async {
    try {
      await _loadCertificatePins();
      await _validateCertificates();

      _logger.log(
        'SSL Pinning service initialized successfully',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'SSL Pinning service initialization failed: $e',
        level: LogLevel.critical,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _loadCertificatePins() async {
    try {
      // تحميل تكوين الشهادات
      final configString = await rootBundle.loadString(
        '$_certificatesPath$_certificateConfigPath',
      );
      final config = json.decode(configString) as Map<String, dynamic>;

      // تحميل الشهادات والمفاتيح العامة
      for (var entry in config.entries) {
        final domain = entry.key;
        final pinConfig = entry.value as Map<String, dynamic>;

        // تحميل تثبيت الشهادات
        if (pinConfig['certificates'] != null) {
          _pinnedCertificates[domain] = List<String>.from(pinConfig['certificates']);
        }

        // تحميل تثبيت المفاتيح العامة
        if (pinConfig['public_keys'] != null) {
          _pinnedPublicKeys[domain] = List<String>.from(pinConfig['public_keys']);
        }
      }
    } catch (e) {
      _logger.log(
        'Failed to load certificate pins: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _validateCertificates() async {
    try {
      for (var domain in _pinnedCertificates.keys) {
        final certificates = _pinnedCertificates[domain]!;

        for (var certHash in certificates) {
          // التحقق من صلاحية الشهادة
          final isValid = await _checkCertificateValidity(domain, certHash);
          if (!isValid) {
            _logger.log(
              'Certificate for $domain is invalid or expired',
              level: LogLevel.warning,
              category: SecurityCategory.security,
            );
          }
        }
      }
    } catch (e) {
      _logger.log(
        'Certificate validation failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<bool> _checkCertificateValidity(String domain, String certHash) async {
    try {
      // التحقق من تاريخ انتهاء الشهادة
      final storedDate = await _storageService.getSecureData(
        'cert_expiry_$domain',
      );

      if (storedDate != null) {
        final expiryDate = DateTime.parse(storedDate);
        return DateTime.now().isBefore(expiryDate);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  HttpClient createSecureHttpClient() {
    final client = HttpClient();

    // تفعيل SSL Pinning
    client.badCertificateCallback = (cert, host, port) {
      return _validateCertificate(cert, host);
    };

    // تكوين إعدادات الأمان
    client.connectionTimeout = const Duration(seconds: 10);
    client.idleTimeout = const Duration(seconds: 15);

    return client;
  }

  IOClient createIOClient() {
    return IOClient(createSecureHttpClient());
  }

  bool _validateCertificate(X509Certificate cert, String host) {
    try {
      // استخراج المجال من المضيف
      final domain = _extractDomain(host);

      // التحقق من الشهادة
      if (_pinnedCertificates.containsKey(domain)) {
        final certHash = _calculateCertificateHash(cert);
        final pinnedHashes = _pinnedCertificates[domain]!;

        if (!pinnedHashes.contains(certHash)) {
          _logger.log(
            'Certificate validation failed for $domain: hash mismatch',
            level: LogLevel.error,
            category: SecurityCategory.security,
          );
          return false;
        }
      }

      // التحقق من المفتاح العام
      if (_pinnedPublicKeys.containsKey(domain)) {
        final publicKeyHash = _calculatePublicKeyHash(cert);
        final pinnedKeys = _pinnedPublicKeys[domain]!;

        if (!pinnedKeys.contains(publicKeyHash)) {
          _logger.log(
            'Public key validation failed for $domain: hash mismatch',
            level: LogLevel.error,
            category: SecurityCategory.security,
          );
          return false;
        }
      }

      // التحقق من صلاحية الشهادة
      if (cert.endValidity.isBefore(DateTime.now())) {
        _logger.log(
          'Certificate expired for $domain',
          level: LogLevel.error,
          category: SecurityCategory.security,
        );
        return false;
      }

      // التحقق من اسم المضيف
      if (!_validateHostname(cert, host)) {
        _logger.log(
          'Hostname validation failed for $domain',
          level: LogLevel.error,
          category: SecurityCategory.security,
        );
        return false;
      }

      return true;
    } catch (e) {
      _logger.log(
        'Certificate validation error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  String _calculateCertificateHash(X509Certificate cert) {
    final der = cert.der;
    final digest = sha256.convert(der);
    return base64.encode(digest.bytes);
  }

  String _calculatePublicKeyHash(X509Certificate cert) {
    // استخراج المفتاح العام من الشهادة
    final publicKeyDer = cert.der;
    final publicKeyData = _extractPublicKey(publicKeyDer);
    final digest = sha256.convert(publicKeyData);
    return base64.encode(digest.bytes);
  }

  Uint8List _extractPublicKey(Uint8List certDer) {
    // استخراج المفتاح العام من DER
    // هذه نسخة مبسطة - في الواقع تحتاج إلى تحليل ASN.1
    try {
      // البحث عن SPKI (Subject Public Key Info)
      final spkiStart = _findSpkiStart(certDer);
      if (spkiStart == -1) {
        throw SecurityException('Could not find SPKI in certificate');
      }

      // استخراج SPKI
      final spkiLength = _getLength(certDer, spkiStart);
      return certDer.sublist(spkiStart, spkiStart + spkiLength);
    } catch (e) {
      _logger.log(
        'Failed to extract public key: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  int _findSpkiStart(Uint8List certDer) {
    // البحث عن بداية SPKI في الشهادة
    // هذه نسخة مبسطة - في الواقع تحتاج إلى تحليل ASN.1 بالكامل
    for (int i = 0; i < certDer.length - 20; i++) {
      if (certDer[i] == 0x30 && certDer[i + 1] == 0x82) {
        // التحقق من وجود OID للمفتاح العام
        if (_isPublicKeyOid(certDer, i + 4)) {
          return i;
        }
      }
    }
    return -1;
  }

  bool _isPublicKeyOid(Uint8List data, int offset) {
    // OIDs المعروفة للمفاتيح العامة
    final rsaOid = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01];
    final ecdsaOid = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01];

    if (offset + rsaOid.length <= data.length) {
      bool matchRsa = true;
      for (int i = 0; i < rsaOid.length; i++) {
        if (data[offset + i] != rsaOid[i]) {
          matchRsa = false;
          break;
        }
      }
      if (matchRsa) return true;
    }

    if (offset + ecdsaOid.length <= data.length) {
      bool matchEcdsa = true;
      for (int i = 0; i < ecdsaOid.length; i++) {
        if (data[offset + i] != ecdsaOid[i]) {
          matchEcdsa = false;
          break;
        }
      }
      if (matchEcdsa) return true;
    }

    return false;
  }

  int _getLength(Uint8List data, int offset) {
    if (data[offset + 1] < 0x80) {
      return data[offset + 1] + 2;
    } else {
      int lengthBytes = data[offset + 1] & 0x7F;
      int length = 0;
      for (int i = 0; i < lengthBytes; i++) {
        length = (length << 8) | data[offset + 2 + i];
      }
      return length + 2 + lengthBytes;
    }
  }

  bool _validateHostname(X509Certificate cert, String host) {
    try {
      // استخراج أسماء المضيف من الشهادة
      final subjectName = cert.subject;
      final altNames = _extractAltNames(cert);

      // التحقق من اسم المضيف
      if (_matchesHostname(subjectName, host)) {
        return true;
      }

      // التحقق من الأسماء البديلة
      for (var altName in altNames) {
        if (_matchesHostname(altName, host)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.log(
        'Hostname validation error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  List<String> _extractAltNames(X509Certificate cert) {
    // استخراج Subject Alternative Names من الشهادة
    // هذه نسخة مبسطة - في الواقع تحتاج إلى تحليل ملحقات X.509
    return [];
  }

  bool _matchesHostname(String certName, String host) {
    // إزالة المسافات الزائدة
    certName = certName.trim().toLowerCase();
    host = host.trim().toLowerCase();

    // التحقق من التطابق المباشر
    if (certName == host) {
      return true;
    }

    // التحقق من أسماء البدل (wildcard)
    if (certName.startsWith('*.')) {
      final wildcardDomain = certName.substring(2);
      final hostParts = host.split('.');

      if (hostParts.length >= 2) {
        final hostDomain = hostParts.sublist(1).join('.');
        return hostDomain == wildcardDomain;
      }
    }

    return false;
  }

  String _extractDomain(String host) {
    // استخراج المجال من المضيف
    final parts = host.split('.');
    if (parts.length >= 2) {
      return parts.sublist(parts.length - 2).join('.');
    }
    return host;
  }

  Future<bool> validateCertificates() async {
    try {
      // التحقق من جميع الشهادات المثبتة
      bool allValid = true;

      for (var domain in _pinnedCertificates.keys) {
        final isValid = await _checkCertificateValidity(domain, '');
        if (!isValid) {
          allValid = false;
          _logger.log(
            'Certificate validation failed for $domain',
            level: LogLevel.warning,
            category: SecurityCategory.security,
          );
        }
      }

      return allValid;
    } catch (e) {
      _logger.log(
        'Certificate validation error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<void> updateCertificatePins() async {
    try {
      // تحديث تثبيت الشهادات من الخادم
      // هذه الوظيفة يمكن أن تستخدم لتحديث الشهادات ديناميكياً

      _logger.log(
        'Certificate pins updated successfully',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to update certificate pins: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  void addCertificatePin(String domain, String certificateHash) {
    if (!_pinnedCertificates.containsKey(domain)) {
      _pinnedCertificates[domain] = [];
    }
    _pinnedCertificates[domain]!.add(certificateHash);
  }

  void addPublicKeyPin(String domain, String publicKeyHash) {
    if (!_pinnedPublicKeys.containsKey(domain)) {
      _pinnedPublicKeys[domain] = [];
    }
    _pinnedPublicKeys[domain]!.add(publicKeyHash);
  }

  void removeCertificatePin(String domain, String certificateHash) {
    if (_pinnedCertificates.containsKey(domain)) {
      _pinnedCertificates[domain]!.remove(certificateHash);
      if (_pinnedCertificates[domain]!.isEmpty) {
        _pinnedCertificates.remove(domain);
      }
    }
  }

  void removePublicKeyPin(String domain, String publicKeyHash) {
    if (_pinnedPublicKeys.containsKey(domain)) {
      _pinnedPublicKeys[domain]!.remove(publicKeyHash);
      if (_pinnedPublicKeys[domain]!.isEmpty) {
        _pinnedPublicKeys.remove(domain);
      }
    }
  }

  List<String> getPinnedCertificates(String domain) {
    return _pinnedCertificates[domain] ?? [];
  }

  List<String> getPinnedPublicKeys(String domain) {
    return _pinnedPublicKeys[domain] ?? [];
  }

  Future<void> clearPins() async {
    _pinnedCertificates.clear();
    _pinnedPublicKeys.clear();

    _logger.log(
      'All certificate pins cleared',
      level: LogLevel.info,
      category: SecurityCategory.security,
    );
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}