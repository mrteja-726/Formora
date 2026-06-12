// lib/core/storage/secure_storage.dart
//
// Static wrapper around FlutterSecureStorage.
// ONLY stores:
//   - Encryption master key
//   - AI API keys (per provider)
//   - App lock state
//   - Last unlock timestamp

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ── Master key ────────────────────────────────────────────────────────────

  static const _masterKeyKey = 'formora_master_key';

  static Future<String?> getMasterKey() =>
      _storage.read(key: _masterKeyKey);

  static Future<void> saveMasterKey(String key) =>
      _storage.write(key: _masterKeyKey, value: key);

  static Future<bool> hasMasterKey() async {
    final key = await _storage.read(key: _masterKeyKey);
    return key != null && key.isNotEmpty;
  }

  // ── AI API Keys ───────────────────────────────────────────────────────────

  static String _aiKeyFor(String providerId) => 'formora_ai_key_$providerId';

  static Future<String?> getAiApiKey(String providerId) =>
      _storage.read(key: _aiKeyFor(providerId));

  static Future<void> saveAiApiKey(String providerId, String apiKey) =>
      _storage.write(key: _aiKeyFor(providerId), value: apiKey);

  static Future<void> deleteAiApiKey(String providerId) =>
      _storage.delete(key: _aiKeyFor(providerId));

  static Future<bool> hasAiApiKey(String providerId) async {
    final key = await _storage.read(key: _aiKeyFor(providerId));
    return key != null && key.isNotEmpty;
  }

  // ── App Lock ──────────────────────────────────────────────────────────────

  static const _appLockKey = 'formora_app_lock_enabled';

  static Future<bool?> getAppLockEnabled() async {
    final v = await _storage.read(key: _appLockKey);
    return v == null ? null : v == 'true';
  }

  static Future<void> setAppLockEnabled(bool enabled) =>
      _storage.write(key: _appLockKey, value: enabled.toString());

  // ── Unlock timestamp ──────────────────────────────────────────────────────

  static const _lastUnlockKey = 'formora_last_unlock';

  static Future<DateTime?> getLastUnlockTimestamp() async {
    final v = await _storage.read(key: _lastUnlockKey);
    return v == null ? null : DateTime.tryParse(v);
  }

  static Future<void> setLastUnlockTimestamp(DateTime ts) =>
      _storage.write(key: _lastUnlockKey, value: ts.toIso8601String());

  // ── Wipe ──────────────────────────────────────────────────────────────────

  static Future<void> deleteAll() => _storage.deleteAll();
}
