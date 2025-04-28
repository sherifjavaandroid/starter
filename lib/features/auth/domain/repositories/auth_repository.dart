import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../entities/session.dart';

abstract class AuthRepository {
  /// تسجيل الدخول باستخدام البريد الإلكتروني وكلمة المرور
  Future<Either<Failure, AuthSession>> login({
    required String email,
    required String password,
  });

  /// إنشاء حساب جديد
  Future<Either<Failure, User>> signup({
    required String email,
    required String password,
    required String name,
  });

  /// تسجيل الخروج
  Future<Either<Failure, void>> logout();

  /// تسجيل الدخول باستخدام البصمة البيومترية
  Future<Either<Failure, AuthSession>> loginWithBiometric();

  /// تفعيل/تعطيل البصمة البيومترية
  Future<Either<Failure, void>> setBiometricAuth(bool enabled);

  /// التحقق من توفر البصمة البيومترية
  Future<Either<Failure, bool>> isBiometricAvailable();

  /// تحديث رمز المصادقة
  Future<Either<Failure, AuthSession>> refreshToken(String refreshToken);

  /// الحصول على المستخدم الحالي
  Future<Either<Failure, User?>> getCurrentUser();

  /// الحصول على الجلسة الحالية
  Future<Either<Failure, AuthSession?>> getCurrentSession();

  /// التحقق من حالة المصادقة
  Future<Either<Failure, bool>> isAuthenticated();

  /// إعادة تعيين كلمة المرور
  Future<Either<Failure, void>> resetPassword(String email);

  /// تغيير كلمة المرور
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// التحقق من البريد الإلكتروني
  Future<Either<Failure, void>> verifyEmail(String verificationCode);

  /// إعادة إرسال رمز التحقق
  Future<Either<Failure, void>> resendVerificationCode();

  /// تحديث معلومات المستخدم
  Future<Either<Failure, User>> updateProfile({
    String? name,
    String? profilePicture,
  });

  /// حذف الحساب
  Future<Either<Failure, void>> deleteAccount(String password);

  /// الحصول على جميع الجلسات النشطة
  Future<Either<Failure, List<AuthSession>>> getActiveSessions();

  /// إنهاء جلسة محددة
  Future<Either<Failure, void>> terminateSession(String sessionId);

  /// إنهاء جميع الجلسات الأخرى
  Future<Either<Failure, void>> terminateOtherSessions();

  /// حفظ بيانات المصادقة محلياً
  Future<Either<Failure, void>> saveAuthData(AuthSession session, User user);

  /// مسح بيانات المصادقة المحلية
  Future<Either<Failure, void>> clearAuthData();

  /// التحقق من صلاحية كلمة المرور
  Future<Either<Failure, bool>> validatePassword(String password);

  /// التحقق من تمكين المصادقة الثنائية
  Future<Either<Failure, bool>> isTwoFactorEnabled();

  /// تفعيل/تعطيل المصادقة الثنائية
  Future<Either<Failure, void>> setTwoFactorAuth(bool enabled);

  /// التحقق من رمز المصادقة الثنائية
  Future<Either<Failure, void>> verifyTwoFactorCode(String code);
}