// Base exception for all app-specific exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  AppException(this.message, {this.code, this.details});

  @override
  String toString() => '$runtimeType: $message';
}

// Authentication Exceptions
class AuthException extends AppException {
  AuthException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

class InvalidCredentialsException extends AuthException {
  InvalidCredentialsException() : super('Invalid email or password');
}

class UserNotFoundException extends AuthException {
  UserNotFoundException() : super('User not found');
}

class UserAlreadyExistsException extends AuthException {
  UserAlreadyExistsException() : super('User already exists');
}

class InvalidTokenException extends AuthException {
  InvalidTokenException() : super('Invalid or expired token');
}

class SessionExpiredException extends AuthException {
  SessionExpiredException() : super('Session has expired');
}

class AccountLockedException extends AuthException {
  final Duration lockoutDuration;

  AccountLockedException(this.lockoutDuration)
      : super('Account is locked. Try again later.');
}

class BiometricAuthException extends AuthException {
  BiometricAuthException(String message) : super(message);
}

// Network Exceptions
class NetworkException extends AppException {
  final int? statusCode;

  NetworkException(String message, {this.statusCode, dynamic details})
      : super(message, details: details);
}

class NoInternetException extends NetworkException {
  NoInternetException() : super('No internet connection');
}

class TimeoutException extends NetworkException {
  TimeoutException() : super('Request timed out');
}

class ServerException extends NetworkException {
  ServerException(String message, {int? statusCode})
      : super(message, statusCode: statusCode);
}

class RateLimitException extends NetworkException {
  final Duration retryAfter;

  RateLimitException(this.retryAfter)
      : super('Rate limit exceeded', statusCode: 429);
}

// Security Exceptions
class SecurityException extends AppException {
  SecurityException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

class RootedDeviceException extends SecurityException {
  RootedDeviceException() : super('Device is rooted or jailbroken');
}

class TamperingDetectedException extends SecurityException {
  TamperingDetectedException() : super('App tampering detected');
}

class DebuggerDetectedException extends SecurityException {
  DebuggerDetectedException() : super('Debugger detected');
}

class SSLPinningException extends SecurityException {
  SSLPinningException() : super('SSL certificate validation failed');
}

class EncryptionException extends SecurityException {
  EncryptionException(String message) : super(message);
}

class DecryptionException extends SecurityException {
  DecryptionException(String message) : super(message);
}

class IntegrityException extends SecurityException {
  IntegrityException(String message) : super(message);
}

// Validation Exceptions
class ValidationException extends AppException {
  final Map<String, List<String>>? errors;

  ValidationException(String message, {this.errors})
      : super(message, details: errors);
}

class InvalidInputException extends ValidationException {
  InvalidInputException(String field, String message)
      : super(message, errors: {field: [message]});
}

class InvalidEmailException extends ValidationException {
  InvalidEmailException() : super('Invalid email format');
}

class WeakPasswordException extends ValidationException {
  WeakPasswordException() : super('Password is too weak');
}

// Storage Exceptions
class StorageException extends AppException {
  StorageException(String message) : super(message);
}

class FileNotFoundException extends StorageException {
  FileNotFoundException(String path) : super('File not found: $path');
}

class StorageFullException extends StorageException {
  StorageFullException() : super('Storage is full');
}

class FileAccessDeniedException extends StorageException {
  FileAccessDeniedException(String path) : super('Access denied: $path');
}

// Permission Exceptions
class PermissionException extends AppException {
  final String permission;

  PermissionException(this.permission)
      : super('Permission denied: $permission');
}

class CameraPermissionException extends PermissionException {
  CameraPermissionException() : super('camera');
}

class StoragePermissionException extends PermissionException {
  StoragePermissionException() : super('storage');
}

class LocationPermissionException extends PermissionException {
  LocationPermissionException() : super('location');
}

// Business Logic Exceptions
class BusinessException extends AppException {
  BusinessException(String message) : super(message);
}

class InsufficientBalanceException extends BusinessException {
  InsufficientBalanceException() : super('Insufficient balance');
}

class TransactionFailedException extends BusinessException {
  TransactionFailedException(String reason) : super('Transaction failed: $reason');
}

class ContentNotFoundException extends BusinessException {
  ContentNotFoundException() : super('Content not found');
}

// Cache Exceptions
class CacheException extends AppException {
  CacheException(String message) : super(message);
}

class CacheExpiredException extends CacheException {
  CacheExpiredException() : super('Cache has expired');
}

class CacheCorruptedException extends CacheException {
  CacheCorruptedException() : super('Cache is corrupted');
}

// Configuration Exceptions
class ConfigurationException extends AppException {
  ConfigurationException(String message) : super(message);
}

class MissingConfigurationException extends ConfigurationException {
  MissingConfigurationException(String key) : super('Missing configuration: $key');
}

class InvalidConfigurationException extends ConfigurationException {
  InvalidConfigurationException(String key) : super('Invalid configuration: $key');
}