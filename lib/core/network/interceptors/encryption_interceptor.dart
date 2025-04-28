import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../security/encryption_service.dart';
import '../../security/security_manager.dart';
import '../../utils/secure_logger.dart' as logger_util;

class EncryptionInterceptor extends Interceptor {
  final EncryptionService _encryptionService;
  final SecurityManager _securityManager;
  final logger_util.SecureLogger _logger;

  // مسارات مستثناة من التشفير
  final List<String> _excludedPaths = [
    '/auth/refresh',
    '/public/*',
    '/health-check',
  ];

  EncryptionInterceptor(
      this._encryptionService,
      this._securityManager,
      this._logger,
      );

  @override
  Future<void> onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) async {
    try {
      // التحقق من استثناء المسار
      if (_isPathExcluded(options.path)) {
        return handler.next(options);
      }

      // تشفير البيانات في حالة POST/PUT/PATCH
      if (_shouldEncryptRequest(options)) {
        final encryptedData = await _encryptRequestData(options.data);
        options.data = encryptedData;

        // إضافة رأس للإشارة إلى أن البيانات مشفرة
        options.headers['X-Encrypted-Content'] = 'true';
        options.headers['X-Encryption-Version'] = '1.0';
      }

      // تشفير المعاملات في URL
      if (options.queryParameters.isNotEmpty) {
        final encryptedParams = await _encryptQueryParameters(options.queryParameters);
        options.queryParameters = encryptedParams;
      }

      handler.next(options);
    } catch (e) {
      _logger.log(
        'Encryption interceptor error: $e',
        level: logger_util.LogLevel.error,
        category: logger_util.SecurityCategory.encryption,
      );
      handler.reject(DioException(requestOptions: options, error: e));
    }
  }

  @override
  Future<void> onResponse(
      Response response,
      ResponseInterceptorHandler handler,
      ) async {
    try {
      // التحقق من وجود بيانات مشفرة في الاستجابة
      if (response.headers.value('X-Encrypted-Content') == 'true') {
        final decryptedData = await _decryptResponseData(response.data);
        response.data = decryptedData;
      }

      handler.next(response);
    } catch (e) {
      _logger.log(
        'Decryption interceptor error: $e',
        level: logger_util.LogLevel.error,
        category: logger_util.SecurityCategory.decryption,
      );
      handler.reject(DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: e,
      ));
    }
  }

  bool _isPathExcluded(String path) {
    return _excludedPaths.any((pattern) {
      if (pattern.endsWith('*')) {
        final prefix = pattern.substring(0, pattern.length - 1);
        return path.startsWith(prefix);
      }
      return path == pattern;
    });
  }

  bool _shouldEncryptRequest(RequestOptions options) {
    return options.method == 'POST' ||
        options.method == 'PUT' ||
        options.method == 'PATCH';
  }

  Future<Map<String, dynamic>> _encryptRequestData(dynamic data) async {
    if (data == null) return {};

    // إنشاء nonce جديد
    final nonce = await _generateNonce();

    // تحويل البيانات إلى JSON
    final jsonData = data is Map ? data : {'data': data};
    final jsonString = json.encode(jsonData);

    // تشفير البيانات
    final encryptedData = await _encryptionService.encryptData(
      jsonString,
      nonce: nonce,
    );

    // إنشاء توقيع للتحقق من السلامة
    final signature = await _encryptionService.generateHmac(base64.encode(encryptedData));

    return {
      'data': base64.encode(encryptedData),
      'nonce': base64.encode(nonce),
      'signature': signature,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<Map<String, dynamic>> _encryptQueryParameters(
      Map<String, dynamic> params,
      ) async {
    if (params.isEmpty) return params;

    final encryptedParams = <String, dynamic>{};

    for (var entry in params.entries) {
      // تشفير القيم فقط
      final encryptedValue = await _encryptionService.encryptData(
        entry.value.toString(),
      );
      encryptedParams[entry.key] = base64.encode(encryptedValue);
    }

    return encryptedParams;
  }

  Future<dynamic> _decryptResponseData(dynamic data) async {
    if (data == null) return null;

    if (data is Map<String, dynamic>) {
      // التحقق من وجود البيانات المطلوبة
      if (!data.containsKey('data') ||
          !data.containsKey('nonce') ||
          !data.containsKey('signature')) {
        throw SecurityException('Invalid encrypted response format');
      }

      // التحقق من التوقيع
      final isValid = await _encryptionService.verifyHmac(
        data['data'],
        data['signature'],
      );

      if (!isValid) {
        throw SecurityException('Invalid response signature');
      }

      // فك تشفير البيانات
      final encryptedData = base64.decode(data['data']);
      final nonce = base64.decode(data['nonce']);

      final decryptedData = await _encryptionService.decryptData(
        encryptedData,
        nonce: nonce,
      );

      // تحويل من JSON
      return json.decode(decryptedData);
    }

    return data;
  }

  Future<Uint8List> _generateNonce() async {
    // استخدام خدمة التشفير لإنشاء nonce آمن
    return await _encryptionService.generateIv();
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}