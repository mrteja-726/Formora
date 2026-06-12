// lib/features/settings/data/settings_repository.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:formora/core/storage/hive_storage.dart';
import 'package:formora/core/di/providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(hiveStorageProvider));
});

class AppSettings {
  final ThemeMode themeMode;
  final bool dynamicColorEnabled;
  final bool appLockEnabled;
  final String defaultAiProvider;
  final bool analyticsEnabled; // Always false — no analytics by default
  final bool showOcrConfidenceBadge;
  final bool autoBackupEnabled;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.dynamicColorEnabled = true,
    this.appLockEnabled = false,
    this.defaultAiProvider = 'gemini',
    this.analyticsEnabled = false, // Cannot be enabled
    this.showOcrConfidenceBadge = true,
    this.autoBackupEnabled = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? dynamicColorEnabled,
    bool? appLockEnabled,
    String? defaultAiProvider,
    bool? showOcrConfidenceBadge,
    bool? autoBackupEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      dynamicColorEnabled: dynamicColorEnabled ?? this.dynamicColorEnabled,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      defaultAiProvider: defaultAiProvider ?? this.defaultAiProvider,
      analyticsEnabled: false, // Always false
      showOcrConfidenceBadge: showOcrConfidenceBadge ?? this.showOcrConfidenceBadge,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
    );
  }
}

class SettingsRepository {
  final HiveStorage _hive;

  static const _themeModeKey = 'theme_mode';
  static const _dynamicColorKey = 'dynamic_color';
  static const _appLockKey = 'app_lock';
  static const _defaultAiKey = 'default_ai_provider';
  static const _ocrBadgeKey = 'ocr_confidence_badge';
  static const _autoBackupKey = 'auto_backup';

  SettingsRepository(this._hive);

  AppSettings load() {
    return AppSettings(
      themeMode: _parseThemeMode(_hive.getSetting<String>(_themeModeKey)),
      dynamicColorEnabled: _hive.getSetting<bool>(_dynamicColorKey) ?? true,
      appLockEnabled: _hive.getSetting<bool>(_appLockKey) ?? false,
      defaultAiProvider:
          _hive.getSetting<String>(_defaultAiKey) ?? 'gemini',
      showOcrConfidenceBadge: _hive.getSetting<bool>(_ocrBadgeKey) ?? true,
      autoBackupEnabled: _hive.getSetting<bool>(_autoBackupKey) ?? false,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _hive.setSetting(_themeModeKey, _themeModeToKey(settings.themeMode));
    await _hive.setSetting(_dynamicColorKey, settings.dynamicColorEnabled);
    await _hive.setSetting(_appLockKey, settings.appLockEnabled);
    await _hive.setSetting(_defaultAiKey, settings.defaultAiProvider);
    await _hive.setSetting(_ocrBadgeKey, settings.showOcrConfidenceBadge);
    await _hive.setSetting(_autoBackupKey, settings.autoBackupEnabled);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _hive.setSetting(_themeModeKey, _themeModeToKey(mode));
  }

  Future<void> setDynamicColor(bool enabled) async {
    await _hive.setSetting(_dynamicColorKey, enabled);
  }

  Future<void> setAppLock(bool enabled) async {
    await _hive.setSetting(_appLockKey, enabled);
  }

  ThemeMode _parseThemeMode(String? key) {
    switch (key) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  String _themeModeToKey(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'light';
      case ThemeMode.dark: return 'dark';
      case ThemeMode.system: return 'system';
    }
  }
}
