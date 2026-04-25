import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/applock_service.dart';


class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  bool _enabled = false;
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _hasBiometric = false;

  @override
  void initState() {
    super.initState();
    _enabled = AppLockService.isEnabled;
    AppLockService.isBiometricAvailable
        .then((v) => setState(() => _hasBiometric = v));
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _savePin() {
    final p1 = _pinController.text.trim();
    final p2 = _confirmController.text.trim();
    if (p1.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits.');
      return;
    }
    if (p1 != p2) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    AppLockService.setPin(p1);
    AppLockService.setEnabled(true);
    setState(() {
      _enabled = true;
      _error = null;
      _pinController.clear();
      _confirmController.clear();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('App lock enabled ✓')));
  }

  void _disable() {
    AppLockService.clearPin();
    setState(() => _enabled = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('App lock disabled')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('App Lock')),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Status card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Icon(
                    _enabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: _enabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    size: 32.sp,
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _enabled ? 'Lock is ON' : 'Lock is OFF',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _enabled
                              ? 'App will ask for PIN/biometrics on open.'
                              : 'Set a PIN below to enable.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24.h),

          if (_hasBiometric) ...[
            ListTile(
              leading: const Icon(Icons.fingerprint_rounded),
              title: const Text('Biometric unlock'),
              subtitle: const Text(
                  'Face ID / Fingerprint will be offered first when lock is on.'),
            ),
            Divider(height: 24.h),
          ],

          // Set / change PIN
          Text(
            _enabled ? 'Change PIN' : 'Set PIN',
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.primary),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'New PIN (4–6 digits)',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _confirmController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              prefixIcon: const Icon(Icons.pin_outlined),
              errorText: _error,
            ),
          ),
          SizedBox(height: 16.h),
          FilledButton.icon(
            onPressed: _savePin,
            icon: const Icon(Icons.save_rounded),
            label: Text(_enabled ? 'Update PIN' : 'Enable Lock'),
          ),

          if (_enabled) ...[
            SizedBox(height: 12.h),
            OutlinedButton.icon(
              onPressed: _disable,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Disable Lock'),
            ),
          ],
        ],
      ),
    );
  }
}
