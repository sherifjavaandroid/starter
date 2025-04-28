import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../security/secure_storage_service.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

enum SecurityCategory {
  security,
  session,
  encryption,
  decryption,
  integrity,
  inputValidation,
  pathValidation,
  rateLimiting,
  initialization,
}

class SecureLogger {
  static final SecureLogger _instance = SecureLogger._internal();
  factory SecureLogger() => _instance;
  SecureLogger._internal();

  SecureStorageService? _storageService;
  final List<LogEntry> _logBuffer = [];
  final int _maxBufferSize = 100;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  bool _isInitialized = false;

  Future<void> initialize(SecureStorageService storageService) async {
    if (_isInitialized) return;

    _storageService = storageService;
    _isInitialized = true;

    // إنشاء مجلد السجلات
    await _createLogDirectory();
  }

  Future<void> log(
      String message, {
        LogLevel level = LogLevel.info,
        SecurityCategory? category,
        Map<String, dynamic>? metadata,
        bool immediate = false,
      }) async {
    final logEntry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      category: category,
      metadata: metadata,
    );

    // في وضع التطوير، طباعة السجل
    if (kDebugMode) {
      _printLog(logEntry);
    }

    // إضافة إلى المخزن المؤقت
    _logBuffer.add(logEntry);

    // التخزين الفوري للسجلات الحرجة
    if (immediate || level == LogLevel.critical || _logBuffer.length >= _maxBufferSize) {
      await _flushLogs();
    }
  }

  void _printLog(LogEntry entry) {
    final color = _getLogColor(entry.level);
    final categoryStr = entry.category != null ? ' [${entry.category.toString().split('.').last}]' : '';
    final metadataStr = entry.metadata != null ? ' ${json.encode(entry.metadata)}' : '';

    debugPrint(
        '$color${_dateFormat.format(entry.timestamp)} '
            '[${entry.level.toString().split('.').last.toUpperCase()}]'
            '$categoryStr: ${entry.message}$metadataStr\x1B[0m'
    );
  }

  String _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '\x1B[36m'; // Cyan
      case LogLevel.info:
        return '\x1B[32m'; // Green
      case LogLevel.warning:
        return '\x1B[33m'; // Yellow
      case LogLevel.error:
        return '\x1B[31m'; // Red
      case LogLevel.critical:
        return '\x1B[35m'; // Magenta
    }
  }

  Future<void> _flushLogs() async {
    if (_logBuffer.isEmpty) return;

    try {
      // تحويل السجلات إلى نص
      final logsText = _logBuffer
          .map((entry) => entry.toJson())
          .map((json) => jsonEncode(json))
          .join('\n');

      // تشفير السجلات قبل الحفظ
      if (_storageService != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = 'log_$timestamp.enc';

        await _storageService!.saveSecureData(
          'logs/$filename',
          logsText,
          encrypt: true,
        );

        // حفظ السجلات في ملف مؤقت للتحليل
        if (kDebugMode) {
          await _saveDebugLogs(logsText);
        }
      }

      // مسح المخزن المؤقت
      _logBuffer.clear();
    } catch (e) {
      // في حالة فشل الحفظ، طباعة الخطأ فقط
      if (kDebugMode) {
        print('Failed to flush logs: $e');
      }
    }
  }

  Future<void> _createLogDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to create log directory: $e');
      }
    }
  }

  Future<void> _saveDebugLogs(String logs) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/logs/debug_$timestamp.log');

      await file.writeAsString(logs);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save debug logs: $e');
      }
    }
  }

  Future<List<String>> getRecentLogs({int count = 100}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) {
        return [];
      }

      final files = await logsDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.log'))
          .cast<File>()
          .toList();

      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      final logs = <String>[];
      for (var file in files.take(count)) {
        final content = await file.readAsString();
        logs.addAll(content.split('\n'));

        if (logs.length >= count) {
          break;
        }
      }

      return logs.take(count).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get recent logs: $e');
      }
      return [];
    }
  }

  Future<void> clearLogs() async {
    try {
      _logBuffer.clear();

      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (await logsDir.exists()) {
        await logsDir.delete(recursive: true);
        await _createLogDirectory();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clear logs: $e');
      }
    }
  }

  Future<void> exportLogs(String outputPath) async {
    try {
      final logs = await getRecentLogs(count: 1000);
      final exportFile = File(outputPath);

      await exportFile.writeAsString(logs.join('\n'));

      await log(
        'Logs exported to $outputPath',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      await log(
        'Failed to export logs: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
    }
  }

  // للاستخدام في حالات الطوارئ
  void emergencyLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '$timestamp [EMERGENCY]: $message';

    // طباعة مباشرة
    if (kDebugMode) {
      print(logMessage);
    }

    // محاولة الحفظ الفوري
    try {
      final file = File('emergency_log.txt');
      file.writeAsStringSync('$logMessage\n', mode: FileMode.append);
    } catch (e) {
      // تجاهل الأخطاء في حالة الطوارئ
    }
  }
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final SecurityCategory? category;
  final Map<String, dynamic>? metadata;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.category,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.toString().split('.').last,
    'message': message,
    'category': category?.toString().split('.').last,
    'metadata': metadata,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    timestamp: DateTime.parse(json['timestamp']),
    level: LogLevel.values.firstWhere(
          (e) => e.toString().split('.').last == json['level'],
    ),
    message: json['message'],
    category: json['category'] != null
        ? SecurityCategory.values.firstWhere(
          (e) => e.toString().split('.').last == json['category'],
    )
        : null,
    metadata: json['metadata'],
  );
}

// Helper extension for secure logging
extension SecureLoggerExtension on String {
  String get sanitized {
    // إزالة المعلومات الحساسة
    return replaceAll(RegExp(r'password\s*=\s*\S+'), 'password=***')
        .replaceAll(RegExp(r'token\s*=\s*\S+'), 'token=***')
        .replaceAll(RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), '***@***.***')
        .replaceAll(RegExp(r'\b\d{16}\b'), '****************') // Credit cards
        .replaceAll(RegExp(r'\b\d{3,4}\b'), '***') // CVV
        .replaceAll(RegExp(r'Bearer\s+\S+'), 'Bearer ***')
        .replaceAll(RegExp(r'Authorization:\s*\S+'), 'Authorization: ***');
  }
}