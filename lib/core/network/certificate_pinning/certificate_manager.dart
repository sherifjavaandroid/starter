import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import '../../utils/secure_logger.dart';
import '../../security/secure_storage_service.dart';

class CertificateManager {
  final SecureStorageService _storageService;
  final SecureLogger _logger;

  // تخزين الشهادات
  final Map<String, List<Certificate>> _certificates = {};

  // مدة صلاحية الشهادات
  static const Duration _certificateValidity = Duration(days: 365);

  CertificateManager(this._storageService, this._logger);

  Future<void> loadCertificates() async {
    try {
      // تحميل الشهادات من assets
      await _loadCertificatesFromAssets();

      // تحميل الشهادات المخزنة
      await _loadStoredCertificates();

      // التحقق من صلاحية الشهادات
      await _validateCertificates();

      _logger.log(
        'Certificates loaded successfully',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to load certificates: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _loadCertificatesFromAssets() async {
    try {
      // تحميل ملف تكوين الشهادات
      final configString = await rootBundle.loadString('assets/certificates/certificate_pins.json');
      final config = json.decode(configString) as Map<String, dynamic>;

      for (var entry in config.entries) {
        final domain = entry.key;
        final certConfig = entry.value as Map<String, dynamic>;

        final certificates = <Certificate>[];

        // تحميل الشهادات
        if (certConfig['certificates'] != null) {
          for (var certPath in certConfig['certificates']) {
            final certData = await rootBundle.load('assets/certificates/$certPath');
            final certificate = Certificate.fromDer(certData.buffer.asUint8List());
            certificates.add(certificate);
          }
        }

        _certificates[domain] = certificates;
      }
    } catch (e) {
      _logger.log(
        'Failed to load certificates from assets: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _loadStoredCertificates() async {
    try {
      final storedCerts = await _storageService.getSecureData('stored_certificates');
      if (storedCerts != null) {
        final decoded = json.decode(storedCerts) as Map<String, dynamic>;

        for (var entry in decoded.entries) {
          final domain = entry.key;
          final certList = entry.value as List<dynamic>;

          final certificates = certList.map((certData) {
            return Certificate.fromJson(certData);
          }).toList();

          // دمج مع الشهادات الموجودة
          if (_certificates.containsKey(domain)) {
            _certificates[domain]!.addAll(certificates);
          } else {
            _certificates[domain] = certificates;
          }
        }
      }
    } catch (e) {
      _logger.log(
        'Failed to load stored certificates: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<void> _validateCertificates() async {
    final now = DateTime.now();

    for (var entry in _certificates.entries) {
      final domain = entry.key;
      final certificates = entry.value;

      certificates.removeWhere((cert) {
        if (cert.expiryDate.isBefore(now)) {
          _logger.log(
            'Certificate expired for $domain',
            level: LogLevel.warning,
            category: SecurityCategory.security,
          );
          return true;
        }
        return false;
      });
    }
  }

  Future<void> addCertificate(String domain, Uint8List certData) async {
    try {
      final certificate = Certificate.fromDer(certData);

      // التحقق من صلاحية الشهادة
      if (!certificate.isValid()) {
        throw SecurityException('Invalid certificate');
      }

      // إضافة الشهادة
      if (!_certificates.containsKey(domain)) {
        _certificates[domain] = [];
      }
      _certificates[domain]!.add(certificate);

      // حفظ التحديث
      await _saveCertificates();

      _logger.log(
        'Certificate added for $domain',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to add certificate: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> removeCertificate(String domain, String fingerprint) async {
    try {
      if (_certificates.containsKey(domain)) {
        _certificates[domain]!.removeWhere((cert) => cert.fingerprint == fingerprint);

        if (_certificates[domain]!.isEmpty) {
          _certificates.remove(domain);
        }

        await _saveCertificates();

        _logger.log(
          'Certificate removed for $domain',
          level: LogLevel.info,
          category: SecurityCategory.security,
        );
      }
    } catch (e) {
      _logger.log(
        'Failed to remove certificate: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _saveCertificates() async {
    try {
      final certsToSave = <String, List<Map<String, dynamic>>>{};

      for (var entry in _certificates.entries) {
        certsToSave[entry.key] = entry.value.map((cert) => cert.toJson()).toList();
      }

      await _storageService.saveSecureData(
        'stored_certificates',
        json.encode(certsToSave),
      );
    } catch (e) {
      _logger.log(
        'Failed to save certificates: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  List<Certificate>? getCertificatesForDomain(String domain) {
    return _certificates[domain];
  }

  bool validateCertificate(String domain, Certificate certificate) {
    final storedCerts = _certificates[domain];
    if (storedCerts == null) return false;

    return storedCerts.any((cert) => cert.fingerprint == certificate.fingerprint);
  }

  Future<void> updateCertificate(String domain, Certificate oldCert, Certificate newCert) async {
    try {
      if (_certificates.containsKey(domain)) {
        final index = _certificates[domain]!.indexWhere((cert) => cert.fingerprint == oldCert.fingerprint);

        if (index != -1) {
          _certificates[domain]![index] = newCert;
          await _saveCertificates();

          _logger.log(
            'Certificate updated for $domain',
            level: LogLevel.info,
            category: SecurityCategory.security,
          );
        }
      }
    } catch (e) {
      _logger.log(
        'Failed to update certificate: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> exportCertificates() async {
    final export = <String, List<Map<String, dynamic>>>{};

    for (var entry in _certificates.entries) {
      export[entry.key] = entry.value.map((cert) => cert.toJson()).toList();
    }

    return export;
  }

  Future<void> importCertificates(Map<String, List<Map<String, dynamic>>> certificates) async {
    try {
      for (var entry in certificates.entries) {
        final domain = entry.key;
        final certList = entry.value;

        final importedCerts = certList.map((certData) => Certificate.fromJson(certData)).toList();

        if (_certificates.containsKey(domain)) {
          _certificates[domain]!.addAll(importedCerts);
        } else {
          _certificates[domain] = importedCerts;
        }
      }

      await _saveCertificates();

      _logger.log(
        'Certificates imported successfully',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to import certificates: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }
}

class Certificate {
  final Uint8List rawData;
  final String fingerprint;
  final DateTime issueDate;
  final DateTime expiryDate;
  final String issuer;
  final String subject;
  final String? serialNumber;
  final List<String>? subjectAltNames;

  Certificate({
    required this.rawData,
    required this.fingerprint,
    required this.issueDate,
    required this.expiryDate,
    required this.issuer,
    required this.subject,
    this.serialNumber,
    this.subjectAltNames,
  });

  factory Certificate.fromDer(Uint8List der) {
    // تحليل الشهادة - هذا مثال مبسط
    return Certificate(
      rawData: der,
      fingerprint: _calculateFingerprint(der),
      issueDate: DateTime.now().subtract(Duration(days: 30)),
      expiryDate: DateTime.now().add(Duration(days: 365)),
      issuer: 'CN=Example CA',
      subject: 'CN=example.com',
    );
  }

  factory Certificate.fromJson(Map<String, dynamic> json) {
    return Certificate(
      rawData: base64.decode(json['rawData']),
      fingerprint: json['fingerprint'],
      issueDate: DateTime.parse(json['issueDate']),
      expiryDate: DateTime.parse(json['expiryDate']),
      issuer: json['issuer'],
      subject: json['subject'],
      serialNumber: json['serialNumber'],
      subjectAltNames: json['subjectAltNames'] != null
          ? List<String>.from(json['subjectAltNames'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rawData': base64.encode(rawData),
      'fingerprint': fingerprint,
      'issueDate': issueDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'issuer': issuer,
      'subject': subject,
      'serialNumber': serialNumber,
      'subjectAltNames': subjectAltNames,
    };
  }

  bool isValid() {
    final now = DateTime.now();
    return now.isAfter(issueDate) && now.isBefore(expiryDate);
  }

  static String _calculateFingerprint(Uint8List der) {
    // حساب بصمة الشهادة
    final digest = sha256.convert(der);
    return digest.toString();
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}