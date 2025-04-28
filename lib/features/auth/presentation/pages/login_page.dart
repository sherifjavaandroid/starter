import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/secure_input_field.dart';
import '../widgets/biometric_auth_widget.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../../../core/security/screenshot_prevention_service.dart';
import '../../../../core/security/security_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _localAuth = LocalAuthentication();

  late final ScreenshotPreventionService _screenshotPrevention;
  late final SecurityManager _securityManager;

  bool _isObscurePassword = true;
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // تفعيل حماية الشاشة
    _screenshotPrevention = context.read<ScreenshotPreventionService>();
    _securityManager = context.read<SecurityManager>();

    _initializeSecurity();
    _checkBiometricAvailability();
  }

  Future<void> _initializeSecurity() async {
    await _screenshotPrevention.enableForPage();

    // منع نسخ النص الحساس
    SystemChannels.platform.setMethodCallHandler((call) async {
      if (call.method == 'TextInput.updateConfig') {
        final args = call.arguments as Map<dynamic, dynamic>;
        if (args['inputAction'] == 'TextInputAction.copy') {
          return null; // منع النسخ
        }
      }
      return null;
    });
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      _isBiometricAvailable = await _localAuth.canCheckBiometrics;
      if (_isBiometricAvailable) {
        final devices = await _localAuth.getAvailableBiometrics();
        _isBiometricAvailable = devices.isNotEmpty;
      }
      setState(() {});
    } catch (e) {
      _isBiometricAvailable = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // إخفاء المحتوى الحساس عند الدخول للخلفية
      _emailController.clear();
      _passwordController.clear();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    _screenshotPrevention.disableForPage();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // تحديث نشاط المستخدم
    _securityManager.updateLastActivity();

    // تنظيف وتصفية المدخلات
    final sanitizedEmail = InputSanitizer.sanitizeEmail(_emailController.text);
    final sanitizedPassword = InputSanitizer.sanitizePassword(_passwordController.text);

    // التحقق من صحة البيانات بعد التنظيف
    if (!Validators.isValidEmail(sanitizedEmail)) {
      _showError('البريد الإلكتروني غير صالح');
      setState(() => _isLoading = false);
      return;
    }

    if (!Validators.isStrongPassword(sanitizedPassword)) {
      _showError('كلمة المرور غير صالحة');
      setState(() => _isLoading = false);
      return;
    }

    // إرسال حدث تسجيل الدخول
    context.read<AuthBloc>().add(
      LoginRequested(
        email: sanitizedEmail,
        password: sanitizedPassword,
      ),
    );
  }

  Future<void> _handleBiometricLogin() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'قم بالمصادقة لتسجيل الدخول',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        context.read<AuthBloc>().add(BiometricLoginRequested());
      }
    } catch (e) {
      _showError('فشلت المصادقة البيومترية');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleForgotPassword() {
    // التنقل لصفحة استعادة كلمة المرور
    Navigator.pushNamed(context, '/forgot-password');
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          _failedAttempts++;
          _showError(state.message);

          if (_failedAttempts >= 3) {
            // تفعيل حماية إضافية بعد 3 محاولات فاشلة
            _showError('تم تجاوز عدد المحاولات المسموح به');
          }
        } else if (state is AuthSuccess) {
          // التنقل للصفحة الرئيسية
          Navigator.pushReplacementNamed(context, '/home');
        }

        setState(() => _isLoading = state is AuthLoading);
      },
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // شعار التطبيق
                      const FlutterLogo(size: 100),
                      const SizedBox(height: 48),

                      // عنوان الصفحة
                      Text(
                        'تسجيل الدخول',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // حقل البريد الإلكتروني
                      SecureInputField(
                        controller: _emailController,
                        labelText: 'البريد الإلكتروني',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال البريد الإلكتروني';
                          }
                          if (!Validators.isValidEmail(value)) {
                            return 'البريد الإلكتروني غير صالح';
                          }
                          return null;
                        },
                        onChanged: (_) => _securityManager.updateLastActivity(),
                      ),
                      const SizedBox(height: 16),

                      // حقل كلمة المرور
                      SecureInputField(
                        controller: _passwordController,
                        labelText: 'كلمة المرور',
                        obscureText: _isObscurePassword,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال كلمة المرور';
                          }
                          if (value.length < 8) {
                            return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                          }
                          return null;
                        },
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _isObscurePassword = !_isObscurePassword);
                          },
                        ),
                        onFieldSubmitted: (_) => _handleLogin(),
                        onChanged: (_) => _securityManager.updateLastActivity(),
                      ),
                      const SizedBox(height: 8),

                      // رابط نسيت كلمة المرور
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _handleForgotPassword,
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // زر تسجيل الدخول
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text('تسجيل الدخول'),
                      ),

                      // تسجيل الدخول البيومتري
                      if (_isBiometricAvailable) ...[
                        const SizedBox(height: 16),
                        BiometricAuthWidget(
                          onAuthenticated: _handleBiometricLogin,
                        ),
                      ],

                      const SizedBox(height: 16),

                      // رابط إنشاء حساب جديد
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('ليس لديك حساب؟'),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/signup');
                            },
                            child: const Text('إنشاء حساب'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}