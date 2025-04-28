import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';

class BiometricAuthWidget extends StatefulWidget {
  final Function()? onAuthFailed;
  final VoidCallback? onSkip;

  const BiometricAuthWidget({
    Key? key,
    this.onAuthFailed,
    this.onSkip,
  }) : super(key: key);

  @override
  State<BiometricAuthWidget> createState() => _BiometricAuthWidgetState();
}

class _BiometricAuthWidgetState extends State<BiometricAuthWidget> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isBiometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (isAvailable && isDeviceSupported) {
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        setState(() {
          _isBiometricAvailable = true;
          _availableBiometrics = availableBiometrics;
        });
      } else {
        setState(() {
          _isBiometricAvailable = false;
        });
      }
    } catch (e) {
      setState(() {
        _isBiometricAvailable = false;
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        if (mounted) {
          context.read<AuthBloc>().add(BiometricAuthEvent());
        }
      } else {
        widget.onAuthFailed?.call();
      }
    } on Exception catch (e) {
      String message = 'Biometric authentication failed';

      if (e.toString().contains(auth_error.notAvailable)) {
        message = 'Biometric authentication is not available';
      } else if (e.toString().contains(auth_error.notEnrolled)) {
        message = 'No biometric credentials enrolled';
      } else if (e.toString().contains(auth_error.lockedOut)) {
        message = 'Too many attempts. Biometric authentication locked';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }

      widget.onAuthFailed?.call();
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Widget _buildBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return const Icon(Icons.face, size: 48);
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return const Icon(Icons.fingerprint, size: 48);
    } else {
      return const Icon(Icons.security, size: 48);
    }
  }

  String _getBiometricType() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else {
      return 'Biometric';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBiometricAvailable) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _isAuthenticating ? null : _authenticate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                if (_isAuthenticating)
                  const CircularProgressIndicator()
                else
                  _buildBiometricIcon(),
                const SizedBox(height: 8),
                Text(
                  _isAuthenticating
                      ? 'Authenticating...'
                      : 'Use ${_getBiometricType()}',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.onSkip != null) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.onSkip,
            child: const Text('Skip'),
          ),
        ],
      ],
    );
  }
}

// Biometric Setup Widget for settings page
class BiometricSetupWidget extends StatefulWidget {
  const BiometricSetupWidget({Key? key}) : super(key: key);

  @override
  State<BiometricSetupWidget> createState() => _BiometricSetupWidgetState();
}

class _BiometricSetupWidgetState extends State<BiometricSetupWidget> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (isAvailable && isDeviceSupported) {
        final authBloc = context.read<AuthBloc>();
        final isEnabled = await authBloc.isBiometricEnabled();

        setState(() {
          _isBiometricAvailable = true;
          _isBiometricEnabled = isEnabled;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isBiometricAvailable = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    try {
      if (enable) {
        // Authenticate first before enabling
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Please authenticate to enable biometric login',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );

        if (authenticated) {
          context.read<AuthBloc>().add(EnableBiometricAuthEvent());
          setState(() {
            _isBiometricEnabled = true;
          });
        }
      } else {
        context.read<AuthBloc>().add(DisableBiometricAuthEvent());
        setState(() {
          _isBiometricEnabled = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${enable ? 'enable' : 'disable'} biometric authentication'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    if (!_isBiometricAvailable) {
      return ListTile(
        leading: const Icon(Icons.fingerprint, color: Colors.grey),
        title: const Text('Biometric Login'),
        subtitle: const Text('Not available on this device'),
        enabled: false,
      );
    }

    return SwitchListTile(
      title: const Text('Biometric Login'),
      subtitle: const Text('Use fingerprint or face to login'),
      value: _isBiometricEnabled,
      onChanged: _toggleBiometric,
      secondary: const Icon(Icons.fingerprint),
    );
  }
}

// Biometric Check Dialog
class BiometricCheckDialog extends StatelessWidget {
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const BiometricCheckDialog({
    Key? key,
    required this.onSuccess,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Biometric Authentication'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fingerprint, size: 48),
          SizedBox(height: 16),
          Text('Would you like to use biometric authentication?'),
          SizedBox(height: 8),
          Text(
            'This will allow you to login faster using your fingerprint or face.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: onSuccess,
          child: const Text('Enable'),
        ),
      ],
    );
  }
}