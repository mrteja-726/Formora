// lib/features/settings/application/settings_notifier.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:formora/features/settings/data/settings_repository.dart';

final settingsNotifierProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  AppSettings build() => _repo.load();

  Future<void> setThemeMode(ThemeMode mode) async {
    await _repo.setThemeMode(mode);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setDynamicColor(bool enabled) async {
    await _repo.setDynamicColor(enabled);
    state = state.copyWith(dynamicColorEnabled: enabled);
  }

  Future<void> setAppLock(bool enabled) async {
    await _repo.setAppLock(enabled);
    state = state.copyWith(appLockEnabled: enabled);
  }

  Future<void> setDefaultAiProvider(String providerId) async {
    await _repo.save(state.copyWith(defaultAiProvider: providerId));
    state = state.copyWith(defaultAiProvider: providerId);
  }
}
