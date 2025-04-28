import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import '../utils/secure_logger.dart';
import '../utils/time_manager.dart';
import 'secure_storage_service.dart';

class RateLimiterService {
  final SecureStorageService _storageService;
  final TimeManager _timeManager;
  final SecureLogger _logger;

  // تخزين سجل الطلبات في الذاكرة
  final Map<String, Queue<DateTime>> _requestHistories = {};

  // تخزين محاولات تسجيل الدخول
  final Map<String, List<DateTime>> _loginAttempts = {};

  // حد الطلبات الافتراضي
  static const int _defaultRequestLimit = 100;
  static const Duration _defaultTimeWindow = Duration(minutes: 1);

  // حد محاولات تسجيل الدخول
  static const int _loginAttemptLimit = 5;
  static const Duration _loginLockoutDuration = Duration(minutes: 15);

  // حدود مخصصة لكل نوع من الطلبات
  final Map<String, RateLimitConfig> _customLimits = {
    '/auth/login': RateLimitConfig(5, Duration(minutes: 5)),
    '/auth/signup': RateLimitConfig(3, Duration(minutes: 10)),
    '/auth/forgot-password': RateLimitConfig(3, Duration(minutes: 10)),
    '/api/sensitive-data': RateLimitConfig(10, Duration(minutes: 1)),
    '/api/payment': RateLimitConfig(5, Duration(minutes: 1)),
  };

  RateLimiterService(
      this._storageService,
      this._timeManager,
      this._logger,
      );

