import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Optional App Lock: off by default, the user can turn it on in Settings.
/// The PIN is never stored, only a salted SHA-256 hash of it.
class AppLock {
  static String newSalt() {
    final r = Random.secure();
    return base64Url.encode(List.generate(16, (_) => r.nextInt(256)));
  }

  static String hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static final _auth = LocalAuthentication();

  static Future<bool> biometricAvailable() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('biometric failed: $e');
      return false;
    }
  }
}
