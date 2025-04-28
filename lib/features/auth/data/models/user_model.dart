import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required String id,
    required String email,
    String? name,
    String? profilePicture,
    DateTime? lastLogin,
    bool isEmailVerified = false,
    bool isBiometricEnabled = false,
    List<String> roles = const ['user'],
    required DateTime createdAt,
    DateTime? updatedAt,
  }) : super(
    id: id,
    email: email,
    name: name,
    profilePicture: profilePicture,
    lastLogin: lastLogin,
    isEmailVerified: isEmailVerified,
    isBiometricEnabled: isBiometricEnabled,
    roles: roles,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      profilePicture: json['profilePicture'] as String?,
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'] as String)
          : null,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      isBiometricEnabled: json['isBiometricEnabled'] as bool? ?? false,
      roles: json['roles'] != null
          ? List<String>.from(json['roles'] as List)
          : ['user'],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'profilePicture': profilePicture,
      'lastLogin': lastLogin?.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'isBiometricEnabled': isBiometricEnabled,
      'roles': roles,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? profilePicture,
    DateTime? lastLogin,
    bool? isEmailVerified,
    bool? isBiometricEnabled,
    List<String>? roles,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      profilePicture: profilePicture ?? this.profilePicture,
      lastLogin: lastLogin ?? this.lastLogin,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      roles: roles ?? this.roles,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}