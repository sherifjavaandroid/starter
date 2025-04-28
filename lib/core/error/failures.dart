import 'package:equatable/equatable.dart';
import 'exceptions.dart';

import 'exceptions.dart';

// Base failure class for clean architecture
abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final dynamic data;

  const Failure(this.message, {this.code, this.data});

  @override
  List<Object?> get props => [message, code, data];
}

// Authentication Failures
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code, super.data});
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure() : super('Invalid email or password');
}

class UserNotFoundFailure extends AuthFailure {
  const UserNotFoundFailure() : super('User not found');
}

class UserAlreadyExistsFailure extends AuthFailure {
  const UserAlreadyExistsFailure() : super('User already exists');
}

class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure() : super('Session has expired');
}

class AccountLockedFailure extends AuthFailure {
  final Duration lockoutDuration;

  const AccountLockedFailure(this.lockoutDuration)
      : super('Account is locked');
}

class BiometricAuthFailure extends AuthFailure {
  const BiometricAuthFailure(super.message);
}

// Network Failures
class NetworkFailure extends Failure {
  final int? statusCode;

  const NetworkFailure(super.message, {this.statusCode, super.data});
}

class ServerFailure extends NetworkFailure {
  const ServerFailure(super.message, {super.statusCode});
}

class NoInternetFailure extends NetworkFailure {
  const NoInternetFailure() : super('No internet connection');
}

class TimeoutFailure extends NetworkFailure {
  const TimeoutFailure() : super('Request timed out');
}

class RateLimitFailure extends NetworkFailure {
  final Duration retryAfter;

  const RateLimitFailure(this.retryAfter)
      : super('Rate limit exceeded', statusCode: 429);
}

// Security Failures
class SecurityFailure extends Failure {
  const SecurityFailure(super.message, {super.code, super.data});
}

class RootedDeviceFailure extends SecurityFailure {
  const RootedDeviceFailure() : super('Device is rooted or jailbroken');
}

class TamperingDetectedFailure extends SecurityFailure {
  const TamperingDetectedFailure() : super('App tampering detected');
}

class SSLPinningFailure extends SecurityFailure {
  const SSLPinningFailure() : super('SSL certificate validation failed');
}

class EncryptionFailure extends SecurityFailure {
  const EncryptionFailure(super.message);
}

class DecryptionFailure extends SecurityFailure {
  const DecryptionFailure(super.message);
}

// Storage Failures
class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

class CacheFailure extends StorageFailure {
  const CacheFailure(super.message);
}

class FileNotFoundFailure extends StorageFailure {
  const FileNotFoundFailure(String path) : super('File not found: $path');
}

class StorageFullFailure extends StorageFailure {
  const StorageFullFailure() : super('Storage is full');
}

// Validation Failures
class ValidationFailure extends Failure {
  final Map<String, List<String>>? errors;

  const ValidationFailure(super.message, {this.errors})
      : super(data: errors);
}

class InvalidInputFailure extends ValidationFailure {
  InvalidInputFailure(String field, String message)
      : super(message, errors: {field: [message]});
}

// Permission Failures
class PermissionFailure extends Failure {
  final String permission;

  const PermissionFailure(this.permission)
      : super('Permission denied: $permission');
}

// Business Logic Failures
class BusinessFailure extends Failure {
  const BusinessFailure(super.message);
}

class ContentNotFoundFailure extends BusinessFailure {
  const ContentNotFoundFailure() : super('Content not found');
}

class InsufficientBalanceFailure extends BusinessFailure {
  const InsufficientBalanceFailure() : super('Insufficient balance');
}

// Configuration Failures
class ConfigurationFailure extends Failure {
  const ConfigurationFailure(super.message);
}

class MissingConfigurationFailure extends ConfigurationFailure {
  const MissingConfigurationFailure(String key)
      : super('Missing configuration: $key');
}

// Extension to convert exceptions to failures
extension ExceptionToFailure on Exception {
  Failure toFailure() {
    if (this is AuthException) {
      return AuthFailure((this as AuthException).message);
    } else if (this is NetworkException) {
      return NetworkFailure(
        (this as NetworkException).message,
        statusCode: (this as NetworkException).statusCode,
      );
    } else if (this is SecurityException) {
      return SecurityFailure((this as SecurityException).message);
    } else if (this is ValidationException) {
      return ValidationFailure(
        (this as ValidationException).message,
        errors: (this as ValidationException).errors,
      );
    } else if (this is StorageException) {
      return StorageFailure((this as StorageException).message);
    } else if (this is PermissionException) {
      return PermissionFailure((this as PermissionException).permission);
    }

    return UnknownFailure(toString());
  }
}

// Unknown Failures
class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}