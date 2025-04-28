import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../security/ssl_pinning_service.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/encryption_interceptor.dart';
import 'interceptors/security_interceptor.dart';

class DioClient {
  final Dio dio;

  DioClient(
      Dio baseDio, {
        required SSLPinningService sslPinningService,
        required AuthInterceptor authInterceptor,
        required ErrorInterceptor errorInterceptor,
        required LoggingInterceptor loggingInterceptor,
        required EncryptionInterceptor encryptionInterceptor,
        required SecurityInterceptor securityInterceptor,
      }) : dio = baseDio {
    // إعدادات Dio الأساسية
    dio.options = BaseOptions(
      baseUrl: 'https://api.unsplash.com',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-App-Version': '1.0.0',
        'X-Platform': 'mobile',
      },
      validateStatus: (status) => status != null && status < 500,
    );

    // إعداد HttpClient الآمن مع SSL Pinning
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => sslPinningService.createSecureHttpClient(),
    );

    // إضافة الـ interceptors بالترتيب الصحيح
    dio.interceptors.addAll([
      // 1. التحقق من الأمان أولاً
      securityInterceptor,

      // 2. التشفير
      encryptionInterceptor,

      // 3. المصادقة
      authInterceptor,

      // 4. التسجيل
      loggingInterceptor,

      // 5. معالجة الأخطاء أخيراً
      errorInterceptor,
    ]);
  }

  // إضافة interceptor ديناميكياً
  void addInterceptor(Interceptor interceptor) {
    dio.interceptors.add(interceptor);
  }

  // إزالة interceptor
  void removeInterceptor(Interceptor interceptor) {
    dio.interceptors.remove(interceptor);
  }

  // مسح جميع الـ interceptors
  void clearInterceptors() {
    dio.interceptors.clear();
  }
}

// تكوين Dio للبيئات المختلفة
class DioConfig {
  static BaseOptions getOptions(Environment environment) {
    switch (environment) {
      case Environment.production:
        return BaseOptions(
          baseUrl: 'https://api.unsplash.com',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        );
      case Environment.staging:
        return BaseOptions(
          baseUrl: 'https://staging-api.unsplash.com',
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        );
      case Environment.development:
        return BaseOptions(
          baseUrl: 'http://localhost:3000',
          connectTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 120),
        );
    }
  }
}

enum Environment {
  production,
  staging,
  development,
}

// مدير إلغاء الطلبات
class CancelTokenManager {
  final Map<String, CancelToken> _tokens = {};

  CancelToken createToken(String id) {
    final token = CancelToken();
    _tokens[id] = token;
    return token;
  }

  void cancelToken(String id) {
    _tokens[id]?.cancel('Request cancelled by user');
    _tokens.remove(id);
  }

  void cancelAll() {
    for (var token in _tokens.values) {
      token.cancel('All requests cancelled');
    }
    _tokens.clear();
  }

  void dispose() {
    cancelAll();
  }
}

// مدير الطلبات المتزامنة
class ConcurrentRequestManager {
  final int maxConcurrentRequests;
  int _currentRequests = 0;
  final List<Function> _queue = [];

  ConcurrentRequestManager({this.maxConcurrentRequests = 3});

  Future<T> queueRequest<T>(Future<T> Function() request) async {
    if (_currentRequests < maxConcurrentRequests) {
      _currentRequests++;
      try {
        final result = await request();
        _currentRequests--;
        _processQueue();
        return result;
      } catch (e) {
        _currentRequests--;
        _processQueue();
        rethrow;
      }
    } else {
      final completer = Completer<T>();
      _queue.add(() async {
        try {
          final result = await request();
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        }
      });
      return completer.future;
    }
  }

  void _processQueue() {
    if (_queue.isNotEmpty && _currentRequests < maxConcurrentRequests) {
      final next = _queue.removeAt(0);
      _currentRequests++;
      next().whenComplete(() {
        _currentRequests--;
        _processQueue();
      });
    }
  }
}

// مدير التخزين المؤقت للطلبات
class RequestCacheManager {
  final Map<String, CacheEntry> _cache = {};
  final Duration defaultTTL;

  RequestCacheManager({this.defaultTTL = const Duration(minutes: 5)});

  void cache(String key, dynamic data, {Duration? ttl}) {
    _cache[key] = CacheEntry(
      data: data,
      expiry: DateTime.now().add(ttl ?? defaultTTL),
    );
  }

  dynamic get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    return entry.data;
  }

  void invalidate(String key) {
    _cache.remove(key);
  }

  void invalidateAll() {
    _cache.clear();
  }

  void cleanExpired() {
    _cache.removeWhere((key, entry) => entry.isExpired);
  }
}

class CacheEntry {
  final dynamic data;
  final DateTime expiry;

  CacheEntry({
    required this.data,
    required this.expiry,
  });

  bool get isExpired => DateTime.now().isAfter(expiry);
}