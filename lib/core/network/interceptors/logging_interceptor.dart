import 'dart:convert';
import 'package:dio/dio.dart';
import '../../utils/secure_logger.dart';

class LoggingInterceptor extends Interceptor {
  final SecureLogger _logger;
  final bool logRequestBody;
  final bool logResponseBody;
  final bool logHeaders;
  final int maxBodyLength;

  // قائمة المسارات المستثناة من التسجيل
  final List<String> _excludedPaths = [
    '/auth/login',
    '/auth/register',
    '/user/password',
  ];

  // قائمة الرؤوس الحساسة
  final List<String> _sensitiveHeaders = [
    'authorization',
    'x-api-key',
    'x-auth-token',
    'cookie',
    'set-cookie',
  ];

  LoggingInterceptor(
      this._logger, {
        this.logRequestBody = false,
        this.logResponseBody = false,
        this.logHeaders = true,
        this.maxBodyLength = 1000,
      });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = options.headers['X-Request-ID'] ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final logData = {
      'request_id': requestId,
      'method': options.method,
      'url': '${options.baseUrl}${options.path}',
      'query_parameters': _sanitizeParameters(options.queryParameters),
    };

    if (logHeaders) {
      logData['headers'] = _sanitizeHeaders(options.headers);
    }

    if (logRequestBody && options.data != null && !_isExcludedPath(options.path)) {
      logData['body'] = _sanitizeBody(options.data);
    }

    _logger.log(
      'Outgoing request',
      level: LogLevel.debug,
      category: SecurityCategory.security,
      metadata: logData,
    );

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestId = response.requestOptions.headers['X-Request-ID'] ??
        response.requestOptions.hashCode.toString();

    final logData = {
      'request_id': requestId,
      'status_code': response.statusCode,
      'status_message': response.statusMessage,
      'duration_ms': _calculateDuration(response.requestOptions),
    };

    if (logHeaders) {
      logData['headers'] = _sanitizeHeaders(response.headers.map);
    }

    if (logResponseBody && response.data != null &&
        !_isExcludedPath(response.requestOptions.path)) {
      logData['body'] = _sanitizeBody(response.data);
    }

    _logger.log(
      'Incoming response',
      level: LogLevel.debug,
      category: SecurityCategory.security,
      metadata: logData,
    );

    handler.next(response);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    final requestId = err.requestOptions.headers['X-Request-ID'] ??
        err.requestOptions.hashCode.toString();

    final logData = {
      'request_id': requestId,
      'error_type': err.type.toString(),
      'error_message': err.message,
      'status_code': err.response?.statusCode,
      'duration_ms': _calculateDuration(err.requestOptions),
    };

    if (err.response != null && logResponseBody &&
        !_isExcludedPath(err.requestOptions.path)) {
      logData['response_body'] = _sanitizeBody(err.response?.data);
    }

    _logger.log(
      'Request error',
      level: LogLevel.error,
      category: SecurityCategory.security,
      metadata: logData,
    );

    handler.next(err);
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, dynamic>{};

    headers.forEach((key, value) {
      if (_sensitiveHeaders.contains(key.toLowerCase())) {
        sanitized[key] = '***REDACTED***';
      } else {
        sanitized[key] = value;
      }
    });

