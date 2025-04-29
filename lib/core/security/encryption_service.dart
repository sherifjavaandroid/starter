import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encryptp;
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:flutter/foundation.dart';

import '../utils/secure_logger.dart';
import 'secure_storage_service.dart';

class EncryptionService {
  final SecureStorageService _storageService;
  final SecureLogger _logger;

  // خوارزميات التشفير
  static const String _aesAlgorithm = 'AES/GCM/NoPadding';
  static const String _rsaAlgorithm = 'RSA/ECB/OAEPWithSHA-256AndMGF1Padding';

  // أحجام المفاتيح
  static const int _aesKeySize = 256;
  static const int _rsaKeySize = 4096;
  static const int _ivSize = 12;
  static const int _tagSize = 128;

  // مفاتيح التخزين
  static const String _aesKeyId = 'aes_master_key';
  static const String _rsaPublicKeyId = 'rsa_public_key';
  static const String _rsaPrivateKeyId = 'rsa_private_key';

  encryptp.Encrypter? _aesEncrypter;
  RSAPublicKey? _rsaPublicKey;
  RSAPrivateKey? _rsaPrivateKey;
  final SecureRandom _secureRandom = FortunaRandom();

  EncryptionService(this._storageService, this._logger);

  // ---------- METHODS REQUIRED BY AuthLocalDataSourceImpl ----------

  /// Method to encrypt data - required by AuthLocalDataSourceImpl
  Future<String> encrypt(String plainText) async {
    try {
      if (_aesEncrypter == null) {
        await initialize();
      }

      // إنشاء IV عشوائي
      final iv = await generateIv();

      // تشفير البيانات
      final encryptedBytes = await encryptData(plainText, nonce: iv);

      // تحويل البيانات المشفرة إلى سلسلة نصية
      final result = {
        'iv': base64.encode(iv),
        'data': base64.encode(encryptedBytes),
      };

      return json.encode(result);
    } catch (e) {
      _logger.log(
        'Encryption failed in encrypt method: $e',
        level: LogLevel.error,
        category: SecurityCategory.encryption,
      );
      rethrow;
    }
  }

  /// Method to decrypt data - required by AuthLocalDataSourceImpl
  Future<String> decrypt(String encryptedText) async {
    try {
      if (_aesEncrypter == null) {
        await initialize();
      }

      final Map<String, dynamic> encryptedData = json.decode(encryptedText);
      final iv = base64.decode(encryptedData['iv']);
      final data = base64.decode(encryptedData['data']);

      return await decryptData(data, nonce: iv);
    } catch (e) {
      _logger.log(
        'Decryption failed in decrypt method: $e',
        level: LogLevel.error,
        category: SecurityCategory.decryption,
      );
      rethrow;
    }
  }

  // ---------- ORIGINAL METHODS ----------

  Future<void> initialize() async {
    try {
      _initializeSecureRandom();
      await _initializeKeys();

      _logger.log(
        'Encryption service initialized successfully',
        level: LogLevel.info,
        category: SecurityCategory.encryption,
      );
    } catch (e) {
      _logger.log(
        'Encryption service initialization failed: $e',
        level: LogLevel.critical,
        category: SecurityCategory.encryption,
      );
      rethrow;
    }
  }

  void _initializeSecureRandom() {
    final seedSource = _createCryptographicallySecureSeed();
    _secureRandom.seed(KeyParameter(seedSource));
  }

  Uint8List _createCryptographicallySecureSeed() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure();
    final seed = Uint8List(32);

    for (int i = 0; i < seed.length; i++) {
      seed[i] = random.nextInt(256);
    }

    // إضافة الختم الزمني للعشوائية
    final timestampBytes = ByteData(8)..setInt64(0, timestamp);
    for (int i = 0; i < 8; i++) {
      seed[i] ^= timestampBytes.getUint8(i);
    }

