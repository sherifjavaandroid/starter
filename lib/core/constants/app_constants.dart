import 'package:flutter/foundation.dart';

class AppConstants {
  // App Info
  static const String appName = 'Secure App';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String packageName = 'com.example.secure_app';

  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'production',
  );

  // Sizes
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultRadius = 8.0;
  static const double smallRadius = 4.0;
  static const double largeRadius = 16.0;

  // Animations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);

  // Text Sizes
  static const double titleTextSize = 24.0;
  static const double subtitleTextSize = 18.0;
  static const double bodyTextSize = 16.0;
  static const double captionTextSize = 14.0;
  static const double smallTextSize = 12.0;

  // Colors
  static const int primaryColorValue = 0xFF2196F3;
  static const int accentColorValue = 0xFFF50057;
  static const int backgroundColorValue = 0xFFF5F5F5;
  static const int errorColorValue = 0xFFE53935;
  static const int successColorValue = 0xFF4CAF50;

  // Image Sizes
  static const double thumbnailSize = 100.0;
  static const double mediumImageSize = 300.0;
  static const double largeImageSize = 600.0;

  // Cache
  static const int imageCacheSize = 100;
  static const Duration cacheDuration = Duration(days: 7);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  // Session
  static const Duration sessionTimeout = Duration(minutes: 15);
  static const Duration refreshTokenThreshold = Duration(minutes: 5);

  // Retry
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Rate Limiting
  static const int maxRequestsPerMinute = 60;
  static const Duration rateLimitWindow = Duration(minutes: 1);

  // Biometric
  static const Duration biometricTimeout = Duration(seconds: 30);
  static const bool biometricAuthDefault = true;

  // Localization
  static const String defaultLanguage = 'en';
  static const List<String> supportedLanguages = ['en', 'ar'];

  // Routes
  static const String splashRoute = '/splash';
  static const String loginRoute = '/login';
  static const String signupRoute = '/signup';
  static const String homeRoute = '/home';
  static const String searchRoute = '/search';
  static const String profileRoute = '/profile';
  static const String settingsRoute = '/settings';

  // Keys
  static const String encryptionKey = 'encryption_key';
  static const String tokenKey = 'token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user';
  static const String themeKey = 'theme';
  static const String languageKey = 'language';

  // Debug
  static const bool enableLogging = !kReleaseMode;
  static const bool enableDebugButtons = !kReleaseMode;
  static const bool enablePerformanceOverlay = false;

  // Feature Flags
  static const bool enableBiometricAuth = true;
  static const bool enableOfflineMode = true;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  static const bool enablePushNotifications = true;

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 32;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;
  static const int maxEmailLength = 255;
}