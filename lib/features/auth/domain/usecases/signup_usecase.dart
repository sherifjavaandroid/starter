import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class SignupUseCase implements UseCase<User, SignupParams> {
  final AuthRepository repository;

  SignupUseCase(this.repository);

  @override
  Future<Either<Failure, User>> call(SignupParams params) async {
    return await repository.signup(
      email: params.email,
      password: params.password,
      name: params.name,
    );
  }
}

class SignupParams extends Equatable {
  final String email;
  final String password;
  final String name;

  const SignupParams({
    required this.email,
    required this.password,
    required this.name,
  });

  @override
  List<Object> get props => [email, password, name];
}