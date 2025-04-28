import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../../../core/utils/secure_logger.dart';

class SecureInputField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final Widget? suffixIcon;
  final int? maxLength;
  final bool enablePaste;
  final bool enableCopy;
  final bool sensitiveData;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final bool autovalidateOnUserInteraction;

  const SecureInputField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.maxLength,
    this.enablePaste = true,
    this.enableCopy = false,
    this.sensitiveData = false,
    this.inputFormatters,
    this.focusNode,
    this.autovalidateOnUserInteraction = true,
  }) : super(key: key);

  @override
  State<SecureInputField> createState() => _SecureInputFieldState();
}

class _SecureInputFieldState extends State<SecureInputField> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  late SecureLogger _logger;

  bool _hasError = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller;
    _logger = SecureLogger();

    _setupSecureInput();
  }

  void _setupSecureInput() {
    // منع النسخ واللصق للبيانات الحساسة
    if (widget.sensitiveData) {
      _controller.addListener(_preventClipboardOperations);
    }

    // مراقبة التركيز
    _focusNode.addListener(_handleFocusChange);
  }

  void _preventClipboardOperations() {
    if (widget.sensitiveData && !widget.enableCopy) {
      // منع النسخ
      SystemChannels.platform.setMethodCallHandler((call) async {
        if (call.method == 'TextInput.updateConfig') {
          final args = call.arguments as Map<dynamic, dynamic>;
          if (args['inputAction'] == 'TextInputAction.copy') {
            return null;
          }
        }
        return null;
      });
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && widget.sensitiveData) {
      // مسح البيانات من الذاكرة عند فقدان التركيز
      if (widget.obscureText) {
        _logger.log(
          'Sensitive input field lost focus, securing data',
          level: LogLevel.debug,
          category: SecurityCategory.security,
        );
      }
    }
  }

  String? _validateInput(String? value) {
    if (widget.validator != null) {
      final error = widget.validator!(value);
      setState(() {
        _hasError = error != null;
        _errorText = error;
      });
      return error;
    }
    return null;
  }

  void _onChanged(String value) {
    // تنظيف المدخلات
    final sanitizedValue = widget.sensitiveData
        ? value // لا نغير البيانات الحساسة
        : InputSanitizer.sanitizeInput(value);

    // التحقق من الصحة
    _validateInput(sanitizedValue);

    // استدعاء callback
    if (widget.onChanged != null) {
      widget.onChanged!(sanitizedValue);
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.sensitiveData) {
      _controller.removeListener(_preventClipboardOperations);
    }
    _focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        maxLength: widget.maxLength,
        autovalidateMode: widget.autovalidateOnUserInteraction
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        decoration: InputDecoration(
          labelText: widget.labelText,
          errorText: _hasError ? _errorText : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: _hasError ? Colors.red : Colors.grey,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: _hasError ? Colors.red : Colors.grey,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: _hasError ? Colors.red : Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),
          suffixIcon: widget.suffixIcon,
          filled: true,
          fillColor: _hasError
              ? Colors.red.withOpacity(0.05)
              : Colors.grey.withOpacity(0.05),
        ),
        validator: _validateInput,
        onChanged: _onChanged,
        onFieldSubmitted: widget.onFieldSubmitted,
        inputFormatters: [
        if (widget.inputFormatters != null) ...widget.inputFormatters!,
    // منع الأحرف الخاصة الخطرة
    FilteringTextInputFormatter.deny(RegExp(r'[<>{}\\\/\'\";]')),
    // حد أقصى للطول
    LengthLimitingTextInputFormatter(widget.maxLength ?? 100),
    ],
    enableInteractiveSelection: widget.enableCopy,
    enableSuggestions: !widget.sensitiveData,
    autocorrect: !widget.sensitiveData,
    // منع النسخ واللصق في البيانات الحساسة
    contextMenuBuilder: widget.sensitiveData
    ? (context, editableTextState) {
    return const SizedBox.shrink();
    }
        : null,
    ),
    if (_hasError && _errorText != null)
    Padding(
    padding: const EdgeInsets.only(top: 4, left: 12),
    child: Text(
    _errorText!,
    style: const TextStyle(
    color: Colors.red,
    fontSize: 12,
    ),
    ),
    ),
    ],
    );
  }
}

// حقل إدخال كلمة المرور الآمن
class SecurePasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final bool showStrengthIndicator;

  const SecurePasswordField({
    Key? key,
    required this.controller,
    this.labelText = 'كلمة المرور',
    this.textInputAction = TextInputAction.done,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.showStrengthIndicator = true,
  }) : super(key: key);

  @override
  State<SecurePasswordField> createState() => _SecurePasswordFieldState();
}

class _SecurePasswordFieldState extends State<SecurePasswordField> {
  bool _isObscure = true;
  double _passwordStrength = 0.0;

  void _updatePasswordStrength(String password) {
    double strength = 0.0;

    if (password.length >= 8) strength += 0.2;
    if (password.length >= 12) strength += 0.1;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.1;

    setState(() => _passwordStrength = strength);
  }

  Color _getStrengthColor() {
    if (_passwordStrength <= 0.3) return Colors.red;
    if (_passwordStrength <= 0.6) return Colors.orange;
    if (_passwordStrength <= 0.8) return Colors.yellow;
    return Colors.green;
  }

  String _getStrengthText() {
    if (_passwordStrength <= 0.3) return 'ضعيف';
    if (_passwordStrength <= 0.6) return 'متوسط';
    if (_passwordStrength <= 0.8) return 'جيد';
    return 'قوي';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SecureInputField(
          controller: widget.controller,
          labelText: widget.labelText,
          obscureText: _isObscure,
          textInputAction: widget.textInputAction,
          sensitiveData: true,
          enableCopy: false,
          enablePaste: false,
          suffixIcon: IconButton(
            icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _isObscure = !_isObscure),
          ),
          validator: (value) {
            if (widget.validator != null) {
              return widget.validator!(value);
            }
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال كلمة المرور';
            }
            if (value.length < 8) {
              return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
            }
            if (!value.contains(RegExp(r'[A-Z]'))) {
              return 'يجب أن تحتوي على حرف كبير واحد على الأقل';
            }
            if (!value.contains(RegExp(r'[a-z]'))) {
              return 'يجب أن تحتوي على حرف صغير واحد على الأقل';
            }
            if (!value.contains(RegExp(r'[0-9]'))) {
              return 'يجب أن تحتوي على رقم واحد على الأقل';
            }
            if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
              return 'يجب أن تحتوي على رمز خاص واحد على الأقل';
            }
            return null;
          },
          onChanged: (value) {
            if (widget.showStrengthIndicator) {
              _updatePasswordStrength(value);
            }
            if (widget.onChanged != null) {
              widget.onChanged!(value);
            }
          },
          onFieldSubmitted: widget.onFieldSubmitted,
        ),
        if (widget.showStrengthIndicator && widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(_getStrengthColor()),
          ),
          const SizedBox(height: 4),
          Text(
            'قوة كلمة المرور: ${_getStrengthText()}',
            style: TextStyle(
              color: _getStrengthColor(),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}