import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../utils/secure_logger.dart';
import '../../security/secure_storage_service.dart';

class PublicKeyStore {
  final SecureStorageService _storageService;
  final SecureLogger _logger;

  // تخزين المفاتيح العامة
  final Map<String, List<PublicKey>> _publicKeys = {};

  // مدة صلاحية المفاتيح
  static const Duration _keyValidity = Duration(days: 365);

  PublicKeyStore(this._storageService, this._logger);

  Future<void> initialize() async {
    try {
      await _loadPublicKeys();
      await _validateKeys();

      _logger.log(
        'Public key store initialized',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Public key store initialization failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _loadPublicKeys() async {
    try {
      final storedKeys = await _storageService.getSecureData('public_keys');
      if (storedKeys != null) {
        final decoded = json.decode(storedKeys) as Map<String, dynamic>;

        for (var entry in decoded.entries) {
          final domain = entry.key;
          final keyList = entry.value as List<dynamic>;

          _publicKeys[domain] = keyList.map((keyData) {
            return PublicKey.fromJson(keyData);
          }).toList();
        }
      }
    } catch (e) {
      _logger.log(
        'Failed to load public keys: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<void> _validateKeys() async {
    final now = DateTime.now();

    for (var entry in _publicKeys.entries) {
      final domain = entry.key;
      final keys = entry.value;

      keys.removeWhere((key) {
        if (key.expiryDate != null && key.expiryDate!.isBefore(now)) {
          _logger.log(
            'Public key expired for $domain',
            level: LogLevel.warning,
            category: SecurityCategory.security,
          );
          return true;
        }
        return false;
      });
    }
  }

  Future<void> addPublicKey(String domain, PublicKey publicKey) async {
    try {
      if (!_publicKeys.containsKey(domain)) {
        _publicKeys[domain] = [];
      }

      // التحقق من عدم وجود المفتاح مسبقاً
      if (!_publicKeys[domain]!.any((key) => key.fingerprint == publicKey.fingerprint)) {
        _publicKeys[domain]!.add(publicKey);
        await _savePublicKeys();

        _logger.log(
          'Public key added for $domain',
          level: LogLevel.info,
          category: SecurityCategory.security,
        );
      }
    } catch (e) {
      _logger.log(
        'Failed to add public key: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> removePublicKey(String domain, String fingerprint) async {
    try {
      if (_publicKeys.containsKey(domain)) {
        _publicKeys[domain]!.removeWhere((key) => key.fingerprint == fingerprint);

        if (_publicKeys[domain]!.isEmpty) {
          _publicKeys.remove(domain);
        }

        await _savePublicKeys();

        _logger.log(
          'Public key removed for $domain',
          level: LogLevel.info,
          category: SecurityCategory.security,
        );
      }
    } catch (e) {
      _logger.log(
        'Failed to remove public key: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _savePublicKeys() async {
    try {
      final keysToSave = <String, List<Map<String, dynamic>>>{};

      for (var entry in _publicKeys.entries) {
        keysToSave[entry.key] = entry.value.map((key) => key.toJson()).toList();
      }

      await _storageService.saveSecureData(
        'public_keys',
        json.encode(keysToSave),
      );
    } catch (e) {
      _logger.log(
        'Failed to save public keys: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  List<PublicKey>? getPublicKeysForDomain(String domain) {
    return _publicKeys[domain];
  }

  bool validatePublicKey(String domain, PublicKey publicKey) {
    final storedKeys = _publicKeys[domain];
    if (storedKeys == null) return false;

    return storedKeys.any((key) => key.fingerprint == publicKey.fingerprint);
  }

  bool verifySignature(String domain, String data, String signature, String keyFingerprint) {
    try {
      final keys = _publicKeys[domain];
      if (keys == null) return false;

      final key = keys.firstWhere((k) => k.fingerprint == keyFingerprint, orElse: () => throw Exception('Key not found'));

      return key.verifySignature(data, signature);
    } catch (e) {
      _logger.log(
        'Signature verification failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<void> updatePublicKey(String domain, PublicKey oldKey, PublicKey newKey) async {
    try {
      if (_publicKeys.containsKey(domain)) {
        final index = _publicKeys[domain]!.indexWhere((key) => key.fingerprint == oldKey.fingerprint);

        if (index != -1) {
          _publicKeys[domain]![index] = newKey;
          await _savePublicKeys();

          _logger.log(
            'Public key updated for $domain',
            level: LogLevel.info,
            category: SecurityCategory.security,
          );
        }
      }
    } catch (e) {
      _logger.log(
        'Failed to update public key: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> rotateKeys(String domain) async {
    try {
      if (_publicKeys.containsKey(domain)) {
        final currentKeys = _publicKeys[domain]!;
        final now = DateTime.now();

        // تحديد المفاتيح التي تحتاج إلى تدوير
        final keysToRotate = currentKeys.where((key) {
          if (key.expiryDate == null) return false;
          return key.expiryDate!.difference(now).inDays < 30; // تدوير قبل 30 يوم من الانتهاء
        }).toList();

        if (keysToRotate.isNotEmpty) {
          _logger.log(
            'Rotating ${keysToRotate.length} keys for $domain',
            level: LogLevel.info,
            category: SecurityCategory.security,
          );

          // هنا يمكن إضافة منطق لتدوير المفاتيح
          // مثل الاتصال بالخادم للحصول على مفاتيح جديدة
        }
      }
    } catch (e) {
      _logger.log(
        'Key rotation failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> exportPublicKeys() async {
    final export = <String, List<Map<String, dynamic>>>{};

    for (var entry in _publicKeys.entries) {
      export[entry.key] = entry.value.map((key) => key.toJson()).toList();
    }

    return export;
  }

  Future<void> importPublicKeys(Map<String, List<Map<String, dynamic>>> keys) async {
    try {
      for (var entry in keys.entries) {
        final domain = entry.key;
        final keyList = entry.value;

        final importedKeys = keyList.map((keyData) => PublicKey.fromJson(keyData)).toList();

        if (_publicKeys.containsKey(domain)) {
          _publicKeys[domain]!.addAll(importedKeys);
        } else {
          _publicKeys[domain] = importedKeys;
        }
      }

      await _savePublicKeys();

      _logger.log(
        'Public keys imported successfully',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to import public keys: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  List<PublicKey> getExpiringKeys({int daysThreshold = 30}) {
    final expiringKeys = <PublicKey>[];
    final now = DateTime.now();

    for (var keys in _publicKeys.values) {
      for (var key in keys) {
        if (key.expiryDate != null) {
          final daysUntilExpiry = key.expiryDate!.difference(now).inDays;
          if (daysUntilExpiry > 0 && daysUntilExpiry <= daysThreshold) {
            expiringKeys.add(key);
          }
        }
      }
    }

    return expiringKeys;
  }
}

class PublicKey {
  final String algorithm;
  final Uint8List keyData;
  final String fingerprint;
  final DateTime? expiryDate;
  final String? keyId;
  final Map<String, dynamic>? metadata;

  PublicKey({
    required this.algorithm,
    required this.keyData,
    required this.fingerprint,
    this.expiryDate,
    this.keyId,
    this.metadata,
  });

  factory PublicKey.fromJson(Map<String, dynamic> json) {
    return PublicKey(
      algorithm: json['algorithm'],
      keyData: base64.decode(json['keyData']),
      fingerprint: json['fingerprint'],
      expiryDate: json['expiryDate'] != null ? DateTime.parse(json['expiryDate']) : null,
      keyId: json['keyId'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'algorithm': algorithm,
      'keyData': base64.encode(keyData),
      'fingerprint': fingerprint,
      'expiryDate': expiryDate?.toIso8601String(),
      'keyId': keyId,
      'metadata': metadata,
    };
  }

  bool verifySignature(String data, String signature) {
    try {
      // تنفيذ التحقق من التوقيع حسب الخوارزمية
      if (algorithm == 'RSA') {
        // استخدام مكتبة التشفير للتحقق من توقيع RSA
        return _verifyRSASignature(data, signature);
      } else if (algorithm == 'ECDSA') {
        // استخدام مكتبة التشفير للتحقق من توقيع ECDSA
        return _verifyECDSASignature(data, signature);
      }

      throw Exception('Unsupported algorithm: $algorithm');
    } catch (e) {
      return false;
    }
  }

  bool _verifyRSASignature(String data, String signature) {
    // تنفيذ التحقق من توقيع RSA
    // هذا مثال مبسط - يجب استخدام مكتبة تشفير حقيقية
    final dataHash = sha256.convert(utf8.encode(data));
    final signatureBytes = base64.decode(signature);

    // التحقق من التوقيع باستخدام المفتاح العام
    // يتطلب تنفيذاً فعلياً باستخدام مكتبة مثل pointycastle
    return true; // placeholder
  }

  bool _verifyECDSASignature(String data, String signature) {
    // تنفيذ التحقق من توقيع ECDSA
    // هذا مثال مبسط - يجب استخدام مكتبة تشفير حقيقية
    final dataHash = sha256.convert(utf8.encode(data));
    final signatureBytes = base64.decode(signature);

    // التحقق من التوقيع باستخدام المفتاح العام
    // يتطلب تنفيذاً فعلياً باستخدام مكتبة مثل pointycastle
    return true; // placeholder
  }

  Uint8List encrypt(Uint8List data) {
    // تشفير البيانات باستخدام المفتاح العام
    // يتطلب تنفيذاً فعلياً باستخدام مكتبة تشفير
    return data; // placeholder
  }

  static String calculateFingerprint(Uint8List keyData) {
    final digest = sha256.convert(keyData);
    return digest.toString();
  }
}