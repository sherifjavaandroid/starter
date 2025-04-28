import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final User user;
  final bool isBiometricEnabled;

  const Authenticated(
      this.user, {
        this.isBiometricEnabled = false,
      });

  @override
  List<Object?> get props => [user, isBiometricEnabled];

  Authenticated copyWith({
    User? user,
    bool? isBiometricEnabled,
  }) {
    return Authenticated(
      user ?? this.user,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
    );
  }
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}