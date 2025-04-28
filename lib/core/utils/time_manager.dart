import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class TimeManager {
  static const Duration _timeCheckInterval = Duration(minutes: 5);
  static const Duration _maxTimeDrift = Duration(minutes: 5);
  static const String _lastSyncKey = 'last_time_sync';
  static const platform = MethodChannel('com.example.secure_app/time_security');

  DateTime? _serverTime;
  DateTime? _lastSyncTime;
  Timer? _syncTimer;
  bool _isInitialized = false;

  // مصادر وقت موثوقة
  final List<String> _timeServers = [
    'https://worldtimeapi.org/api/timezone/Etc/UTC',
    'https://timeapi.io/api/Time/current/zone?timeZone=UTC',
    'https://worldclockapi.com/api/json/utc/now',
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _syncWithServer();
    _startPeriodicSync();
    _isInitialized = true;
  }

  DateTime getCurrentTime() {
    if (_serverTime == null || _lastSyncTime == null) {
      return DateTime.now().toUtc();
    }

    final elapsed = DateTime.now().difference(_lastSyncTime!);
    return _serverTime!.add(elapsed);
  }

  int getCurrentTimestamp() {
    return getCurrentTime().millisecondsSinceEpoch;
  }

  bool isTimestampValid(int timestamp, {Duration? maxAge}) {
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final currentTime = getCurrentTime();

    // التحقق من أن الطابع الزمني ليس من المستقبل
    if (time.isAfter(currentTime.add(_maxTimeDrift))) {
      return false;
    }

    // التحقق من عمر الطابع الزمني
    if (maxAge != null) {
      final age = currentTime.difference(time);
      if (age > maxAge) {
        return false;
      }
    }

    return true;
  }

  Future<bool> isTimeValid() async {
    try {
      // التحقق من تغيير الوقت النظامي
      if (await _detectTimeManipulation()) {
        return false;
      }

      // التحقق من انحراف الوقت
      final serverTime = await _fetchServerTime();
      if (serverTime == null) {
        return true; // نفترض الصحة في حالة عدم القدرة على الاتصال
      }

      final localTime = DateTime.now().toUtc();
      final timeDiff = localTime.difference(serverTime).abs();

      return timeDiff < _maxTimeDrift;
    } catch (e) {
      // في حالة الفشل، نفترض الصحة لتجنب حظر المستخدم
      return true;
    }
  }

  Future<void> _syncWithServer() async {
    try {
      final serverTime = await _fetchServerTime();
      if (serverTime != null) {
        _serverTime = serverTime;
        _lastSyncTime = DateTime.now();
      }
    } catch (e) {
      // تجاهل الأخطاء وإعادة المحاولة لاحقاً
    }
  }

  Future<DateTime?> _fetchServerTime() async {
    for (final serverUrl in _timeServers) {
      try {
        final response = await http.get(Uri.parse(serverUrl))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          // معالجة الاستجابة حسب نوع الخادم
          if (serverUrl.contains('worldtimeapi.org')) {
            return DateTime.parse(data['utc_datetime']);
          } else if (serverUrl.contains('timeapi.io')) {
            return DateTime.parse(data['dateTime']);
          } else if (serverUrl.contains('worldclockapi.com')) {
            return DateTime.parse(data['currentDateTime']);
          }
        }
      } catch (e) {
        // تجربة الخادم التالي
        continue;
      }
    }

    return null;
  }

  Future<bool> _detectTimeManipulation() async {
    try {
      // استخدام القناة للتحقق من تغيير الوقت النظامي
      final isManipulated = await platform.invokeMethod<bool>('detectTimeManipulation');
      return isManipulated ?? false;
    } on PlatformException {
      return false;
    }
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_timeCheckInterval, (_) async {
      await _syncWithServer();
      await _checkTimeSecurity();
    });
  }

  Future<void> _checkTimeSecurity() async {
    if (!await isTimeValid()) {
      // إطلاق حدث تحذير
      _handleTimeManipulation();
    }
  }

  void _handleTimeManipulation() {
    // يمكن إضافة إجراءات مخصصة هنا
    // مثل تسجيل الحدث أو إنهاء الجلسة
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _isInitialized = false;
  }

  // للتحقق من صلاحية العمليات الحساسة زمنياً
  bool validateTimeWindow(DateTime startTime, Duration window) {
    final currentTime = getCurrentTime();
    final endTime = startTime.add(window);

    return currentTime.isAfter(startTime) && currentTime.isBefore(endTime);
  }

  // للتحقق من التسلسل الزمني
  bool validateSequence(DateTime previousTime, DateTime currentTime) {
    return currentTime.isAfter(previousTime);
  }

  // لإنشاء طابع زمني موقع
  String createSignedTimestamp() {
    final timestamp = getCurrentTimestamp();
    // يمكن إضافة توقيع هنا باستخدام مفتاح سري
    return '$timestamp';
  }

  // للتحقق من طابع زمني موقع
  bool verifySignedTimestamp(String signedTimestamp, {Duration? maxAge}) {
    try {
      final timestamp = int.parse(signedTimestamp.split(':')[0]);
      return isTimestampValid(timestamp, maxAge: maxAge);
    } catch (e) {
      return false;
    }
  }
}

// استثناء خاص بالتلاعب بالوقت
class TimeManipulationException implements Exception {
  final String message;
  TimeManipulationException(this.message);

  @override
  String toString() => 'TimeManipulationException: $message';
}