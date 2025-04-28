import 'dart:async';
import 'package:flutter/material.dart';
import 'exceptions.dart';
import 'failures.dart';
import '../utils/secure_logger.dart';

class ErrorHandler {
  final SecureLogger _logger;

  ErrorHandler(this._logger);

  /// Central error handling method
  Future<Object?> handleError<T>(
      Future<T> Function() operation, {
        String? context,
        bool shouldRethrow = false,
        T Function(Failure)? onFailure,
      }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      final failure = _mapErrorToFailure(error, stackTrace);

      _logger.log(
        'Error occurred${context != null ? ' in $context' : ''}: ${failure.message}',
        level: LogLevel.error,
        category: SecurityCategory.security,
        metadata: {
          'error_type': error.runtimeType.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );

      if (onFailure != null) {
        return onFailure(failure);
      }

      if (shouldRethrow) {
        throw failure;
      }

      return failure;
    }
  }

  /// Synchronous error handling
  T handleErrorSync<T>(
      T Function() operation, {
        String? context,
        bool shouldRethrow = false,
        T Function(Failure)? onFailure,
      }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      final failure = _mapErrorToFailure(error, stackTrace);

      _logger.log(
        'Error occurred${context != null ? ' in $context' : ''}: ${failure.message}',
        level: LogLevel.error,
        category: SecurityCategory.security,
        metadata: {
          'error_type': error.runtimeType.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );

      if (onFailure != null) {
        return onFailure(failure);
      }

      if (shouldRethrow) {
        throw failure;
      }

      throw failure;
    }
  }

  /// Stream error handling
  Stream<T> handleStreamError<T>(
      Stream<T> stream, {
        String? context,
        void Function(Failure)? onError,
      }) {
    return stream.handleError((error, stackTrace) {
      final failure = _mapErrorToFailure(error, stackTrace);

      _logger.log(
        'Stream error occurred${context != null ? ' in $context' : ''}: ${failure.message}',
        level: LogLevel.error,
        category: SecurityCategory.security,
        metadata: {
          'error_type': error.runtimeType.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );

      if (onError != null) {
        onError(failure);
      }
    });
  }

  /// Get user-friendly error message
  String getUserFriendlyMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return _getNetworkErrorMessage(failure);
    }

    if (failure is AuthFailure) {
      return _getAuthErrorMessage(failure);
    }

    if (failure is SecurityFailure) {
      return _getSecurityErrorMessage(failure);
    }

    if (failure is ValidationFailure) {
      return _getValidationErrorMessage(failure);
    }

    if (failure is StorageFailure) {
      return _getStorageErrorMessage(failure);
    }

    if (failure is PermissionFailure) {
      return _getPermissionErrorMessage(failure);
    }

    if (failure is BusinessFailure) {
      return _getBusinessErrorMessage(failure);
    }

