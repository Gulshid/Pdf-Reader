import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class AppLockService {
  static final _auth = LocalAuthentication();
  static Box? get _box =>
      Hive.isBoxOpen('settings') ? Hive.box('settings') : null;

  static const _keyEnabled = 'app_lock_enabled';
  static const _keyPin = 'app_lock_pin';

  // ── Settings ──────────────────────────────────────────────────────────────

  static bool get isEnabled =>
      _box?.get(_keyEnabled, defaultValue: false) ?? false;

  static void setEnabled(bool v) => _box?.put(_keyEnabled, v);

  static String? get pin => _box?.get(_keyPin) as String?;

  static void setPin(String p) => _box?.put(_keyPin, p);

  static void clearPin() {
    _box?.delete(_keyPin);
    _box?.put(_keyEnabled, false);
  }

  // ── Biometrics ────────────────────────────────────────────────────────────

  /// True if the device supports biometrics AND has at least one enrolled.
  static Future<bool> get isBiometricAvailable async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;

      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Returns true if authentication succeeded.
  static Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock PDF Reader Pro',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == auth_error.notEnrolled ||
          e.code == auth_error.notAvailable ||
          e.code == auth_error.lockedOut ||
          e.code == auth_error.permanentlyLockedOut) {
        return false;
      }
      return false;
    }
  }

  static bool verifyPin(String entered) => entered == pin;
}
