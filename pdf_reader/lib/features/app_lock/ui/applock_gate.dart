import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/applock_service.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => const AppLockGate(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  final _pinController = TextEditingController();
  String? _error;
  bool _authenticating = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    // Only check if biometric is available — do NOT auto-trigger the prompt.
    // The user must tap the button themselves.
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await AppLockService.isBiometricAvailable;
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
    // ← NO auto-call to _tryBiometric() here anymore
  }

  Future<void> _tryBiometric() async {
    // Guard: if already authenticating, do nothing — prevents repeat dialogs
    if (_authenticating) return;

    setState(() {
      _authenticating = true;
      _error = null;
    });

    final ok = await AppLockService.authenticateWithBiometrics();

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      return;
    }

    // Auth failed or cancelled — reset state, let user try again manually
    setState(() => _authenticating = false);
  }

  void _submitPin() {
    final entered = _pinController.text.trim();
    if (AppLockService.verifyPin(entered)) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = 'Incorrect PIN. Try again.';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: false, // prevent back-button bypass
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 64.sp, color: cs.primary),
                  SizedBox(height: 24.h),
                  Text(
                    'App Locked',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Enter your PIN to continue.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurface.withOpacity(0.6)),
                  ),
                  SizedBox(height: 32.h),

                  // PIN field — autofocus always (no biometric auto-popup stealing focus)
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                      errorText: _error,
                      prefixIcon: const Icon(Icons.pin_outlined),
                    ),
                    onSubmitted: (_) => _submitPin(),
                  ),
                  SizedBox(height: 16.h),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _authenticating ? null : _submitPin,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Unlock with PIN'),
                    ),
                  ),

                  // Biometric button — only shown when available, only triggers on tap
                  if (_biometricAvailable) ...[
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _authenticating ? null : _tryBiometric,
                        icon: _authenticating
                            ? SizedBox(
                                width: 18.w,
                                height: 18.w,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: cs.primary),
                              )
                            : const Icon(Icons.fingerprint_rounded),
                        label: Text(_authenticating
                            ? 'Waiting for biometric…'
                            : 'Use fingerprint / Face ID'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}