    // Generic message for unknown errors
    return 'An unexpected error occurred. Please try again.';
  }

  String _getNetworkErrorMessage(NetworkFailure failure) {
    if (failure is NoInternetFailure) {
      return 'No internet connection. Please check your network.';
    }

    if (failure is TimeoutFailure) {
      return 'Connection timed out. Please try again.';
    }

    if (failure is ServerFailure) {
      if (failure.statusCode == 500) {
        return 'Server error. Please try again later.';
      }
      if (failure.statusCode == 503) {
        return 'Service temporarily unavailable.';
      }
      return 'Connection error. Please try again.';
    }

    if (failure is RateLimitFailure) {
      return 'Too many requests. Please wait and try again.';
    }

    return 'Network error. Please check your connection.';
  }

  String _getAuthErrorMessage(AuthFailure failure) {
    if (failure is InvalidCredentialsFailure) {
      return 'Invalid email or password.';
    }

    if (failure is UserNotFoundFailure) {
      return 'User not found.';
    }

    if (failure is UserAlreadyExistsFailure) {
      return 'User already exists.';
    }

    if (failure is SessionExpiredFailure) {
      return 'Your session has expired. Please login again.';
    }

    if (failure is AccountLockedFailure) {
      final minutes = failure.lockoutDuration.inMinutes;
      return 'Account locked. Try again in $minutes minutes.';
    }

    if (failure is BiometricAuthFailure) {
      return 'Biometric authentication failed.';
    }

    return 'Authentication error. Please try again.';
  }

  String _getSecurityErrorMessage(SecurityFailure failure) {
    if (failure is RootedDeviceFailure) {
      return 'This app cannot run on rooted devices.';
    }

    if (failure is TamperingDetectedFailure) {
      return 'Security violation detected.';
    }

    if (failure is SSLPinningFailure) {
      return 'Secure connection failed.';
    }

    if (failure is EncryptionFailure || failure is DecryptionFailure) {
      return 'Data security error.';
    }

    return 'Security error. Please restart the app.';
  }

  String _getValidationErrorMessage(ValidationFailure failure) {
    if (failure.errors != null && failure.errors!.isNotEmpty) {
      // Return first error message
      return failure.errors!.values.first.first;
    }

    return failure.message;
  }

  String _getStorageErrorMessage(StorageFailure failure) {
    if (failure is FileNotFoundFailure) {
      return 'File not found.';
    }

    if (failure is StorageFullFailure) {
      return 'Storage is full. Please free up space.';
    }

    if (failure is CacheFailure) {
      return 'Cache error. Refreshing data...';
    }

    return 'Storage error. Please try again.';
  }

  String _getPermissionErrorMessage(PermissionFailure failure) {
    final permission = failure.permission.toUpperCase();
    return '$permission permission is required for this feature.';
  }

  String _getBusinessErrorMessage(BusinessFailure failure) {
    if (failure is ContentNotFoundFailure) {
      return 'Content not found.';
    }

    if (failure is InsufficientBalanceFailure) {
      return 'Insufficient balance.';
    }

    return failure.message;
  }

  /// Report non-critical error
  void reportError(dynamic error, StackTrace stackTrace, {String? context}) {
    _logger.log(
      'Non-critical error${context != null ? ' in $context' : ''}: $error',
      level: LogLevel.warning,
      category: SecurityCategory.security,
      metadata: {
        'error_type': error.runtimeType.toString(),
        'stack_trace': stackTrace.toString(),
      },
    );
  }

  /// Report critical error
  void reportCriticalError(dynamic error, StackTrace stackTrace, {String? context}) {
    _logger.log(
      'Critical error${context != null ? ' in $context' : ''}: $error',
      level: LogLevel.critical,
      category: SecurityCategory.security,
      metadata: {
        'error_type': error.runtimeType.toString(),
        'stack_trace': stackTrace.toString(),
      },
    );

    // Could add crash reporting service here
  }

  /// Map errors to failures
  Failure _mapErrorToFailure(dynamic error, StackTrace stackTrace) {
    if (error is Failure) {
      return error;
    }

    if (error is AppException) {
      return error.toFailure();
    }

    // Handle specific error types
    if (error is FormatException) {
      return ValidationFailure('Invalid format: ${error.message}');
    }

    if (error is TimeoutException) {
      return const TimeoutFailure();
    }

    if (error is StateError) {
      return BusinessFailure('Invalid state: ${error.message}');
    }

    if (error is TypeError) {
      return BusinessFailure('Type error: ${error.toString()}');
    }

    if (error is NoSuchMethodError) {
      return BusinessFailure('Method not found: ${error.toString()}');
    }

    if (error is AssertionError) {
      return BusinessFailure('Assertion failed: ${error.toString()}');
    }

    // Generic error
    return UnknownFailure(error.toString());
  }
}

// Global error handling widget
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(FlutterErrorDetails)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (details) {
      setState(() {
        _errorDetails = details;
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return widget.errorBuilder?.call(_errorDetails!) ??
          ErrorWidget(_errorDetails!.exception);
    }

    return widget.child;
  }
}

// Error handler mixin for blocs
mixin ErrorHandlerMixin {
  ErrorHandler get errorHandler;

  Future<T> handleBlocOperation<T>(
      Future<T> Function() operation, {
        String? context,
        void Function(Failure)? onFailure,
      }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      final failure = _mapErrorToFailure(error, stackTrace);

      if (onFailure != null) {
        onFailure(failure);
      }

      errorHandler.reportError(error, stackTrace, context: context);
      throw failure;
    }
  }

  Failure _mapErrorToFailure(dynamic error, StackTrace stackTrace) {
    if (error is Failure) {
      return error;
    }

    if (error is AppException) {
      return error.toFailure();
    }

    return UnknownFailure(error.toString());
  }
}