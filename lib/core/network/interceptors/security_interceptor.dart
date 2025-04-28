import 'package:dio/dio.dart';
import '../../security/security_manager.dart';
import '../../security/rate_limiter_service.dart';
import '../../security/root_detection_service.dart';
import '../../security/anti_tampering_service.dart';
import '../../utils/secure_logger.dart';
import '../../utils/device_info_service.dart';

class SecurityInterceptor extends Interceptor {
  final SecurityManager _securityManager;
  final RateLimiterService _rateLimiterService;
  final RootDetectionService _rootDetectionService;
  final AntiTamperingService _antiTamperingService;
  final DeviceInfoService _deviceInfoService;
  final SecureLogger _logger;

  SecurityInterceptor(
      this._securityManager,
      this._rateLimiterService,
      this._rootDetectionService,
      this._antiTamperingService,
      this._deviceInfoService,
      this._logger,
      );

  @override
  Future<void> onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) async {
    try {
      // التحقق من سلامة البيئة
      await _checkEnvironmentSecurity();

      // التحقق من معدل الطلبات
      if (!await _checkRateLimit(options)) {
        throw RateLimitException();
      }

      // التحقق من صحة الطلب
      final isValid = await _securityManager.validateRequest(
        path: options.path,
        params: _getRequestParams(options),
        method: options.method,
      );

      if (!isValid) {
        throw SecurityViolationException('Invalid request');
      }

      // إضافة رؤوس الأمان
      await _addSecurityHeaders(options);

      // تحديث نشاط المستخدم
      _securityManager.updateLastActivity();

      handler.next(options);
    } catch (e) {
      _logger.log(
        'Security interceptor error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      handler.reject(DioError(requestOptions: options, error: e));
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // التحقق من رؤوس الأمان في الاستجابة
    _validateResponseSecurity(response);

    // تحديث نشاط المستخدم
    _securityManager.updateLastActivity();

    handler.next(response);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    // تسجيل الأخطاء الأمنية
    if (err.error is SecurityViolationException) {
      _logger.log(
        'Security violation: ${err.error}',
        level: LogLevel.critical,
        category: SecurityCategory.security,
      );
    }

    handler.next(err);
  }

  Future<void> _checkEnvironmentSecurity() async {
    // التحقق من الجذر/الجيلبريك
    if (await _rootDetectionService.isDeviceRooted()) {
      throw SecurityViolationException('Device is rooted');
    }

    // التحقق من سلامة التطبيق
    if (!await _antiTamperingService.isAppIntegrityValid()) {
      throw SecurityViolationException('App integrity compromised');
    }

    // التحقق من التصحيح
    if (await _antiTamperingService.isDebuggingEnabled()) {
      throw SecurityViolationException('Debugging detected');
    }

    // التحقق من حقن الكود
    if (await _antiTamperingService.detectCodeInjection()) {
      throw SecurityViolationException('Code injection detected');
    }
  }

  Future<bool> _checkRateLimit(RequestOptions options) async {
    final userId = options.extra['userId'] as String?;

    return await _rateLimiterService.checkRateLimit(
      options.path,
      options.method,
      userId: userId,
    );
  }

  Map<String, dynamic> _getRequestParams(RequestOptions options) {
    if (options.method == 'GET' || options.method == 'DELETE') {
      return options.queryParameters;
    } else {
      return options.data is Map<String, dynamic> ? options.data : {};
    }
  }

  Future<void> _addSecurityHeaders(RequestOptions options) async {
    // إضافة معرف الجهاز
    final deviceId = await _deviceInfoService.getDeviceId();
    options.headers['X-Device-ID'] = deviceId;

    // إضافة معلومات الجهاز
    final deviceInfo = await _deviceInfoService.getDeviceInfo();
    options.headers['X-Device-Info'] = deviceInfo;

    // إضافة معرف الطلب الفريد
    options.headers['X-Request-ID'] = DateTime.now().millisecondsSinceEpoch.toString();

    // إضافة توقيع الطلب
    final signature = await _generateRequestSignature(options);
    options.headers['X-Request-Signature'] = signature;

    // إضافة نسخة التطبيق
    options.headers['X-App-Version'] = '1.0.0';

    // إضافة نظام التشغيل
    options.headers['X-OS'] = await _deviceInfoService.getOS();

    // إضافة الطابع الزمني
    options.headers['X-Timestamp'] = DateTime.now().toUtc().toIso8601String();
  }

  Future<String> _generateRequestSignature(RequestOptions options) async {
    // إنشاء توقيع للطلب للتأكد من عدم التلاعب
    final signatureData = [
      options.method,
      options.path,
      options.headers['X-Timestamp'],
      options.headers['X-Device-ID'],
    ].join('|');

    return await _securityManager.generateRequestSignature(signatureData);
  }

  void _validateResponseSecurity(Response response) {
    // التحقق من وجود رؤوس الأمان المطلوبة
    final requiredHeaders = [
      'X-Security-Token',
      'X-Response-Signature',
      'Strict-Transport-Security',
      'X-Content-Type-Options',
      'X-Frame-Options',
      'X-XSS-Protection',
    ];

    for (var header in requiredHeaders) {
      if (response.headers.value(header) == null) {
        _logger.log(
          'Missing security header: $header',
          level: LogLevel.warning,
          category: SecurityCategory.security,
        );
      }
    }

    // التحقق من توقيع الاستجابة
    final signature = response.headers.value('X-Response-Signature');
    if (signature != null) {
      _verifyResponseSignature(response, signature);
    }
  }

  void _verifyResponseSignature(Response response, String signature) {
    // التحقق من توقيع الاستجابة
    // يمكن تنفيذ منطق التحقق هنا
  }
}

class RateLimitException implements Exception {
  final String message;
  RateLimitException([this.message = 'Rate limit exceeded']);

  @override
  String toString() => 'RateLimitException: $message';
}

class SecurityViolationException implements Exception {
  final String message;
  SecurityViolationException(this.message);

  @override
  String toString() => 'SecurityViolationException: $message';
}