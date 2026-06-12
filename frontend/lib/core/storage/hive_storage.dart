// lib/core/storage/hive_storage.dart
//
// Manages Hive CE initialization and typed box access.
// Settings (non-sensitive) and AI config metadata (no API keys) live here.

import 'package:hive_ce_flutter/hive_flutter.dart';

class HiveBoxNames {
  static const settings = 'formora_settings';
  static const aiConfig = 'formora_ai_config';
  static const uiCache = 'formora_ui_cache';
}

class HiveStorage {
  late final Box<dynamic> _settingsBox;
  late final Box<dynamic> _aiConfigBox;
  late final Box<dynamic> _uiCacheBox;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _settingsBox = await Hive.openBox<dynamic>(HiveBoxNames.settings);
    _aiConfigBox = await Hive.openBox<dynamic>(HiveBoxNames.aiConfig);
    _uiCacheBox = await Hive.openBox<dynamic>(HiveBoxNames.uiCache);
    _initialized = true;
  }

  Box<dynamic> get settings => _settingsBox;
  Box<dynamic> get aiConfig => _aiConfigBox;
  Box<dynamic> get uiCache => _uiCacheBox;

  // ── Settings helpers ───────────────────────────────────────────────────

  T? getSetting<T>(String key) => _settingsBox.get(key) as T?;
  Future<void> setSetting<T>(String key, T value) =>
      _settingsBox.put(key, value);
  Future<void> deleteSetting(String key) => _settingsBox.delete(key);

  // ── AI config helpers (non-sensitive meta only) ─────────────────────────

  T? getAiConfig<T>(String key) => _aiConfigBox.get(key) as T?;
  Future<void> setAiConfig<T>(String key, T value) =>
      _aiConfigBox.put(key, value);
  Future<void> deleteAiConfig(String key) => _aiConfigBox.delete(key);

  // ── UI cache helpers ───────────────────────────────────────────────────

  T? getCache<T>(String key) => _uiCacheBox.get(key) as T?;
  Future<void> setCache<T>(String key, T value) => _uiCacheBox.put(key, value);

  Future<void> clearAll() async {
    await _settingsBox.clear();
    await _aiConfigBox.clear();
    await _uiCacheBox.clear();
  }
}
