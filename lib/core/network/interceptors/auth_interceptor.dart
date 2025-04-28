import 'package:dio/dio.dart';
import '../../security/token_manager.dart';
import '../../utils/secure_logger.dart';

class AuthInterceptor extends Interceptor {
  final TokenManager _tokenManager;
  final SecureLogger _logger;
  final Dio _dio;
  bool _isRefreshing = false;
  final List<RequestOptions> _pendingRequests = [];

  AuthInterceptor(this._tokenManager, this._logger, this._dio);

  @override
  Future<void> onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) async {
    try {
      // التحقق من انتهاء صلاحية التوكن
      if (await _tokenManager.isTokenExpired()) {
        if (_isRefreshing) {
          // إضافة الطلب إلى قائمة الانتظار
          _pendingRequests.add(options);
          return;
        }

        _isRefreshing = true;

        try {
          // تحديث التوكن
          await _refreshToken();

          // معالجة الطلبات المعلقة
          await _processPendingRequests();
        } catch (e) {
          _logger.log(
            'Token refresh failed: $e',
            level: LogLevel.error,
            category: SecurityCategory.security,
          );
          return handler.reject(DioError(
            requestOptions: options,
            error: 'Token refresh failed',
          ));
        } finally {
          _isRefreshing = false;
        }
      }

      // إضافة التوكن إلى الرأس
      final token = await _tokenManager.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }

      // إضافة رأس الأمان
      options.headers['X-Security-Token'] = DateTime.now().millisecondsSinceEpoch.toString();

      handler.next(options);
    } catch (e) {
      _logger.log(
        'Auth interceptor error: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      handler.reject(DioError(requestOptions: options, error: e));
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // التحقق من وجود توكن جديد في الاستجابة
    final newToken = response.headers.value('X-New-Access-Token');
    if (newToken != null) {
      _updateToken(newToken);
    }

    handler.next(response);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        await _refreshToken();

        // إعادة محاولة الطلب الأصلي
        final retryResponse = await _retryRequest(err.requestOptions);
        return handler.resolve(retryResponse);
      } catch (e) {
        _logger.log(
          'Retry after token refresh failed: $e',
          level: LogLevel.error,
          category: SecurityCategory.security,
        );
      }
    }

    handler.next(err);
  }

  Future<void> _refreshToken() async {
    final refreshToken = await _tokenManager.getRefreshToken();
    if (refreshToken == null) {
      throw UnauthorizedException();
    }

    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final newAccessToken = response.data['access_token'];
      final newRefreshToken = response.data['refresh_token'];

      await _tokenManager.rotateTokens(
        newAccessToken: newAccessToken,
        newRefreshToken: newRefreshToken,
      );
    } catch (e) {
      // مسح التوكنات في حالة فشل التحديث
      await _tokenManager.clearTokens();
      throw e;
    }
  }

  Future<void> _processPendingRequests() async {
    final token = await _tokenManager.getAccessToken();

    for (var options in _pendingRequests) {
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }

      // إعادة إرسال الطلب
      _dio.fetch(options).then(
            (response) => options.extra['handler'].resolve(response),
        onError: (error) => options.extra['handler'].reject(error),
      );
    }

    _pendingRequests.clear();
  }

  Future<Response> _retryRequest(RequestOptions requestOptions) async {
    final token = await _tokenManager.getAccessToken();

    if (token != null) {
      requestOptions.headers['Authorization'] = 'Bearer $token';
    }

    return _dio.fetch(requestOptions);
  }

  void _updateToken(String newToken) async {
    try {
      await _tokenManager.saveTokens(
        accessToken: newToken,
        refreshToken: await _tokenManager.getRefreshToken() ?? '',
      );
    } catch (e) {
      _logger.log(
        'Token update failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Unauthorized']);

  @override
  String toString() => 'UnauthorizedException: $message';
}