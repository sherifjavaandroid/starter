
import 'package:dio/dio.dart' as dio;
import '../../../../core/constants/api_constants.dart' as api;
import '../../../../core/error/exceptions.dart' as exceptions;
import '../../../../core/network/network_service.dart' as network;
import '../../../../core/utils/secure_logger.dart' as logger;
import '../models/user_model.dart';
import '../models/token_model.dart';
import '../models/login_request_model.dart';
import '../models/biometric_auth_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(LoginRequestModel request);
  Future<UserModel> signup(SignupRequestModel request);
  Future<void> logout();
  Future<UserModel> getCurrentUser();
  Future<TokenModel> refreshToken(String refreshToken);
  Future<void> resetPassword(String email);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> verifyEmail(String verificationCode);
  Future<void> resendVerificationCode();
  Future<UserModel> updateProfile({String? name, String? profilePicture});
  Future<void> deleteAccount(String password);
  Future<void> enrollBiometric(BiometricEnrollmentRequest request);
  Future<TokenModel> authenticateWithBiometric(BiometricAuthRequest request);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final network.NetworkService _networkService;
  final logger.SecureLogger _logger;

  AuthRemoteDataSourceImpl(this._networkService, this._logger);

  @override
  Future<UserModel> login(LoginRequestModel request) async {
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        endpoint: api.ApiConstants.login,
        data: request.toJson(),
        converter: (json) => json as Map<String, dynamic>,
      );

      // التحقق من وجود بيانات المستخدم في الاستجابة
      if (response.containsKey('user') && response.containsKey('token')) {
        // حفظ التوكنات (يتم التعامل معها في repository)
        final userJson = response['user'] as Map<String, dynamic>;
        return UserModel.fromJson(userJson);
      } else {
        throw exceptions.AuthException('Invalid login response format');
      }
    } on dio.DioException catch (e) {
      _logger.log(
        'Login failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw _handleError(e);
    } catch (e) {
      _logger.log(
        'Login error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw exceptions.AuthException('Login failed: $e');
    }
  }

  @override
  Future<UserModel> signup(SignupRequestModel request) async {
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        endpoint: api.ApiConstants.register,
        data: request.toJson(),
        converter: (json) => json as Map<String, dynamic>,
      );

      if (response.containsKey('user')) {
        final userJson = response['user'] as Map<String, dynamic>;
        return UserModel.fromJson(userJson);
      } else {
        throw exceptions.AuthException('Invalid signup response format');
      }
    } on dio.DioException catch (e) {
      _logger.log(
        'Signup failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw _handleError(e);
    } catch (e) {
      _logger.log(
        'Signup error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw exceptions.AuthException('Signup failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _networkService.post<void>(
        endpoint: api.ApiConstants.logout,
        converter: (_) => null,
      );
    } on dio.DioException catch (e) {
      _logger.log(
        'Logout failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      // في حالة فشل تسجيل الخروج، نستمر في مسح البيانات المحلية
    } catch (e) {
      _logger.log(
        'Logout error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        endpoint: '/auth/me',
        converter: (json) => json as Map<String, dynamic>,
      );

      return UserModel.fromJson(response);
    } on dio.DioException catch (e) {
      _logger.log(
        'Get current user failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw _handleError(e);
    } catch (e) {
      _logger.log(
        'Get current user error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw exceptions.AuthException('Failed to get current user: $e');
    }
  }

  @override
  Future<TokenModel> refreshToken(String refreshToken) async {
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        endpoint: api.ApiConstants.refreshToken,
        data: {'refresh_token': refreshToken},
        converter: (json) => json as Map<String, dynamic>,
      );

      return TokenModel.fromJson(response);
    } on dio.DioException catch (e) {
      _logger.log(
        'Token refresh failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw _handleError(e);
    } catch (e) {
      _logger.log(
        'Token refresh error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw exceptions.AuthException('Token refresh failed: $e');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _networkService.post<void>(
        endpoint: api.ApiConstants.forgotPassword,
        data: {'email': email},
        converter: (_) => null,
      );
    } on dio.DioException catch (e) {
      _logger.log(
        'Password reset failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw _handleError(e);
    } catch (e) {
      _logger.log(
        'Password reset error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw exceptions.AuthException('Password reset failed: $e');
    }
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      await _networkService.post<void>(
        endpoint: '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        converter: (_) => null,
      );
    } on dio.DioException catch (e) {
      _logger.log(
        'Change password failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw _handleError(e);
    } catch (e) {
      _logger.log(
        'Change password error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw exceptions.AuthException('Change password failed: $e');
    }
  }

  @override
  Future<void> verifyEmail(String verificationCode) async {
    try {
      await _networkService.post<void>(
        endpoint: '/auth/verify-email',
        data: {'code': verificationCode},
        converter: (_) => null,
      );
    } on dio.DioException catch (e) {
      _logger.log(
        'Email verification failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw _handleError(e);
    } catch (e) {
      _logger.log(
        'Email verification error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw exceptions.AuthException('Email verification failed: $e');
    }
  }

  @override
  Future<void> resendVerificationCode() async {
    try {
      await _networkService.post<void>(
        endpoint: '/auth/resend-verification',
        converter: (_) => null,
      );
    } on dio.DioException catch (e) {
      _logger.log(
        'Resend verification code failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw _handleError(e);
    } catch (e) {
      _logger.log(
        'Resend verification code error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw exceptions.AuthException('Resend verification code failed: $e');
    }
  }

  @override
  Future<UserModel> updateProfile({String? name, String? profilePicture}) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (profilePicture != null) data['profile_picture'] = profilePicture;

      final response = await _networkService.put<Map<String, dynamic>>(
        endpoint: '/auth/profile',
        data: data,
        converter: (json) => json as Map<String, dynamic>,
      );

      return UserModel.fromJson(response);
    } on dio.DioException catch (e) {
      _logger.log(
        'Update profile failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw _handleError(e);
    } catch (e) {
      _logger.log(
        'Update profile error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw exceptions.AuthException('Update profile failed: $e');
    }
  }

  @override
  Future<void> deleteAccount(String password) async {
    try {
      await _networkService.delete<void>(
        endpoint: '/auth/account',
        data: {'password': password},
        converter: (_) => null,
      );
    } on dio.DioException catch (e) {
      _logger.log(
        'Delete account failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw _handleError(e);
    } catch (e) {
      _logger.log(
        'Delete account error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw exceptions.AuthException('Delete account failed: $e');
    }
  }

  @override
  Future<void> enrollBiometric(BiometricEnrollmentRequest request) async {
    try {
      await _networkService.post<void>(
        endpoint: '/auth/biometric/enroll',
        data: request.toJson(),
        converter: (_) => null,
      );
    } on dio.DioException catch (e) {
      _logger.log(
        'Biometric enrollment failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw _handleError(e);
    } catch (e) {
      _logger.log(
        'Biometric enrollment error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw exceptions.AuthException('Biometric enrollment failed: $e');
    }
  }

  @override
  Future<TokenModel> authenticateWithBiometric(BiometricAuthRequest request) async {
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        endpoint: '/auth/biometric/authenticate',
        data: request.toJson(),
        converter: (json) => json as Map<String, dynamic>,
      );

      return TokenModel.fromJson(response);
    } on dio.DioException catch (e) {
      _logger.log(
        'Biometric authentication failed: ${e.message}',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw _handleError(e);
    } catch (e) {
      _logger.log(
        'Biometric authentication error: $e',
        level: logger.LogLevel.error,
        category: logger.SecurityCategory.security,
      );
      throw exceptions.AuthException('Biometric authentication failed: $e');
    }
  }

  Exception _handleError(dio.DioException error) {
    switch (error.response?.statusCode) {
      case 400:
        return exceptions.ValidationException(
          error.response?.data['message'] ?? 'Invalid input',
          errors: error.response?.data['errors'],
        );
      case 401:
        return network.UnauthorizedException();
      case 403:
        return network.ForbiddenException();
      case 404:
        return exceptions.UserNotFoundException();
      case 409:
        return exceptions.UserAlreadyExistsException();
      case 429:
        return exceptions.RateLimitException(const Duration(seconds: 60));
      default:
        return exceptions.ServerException(
          error.response?.data['message'] ?? 'Server error',
          statusCode: error.response?.statusCode,
        );
    }
  }
}