    return seed;
  }

  Future<void> _initializeKeys() async {
    // محاولة تحميل المفاتيح الموجودة
    await _loadExistingKeys();

    // إنشاء مفاتيح جديدة إذا لم تكن موجودة
    if (_aesEncrypter == null || _rsaPublicKey == null || _rsaPrivateKey == null) {
      await _generateNewKeys();
    }
  }

  Future<void> _loadExistingKeys() async {
    try {
      // تحميل مفتاح AES
      final aesKeyData = await _storageService.getSecureData(_aesKeyId);
      if (aesKeyData != null) {
        final aesKey = encryptp.Key.fromBase64(aesKeyData);
        _aesEncrypter = encryptp.Encrypter(encryptp.AES(aesKey, mode: encryptp.AESMode.gcm));
      }

      // تحميل مفاتيح RSA
      final publicKeyData = await _storageService.getSecureData(_rsaPublicKeyId);
      final privateKeyData = await _storageService.getSecureData(_rsaPrivateKeyId);

      if (publicKeyData != null && privateKeyData != null) {
        _rsaPublicKey = _deserializeRSAPublicKey(publicKeyData);
        _rsaPrivateKey = _deserializeRSAPrivateKey(privateKeyData);
      }
    } catch (e) {
      _logger.log(
        'Failed to load existing keys: $e',
        level: LogLevel.warning,
        category: SecurityCategory.encryption,
      );
    }
  }

  Future<void> _generateNewKeys() async {
    // إنشاء مفتاح AES جديد
    final aesKey = _generateSecureKey(_aesKeySize ~/ 8);
    _aesEncrypter = encryptp.Encrypter(encryptp.AES(
      encryptp.Key(aesKey),
      mode: encryptp.AESMode.gcm,
    ));

    // إنشاء زوج مفاتيح RSA جديد
    final rsaKeyPair = _generateRSAKeyPair();
    _rsaPublicKey = rsaKeyPair.publicKey as RSAPublicKey;
    _rsaPrivateKey = rsaKeyPair.privateKey as RSAPrivateKey;

    // حفظ المفاتيح
    await _saveKeys(aesKey);
  }

  Uint8List _generateSecureKey(int length) {
    return _secureRandom.nextBytes(length);
  }

  AsymmetricKeyPair<PublicKey, PrivateKey> _generateRSAKeyPair() {
    final keyParams = RSAKeyGeneratorParameters(BigInt.parse('65537'), _rsaKeySize, 64);
    final keyGenerator = RSAKeyGenerator()
      ..init(ParametersWithRandom(keyParams, _secureRandom));

    return keyGenerator.generateKeyPair();
  }

  Future<void> _saveKeys(Uint8List aesKey) async {
    await _storageService.saveSecureData(
      _aesKeyId,
      base64.encode(aesKey),
    );

    await _storageService.saveSecureData(
      _rsaPublicKeyId,
      _serializeRSAPublicKey(_rsaPublicKey!),
    );

    await _storageService.saveSecureData(
      _rsaPrivateKeyId,
      _serializeRSAPrivateKey(_rsaPrivateKey!),
    );
  }

  Future<Uint8List> encryptData(String data, {Uint8List? nonce}) async {
    if (_aesEncrypter == null) {
      throw SecurityException('Encryption service not initialized');
    }

    try {
      // إنشاء IV عشوائي
      final iv = nonce ?? _generateSecureKey(_ivSize);

      // تشفير البيانات
      final encrypted = _aesEncrypter!.encrypt(
        data,
        iv: encryptp.IV(iv),
      );

      // دمج IV مع البيانات المشفرة
      final combined = Uint8List(iv.length + encrypted.bytes.length);
      combined.setRange(0, iv.length, iv);
      combined.setRange(iv.length, combined.length, encrypted.bytes);

      return combined;
    } catch (e) {
      _logger.log(
        'Data encryption failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.encryption,
      );
      rethrow;
    }
  }

  Future<String> decryptData(Uint8List encryptedData, {Uint8List? nonce}) async {
    if (_aesEncrypter == null) {
      throw SecurityException('Encryption service not initialized');
    }

    try {
      // استخراج IV من البيانات المشفرة
      Uint8List iv;
      Uint8List ciphertext;

      if (nonce != null) {
        iv = nonce;
        ciphertext = encryptedData;
      } else {
        iv = encryptedData.sublist(0, _ivSize);
        ciphertext = encryptedData.sublist(_ivSize);
      }

      // فك التشفير
      final decrypted = _aesEncrypter!.decrypt(
        encryptp.Encrypted(ciphertext),
        iv: encryptp.IV(iv),
      );

      return decrypted;
    } catch (e) {
      _logger.log(
        'Data decryption failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.decryption,
      );
      rethrow;
    }
  }

  Future<Uint8List> deriveKey(String password, Uint8List salt, {int iterations = 100000}) async {
    // استخدام PBKDF2 لاشتقاق المفتاح
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));

    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  Future<String> generateHmac(String data) async {
    final key = _generateSecureKey(32);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }

  Future<bool> verifyHmac(String data, String hmacString) async {
    try {
      final hmacKey = _generateSecureKey(32);
      final hmac = Hmac(sha256, hmacKey);
      final digest = hmac.convert(utf8.encode(data));
      return digest.toString() == hmacString;
    } catch (e) {
      return false;
    }
  }

  Future<String> hashData(String data) async {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> encryptWithRSA(String data) async {
    if (_rsaPublicKey == null) {
      throw SecurityException('RSA public key not initialized');
    }

    try {
      final cipher = OAEPEncoding(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(_rsaPublicKey!));

      final input = Uint8List.fromList(utf8.encode(data));
      final output = cipher.process(input);

      return base64.encode(output);
    } catch (e) {
      _logger.log(
        'RSA encryption failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.encryption,
      );
      rethrow;
    }
  }

  Future<String> decryptWithRSA(String encryptedData) async {
    if (_rsaPrivateKey == null) {
      throw SecurityException('RSA private key not initialized');
    }

    try {
      final cipher = OAEPEncoding(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(_rsaPrivateKey!));

      final input = base64.decode(encryptedData);
      final output = cipher.process(input);

      return utf8.decode(output);
    } catch (e) {
      _logger.log(
        'RSA decryption failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.decryption,
      );
      rethrow;
    }
  }

  Future<Uint8List> generateIv() async {
    return _generateSecureKey(_ivSize);
  }

  String _serializeRSAPublicKey(RSAPublicKey key) {
    final params = {
      'modulus': key.modulus.toString(),
      'exponent': key.exponent.toString(),
    };
    return json.encode(params);
  }

  RSAPublicKey _deserializeRSAPublicKey(String serialized) {
    final params = json.decode(serialized);
    return RSAPublicKey(
      BigInt.parse(params['modulus']),
      BigInt.parse(params['exponent']),
    );
  }

  String _serializeRSAPrivateKey(RSAPrivateKey key) {
    final params = {
      'modulus': key.modulus.toString(),
      'privateExponent': key.privateExponent.toString(),
      'p': key.p.toString(),
      'q': key.q.toString(),
    };
    return json.encode(params);
  }

  RSAPrivateKey _deserializeRSAPrivateKey(String serialized) {
    final params = json.decode(serialized);
    return RSAPrivateKey(
      BigInt.parse(params['modulus']),
      BigInt.parse(params['privateExponent']),
      BigInt.parse(params['p']),
      BigInt.parse(params['q']),
    );
  }

  Future<void> rotateKeys() async {
    await _generateNewKeys();
    _logger.log(
      'Encryption keys rotated successfully',
      level: LogLevel.info,
      category: SecurityCategory.encryption,
    );
  }

  Future<void> clearKeys() async {
    await _storageService.deleteSecureData(_aesKeyId);
    await _storageService.deleteSecureData(_rsaPublicKeyId);
    await _storageService.deleteSecureData(_rsaPrivateKeyId);

    _aesEncrypter = null;
    _rsaPublicKey = null;
    _rsaPrivateKey = null;
  }

  /// إعادة تشفير البيانات باستخدام مفتاح جديد
  Future<String> reEncryptData(String encryptedText) async {
    // فك تشفير البيانات باستخدام المفتاح الحالي
    final decryptedData = await decrypt(encryptedText);

    // إنشاء مفاتيح جديدة
    await rotateKeys();

    // إعادة تشفير البيانات بالمفتاح الجديد
    return await encrypt(decryptedData);
  }

  /// التحقق من صحة التشفير
  Future<bool> verifyEncryption(String plainText, String encryptedText) async {
    try {
      final decrypted = await decrypt(encryptedText);
      return decrypted == plainText;
    } catch (e) {
      return false;
    }
  }

  /// تشفير ملف كامل
  Future<Uint8List> encryptFile(Uint8List fileData) async {
    final iv = await generateIv();
    final encrypted = _aesEncrypter!.encryptBytes(
      fileData,
      iv: encryptp.IV(iv),
    );

    // دمج IV مع البيانات المشفرة
    final combined = Uint8List(iv.length + encrypted.bytes.length);
    combined.setRange(0, iv.length, iv);
    combined.setRange(iv.length, combined.length, encrypted.bytes);

    return combined;
  }

  /// فك تشفير ملف
  Future<Uint8List> decryptFile(Uint8List encryptedFile) async {
    final iv = encryptedFile.sublist(0, _ivSize);
    final encrypted = encryptedFile.sublist(_ivSize);

    final decrypted = _aesEncrypter!.decryptBytes(
      encryptp.Encrypted(encrypted),
      iv: encryptp.IV(iv),
    );

    return Uint8List.fromList(decrypted);
  }

  /// إنشاء توقيع رقمي للبيانات
  Future<String> signData(String data) async {
    if (_rsaPrivateKey == null) {
      throw SecurityException('RSA private key not initialized');
    }

    try {
      final dataHash = sha256.convert(utf8.encode(data)).bytes;
      final signer = Signer('SHA-256/RSA')
        ..init(true, PrivateKeyParameter<RSAPrivateKey>(_rsaPrivateKey!));

      final signature = signer.generateSignature(Uint8List.fromList(dataHash));
      return base64.encode((signature as RSASignature).bytes);
    } catch (e) {
      _logger.log(
        'Failed to create digital signature: $e',
        level: LogLevel.error,
        category: SecurityCategory.encryption,
      );
      rethrow;
    }
  }

  /// التحقق من صحة التوقيع الرقمي
  Future<bool> verifySignature(String data, String signature) async {
    if (_rsaPublicKey == null) {
      throw SecurityException('RSA public key not initialized');
    }

    try {
      final dataHash = sha256.convert(utf8.encode(data)).bytes;
      final verifier = Signer('SHA-256/RSA')
        ..init(false, PublicKeyParameter<RSAPublicKey>(_rsaPublicKey!));

      final signatureBytes = base64.decode(signature);
      return verifier.verifySignature(
        Uint8List.fromList(dataHash),
        RSASignature(signatureBytes),
      );
    } catch (e) {
      _logger.log(
        'Signature verification failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.encryption,
      );
      return false;
    }
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}