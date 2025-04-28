class SecurityConstants {
  // Encryption
  static const String aesAlgorithm = 'AES/GCM/NoPadding';
  static const String rsaAlgorithm = 'RSA/ECB/OAEPWithSHA-256AndMGF1Padding';
  static const int aesKeySize = 256;
  static const int rsaKeySize = 4096;
  static const int ivSize = 12;
  static const int tagSize = 128;

  // Key Derivation
  static const String pbkdf2Algorithm = 'PBKDF2WithHmacSHA256';
  static const int keyDerivationIterations = 100000;
  static const int saltSize = 16;

  // Hashing
  static const String hashAlgorithm = 'SHA-256';
  static const String hmacAlgorithm = 'HmacSHA256';

  // SSL Pinning
  static const Duration certificateValidityPeriod = Duration(days: 30);
  static const int maxCertificateAge = 365; // days
  static const List<String> trustedDomains = [
    'api.unsplash.com',
    'images.unsplash.com',
  ];

  // Token Management
  static const Duration accessTokenValidity = Duration(hours: 1);
  static const Duration refreshTokenValidity = Duration(days: 30);
  static const Duration tokenRefreshBuffer = Duration(minutes: 5);

  // Session Management
  static const Duration sessionTimeout = Duration(minutes: 15);
  static const Duration sessionExtensionThreshold = Duration(minutes: 5);
  static const int maxSessionsPerUser = 5;

  // Rate Limiting
  static const int maxLoginAttempts = 5;
  static const int maxPasswordResetAttempts = 3;
  static const int maxOtpAttempts = 3;
  static const Duration lockoutDuration = Duration(minutes: 15);
  static const Duration rateLimitWindow = Duration(minutes: 1);

  // Password Policy
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 64;
  static const int passwordExpiryDays = 90;
  static const int passwordHistoryCount = 5;
  static final RegExp passwordComplexityRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
  );



  // Biometric Authentication
  static const Duration biometricTimeout = Duration(seconds: 30);
  static const int maxBiometricAttempts = 3;
  static const Duration biometricLockoutDuration = Duration(minutes: 5);

  // Security Headers
  static const Map<String, String> securityHeaders = {
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Content-Security-Policy': "default-src 'self'",
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Permissions-Policy': 'geolocation=(), microphone=(), camera=()',
  };

  // Content Security Policy
  static const String cspPolicy = "default-src 'self'; "
      "script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
      "style-src 'self' 'unsafe-inline'; "
      "img-src 'self' data: https:; "
      "connect-src 'self' https://api.unsplash.com; "
      "font-src 'self'; "
      "object-src 'none'; "
      "media-src 'self'; "
      "frame-src 'none';";

  // Anti-Tampering
  static const Duration integrityCheckInterval = Duration(hours: 6);
  static const Duration rootCheckInterval = Duration(minutes: 30);
  static const Duration debuggerCheckInterval = Duration(minutes: 5);

  // Data Protection
  static const List<String> sensitiveFields = [
    'password',
    'token',
    'refresh_token',
    'credit_card',
    'ssn',
    'api_key',
    'private_key',
  ];

  // File Security
  static const List<String> allowedFileExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp',
    'pdf', 'doc', 'docx', 'txt',
  ];
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB

  // Network Security
  static const Duration networkTimeout = Duration(seconds: 30);
  static const int maxRedirects = 5;
  static const bool validateCertificates = true;

  // Logging
  static const Duration logRetentionPeriod = Duration(days: 30);
  static const int maxLogFileSize = 5 * 1024 * 1024; // 5MB
  static const List<String> sensitiveLogPatterns = [
    r'password=\S+',
    r'token=\S+',
    r'Bearer\s+\S+',
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
  ];

  // Secure Defaults
  static const bool defaultSecureMode = true;
  static const bool defaultStrictMode = true;
  static const bool defaultParanoidMode = false;

  // Error Messages
  static const String genericErrorMessage = 'An error occurred. Please try again.';
  static const String securityViolationMessage = 'Security violation detected.';
  static const String sessionExpiredMessage = 'Your session has expired. Please login again.';
  static const String rootedDeviceMessage = 'This app cannot run on rooted devices.';
  static const String debuggerDetectedMessage = 'Debugger detected. App will now close.';
}