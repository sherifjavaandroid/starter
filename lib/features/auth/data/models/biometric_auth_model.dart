import 'package:local_auth/local_auth.dart';

class BiometricAuthModel {
  final bool isAvailable;
  final List<BiometricType> availableBiometrics;
  final bool isEnrolled;
  final bool isEnabled;
  final String? publicKey;
  final DateTime? enrollmentDate;
  final DateTime? lastUsedDate;
  final int? failedAttempts;
  final bool? isLocked;
  final DateTime? lockoutEndTime;

  BiometricAuthModel({
    required this.isAvailable,
    required this.availableBiometrics,
    required this.isEnrolled,
    required this.isEnabled,
    this.publicKey,
    this.enrollmentDate,
    this.lastUsedDate,
    this.failedAttempts,
    this.isLocked,
    this.lockoutEndTime,
  });

  factory BiometricAuthModel.fromJson(Map<String, dynamic> json) {
    return BiometricAuthModel(
      isAvailable: json['isAvailable'] as bool,
      availableBiometrics: (json['availableBiometrics'] as List?)
          ?.map((e) => _parseBiometricType(e as String))
          .toList() ?? [],
      isEnrolled: json['isEnrolled'] as bool,
      isEnabled: json['isEnabled'] as bool,
      publicKey: json['publicKey'] as String?,
      enrollmentDate: json['enrollmentDate'] != null
          ? DateTime.parse(json['enrollmentDate'] as String)
          : null,
      lastUsedDate: json['lastUsedDate'] != null
          ? DateTime.parse(json['lastUsedDate'] as String)
          : null,
      failedAttempts: json['failedAttempts'] as int?,
      isLocked: json['isLocked'] as bool?,
      lockoutEndTime: json['lockoutEndTime'] != null
          ? DateTime.parse(json['lockoutEndTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isAvailable': isAvailable,
      'availableBiometrics': availableBiometrics
          .map((e) => _biometricTypeToString(e))
          .toList(),
      'isEnrolled': isEnrolled,
      'isEnabled': isEnabled,
      'publicKey': publicKey,
      'enrollmentDate': enrollmentDate?.toIso8601String(),
      'lastUsedDate': lastUsedDate?.toIso8601String(),
      'failedAttempts': failedAttempts,
      'isLocked': isLocked,
      'lockoutEndTime': lockoutEndTime?.toIso8601String(),
    };
  }

  BiometricAuthModel copyWith({
    bool? isAvailable,
    List<BiometricType>? availableBiometrics,
    bool? isEnrolled,
    bool? isEnabled,
    String? publicKey,
    DateTime? enrollmentDate,
    DateTime? lastUsedDate,
    int? failedAttempts,
    bool? isLocked,
    DateTime? lockoutEndTime,
  }) {
    return BiometricAuthModel(
      isAvailable: isAvailable ?? this.isAvailable,
      availableBiometrics: availableBiometrics ?? this.availableBiometrics,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      isEnabled: isEnabled ?? this.isEnabled,
      publicKey: publicKey ?? this.publicKey,
      enrollmentDate: enrollmentDate ?? this.enrollmentDate,
      lastUsedDate: lastUsedDate ?? this.lastUsedDate,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      isLocked: isLocked ?? this.isLocked,
      lockoutEndTime: lockoutEndTime ?? this.lockoutEndTime,
    );
  }

  static BiometricType _parseBiometricType(String type) {
    switch (type.toLowerCase()) {
      case 'face':
        return BiometricType.face;
      case 'fingerprint':
        return BiometricType.fingerprint;
      case 'iris':
        return BiometricType.iris;
      default:
        return BiometricType.fingerprint;
    }
  }

  static String _biometricTypeToString(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'face';
      case BiometricType.fingerprint:
        return 'fingerprint';
      case BiometricType.iris:
        return 'iris';
      default:
        return 'unknown';
    }
  }

  bool get isLockedOut {
    if (isLocked == true && lockoutEndTime != null) {
      return DateTime.now().isBefore(lockoutEndTime!);
    }
    return false;
  }

  Duration? get remainingLockoutTime {
    if (isLockedOut && lockoutEndTime != null) {
      return lockoutEndTime!.difference(DateTime.now());
    }
    return null;
  }
}

class BiometricAuthRequest {
  final String userId;
  final String publicKey;
  final String signature;
  final DateTime timestamp;
  final String deviceId;
  final BiometricType biometricType;

  BiometricAuthRequest({
    required this.userId,
    required this.publicKey,
    required this.signature,
    required this.timestamp,
    required this.deviceId,
    required this.biometricType,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'public_key': publicKey,
      'signature': signature,
      'timestamp': timestamp.toIso8601String(),
      'device_id': deviceId,
      'biometric_type': _biometricTypeToString(biometricType),
    };
  }

  static String _biometricTypeToString(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'face';
      case BiometricType.fingerprint:
        return 'fingerprint';
      case BiometricType.iris:
        return 'iris';
      default:
        return 'unknown';
    }
  }
}

class BiometricEnrollmentRequest {
  final String userId;
  final String publicKey;
  final BiometricType biometricType;
  final String deviceId;
  final String deviceModel;
  final String osVersion;

  BiometricEnrollmentRequest({
    required this.userId,
    required this.publicKey,
    required this.biometricType,
    required this.deviceId,
    required this.deviceModel,
    required this.osVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'public_key': publicKey,
      'biometric_type': _biometricTypeToString(biometricType),
      'device_id': deviceId,
      'device_model': deviceModel,
      'os_version': osVersion,
    };
  }

  static String _biometricTypeToString(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'face';
      case BiometricType.fingerprint:
        return 'fingerprint';
      case BiometricType.iris:
        return 'iris';
      default:
        return 'unknown';
    }
  }
}