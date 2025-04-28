class TokenModel {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String tokenType;
  final List<String>? scopes;

  TokenModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.tokenType = 'Bearer',
    this.scopes,
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    return TokenModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: json['expires_at'] is String
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(json['expires_at'] as int),
      tokenType: json['token_type'] as String? ?? 'Bearer',
      scopes: json['scopes'] != null
          ? List<String>.from(json['scopes'] as List)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_at': expiresAt.toIso8601String(),
      'token_type': tokenType,
      'scopes': scopes,
    };
  }

  TokenModel copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? tokenType,
    List<String>? scopes,
  }) {
    return TokenModel(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      tokenType: tokenType ?? this.tokenType,
      scopes: scopes ?? this.scopes,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingTime => isExpired
      ? Duration.zero
      : expiresAt.difference(DateTime.now());

  String get authorizationHeader => '$tokenType $accessToken';
}