// lib/features/ai_chat/data/ai_config_repository.dart
//
// Stores AI provider configuration:
//   - Selected provider ID (Hive — non-sensitive)
//   - Selected model per provider (Hive — non-sensitive)
//   - API keys (FlutterSecureStorage — sensitive, never in Hive)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:formora/core/storage/hive_storage.dart';
import 'package:formora/core/storage/secure_storage.dart';
import 'package:formora/core/di/providers.dart';

final aiConfigRepositoryProvider = Provider<AiConfigRepository>((ref) {
  return AiConfigRepository(ref.watch(hiveStorageProvider));
});

class AiConfigRepository {
  final HiveStorage _hive;

  static const _activeProviderKey = 'ai_active_provider';
  static const _activeModelPrefix = 'ai_model_';

  AiConfigRepository(this._hive);

  // ── Provider Selection ────────────────────────────────────────────────────

  String? get activeProviderId =>
      _hive.getAiConfig<String>(_activeProviderKey);

  Future<void> setActiveProvider(String providerId) =>
      _hive.setAiConfig(_activeProviderKey, providerId);

  // ── Model Selection ───────────────────────────────────────────────────────

  String? getSelectedModel(String providerId) =>
      _hive.getAiConfig<String>('$_activeModelPrefix$providerId');

  Future<void> setSelectedModel(String providerId, String model) =>
      _hive.setAiConfig('$_activeModelPrefix$providerId', model);

  // ── API Keys (Secure Storage only) ───────────────────────────────────────

  Future<void> saveApiKey(String providerId, String apiKey) =>
      SecureStorage.saveAiApiKey(providerId, apiKey);

  Future<String?> getApiKey(String providerId) =>
      SecureStorage.getAiApiKey(providerId);

  Future<void> deleteApiKey(String providerId) =>
      SecureStorage.deleteAiApiKey(providerId);

  Future<bool> hasApiKey(String providerId) =>
      SecureStorage.hasAiApiKey(providerId);

  // ── Config Summary ────────────────────────────────────────────────────────

  Future<Map<String, bool>> getProviderKeyStatus(
      List<String> providerIds) async {
    final result = <String, bool>{};
    for (final id in providerIds) {
      result[id] = await hasApiKey(id);
    }
    return result;
  }
}
