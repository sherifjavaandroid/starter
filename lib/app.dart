import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'core/di/injection_container.dart' as di;
import 'core/security/root_detection_service.dart';
import 'core/security/screenshot_prevention_service.dart';
import 'core/security/security_manager.dart';
import 'core/security/rate_limiter_service.dart';
import 'core/security/anti_tampering_service.dart';
import 'core/security/package_validation_service.dart';
import 'core/utils/environment_checker.dart';
import 'core/utils/session_manager.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/signup_page.dart';
import 'features/home/presentation/bloc/home_bloc.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/search/presentation/bloc/search_bloc.dart';
import 'features/search/presentation/pages/search_page.dart';

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late SecurityManager _securityManager;
  late SessionManager _sessionManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSecurity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeSecurity() async {
    _securityManager = GetIt.instance<SecurityManager>();
    _sessionManager = GetIt.instance<SessionManager>();

    final isSecure = await _securityManager.performSecurityCheck();
    if (!isSecure) {
      _handleSecurityFailure();
    }
  }

  void _handleSecurityFailure() {
    // Handle security failure - could show error dialog or exit app
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Security Error'),
        content: const Text(
          'This device does not meet security requirements. '
              'Please ensure your device is not rooted/jailbroken and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _sessionManager.recordBackgroundTime();
    } else if (state == AppLifecycleState.resumed) {
      _sessionManager.checkSessionTimeout().then((isTimeout) {
        if (isTimeout) {
          _handleSessionTimeout();
        }
      });
    }
  }

  void _handleSessionTimeout() {
    // Handle session timeout - navigate to login
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => GetIt.instance<AuthBloc>()..add(CheckAuthStatusEvent()),
        ),
        BlocProvider<HomeBloc>(
          create: (context) => GetIt.instance<HomeBloc>(),
        ),
        BlocProvider<SearchBloc>(
          create: (context) => GetIt.instance<SearchBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'Secure Flutter App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        debugShowCheckedModeBanner: false,
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginPage(),
          '/signup': (context) => const SignUpPage(),
          '/home': (context) => const HomePage(),
          '/search': (context) => const SearchPage(),
        },
        onGenerateRoute: (settings) {
          // Add route guards here
          return null;
        },
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: child!,
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    await Future.delayed(const Duration(seconds: 2)); // Show splash screen briefly

    if (!mounted) return;

    final authBloc = context.read<AuthBloc>();
    authBloc.stream.listen((state) {
      if (state is Authenticated) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else if (state is Unauthenticated) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Add your app logo here
            const FlutterLogo(size: 100),
            const SizedBox(height: 24),
            Text(
              'Secure App',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}