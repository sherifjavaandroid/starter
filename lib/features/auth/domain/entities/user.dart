import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String? profilePicture;
  final DateTime? lastLogin;
  final bool isEmailVerified;
  final bool isBiometricEnabled;
  final List<String> roles;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.profilePicture,
    this.lastLogin,
    this.isEmailVerified = false,
    this.isBiometricEnabled = false,
    this.roles = const ['user'],
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    profilePicture,
    lastLogin,
    isEmailVerified,
    isBiometricEnabled,
    roles,
    createdAt,
    updatedAt,
  ];

  User copyWith({
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
    return User(
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

  bool hasRole(String role) {
    return roles.contains(role);
  }

  bool get isAdmin => hasRole('admin');
  bool get isModerator => hasRole('moderator');
}