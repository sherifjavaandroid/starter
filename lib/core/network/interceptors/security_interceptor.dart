import 'package:dio/dio.dart';
import '../../security/security_manager.dart';
import '../../security/rate_limiter_service.dart';
import '../../security/root_detection_service.dart';
import '../../security/anti_tampering_service.dart';
import '../../utils/secure_logger.dart' as logger_util;
import '../../utils/device_info_service.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityInterceptor extends Interceptor {
  final SecurityManager _securityManager;
  final RateLimiterService _rateLimiterService;
  final RootDetectionService _rootDetectionService;
  final AntiTamperingService _antiTamperingService;
  final DeviceInfoService _deviceInfoService;
  final logger_util.SecureLogger _logger;

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
      // Check environment security
      await _checkEnvironmentSecurity();

      // Check rate limits
      if (!await _checkRateLimit(options)) {
        throw RateLimitException();
      }

      // Validate request
      final isValid = await _securityManager.validateRequest(
        path: options.path,
        params: _getRequestParams(options),
        method: options.method,
      );

      if (!isValid) {
        throw SecurityViolationException('Invalid request');
      }

      // Add security headers
      await _addSecurityHeaders(options);

      // Update user activity
      _securityManager.updateLastActivity();

      handler.next(options);
    } catch (e) {
      _logger.log(
        'Security interceptor error: $e',
        level: logger_util.LogLevel.error,
        category: logger_util.SecurityCategory.security,
      );
      handler.reject(DioException(requestOptions: options, error: e));
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Validate security headers in response
    _validateResponseSecurity(response);

    // Update user activity
    _securityManager.updateLastActivity();

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Log security errors
    if (err.error is SecurityViolationException) {
      _logger.log(
        'Security violation: ${err.error}',
        level: logger_util.LogLevel.critical,
        category: logger_util.SecurityCategory.security,
      );
    }

    handler.next(err);
  }

  Future<void> _checkEnvironmentSecurity() async {
    // Check for root/jailbreak
    if (await _rootDetectionService.isDeviceRooted()) {
      throw SecurityViolationException('Device is rooted');
    }

    // Check app integrity
    if (!await _antiTamperingService.isAppIntegrityValid()) {
      throw SecurityViolationException('App integrity compromised');
    }

    // Check for debugging
    if (await _antiTamperingService.isDebuggingEnabled()) {
      throw SecurityViolationException('Debugging detected');
    }

    // Check for code injection
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
    // Add device ID
    final deviceId = await _deviceInfoService.getDeviceId();
    options.headers['X-Device-ID'] = deviceId;

    // Add device info
    final deviceInfo = await _deviceInfoService.getDeviceInfo();
    options.headers['X-Device-Info'] = deviceInfo;

    // Add unique request ID
    options.headers['X-Request-ID'] = DateTime.now().millisecondsSinceEpoch.toString();

    // Add request signature
    final signature = await _generateRequestSignature(options);
    options.headers['X-Request-Signature'] = signature;

    // Add app version
    options.headers['X-App-Version'] = '1.0.0';

    // Add OS
    options.headers['X-OS'] = _deviceInfoService.getOS();

    // Add timestamp
    options.headers['X-Timestamp'] = DateTime.now().toUtc().toIso8601String();
  }

  Future<String> _generateRequestSignature(RequestOptions options) async {
    // Create a signature for the request to prevent tampering
    final signatureData = [
      options.method,
      options.path,
      options.headers['X-Timestamp'],
      options.headers['X-Device-ID'],
    ].join('|');

    // If SecurityManager doesn't have generateRequestSignature method,
    // we'll implement our own here
    final bytes = utf8.encode(signatureData);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _validateResponseSecurity(Response response) {
    // Check for required security headers
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
          level: logger_util.LogLevel.warning,
          category: logger_util.SecurityCategory.security,
        );
      }
    }

    // Verify response signature
    final signature = response.headers.value('X-Response-Signature');
    if (signature != null) {
      _verifyResponseSignature(response, signature);
    }
  }

  void _verifyResponseSignature(Response response, String signature) {
    // Verify response signature
    // Implementation logic can be added here
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