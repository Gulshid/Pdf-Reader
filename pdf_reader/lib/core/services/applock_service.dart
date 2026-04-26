import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class AppLockService {
  static final _auth = LocalAuthentication();
  static Box? get _box =>
      Hive.isBoxOpen('settings') ? Hive.box('settings') : null;

  static const _keyEnabled = 'app_lock_enabled';
  static const _keyPin     = 'app_lock_pin';

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
    } on PlatformException catch (e) {
      debugPrint('[AppLockService] isBiometricAvailable error: ${e.code} ${e.message}');
      return false;
    }
  }

  /// Returns true if biometric authentication succeeded.
  ///
  /// Uses [biometricOnly: true] so the system shows fingerprint/Face ID
  /// and does NOT fall back to device PIN/pattern — that would bypass our
  /// own PIN screen and confuse the UX.
  ///
  /// [stickyAuth: true] keeps the prompt alive if the user switches away
  /// and comes back (e.g. checks a password manager).
  static Future<bool> authenticateWithBiometrics() async {
    try {
      // Stop any in-progress auth before starting a new one.
      // Prevents stacked system dialogs on repeated taps.
      await _auth.stopAuthentication();

      return await _auth.authenticate(
        localizedReason: 'Unlock PDF Reader Pro',
        options: const AuthenticationOptions(
          biometricOnly: true,   // ← fingerprint / Face ID only, no device PIN fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[AppLockService] authenticateWithBiometrics error: ${e.code} ${e.message}');

      // All known failure codes → return false so the UI can react cleanly.
      // We do NOT rethrow — the gate handles UI feedback itself.
      switch (e.code) {
        case auth_error.notEnrolled:
        case auth_error.notAvailable:
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
        case auth_error.passcodeNotSet:
        default:
          return false;
      }
    }
  }

  static bool verifyPin(String entered) => entered == pin;
}
// import 'package:flutter/services.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:local_auth/local_auth.dart';
// import 'package:local_auth/error_codes.dart' as auth_error;

// class AppLockService {
//   static final _auth = LocalAuthentication();
//   static Box? get _box =>
//       Hive.isBoxOpen('settings') ? Hive.box('settings') : null;

//   static const _keyEnabled = 'app_lock_enabled';
//   static const _keyPin = 'app_lock_pin';

//   // ── Settings ──────────────────────────────────────────────────────────────

//   static bool get isEnabled =>
//       _box?.get(_keyEnabled, defaultValue: false) ?? false;

//   static void setEnabled(bool v) => _box?.put(_keyEnabled, v);

//   static String? get pin => _box?.get(_keyPin) as String?;

//   static void setPin(String p) => _box?.put(_keyPin, p);

//   static void clearPin() {
//     _box?.delete(_keyPin);
//     _box?.put(_keyEnabled, false);
//   }

//   // ── Biometrics ────────────────────────────────────────────────────────────

//   /// True if the device supports biometrics AND has at least one enrolled.
//   static Future<bool> get isBiometricAvailable async {
//     try {
//       final supported = await _auth.isDeviceSupported();
//       if (!supported) return false;

//       final enrolled = await _auth.getAvailableBiometrics();
//       return enrolled.isNotEmpty;
//     } on PlatformException {
//       return false;
//     }
//   }

//   /// Returns true if authentication succeeded.
//   static Future<bool> authenticateWithBiometrics() async {
//     try {
//       return await _auth.authenticate(
//         localizedReason: 'Unlock PDF Reader Pro',
//         options: const AuthenticationOptions(
//           biometricOnly: false,
//           stickyAuth: true,
//           useErrorDialogs: true,
//         ),
//       );
//     } on PlatformException catch (e) {
//       if (e.code == auth_error.notEnrolled ||
//           e.code == auth_error.notAvailable ||
//           e.code == auth_error.lockedOut ||
//           e.code == auth_error.permanentlyLockedOut) {
//         return false;
//       }
//       return false;
//     }
//   }

//   static bool verifyPin(String entered) => entered == pin;
// }
