import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  const LoginEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [email, password];
}

class SignUpEvent extends AuthEvent {
  final String email;
  final String password;
  final String name;

  const SignUpEvent({
    required this.email,
    required this.password,
    required this.name,
  });

  @override
  List<Object> get props => [email, password, name];
}

class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}

class RefreshTokenEvent extends AuthEvent {
  const RefreshTokenEvent();
}

class BiometricAuthEvent extends AuthEvent {
  const BiometricAuthEvent();
}

class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}

class EnableBiometricAuthEvent extends AuthEvent {
  const EnableBiometricAuthEvent();
}

class DisableBiometricAuthEvent extends AuthEvent {
  const DisableBiometricAuthEvent();
}