import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class BiometricAuthUseCase implements UseCase<AuthSession, NoParams> {
  final AuthRepository repository;

  BiometricAuthUseCase(this.repository);

  @override
  Future<Either<Failure, AuthSession>> call(NoParams params) async {
    return await repository.loginWithBiometric();
  }

  Future<Either<Failure, bool>> checkAvailability() async {
    return await repository.isBiometricAvailable();
  }

  Future<Either<Failure, void>> enable() async {
    return await repository.setBiometricAuth(true);
  }

  Future<Either<Failure, void>> disable() async {
    return await repository.setBiometricAuth(false);
  }
}