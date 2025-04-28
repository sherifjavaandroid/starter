import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class NonceGeneratorService {
  final Random _secureRandom = Random.secure();
  final Map<String, DateTime> _nonceCache = {};

  // مدة صلاحية nonce (5 دقائق)
  static const Duration _nonceValidity = Duration(minutes: 5);

  /// توليد nonce عشوائي
  Future<Uint8List> generateNonce({int length = 16}) async {
    final nonce = Uint8List(length);
    for (int i = 0; i < length; i++) {
      nonce[i] = _secureRandom.nextInt(256);
    }
    return nonce;
  }

  /// توليد nonce نصي
  Future<String> generateStringNonce({int length = 32}) async {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buffer = StringBuffer();

    for (int i = 0; i < length; i++) {
      buffer.write(chars[_secureRandom.nextInt(chars.length)]);
    }

    return buffer.toString();
  }

  /// توليد nonce مع طابع زمني
  Future<String> generateTimestampedNonce() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = await generateStringNonce(length: 16);
    return '$timestamp-$randomPart';
  }

  /// توليد nonce مشفر
  Future<String> generateCryptographicNonce() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = await generateNonce(length: 32);

    final data = '$timestamp:${base64.encode(randomBytes)}';
    final hash = sha256.convert(utf8.encode(data));

    return hash.toString();
  }

  /// توليد nonce للطلبات
  Future<String> generateRequestNonce() async {
    final nonce = await generateCryptographicNonce();
    _nonceCache[nonce] = DateTime.now();
    _cleanupOldNonces();
    return nonce;
  }

  /// التحقق من صلاحية nonce
  bool validateNonce(String nonce) {
    if (!_nonceCache.containsKey(nonce)) {
      return false;
    }

    final creationTime = _nonceCache[nonce]!;
    final now = DateTime.now();

    if (now.difference(creationTime) > _nonceValidity) {
      _nonceCache.remove(nonce);
      return false;
    }

    return true;
  }

  /// استخدام nonce (يجعله غير صالح للاستخدام مرة أخرى)
  bool consumeNonce(String nonce) {
    if (!validateNonce(nonce)) {
      return false;
    }

    _nonceCache.remove(nonce);
    return true;
  }

  /// تنظيف nonces القديمة
  void _cleanupOldNonces() {
    final now = DateTime.now();
    _nonceCache.removeWhere((nonce, creationTime) {
      return now.difference(creationTime) > _nonceValidity;
    });
  }

  /// توليد nonce للتوقيع
  Future<Map<String, String>> generateSignatureNonce(String data) async {
    final nonce = await generateStringNonce();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    final signatureData = '$data:$nonce:$timestamp';
    final signature = sha256.convert(utf8.encode(signatureData)).toString();

    return {
      'nonce': nonce,
      'timestamp': timestamp,
      'signature': signature,
    };
  }

  /// التحقق من nonce التوقيع
  bool verifySignatureNonce(
      String data,
      String nonce,
      String timestamp,
      String signature,
      ) {
    try {
      final timestampMs = int.parse(timestamp);
      final nonceTime = DateTime.fromMillisecondsSinceEpoch(timestampMs);

      // التحقق من أن nonce ليس قديماً جداً
      if (DateTime.now().difference(nonceTime) > _nonceValidity) {
        return false;
      }

      // التحقق من التوقيع
      final signatureData = '$data:$nonce:$timestamp';
      final expectedSignature = sha256.convert(utf8.encode(signatureData)).toString();

      return signature == expectedSignature;
    } catch (e) {
      return false;
    }
  }

  /// توليد nonce للجلسة
  Future<String> generateSessionNonce(String userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = await generateStringNonce(length: 24);
    final sessionData = '$userId:$timestamp:$randomPart';

    final hash = sha256.convert(utf8.encode(sessionData));
    return base64Url.encode(hash.bytes);
  }

  /// توليد nonce للتحقق من CSRF
  Future<String> generateCsrfNonce() async {
    final nonce = await generateCryptographicNonce();
    final encoded = base64Url.encode(utf8.encode(nonce));
    return encoded.substring(0, 32); // طول ثابت
  }

  /// توليد nonce للتشفير
  Future<Uint8List> generateEncryptionNonce({int length = 12}) async {
    // طول IV القياسي لـ AES-GCM
    return await generateNonce(length: length);
  }

  /// توليد nonce للمصادقة
  Future<String> generateAuthNonce() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = await generateNonce(length: 16);

    final nonceData = {
      'ts': timestamp,
      'rnd': base64.encode(randomBytes),
    };

    final jsonData = json.encode(nonceData);
    return base64Url.encode(utf8.encode(jsonData));
  }

  /// التحقق من nonce المصادقة
  bool verifyAuthNonce(String nonce, {Duration maxAge = const Duration(minutes: 5)}) {
    try {
      final decoded = utf8.decode(base64Url.decode(nonce));
      final nonceData = json.decode(decoded);

      final timestamp = nonceData['ts'] as int;
      final nonceTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

      return DateTime.now().difference(nonceTime) <= maxAge;
    } catch (e) {
      return false;
    }
  }
}