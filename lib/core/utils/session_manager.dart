import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../security/secure_storage_service.dart';
import '../security/token_manager.dart';
import 'secure_logger.dart';
import 'time_manager.dart';
import 'device_info_service.dart';

class SessionManager {
  final SecureStorageService _storageService;
  final TokenManager _tokenManager;
  final TimeManager _timeManager;
  final DeviceInfoService _deviceInfoService;
  final SecureLogger _logger;

  // مدة الجلسة الافتراضية
  static const Duration _defaultSessionDuration = Duration(minutes: 15);

  // مدة التحذير قبل انتهاء الجلسة
  static const Duration _warningPeriod = Duration(minutes: 2);

  // بيانات الجلسة الحالية
  Session? _currentSession;

  // مؤقتات الجلسة
  Timer? _sessionTimer;
  Timer? _warningTimer;

  // المستمعين لأحداث الجلسة
  final List<SessionEventListener> _eventListeners = [];

  SessionManager(
      this._storageService,
      this._tokenManager,
      this._timeManager,
      this._deviceInfoService,
      this._logger,
      );

  /// بدء جلسة جديدة
  Future<void> startSession({
    required String userId,
    required String accessToken,
    required String refreshToken,
    Duration? customDuration,
  }) async {
    try {
      // إنهاء الجلسة الحالية إن وجدت
      if (_currentSession != null) {
        await endSession();
      }

      // إنشاء جلسة جديدة
      final deviceId = await _deviceInfoService.getDeviceId();
      final fingerprint = await _deviceInfoService.getDeviceFingerprint();
      final startTime = _timeManager.getCurrentTime();
      final expiryTime = startTime.add(customDuration ?? _defaultSessionDuration);

      _currentSession = Session(
        sessionId: _generateSessionId(),
        userId: userId,
        deviceId: deviceId,
        deviceFingerprint: fingerprint,
        startTime: startTime,
        expiryTime: expiryTime,
        lastActivityTime: startTime,
      );

      // حفظ الرموز
      await _tokenManager.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        deviceId: deviceId,
      );

      // حفظ بيانات الجلسة
      await _saveSession(_currentSession!);

      // بدء مؤقتات الجلسة
      _startSessionTimers();

      // إخطار المستمعين
      _notifyListeners(SessionEvent.started);

      _logger.log(
        'Session started for user: $userId',
        level: LogLevel.info,
        category: SecurityCategory.session,
      );
    } catch (e) {
      _logger.log(
        'Failed to start session: $e',
        level: LogLevel.error,
        category: SecurityCategory.session,
      );
      rethrow;
    }
  }

  /// إنهاء الجلسة الحالية
  Future<void> endSession() async {
    try {
      if (_currentSession == null) return;

      // إلغاء المؤقتات
      _cancelTimers();

      // مسح الرموز
      await _tokenManager.clearTokens();

      // مسح بيانات الجلسة
      await _clearSession();

      // إخطار المستمعين
      _notifyListeners(SessionEvent.ended);

      _logger.log(
        'Session ended for user: ${_currentSession?.userId}',
        level: LogLevel.info,
        category: SecurityCategory.session,
      );

      _currentSession = null;
    } catch (e) {
      _logger.log(
        'Failed to end session: $e',
        level: LogLevel.error,
        category: SecurityCategory.session,
      );
      rethrow;
    }
  }

  /// تحديث نشاط الجلسة
  void updateActivity() {
    if (_currentSession == null) return;

    _currentSession!.lastActivityTime = _timeManager.getCurrentTime();
    _saveSession(_currentSession!);

    // إعادة تعيين مؤقتات الجلسة
    _restartSessionTimers();
  }

  /// التحقق من صلاحية الجلسة
  Future<bool> isSessionValid() async {
    if (_currentSession == null) return false;

    // التحقق من انتهاء الوقت
    if (_timeManager.getCurrentTime().isAfter(_currentSession!.expiryTime)) {
      await endSession();
      return false;
    }

    // التحقق من تطابق الجهاز
    final currentDeviceId = await _deviceInfoService.getDeviceId();
    if (currentDeviceId != _currentSession!.deviceId) {
      await endSession();
      return false;
    }

    // التحقق من صحة الرموز
    if (await _tokenManager.isTokenExpired()) {
      await endSession();
      return false;
    }

    return true;
  }

  /// تمديد الجلسة
  Future<void> extendSession({Duration? extension}) async {
    if (_currentSession == null) return;

    final extensionDuration = extension ?? _defaultSessionDuration;
    _currentSession!.expiryTime = _currentSession!.expiryTime.add(extensionDuration);

    await _saveSession(_currentSession!);
    _restartSessionTimers();

    _notifyListeners(SessionEvent.extended);

    _logger.log(
      'Session extended by ${extensionDuration.inMinutes} minutes',
      level: LogLevel.info,
      category: SecurityCategory.session,
    );
  }

  /// استعادة الجلسة
  Future<bool> restoreSession() async {
    try {
      final sessionData = await _storageService.getSecureData('current_session');
      if (sessionData == null) return false;

      final sessionJson = json.decode(sessionData);
      final session = Session.fromJson(sessionJson);

      // التحقق من صلاحية الجلسة
      if (_timeManager.getCurrentTime().isAfter(session.expiryTime)) {
        await _clearSession();
        return false;
      }

      // التحقق من تطابق الجهاز
      final currentDeviceId = await _deviceInfoService.getDeviceId();
      if (currentDeviceId != session.deviceId) {
        await _clearSession();
        return false;
      }

      _currentSession = session;
      _startSessionTimers();

      _notifyListeners(SessionEvent.restored);

      _logger.log(
        'Session restored for user: ${session.userId}',
        level: LogLevel.info,
        category: SecurityCategory.session,
      );

      return true;
    } catch (e) {
      _logger.log(
        'Failed to restore session: $e',
        level: LogLevel.error,
        category: SecurityCategory.session,
      );
      return false;
    }
  }

  /// إضافة مستمع لأحداث الجلسة
  void addListener(SessionEventListener listener) {
    _eventListeners.add(listener);
  }

  /// إزالة مستمع
  void removeListener(SessionEventListener listener) {
    _eventListeners.remove(listener);
  }

  /// الحصول على معلومات الجلسة الحالية
  Session? get currentSession => _currentSession;

  /// الحصول على الوقت المتبقي للجلسة
  Duration? get remainingTime {
    if (_currentSession == null) return null;

    final now = _timeManager.getCurrentTime();
    if (now.isAfter(_currentSession!.expiryTime)) {
      return Duration.zero;
    }

    return _currentSession!.expiryTime.difference(now);
  }

  String _generateSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random.secure().nextInt(999999)}';
  }

  Future<void> _saveSession(Session session) async {
    await _storageService.saveSecureData(
      'current_session',
      json.encode(session.toJson()),
    );
  }

  Future<void> _clearSession() async {
    await _storageService.deleteSecureData('current_session');
  }

  void _startSessionTimers() {
    _cancelTimers();

    final now = _timeManager.getCurrentTime();
    final expiryDuration = _currentSession!.expiryTime.difference(now);
    final warningDuration = expiryDuration - _warningPeriod;

    // مؤقت التحذير
    if (warningDuration > Duration.zero) {
      _warningTimer = Timer(warningDuration, () {
        _notifyListeners(SessionEvent.expiringSoon);
      });
    }

    // مؤقت انتهاء الجلسة
    _sessionTimer = Timer(expiryDuration, () async {
      await endSession();
      _notifyListeners(SessionEvent.expired);
    });
  }

  void _restartSessionTimers() {
    _startSessionTimers();
  }

  void _cancelTimers() {
    _sessionTimer?.cancel();
    _warningTimer?.cancel();
    _sessionTimer = null;
    _warningTimer = null;
  }

  void _notifyListeners(SessionEvent event) {
    for (var listener in _eventListeners) {
      listener(event, _currentSession);
    }
  }

  Future<void> dispose() async {
    _cancelTimers();
    _eventListeners.clear();
  }
}

class Session {
  final String sessionId;
  final String userId;
  final String deviceId;
  final String deviceFingerprint;
  final DateTime startTime;
  DateTime expiryTime;
  DateTime lastActivityTime;

  Session({
    required this.sessionId,
    required this.userId,
    required this.deviceId,
    required this.deviceFingerprint,
    required this.startTime,
    required this.expiryTime,
    required this.lastActivityTime,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      sessionId: json['sessionId'],
      userId: json['userId'],
      deviceId: json['deviceId'],
      deviceFingerprint: json['deviceFingerprint'],
      startTime: DateTime.parse(json['startTime']),
      expiryTime: DateTime.parse(json['expiryTime']),
      lastActivityTime: DateTime.parse(json['lastActivityTime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'deviceId': deviceId,
      'deviceFingerprint': deviceFingerprint,
      'startTime': startTime.toIso8601String(),
      'expiryTime': expiryTime.toIso8601String(),
      'lastActivityTime': lastActivityTime.toIso8601String(),
    };
  }
}

enum SessionEvent {
  started,
  ended,
  extended,
  restored,
  expired,
  expiringSoon,
}

typedef SessionEventListener = void Function(SessionEvent event, Session? session);