    return sanitized;
  }

  Map<String, dynamic> _sanitizeParameters(Map<String, dynamic> params) {
    final sanitized = <String, dynamic>{};

    params.forEach((key, value) {
      if (_isSensitiveParameter(key)) {
        sanitized[key] = '***REDACTED***';
      } else {
        sanitized[key] = value;
      }
    });

    return sanitized;
  }

  dynamic _sanitizeBody(dynamic body) {
    if (body == null) return null;

    try {
      if (body is Map<String, dynamic>) {
        return _sanitizeMap(body);
      } else if (body is List) {
        return _sanitizeList(body);
      } else if (body is String) {
        if (body.length > maxBodyLength) {
          return '${body.substring(0, maxBodyLength)}...[TRUNCATED]';
        }
        return body;
      } else {
        return body.toString();
      }
    } catch (e) {
      return '[Error sanitizing body: $e]';
    }
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final sanitized = <String, dynamic>{};

    map.forEach((key, value) {
      if (_isSensitiveParameter(key)) {
        sanitized[key] = '***REDACTED***';
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = _sanitizeMap(value);
      } else if (value is List) {
        sanitized[key] = _sanitizeList(value);
      } else if (value is String && value.length > maxBodyLength) {
        sanitized[key] = '${value.substring(0, maxBodyLength)}...[TRUNCATED]';
      } else {
        sanitized[key] = value;
      }
    });

    return sanitized;
  }

  List<dynamic> _sanitizeList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map<String, dynamic>) {
        return _sanitizeMap(item);
      } else if (item is List) {
        return _sanitizeList(item);
      } else if (item is String && item.length > maxBodyLength) {
        return '${item.substring(0, maxBodyLength)}...[TRUNCATED]';
      } else {
        return item;
      }
    }).toList();
  }

  bool _isSensitiveParameter(String key) {
    final sensitiveKeys = [
      'password',
      'token',
      'secret',
      'api_key',
      'apikey',
      'credit_card',
      'creditcard',
      'cvv',
      'ssn',
      'pin',
      'private_key',
      'privatekey',
    ];

    return sensitiveKeys.any((sensitive) =>
        key.toLowerCase().contains(sensitive.toLowerCase()));
  }

  bool _isExcludedPath(String path) {
    return _excludedPaths.any((excluded) => path.startsWith(excluded));
  }

  int _calculateDuration(RequestOptions options) {
    final startTime = options.extra['start_time'] as int?;
    if (startTime == null) return 0;

    return DateTime.now().millisecondsSinceEpoch - startTime;
  }
}

// معترض تسجيل الأداء
class PerformanceLoggingInterceptor extends Interceptor {
  final SecureLogger _logger;

  PerformanceLoggingInterceptor(this._logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['start_time'] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logPerformance(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    _logPerformance(err.requestOptions, err.response?.statusCode);
    handler.next(err);
  }

  void _logPerformance(RequestOptions options, int? statusCode) {
    final startTime = options.extra['start_time'] as int?;
    if (startTime == null) return;

    final duration = DateTime.now().millisecondsSinceEpoch - startTime;

    _logger.log(
      'Request performance',
      level: LogLevel.debug,
      category: SecurityCategory.security,
      metadata: {
        'method': options.method,
        'path': options.path,
        'status_code': statusCode,
        'duration_ms': duration,
        'size_bytes': options.data?.toString().length ?? 0,
      },
    );

    // تحذير في حالة الأداء البطيء
    if (duration > 3000) {
      _logger.log(
        'Slow request detected',
        level: LogLevel.warning,
        category: SecurityCategory.security,
        metadata: {
          'method': options.method,
          'path': options.path,
          'duration_ms': duration,
        },
      );
    }
  }
}

// معترض تسجيل الأمان
class SecurityLoggingInterceptor extends Interceptor {
  final SecureLogger _logger;

  SecurityLoggingInterceptor(this._logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _checkSecurityHeaders(options);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _checkResponseSecurity(response);
    handler.next(response);
  }

  void _checkSecurityHeaders(RequestOptions options) {
    final requiredHeaders = [
      'X-Device-ID',
      'X-Request-ID',
      'X-App-Version',
    ];

    final missingHeaders = requiredHeaders
        .where((header) => !options.headers.containsKey(header))
        .toList();

    if (missingHeaders.isNotEmpty) {
      _logger.log(
        'Missing security headers',
        level: LogLevel.warning,
        category: SecurityCategory.security,
        metadata: {
          'missing_headers': missingHeaders,
          'path': options.path,
        },
      );
    }
  }

  void _checkResponseSecurity(Response response) {
    final securityHeaders = {
      'Strict-Transport-Security': response.headers.value('Strict-Transport-Security'),
      'X-Content-Type-Options': response.headers.value('X-Content-Type-Options'),
      'X-Frame-Options': response.headers.value('X-Frame-Options'),
      'X-XSS-Protection': response.headers.value('X-XSS-Protection'),
      'Content-Security-Policy': response.headers.value('Content-Security-Policy'),
    };

    final missingHeaders = securityHeaders.entries
        .where((entry) => entry.value == null)
        .map((entry) => entry.key)
        .toList();

    if (missingHeaders.isNotEmpty) {
      _logger.log(
        'Missing security headers in response',
        level: LogLevel.warning,
        category: SecurityCategory.security,
        metadata: {
          'missing_headers': missingHeaders,
          'path': response.requestOptions.path,
        },
      );
    }
  }
}