import 'package:dartz/dartz.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/login_request_model.dart';
import '../models/biometric_auth_model.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final DeviceInfoService deviceInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
    required this.deviceInfo,
  });

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure('No internet connection'));
    }

    try {
      final deviceId = await deviceInfo.getDeviceId();
      final deviceModel = await deviceInfo.getDeviceModel();
      final osVersion = await deviceInfo.getOSVersion();

      final loginRequest = LoginRequestModel(
        email: email,
        password: password,
        deviceId: deviceId,
        deviceModel: deviceModel,
        osVersion: osVersion,
        appVersion: await deviceInfo.getAppVersion(),
      );

      final result = await remoteDataSource.login(loginRequest);

      // Cache user and tokens
      await localDataSource.cacheUser(result.user);
      await localDataSource.cacheTokens(result.tokens);
      await localDataSource.updateLastActivity();

      return Right(result.user.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on SecurityException catch (e) {
      return Left(SecurityFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> signup(String email, String password, String name) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure('No internet connection'));
    }

    try {
      final deviceId = await deviceInfo.getDeviceId();

      final result = await remoteDataSource.signup(
        email: email,
        password: password,
        name: name,
        deviceId: deviceId,
      );

      // Cache user and tokens
      await localDataSource.cacheUser(result.user);
      await localDataSource.cacheTokens(result.tokens);
      await localDataSource.updateLastActivity();

      return Right(result.user.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      if (await networkInfo.isConnected) {
        await remoteDataSource.logout();
      }
      await localDataSource.clearCache();
      return const Right(null);
    } on ServerException catch (e) {
      // Clear local cache even if server logout fails
      await localDataSource.clearCache();
      return Left(ServerFailure(e.message));
    } catch (e) {
      await localDataSource.clearCache();
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      final cachedUser = await localDataSource.getCachedUser();
      if (cachedUser == null) {
        return Left(CacheFailure('No cached user found'));
      }

      // Check if session is still valid
      if (!await localDataSource.isSessionValid()) {
        await localDataSource.clearCache();
        return Left(SessionExpiredFailure('Session has expired'));
      }

      await localDataSource.updateLastActivity();
      return Right(cachedUser.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> refreshToken() async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure('No internet connection'));
    }

    try {
      final tokens = await localDataSource.getCachedTokens();
      if (tokens == null) {
        return Left(CacheFailure('No cached tokens found'));
      }

      final newTokens = await remoteDataSource.refreshToken(tokens.refreshToken);
      await localDataSource.cacheTokens(newTokens);

      return Right(newTokens.accessToken);
    } on ServerException catch (e) {
      if (e.statusCode == 401) {
        // Token refresh failed, clear cache and force re-login
        await localDataSource.clearCache();
        return Left(AuthenticationFailure('Token refresh failed, please login again'));
      }
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> biometricAuth() async {
    try {
      final biometricData = await localDataSource.getBiometricAuth();
      if (biometricData == null) {
        return const Right(false);
      }

      final deviceId = await deviceInfo.getDeviceId();
      if (biometricData.deviceId != deviceId) {
        // Device mismatch, disable biometric auth
        await localDataSource.cacheBiometricAuth(
          BiometricAuthModel(
            enabled: false,
            deviceId: deviceId,
            lastUsed: DateTime.now(),
          ),
        );
        return const Right(false);
      }

      final result = await remoteDataSource.biometricAuth(deviceId);

      // Update tokens and last used time
      await localDataSource.cacheTokens(result.tokens);
      await localDataSource.cacheBiometricAuth(
        biometricData.copyWith(lastUsed: DateTime.now()),
      );

      return const Right(true);
    } on BiometricAuthException catch (e) {
      return Left(BiometricFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Session>> getSession() async {
    try {
      final tokens = await localDataSource.getCachedTokens();
      final user = await localDataSource.getCachedUser();

      if (tokens == null || user == null) {
        return Left(CacheFailure('No session data found'));
      }

      if (!await localDataSource.isSessionValid()) {
        return Left(SessionExpiredFailure('Session has expired'));
      }

      return Right(Session(
        user: user.toEntity(),
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt: tokens.expiresAt,
      ));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> enableBiometricAuth() async {
    try {
      final deviceId = await deviceInfo.getDeviceId();
      final biometricData = BiometricAuthModel(
        enabled: true,
        deviceId: deviceId,
        lastUsed: DateTime.now(),
      );

      await localDataSource.cacheBiometricAuth(biometricData);
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> disableBiometricAuth() async {
    try {
      final deviceId = await deviceInfo.getDeviceId();
      final biometricData = BiometricAuthModel(
        enabled: false,
        deviceId: deviceId,
        lastUsed: DateTime.now(),
      );

      await localDataSource.cacheBiometricAuth(biometricData);
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}