import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  final String sessionId;
  final String userId;
  final String accessToken;
  final String refreshToken;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String deviceId;
  final String? deviceName;
  final String? deviceModel;
  final String? ipAddress;
  final String? userAgent;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  const AuthSession({
    required this.sessionId,
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.createdAt,
    required this.expiresAt,
    required this.deviceId,
    this.deviceName,
    this.deviceModel,
    this.ipAddress,
    this.userAgent,
    this.isActive = true,
    this.metadata,
  });

  @override
  List<Object?> get props => [
    sessionId,
    userId,
    accessToken,
    refreshToken,
    createdAt,
    expiresAt,
    deviceId,
    deviceName,
    deviceModel,
    ipAddress,
    userAgent,
    isActive,
    metadata,
  ];

  AuthSession copyWith({
    String? sessionId,
    String? userId,
    String? accessToken,
    String? refreshToken,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? deviceId,
    String? deviceName,
    String? deviceModel,
    String? ipAddress,
    String? userAgent,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return AuthSession(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceModel: deviceModel ?? this.deviceModel,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingTime => isExpired
      ? Duration.zero
      : expiresAt.difference(DateTime.now());

  bool get needsRefresh {
    const refreshThreshold = Duration(minutes: 5);
    return remainingTime <= refreshThreshold;
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceModel': deviceModel,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String?,
      deviceModel: json['deviceModel'] as String?,
      ipAddress: json['ipAddress'] as String?,
      userAgent: json['userAgent'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}