import 'dart:io';
import 'package:dio/dio.dart';
import '../../utils/secure_logger.dart';
import '../network_service.dart';

class ErrorInterceptor extends Interceptor {
  final SecureLogger _logger;

  ErrorInterceptor(this._logger);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // معالجة الخطأ وتحويله إلى استثناء مخصص
    final customException = _handleError(err);

    // تسجيل الخطأ بشكل آمن
    _logError(err, customException);

    // إرجاع الخطأ المخصص
    handler.next(DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: customException,
    ));
  }

  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException();

      case DioExceptionType.badResponse:
        return _handleResponseError(error);

      case DioExceptionType.cancel:
        return NetworkException('Request cancelled');

      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return NoInternetException();
        }
        return NetworkException('Unknown error occurred');

      default:
        return NetworkException('Network error occurred');
    }
  }

  Exception _handleResponseError(DioException error) {
    if (error.response?.statusCode == null) {
      return NetworkException('No response from server');
    }

    final statusCode = error.response!.statusCode!;
    final data = error.response?.data;
    String? message;

    // محاولة استخراج رسالة الخطأ من الاستجابة
    if (data is Map<String, dynamic>) {
      message = data['message'] ?? data['error'] ?? data['errors']?.toString();
    }

    switch (statusCode) {
      case 400:
        return BadRequestException(message ?? 'Bad request');
      case 401:
        return UnauthorizedException(message ?? 'Unauthorized');
      case 403:
        return ForbiddenException(message ?? 'Forbidden');
      case 404:
        return NotFoundException(message ?? 'Not found');
      case 409:
        return ConflictException(message ?? 'Conflict');
      case 422:
        return ValidationException(message ?? 'Validation error', data);
      case 429:
        return RateLimitException(message ?? 'Too many requests');
      case 500:
        return ServerException(message ?? 'Internal server error', statusCode);
      case 502:
        return ServerException(message ?? 'Bad gateway', statusCode);
      case 503:
        return ServerException(message ?? 'Service unavailable', statusCode);
      case 504:
        return ServerException(message ?? 'Gateway timeout', statusCode);
      default:
        if (statusCode >= 500) {
          return ServerException(message ?? 'Server error', statusCode);
        }
        return NetworkException(message ?? 'Network error', statusCode);
    }
  }

  void _logError(DioException error, Exception customException) {
    final logLevel = _getLogLevel(error);
    final sanitizedRequest = _sanitizeRequest(error.requestOptions);
    final sanitizedResponse = _sanitizeResponse(error.response);

    _logger.log(
      'Network error occurred',
      level: logLevel,
      category: SecurityCategory.security,
      metadata: {
        'error_type': error.type.toString(),
        'custom_exception': customException.toString(),
        'status_code': error.response?.statusCode,
        'request': sanitizedRequest,
        'response': sanitizedResponse,
      },
    );
  }

  LogLevel _getLogLevel(DioException error) {
    if (error.response?.statusCode == null) {
      return LogLevel.error;
    }

    final statusCode = error.response!.statusCode!;
    if (statusCode >= 500) {
      return LogLevel.critical;
    } else if (statusCode >= 400) {
      return LogLevel.warning;
    } else {
      return LogLevel.error;
    }
  }

  Map<String, dynamic> _sanitizeRequest(RequestOptions options) {
    return {
      'method': options.method,
      'path': options.path,
      'base_url': options.baseUrl,
      'query_parameters': _sanitizeParameters(options.queryParameters),
      'headers': _sanitizeHeaders(options.headers),
      // لا نسجل البيانات الحساسة
      'has_data': options.data != null,
    };
  }

  Map<String, dynamic>? _sanitizeResponse(Response? response) {
    if (response == null) return null;

    return {
      'status_code': response.statusCode,
      'status_message': response.statusMessage,
      'headers': _sanitizeHeaders(response.headers.map),
      // لا نسجل البيانات الحساسة
      'has_data': response.data != null,
    };
  }

  Map<String, dynamic> _sanitizeParameters(Map<String, dynamic> params) {
    final sanitized = <String, dynamic>{};

    for (var entry in params.entries) {
      if (_isSensitiveParameter(entry.key)) {
        sanitized[entry.key] = '***';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }

    return sanitized;
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, dynamic>{};

    for (var entry in headers.entries) {
      if (_isSensitiveHeader(entry.key)) {
        sanitized[entry.key] = '***';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }

    return sanitized;
  }

  bool _isSensitiveParameter(String key) {
    final sensitiveKeys = [
      'password',
      'token',
      'secret',
      'api_key',
      'apiKey',
      'credit_card',
      'creditCard',
      'cvv',
      'ssn',
    ];

    return sensitiveKeys.any((sensitive) =>
        key.toLowerCase().contains(sensitive.toLowerCase()));
  }

  bool _isSensitiveHeader(String key) {
    final sensitiveHeaders = [
      'authorization',
      'x-api-key',
      'x-auth-token',
      'cookie',
      'set-cookie',
    ];

    return sensitiveHeaders.any((sensitive) =>
    key.toLowerCase() == sensitive.toLowerCase());
  }
}

// استثناءات مخصصة
class BadRequestException extends NetworkException {
  BadRequestException(String message) : super(message, statusCode: 400);
}

class ValidationException extends NetworkException {
  final Map<String, dynamic>? errors;

  ValidationException(String message, this.errors)
      : super(message, statusCode: 422, data: errors);
}

class ConflictException extends NetworkException {
  ConflictException(String message) : super(message, statusCode: 409);
}

class InternalServerException extends NetworkException {
  InternalServerException(String message) : super(message, statusCode: 500);
}