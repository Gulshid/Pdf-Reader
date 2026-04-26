import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/applock_service.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key});

  static Future<void> show(BuildContext context) {
    debugPrint('[GATE] show() called — pushing route');
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
  bool _biometricInProgress = false;
  bool _biometricAvailable = false;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[GATE] initState');
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    debugPrint('[GATE] dispose');
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await AppLockService.isBiometricAvailable;
    debugPrint('[GATE] biometricAvailable=$available');
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
  }

  void _unlock() {
    debugPrint('[GATE] _unlock called | mounted=$mounted | _authenticated=$_authenticated');
    if (!mounted) return;
    setState(() => _authenticated = true);
    debugPrint('[GATE] _authenticated set to true — scheduling pop');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[GATE] postFrameCallback — mounted=$mounted, calling pop');
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _tryBiometric() async {
    debugPrint('[GATE] _tryBiometric called | _biometricInProgress=$_biometricInProgress');
    if (_biometricInProgress) return;

    setState(() {
      _biometricInProgress = true;
      _error = null;
    });

    debugPrint('[GATE] calling AppLockService.authenticateWithBiometrics()');
    final ok = await AppLockService.authenticateWithBiometrics();
    debugPrint('[GATE] authenticateWithBiometrics returned: $ok | mounted=$mounted');

    if (!mounted) return;
    setState(() => _biometricInProgress = false);

    if (ok) _unlock();
  }

  void _submitPin() {
    final entered = _pinController.text.trim();
    debugPrint('[GATE] _submitPin | entered.length=${entered.length}');
    if (AppLockService.verifyPin(entered)) {
      debugPrint('[GATE] PIN correct — calling _unlock');
      _unlock();
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
      canPop: _authenticated,
      onPopInvokedWithResult: (didPop, result) {
        debugPrint('[GATE] PopScope.onPopInvokedWithResult: didPop=$didPop _authenticated=$_authenticated');
      },
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

                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    autofocus: !_biometricAvailable,
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
                      onPressed: _submitPin,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Unlock with PIN'),
                    ),
                  ),

                  if (_biometricAvailable) ...[
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _biometricInProgress ? null : _tryBiometric,
                        icon: _biometricInProgress
                            ? SizedBox(
                                width: 18.w,
                                height: 18.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.primary,
                                ),
                              )
                            : const Icon(Icons.fingerprint_rounded),
                        label: Text(
                          _biometricInProgress
                              ? 'Waiting for biometric…'
                              : 'Use fingerprint / Face ID',
                        ),
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