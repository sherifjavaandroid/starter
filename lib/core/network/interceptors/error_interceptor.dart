import 'dart:io';
import 'package:dio/dio.dart';
import '../../utils/secure_logger.dart';

class ErrorInterceptor extends Interceptor {
  final SecureLogger _logger;

  ErrorInterceptor(this._logger);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle the error and convert it to a custom exception
    final customException = _handleError(err);

    // Log the error securely
    _logError(err, customException);

    // Return the custom exception
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

    // Try to extract error message from response
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
        return NetworkException(message ?? 'Network error', statusCode: statusCode);
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
      // Don't log sensitive data
      'has_data': options.data != null,
    };
  }

  Map<String, dynamic>? _sanitizeResponse(Response? response) {
    if (response == null) return null;

    return {
      'status_code': response.statusCode,
      'status_message': response.statusMessage,
      'headers': _sanitizeHeaders(response.headers.map),
      // Don't log sensitive data
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

// Custom exceptions
class BadRequestException extends NetworkException {
  BadRequestException(super.message) : super(statusCode: 400);
}

class ValidationException extends NetworkException {
  final Map<String, dynamic>? errors;

  ValidationException(super.message, this.errors)
      : super(statusCode: 422);
}

class ConflictException extends NetworkException {
  ConflictException(super.message) : super(statusCode: 409);
}

class InternalServerException extends NetworkException {
  InternalServerException(super.message) : super(statusCode: 500);
}

// Modified NetworkException to fix the constructor issue
class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  NetworkException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'NetworkException: $message ${statusCode != null ? '($statusCode)' : ''}';
}

// Other custom exceptions
class TimeoutException extends NetworkException {
  TimeoutException() : super('Request timed out');
}

class NoInternetException extends NetworkException {
  NoInternetException() : super('No internet connection');
}

class ServerException extends NetworkException {
  ServerException(super.message, int statusCode) : super(statusCode: statusCode);
}

class UnauthorizedException extends NetworkException {
  UnauthorizedException(super.message) : super(statusCode: 401);
}

class ForbiddenException extends NetworkException {
  ForbiddenException(super.message) : super(statusCode: 403);
}

class NotFoundException extends NetworkException {
  NotFoundException(super.message) : super(statusCode: 404);
}

class RateLimitException extends NetworkException {
  RateLimitException(super.message) : super(statusCode: 429);
}