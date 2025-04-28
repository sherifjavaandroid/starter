import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app.dart';
import 'core/di/injection_container.dart' as di;
import 'core/security/security_manager.dart';
import 'core/security/root_detection_service.dart';
import 'core/security/screenshot_prevention_service.dart';
import 'core/security/anti_tampering_service.dart';
import 'core/utils/environment_checker.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/home/presentation/bloc/home_bloc.dart';
import 'features/search/presentation/bloc/search_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تعطيل وضع التصحيح لمنع التحليل العكسي
  assert(() {
    debugPrint = (String? message, {int? wrapWidth}) {};
    return true;
  }());

  // تعيين توجه الشاشة للموبايل فقط
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // إخفاء شريط الحالة
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.bottom],
  );

  // تهيئة حاوية حقن التبعيات
  await di.init();

  // التحقق من البيئة الآمنة
  final environmentChecker = di.sl<EnvironmentChecker>();
  if (!await environmentChecker.isSecureEnvironment()) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Insecure environment detected'),
        ),
      ),
    ));
    return;
  }

  // فحص الجذر/الجيلبريك
  final rootDetectionService = di.sl<RootDetectionService>();
  final isRooted = await rootDetectionService.isDeviceRooted();

  if (isRooted) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Device is rooted or jailbroken. Cannot run app.'),
        ),
      ),
    ));
    return;
  }

  // تهيئة حماية ضد التلاعب
  final antiTamperingService = di.sl<AntiTamperingService>();
  await antiTamperingService.initialize();

  // التحقق من سلامة التطبيق
  if (!await antiTamperingService.isAppIntegrityValid()) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('App integrity compromised'),
        ),
      ),
    ));
    return;
  }

  // تهيئة مدير الأمان
  final securityManager = di.sl<SecurityManager>();
  await securityManager.initialize();

  // حماية من لقطات الشاشة
  final screenshotPrevention = di.sl<ScreenshotPreventionService>();
  await screenshotPrevention.enable();

  // تشغيل التطبيق
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()),
        BlocProvider(create: (_) => di.sl<HomeBloc>()),
        BlocProvider(create: (_) => di.sl<SearchBloc>()),
      ],
      child: const SecureApp(),
    ),
  );
}