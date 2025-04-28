import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import '../utils/secure_logger.dart';

class ObfuscationService {
  final SecureLogger _logger;
  final Random _random = Random.secure();

  // قاموس التعتيم
  final Map<String, String> _obfuscationMap = {};
  final Map<String, String> _reverseMap = {};

  ObfuscationService(this._logger);

  Future<void> initialize() async {
    try {
      _generateObfuscationMaps();

      _logger.log(
        'Obfuscation service initialized',
        level: LogLevel.info,
        category: SecurityCategory.security,
      );
    } catch (e) {
      _logger.log(
        'Obfuscation service initialization failed: $e',
        level: LogLevel.error,
        category: SecurityCategory.security,
      );
      rethrow;
    }
  }

  /// تعتيم النص
  String obfuscate(String text) {
    if (text.isEmpty) return text;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final obfuscatedChar = _obfuscationMap[char] ?? _obfuscateChar(char);
      buffer.write(obfuscatedChar);
    }

    return buffer.toString();
  }

  /// فك تعتيم النص
  String deobfuscate(String obfuscatedText) {
    if (obfuscatedText.isEmpty) return obfuscatedText;

    final buffer = StringBuffer();
    for (int i = 0; i < obfuscatedText.length; i++) {
      final char = obfuscatedText[i];
      final originalChar = _reverseMap[char] ?? char;
      buffer.write(originalChar);
    }

    return buffer.toString();
  }

  /// تعتيم كائن JSON
  Map<String, dynamic> obfuscateJson(Map<String, dynamic> json) {
    final obfuscated = <String, dynamic>{};

    json.forEach((key, value) {
      final obfuscatedKey = obfuscate(key);

      if (value is String) {
        obfuscated[obfuscatedKey] = obfuscate(value);
      } else if (value is Map<String, dynamic>) {
        obfuscated[obfuscatedKey] = obfuscateJson(value);
      } else if (value is List) {
        obfuscated[obfuscatedKey] = obfuscateList(value);
      } else {
        obfuscated[obfuscatedKey] = value;
      }
    });

    return obfuscated;
  }

  /// فك تعتيم كائن JSON
  Map<String, dynamic> deobfuscateJson(Map<String, dynamic> obfuscatedJson) {
    final deobfuscated = <String, dynamic>{};

    obfuscatedJson.forEach((key, value) {
      final originalKey = deobfuscate(key);

      if (value is String) {
        deobfuscated[originalKey] = deobfuscate(value);
      } else if (value is Map<String, dynamic>) {
        deobfuscated[originalKey] = deobfuscateJson(value);
      } else if (value is List) {
        deobfuscated[originalKey] = deobfuscateList(value);
      } else {
        deobfuscated[originalKey] = value;
      }
    });

    return deobfuscated;
  }

  /// تعتيم قائمة
  List<dynamic> obfuscateList(List<dynamic> list) {
    return list.map((item) {
      if (item is String) {
        return obfuscate(item);
      } else if (item is Map<String, dynamic>) {
        return obfuscateJson(item);
      } else if (item is List) {
        return obfuscateList(item);
      } else {
        return item;
      }
    }).toList();
  }

  /// فك تعتيم قائمة
  List<dynamic> deobfuscateList(List<dynamic> obfuscatedList) {
    return obfuscatedList.map((item) {
      if (item is String) {
        return deobfuscate(item);
      } else if (item is Map<String, dynamic>) {
        return deobfuscateJson(item);
      } else if (item is List) {
        return deobfuscateList(item);
      } else {
        return item;
      }
    }).toList();
  }

  /// تعتيم الأسماء المتغيرة
  String obfuscateVariableName(String name) {
    final hash = _generateHash(name);
    return '_${hash.substring(0, 8)}';
  }

  /// تعتيم أسماء الملفات
  String obfuscateFileName(String fileName) {
    final extension = fileName.split('.').last;
    final baseName = fileName.substring(0, fileName.lastIndexOf('.'));
    final obfuscatedBaseName = obfuscate(baseName);
    return '$obfuscatedBaseName.$extension';
  }

  /// تعتيم المسارات
  String obfuscatePath(String path) {
    final segments = path.split('/');
    final obfuscatedSegments = segments.map((segment) {
      if (segment.isEmpty || segment == '.' || segment == '..') {
        return segment;
      }
      return obfuscate(segment);
    }).toList();

    return obfuscatedSegments.join('/');
  }

  /// تعتيم كود المصدر
  String obfuscateSourceCode(String code) {
    // تعتيم الثوابت النصية
    code = _obfuscateStringLiterals(code);

    // تعتيم أسماء المتغيرات
    code = _obfuscateVariables(code);

    // تعتيم أسماء الدوال
    code = _obfuscateFunctions(code);

    // إضافة كود مزيف
    code = _injectDummyCode(code);

    return code;
  }

  void _generateObfuscationMaps() {
    // توليد خريطة التعتيم للحروف
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final charList = chars.split('');
    final shuffledList = List<String>.from(charList)..shuffle(_random);

    for (int i = 0; i < charList.length; i++) {
      _obfuscationMap[charList[i]] = shuffledList[i];
      _reverseMap[shuffledList[i]] = charList[i];
    }
  }

  String _obfuscateChar(String char) {
    // للحروف غير الموجودة في الخريطة
    final code = char.codeUnitAt(0);
    final obfuscatedCode = (code + 13) % 256; // ROT13-like
    return String.fromCharCode(obfuscatedCode);
  }

  String _generateHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _obfuscateStringLiterals(String code) {
    // تعتيم الثوابت النصية في الكود
    return code.replaceAllMapped(
      RegExp(r'"([^"]*)"'),
          (match) {
        final literal = match.group(1)!;
        return '"${obfuscate(literal)}"';
      },
    );
  }

  String _obfuscateVariables(String code) {
    // تعتيم أسماء المتغيرات
    return code.replaceAllMapped(
      RegExp(r'\b(var|final|const)\s+([a-zA-Z_][a-zA-Z0-9_]*)\b'),
          (match) {
        final type = match.group(1)!;
        final name = match.group(2)!;
        return '$type ${obfuscateVariableName(name)}';
      },
    );
  }

  String _obfuscateFunctions(String code) {
    // تعتيم أسماء الدوال
    return code.replaceAllMapped(
      RegExp(r'\b([a-zA-Z_][a-zA-Z0-9_]*)\s*\('),
          (match) {
        final name = match.group(1)!;
        if (name == 'void' || name == 'if' || name == 'while' || name == 'for') {
          return match.group(0)!;
        }
        return '${obfuscateVariableName(name)}(';
      },
    );
  }

  String _injectDummyCode(String code) {
    // إضافة كود مزيف لتعقيد عملية الهندسة العكسية
    final dummyCode = '''
      // START_DUMMY_CODE
      if (false) {
        ${_generateDummyCode()}
      }
      // END_DUMMY_CODE
    ''';

    // إدراج الكود المزيف في أماكن عشوائية
    final lines = code.split('\n');
    final insertIndex = _random.nextInt(lines.length);
    lines.insert(insertIndex, dummyCode);

    return lines.join('\n');
  }

  String _generateDummyCode() {
    final operations = [
      'var _dummy = ${_random.nextInt(1000)};',
      'for (int i = 0; i < ${_random.nextInt(10)}; i++) { /* dummy */ }',
      'if (_dummy > ${_random.nextInt(500)}) { _dummy--; }',
      'while (false) { /* dummy */ }',
    ];

    return operations[_random.nextInt(operations.length)];
  }

  /// تعتيم المفاتيح
  String obfuscateKey(String key) {
    final parts = <String>[];
    for (int i = 0; i < key.length; i += 4) {
      final end = (i + 4 > key.length) ? key.length : i + 4;
      parts.add(key.substring(i, end));
    }

    parts.shuffle(_random);
    return parts.map((part) => obfuscate(part)).join('-');
  }

  /// فك تعتيم المفاتيح
  String deobfuscateKey(String obfuscatedKey) {
    final parts = obfuscatedKey.split('-');
    final deobfuscatedParts = parts.map((part) => deobfuscate(part)).toList();

    // إعادة ترتيب الأجزاء
    // هذا يتطلب معرفة الترتيب الأصلي أو تخزينه
    return deobfuscatedParts.join();
  }
}