  Future<void> initialize() async {
    try {
      // تحميل البيانات المخزنة سابقاً
      await _loadStoredData();

      // بدء مراقبة وتنظيف البيانات القديمة
      _startMonitoring();

      _logger.log(
        'Rate limiter service initialized',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Rate limiter initialization failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  Future<bool> checkRateLimit(String endpoint, String method, {String? userId}) async {
    try {
      final key = _generateKey(endpoint, method, userId);
      final now = _timeManager.getCurrentTime();

      // الحصول على تكوين الحد المناسب
      final limitConfig = _customLimits[endpoint] ??
          RateLimitConfig(_defaultRequestLimit, _defaultTimeWindow);

      // إنشاء قائمة جديدة إذا لم تكن موجودة
      _requestHistories.putIfAbsent(key, () => Queue<DateTime>());

      // تنظيف الطلبات القديمة
      _cleanupOldRequests(key, now, limitConfig.timeWindow);

      // التحقق من تجاوز الحد
      if (_requestHistories[key]!.length >= limitConfig.maxRequests) {
        _logger.log(
          'Rate limit exceeded for $endpoint',
          level: LogLevel.warning,
          category: SecurityCategory.rateLimiting,
        );
        await _recordViolation(key, endpoint, userId);
        return false;
      }

      // إضافة الطلب الحالي
      _requestHistories[key]!.add(now);

      // حفظ التحديث
      await _saveRequestHistory(key);

      return true;
    } catch (e) {
      _logger.log(
        'Rate limit check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.rateLimiting,
      );
      return false;
    }
  }

  Future<bool> checkLoginAttempt(String username) async {
    try {
      final now = _timeManager.getCurrentTime();

      // إنشاء قائمة جديدة إذا لم تكن موجودة
      _loginAttempts.putIfAbsent(username, () => []);

      // تنظيف المحاولات القديمة
      _loginAttempts[username] = _loginAttempts[username]!
          .where((attempt) => now.difference(attempt) < _loginLockoutDuration)
          .toList();

      // التحقق من حالة القفل
      if (_loginAttempts[username]!.length >= _loginAttemptLimit) {
        final oldestAttempt = _loginAttempts[username]!.first;
        final lockoutRemaining = _loginLockoutDuration - now.difference(oldestAttempt);

        if (lockoutRemaining > Duration.zero) {
          _logger.log(
            'Login attempt blocked for $username: account locked',
            level: LogLevel.warning,
            category: SecurityCategory.security,
          );
          return false;
        }
      }

      return true;
    } catch (e) {
      _logger.log(
        'Login attempt check failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return false;
    }
  }

  Future<void> recordLoginAttempt(String username, bool success) async {
    try {
      if (success) {
        // مسح المحاولات عند النجاح
        _loginAttempts.remove(username);
        await _storageService.deleteSecureData('login_attempts_$username');
      } else {
        // تسجيل المحاولة الفاشلة
        final now = _timeManager.getCurrentTime();
        _loginAttempts.putIfAbsent(username, () => []);
        _loginAttempts[username]!.add(now);

        // حفظ المحاولات
        await _saveLoginAttempts(username);

        // التحقق من القفل
        if (_loginAttempts[username]!.length >= _loginAttemptLimit) {
          _logger.log(
            'Account locked for $username due to multiple failed attempts',
            level: LogLevel.warning,
            category: SecurityCategory.security,
          );
        }
      }
    } catch (e) {
      _logger.log(
        'Failed to record login attempt: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<Duration?> getLockoutDuration(String username) async {
    try {
      if (!_loginAttempts.containsKey(username) ||
          _loginAttempts[username]!.length < _loginAttemptLimit) {
        return null;
      }

      final now = _timeManager.getCurrentTime();
      final oldestAttempt = _loginAttempts[username]!.first;
      final lockoutRemaining = _loginLockoutDuration - now.difference(oldestAttempt);

      return lockoutRemaining > Duration.zero ? lockoutRemaining : null;
    } catch (e) {
      _logger.log(
        'Failed to get lockout duration: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return null;
    }
  }

  void _cleanupOldRequests(String key, DateTime now, Duration timeWindow) {
    while (_requestHistories[key]!.isNotEmpty &&
        now.difference(_requestHistories[key]!.first) > timeWindow) {
      _requestHistories[key]!.removeFirst();
    }
  }

  String _generateKey(String endpoint, String method, String? userId) {
    return '${method}_${endpoint}_${userId ?? 'anonymous'}';
  }

  Future<void> _recordViolation(String key, String endpoint, String? userId) async {
    try {
      final violations = await _getViolations();
      violations.add({
        'key': key,
        'endpoint': endpoint,
        'userId': userId,
        'timestamp': _timeManager.getCurrentTime().toIso8601String(),
      });

      await _saveViolations(violations);

      // التحقق من الانتهاكات المتكررة
      final userViolations = violations.where((v) => v['userId'] == userId).toList();
      if (userViolations.length > 10) {
        _logger.log(
          'Multiple rate limit violations detected for user $userId',
          level: LogLevel.critical,
          category: SecurityCategory.security,
        );
        // يمكن اتخاذ إجراءات إضافية هنا
      }
    } catch (e) {
      _logger.log(
        'Failed to record violation: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<void> _loadStoredData() async {
    try {
      // تحميل سجل الطلبات
      final storedHistories = await _storageService.getSecureData('request_histories');
      if (storedHistories != null) {
        final decoded = json.decode(storedHistories) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          _requestHistories[key] = Queue<DateTime>.from(
              (value as List).map((ts) => DateTime.parse(ts))
          );
        });
      }

      // تحميل محاولات تسجيل الدخول
      final storedAttempts = await _storageService.getSecureData('login_attempts');
      if (storedAttempts != null) {
        final decoded = json.decode(storedAttempts) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          _loginAttempts[key] = (value as List)
              .map((ts) => DateTime.parse(ts))
              .toList();
        });
      }
    } catch (e) {
      _logger.log(
        'Failed to load stored data: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<void> _saveRequestHistory(String key) async {
    try {
      // تحويل القائمة إلى تنسيق قابل للتخزين
      final historyToSave = _requestHistories.map((k, v) =>
          MapEntry(k, v.map((dt) => dt.toIso8601String()).toList())
      );

      await _storageService.saveSecureData(
        'request_histories',
        json.encode(historyToSave),
      );
    } catch (e) {
      _logger.log(
        'Failed to save request history: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<void> _saveLoginAttempts(String username) async {
    try {
      final attemptsToSave = _loginAttempts.map((k, v) =>
          MapEntry(k, v.map((dt) => dt.toIso8601String()).toList())
      );

      await _storageService.saveSecureData(
        'login_attempts',
        json.encode(attemptsToSave),
      );
    } catch (e) {
      _logger.log(
        'Failed to save login attempts: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getViolations() async {
    try {
      final storedViolations = await _storageService.getSecureData('rate_limit_violations');
      if (storedViolations != null) {
        return List<Map<String, dynamic>>.from(json.decode(storedViolations));
      }
      return [];
    } catch (e) {
      _logger.log(
        'Failed to get violations: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      return [];
    }
  }

  Future<void> _saveViolations(List<Map<String, dynamic>> violations) async {
    try {
      await _storageService.saveSecureData(
        'rate_limit_violations',
        json.encode(violations),
      );
    } catch (e) {
      _logger.log(
        'Failed to save violations: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  void _startMonitoring() {
    // تنظيف دوري للبيانات القديمة كل 5 دقائق
    Timer.periodic(Duration(minutes: 5), (_) async {
      await _cleanupOldData();
    });
  }

  Future<void> _cleanupOldData() async {
    try {
      final now = _timeManager.getCurrentTime();

      // تنظيف سجل الطلبات
      _requestHistories.forEach((key, queue) {
        _cleanupOldRequests(key, now, Duration(hours: 1));
      });

      // تنظيف محاولات تسجيل الدخول
      _loginAttempts.forEach((username, attempts) {
        _loginAttempts[username] = attempts
            .where((attempt) => now.difference(attempt) < _loginLockoutDuration)
            .toList();
      });

      // حفظ البيانات المحدثة
      await _saveRequestHistory('');
      await _saveLoginAttempts('');

      _logger.log(
        'Rate limiter data cleanup completed',
        level: LogLevel.debug,
        category: SecurityCategory.rateLimiting,
      );
    } catch (e) {
      _logger.log(
        'Rate limiter cleanup failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.rateLimiting,
      );
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      return {
        'total_endpoints_monitored': _requestHistories.length,
        'total_users_with_login_attempts': _loginAttempts.length,
        'total_violations': (await _getViolations()).length,
        'current_timestamp': _timeManager.getCurrentTime().toIso8601String(),
      };
    } catch (e) {
      _logger.log(
        'Failed to get rate limiter stats: $e',
        level: LogLevel.error,
        category: SecurityCategory.rateLimiting,
      );
      return {};
    }
  }

  Future<void> resetUserLimits(String userId) async {
    try {
      // إزالة جميع سجلات الطلبات للمستخدم
      _requestHistories.removeWhere((key, _) => key.contains(userId));

      // إزالة محاولات تسجيل الدخول
      _loginAttempts.remove(userId);

      // حفظ التغييرات
      await _saveRequestHistory('');
      await _saveLoginAttempts('');

      _logger.log(
        'Rate limits reset for user: $userId',
        level: LogLevel.info,
        category: SecurityCategory.rateLimiting,
      );
    } catch (e) {
      _logger.log(
        'Failed to reset user limits: $e',
        level: LogLevel.error,
        category: SecurityCategory.rateLimiting,
      );
    }
  }

  void updateRateLimit(String endpoint, int maxRequests, Duration timeWindow) {
    _customLimits[endpoint] = RateLimitConfig(maxRequests, timeWindow);

    _logger.log(
      'Rate limit updated for $endpoint: $maxRequests requests per $timeWindow',
      level: LogLevel.info,
      category: SecurityCategory.rateLimiting,
    );
  }
}

class RateLimitConfig {
  final int maxRequests;
  final Duration timeWindow;

  RateLimitConfig(this.maxRequests, this.timeWindow);
}