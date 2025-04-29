import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../utils/secure_logger.dart';

class SecureStorageService {
  final SecureLogger _logger;
  late final FlutterSecureStorage _storage;
  encrypt.Encrypter? _encrypter;

  // مفتاح التشفير الإضافي
  static const String _storageKeyId = 'secure_storage_key';

  // خيارات التخزين الآمن
  final AndroidOptions _androidOptions = const AndroidOptions(
    encryptedSharedPreferences: true,
    keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
  );

  final IOSOptions _iosOptions = const IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    accountName: 'com.example.secure_app',
    synchronizable: false,
  );

  SecureStorageService(this._logger);

  Future<void> initialize() async {
    try {
      _storage = FlutterSecureStorage(
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

      // تهيئة مفتاح التشفير الإضافي
      await _initializeEncryptionKey();

      _logger.log(
        'Secure storage service initialized successfully',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Secure storage initialization failed: $e',
        level: LogLevel.critical,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> _initializeEncryptionKey() async {
    try {
      // محاولة تحميل المفتاح الموجود
      String? existingKey = await _storage.read(key: _storageKeyId);

      if (existingKey == null) {
        // إنشاء مفتاح جديد
        final key = _generateSecureKey();
        await _storage.write(key: _storageKeyId, value: base64.encode(key));
        _encrypter = encrypt.Encrypter(encrypt.AES(
          encrypt.Key(key),
          mode: encrypt.AESMode.gcm,
        ));
      } else {
        // استخدام المفتاح الموجود
        final key = base64.decode(existingKey);
        _encrypter = encrypt.Encrypter(encrypt.AES(
          encrypt.Key(key),
          mode: encrypt.AESMode.gcm,
        ));
      }
    } catch (e) {
      _logger.log(
        'Failed to initialize encryption key: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Uint8List _generateSecureKey() {
    final random = Random.secure();
    final key = Uint8List(32); // 256-bit key
    for (int i = 0; i < key.length; i++) {
      key[i] = random.nextInt(256);
    }
    return key;
  }

  // ---------- ADDED/MODIFIED METHODS TO MATCH AuthLocalDataSourceImpl REQUIREMENTS ----------

  /// Read data from secure storage (adapter method used by AuthLocalDataSourceImpl)
  Future<String?> read(String key) async {
    return await getSecureData(key);
  }

  /// Write data to secure storage (adapter method used by AuthLocalDataSourceImpl)
  Future<void> write(String key, String value) async {
    await saveSecureData(key, value);
  }

  /// Delete data from secure storage (adapter method used by AuthLocalDataSourceImpl)
  Future<void> delete(String key) async {
    await deleteSecureData(key);
  }

  // ---------- ORIGINAL METHODS ----------

  Future<void> saveSecureData(String key, String value, {bool useEncryption = true}) async {
    try {
      if (useEncryption && _encrypter != null) {
        // تشفير البيانات قبل حفظها
        final iv = encrypt.IV.fromSecureRandom(16);
        final encrypted = _encrypter!.encrypt(value, iv: iv);

        // دمج IV مع البيانات المشفرة
        final combined = {
          'iv': base64.encode(iv.bytes),
          'data': encrypted.base64,
        };

        await _storage.write(key: key, value: json.encode(combined));
      } else {
        // حفظ البيانات بدون تشفير إضافي
        await _storage.write(key: key, value: value);
      }

      _logger.log(
        'Data saved securely with key: $key',
        level: LogLevel.debug,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to save secure data: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<String?> getSecureData(String key, {bool decrypt = true}) async {
    try {
      final value = await _storage.read(key: key);

      if (value == null) return null;

      if (decrypt && _encrypter != null) {
        // محاولة فك تشفير البيانات
        try {
          final combined = json.decode(value);
          final iv = encrypt.IV.fromBase64(combined['iv']);
          final encryptedData = encrypt.Encrypted.fromBase64(combined['data']);

          return _encrypter!.decrypt(encryptedData, iv: iv);
        } catch (e) {
          // في حالة فشل فك التشفير، إرجاع البيانات كما هي
          _logger.log(
            'Failed to decrypt data, returning raw: $e',
            level: LogLevel.warning,
            category: SecurityCategory.security,
          );
          return value;
        }
      } else {
        return value;
      }
    } catch (e) {
      _logger.log(
        'Failed to retrieve secure data: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return null;
    }
  }

  Future<void> deleteSecureData(String key) async {
    try {
      await _storage.delete(key: key);
      _logger.log(
        'Data deleted securely with key: $key',
        level: LogLevel.debug,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to delete secure data: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
      // إعادة تهيئة مفتاح التشفير
      await _initializeEncryptionKey();

      _logger.log(
        'All secure data deleted',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to delete all secure data: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<Map<String, String>> getAllData() async {
    try {
      return await _storage.readAll();
    } catch (e) {
      _logger.log(
        'Failed to read all secure data: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return {};
    }
  }

  Future<bool> containsKey(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value != null;
    } catch (e) {
      _logger.log(
        'Failed to check key existence: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  // حفظ بيانات حساسة مع زمن انتهاء
  Future<void> saveTemporaryData(String key, String value, Duration expiration) async {
    try {
      final expiryTime = DateTime.now().add(expiration);
      final wrappedData = {
        'value': value,
        'expiry': expiryTime.toIso8601String(),
      };

      await saveSecureData(key, json.encode(wrappedData));
    } catch (e) {
      _logger.log(
        'Failed to save temporary data: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  // استرجاع بيانات مؤقتة مع التحقق من الانتهاء
  Future<String?> getTemporaryData(String key) async {
    try {
      final data = await getSecureData(key);
      if (data == null) return null;

      final wrappedData = json.decode(data);
      final expiryTime = DateTime.parse(wrappedData['expiry']);

      if (DateTime.now().isAfter(expiryTime)) {
        // حذف البيانات المنتهية
        await deleteSecureData(key);
        return null;
      }

      return wrappedData['value'];
    } catch (e) {
      _logger.log(
        'Failed to get temporary data: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return null;
    }
  }

  // حفظ كائن معقد بشكل آمن
  Future<void> saveSecureObject<T>(String key, T object, String Function(T) toJson) async {
    try {
      final jsonString = toJson(object);
      await saveSecureData(key, jsonString);
    } catch (e) {
      _logger.log(
        'Failed to save secure object: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  // استرجاع كائن معقد
  Future<T?> getSecureObject<T>(String key, T Function(String) fromJson) async {
    try {
      final jsonString = await getSecureData(key);
      if (jsonString == null) return null;

      return fromJson(jsonString);
    } catch (e) {
      _logger.log(
        'Failed to get secure object: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return null;
    }
  }

  // تنظيف البيانات المنتهية
  Future<void> cleanExpiredData() async {
    try {
      final allData = await getAllData();
      for (var entry in allData.entries) {
        try {
          final data = json.decode(entry.value);
          if (data.containsKey('expiry')) {
            final expiryTime = DateTime.parse(data['expiry']);
            if (DateTime.now().isAfter(expiryTime)) {
              await deleteSecureData(entry.key);
            }
          }
        } catch (_) {
          // تجاهل البيانات غير المؤقتة
        }
      }
    } catch (e) {
      _logger.log(
        'Failed to clean expired data: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  // إضافة حماية إضافية للبيانات فائقة الحساسية
  Future<void> saveUltraSecureData(String key, String value) async {
    try {
      // تشفير البيانات مرتين
      if (_encrypter != null) {
        // التشفير الأول
        final iv1 = encrypt.IV.fromSecureRandom(16);
        final encrypted1 = _encrypter!.encrypt(value, iv: iv1);

        // التشفير الثاني
        final iv2 = encrypt.IV.fromSecureRandom(16);
        final encrypted2 = _encrypter!.encrypt(encrypted1.base64, iv: iv2);

        final combined = {
          'iv1': base64.encode(iv1.bytes),
          'iv2': base64.encode(iv2.bytes),
          'data': encrypted2.base64,
        };

        await _storage.write(key: key, value: json.encode(combined));
      } else {
        await saveSecureData(key, value);
      }
    } catch (e) {
      _logger.log(
        'Failed to save ultra secure data: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  // استرجاع البيانات فائقة الحساسية
  Future<String?> getUltraSecureData(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value == null) return null;

      if (_encrypter != null) {
        try {
          final combined = json.decode(value);
          final iv1 = encrypt.IV.fromBase64(combined['iv1']);
          final iv2 = encrypt.IV.fromBase64(combined['iv2']);
          final encryptedData = encrypt.Encrypted.fromBase64(combined['data']);

          // فك التشفير الثاني
          final decrypted2 = _encrypter!.decrypt(encryptedData, iv: iv2);
          final encrypted1 = encrypt.Encrypted.fromBase64(decrypted2);

          // فك التشفير الأول
          return _encrypter!.decrypt(encrypted1, iv: iv1);
        } catch (e) {
          _logger.log(
            'Failed to decrypt ultra secure data: $e',
            level: LogLevel.error,
            category: SecurityCategory.security,
          );
          return null;
        }
      } else {
        return value;
      }
    } catch (e) {
      _logger.log(
        'Failed to retrieve ultra secure data: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return null;
    }
  }

  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      await _initializeEncryptionKey();

      _logger.log(
        'All secure data cleared',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Failed to clear all secure data: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }
}