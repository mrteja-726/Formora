// lib/core/security/biometric_service.dart
//
// Handles:
//  - Optional app-level lock (on cold start / resume after timeout)
//  - Mandatory authentication for sensitive actions

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'package:formora/core/storage/secure_storage.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

enum BiometricResult { success, failed, notAvailable, notEnrolled, cancelled }

enum SensitiveAction {
  appUnlock,
  backupRestore,
  viewSensitiveField,
  deleteProfile,
  exportData,
  changeAiKey,
}

extension SensitiveActionLabel on SensitiveAction {
  String get localizedReason {
    switch (this) {
      case SensitiveAction.appUnlock:
        return 'Unlock Formora to access your data';
      case SensitiveAction.backupRestore:
        return 'Authenticate to restore your backup';
      case SensitiveAction.viewSensitiveField:
        return 'Authenticate to view this sensitive field';
      case SensitiveAction.deleteProfile:
        return 'Authenticate to delete this profile';
      case SensitiveAction.exportData:
        return 'Authenticate to export your data';
      case SensitiveAction.changeAiKey:
        return 'Authenticate to change AI provider settings';
    }
  }
}

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<List<BiometricType>> enrolledBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  Future<bool> isAppLockEnabled() async {
    return await SecureStorage.getAppLockEnabled() ?? false;
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    await SecureStorage.setAppLockEnabled(enabled);
  }

  Future<BiometricResult> authenticate(SensitiveAction action) async {
    if (!await isAvailable()) {
      return BiometricResult.notAvailable;
    }

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: action.localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
      return authenticated ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
          return BiometricResult.notAvailable;
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          return BiometricResult.notEnrolled;
        case LocalAuthExceptionCode.userCanceled:
          return BiometricResult.cancelled;
        default:
          return BiometricResult.failed;
      }
    }
  }

  Future<void> requireAuthentication(SensitiveAction action) async {
    final result = await authenticate(action);
    switch (result) {
      case BiometricResult.success:
        return;
      case BiometricResult.notAvailable:
        throw BiometricException(
            'Device authentication is not available. Please set up a PIN or biometric in device settings.');
      case BiometricResult.notEnrolled:
        throw BiometricException('No biometric or PIN enrolled on this device.');
      case BiometricResult.cancelled:
        throw BiometricCancelledException();
      case BiometricResult.failed:
        throw BiometricException('Authentication failed.');
    }
  }

  Future<bool> shouldShowAppLock() async {
    if (!await isAppLockEnabled()) return false;
    final lastUnlock = await SecureStorage.getLastUnlockTimestamp();
    if (lastUnlock == null) return true;
    final elapsed = DateTime.now().difference(lastUnlock);
    return elapsed.inMinutes >= 5;
  }

  Future<void> recordUnlock() async {
    await SecureStorage.setLastUnlockTimestamp(DateTime.now());
  }
}

class BiometricException implements Exception {
  final String message;
  const BiometricException(this.message);
  @override
  String toString() => 'BiometricException: $message';
}

class BiometricCancelledException implements Exception {
  const BiometricCancelledException();
  @override
  String toString() => 'BiometricCancelledException';
}
