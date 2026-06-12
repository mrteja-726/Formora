// lib/features/ai_chat/data/ai_provider_registry.dart
//
// Factory that builds the correct AiProviderInterface from stored config.
// Add new providers here — no other files need to change.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:formora/features/ai_chat/domain/ai_provider_interface.dart';
import 'package:formora/features/ai_chat/data/ai_config_repository.dart';
import 'package:formora/features/ai_chat/data/providers/anthropic_provider.dart';
import 'package:formora/features/ai_chat/data/providers/gemini_provider.dart';
import 'package:formora/features/ai_chat/data/providers/openai_provider.dart';
import 'package:formora/features/ai_chat/data/providers/openrouter_provider.dart';

final aiProviderRegistryProvider =
    Provider<AiProviderRegistry>((ref) {
  return AiProviderRegistry(ref.watch(aiConfigRepositoryProvider));
});

/// Provider that resolves to the currently configured AI provider instance.
/// Returns null if no provider is configured or API key is missing.
final activeAiProviderProvider =
    FutureProvider<AiProviderInterface?>((ref) async {
  final registry = ref.watch(aiProviderRegistryProvider);
  return registry.getActiveProvider();
});

class AiProviderRegistry {
  final AiConfigRepository _config;

  AiProviderRegistry(this._config);

  /// All registered provider metadata (no keys needed).
  List<ProviderMetadata> get allProviders => const [
        ProviderMetadata(id: 'gemini', displayName: 'Google Gemini', description: 'Gemini 1.5 Flash / Pro', emoji: '✨'),
        ProviderMetadata(id: 'openai', displayName: 'OpenAI', description: 'GPT-4o and GPT-4 Turbo', emoji: '🤖'),
        ProviderMetadata(id: 'openrouter', displayName: 'OpenRouter', description: '100+ models in one place', emoji: '🔀'),
        ProviderMetadata(id: 'anthropic', displayName: 'Anthropic Claude', description: 'Claude 3.5 Sonnet / Haiku', emoji: '🧠'),
      ];

  /// Build the active provider instance using the stored API key.
  Future<AiProviderInterface?> getActiveProvider() async {
    final providerId = _config.activeProviderId;
    if (providerId == null) return null;
    return buildProvider(providerId);
  }

  /// Build any provider instance by ID.
  Future<AiProviderInterface?> buildProvider(String providerId) async {
    final apiKey = await _config.getApiKey(providerId);
    if (apiKey == null || apiKey.isEmpty) return null;
    return _instantiate(providerId, apiKey);
  }

  AiProviderInterface? _instantiate(String providerId, String apiKey) {
    switch (providerId) {
      case 'gemini':
        return GeminiProvider(apiKey);
      case 'openai':
        return OpenAiProvider(apiKey);
      case 'openrouter':
        return OpenRouterProvider(apiKey);
      case 'anthropic':
        return AnthropicProvider(apiKey);
      default:
        return null;
    }
  }

  /// Test a provider's API key before saving it.
  Future<String?> testProvider(String providerId, String apiKey) async {
    final instance = _instantiate(providerId, apiKey);
    if (instance == null) return 'Unknown provider: $providerId';
    return instance.testConnection(apiKey);
  }

  /// Save a tested API key and set as active provider.
  Future<void> configureProvider({
    required String providerId,
    required String apiKey,
    String? model,
  }) async {
    await _config.saveApiKey(providerId, apiKey);
    await _config.setActiveProvider(providerId);
    if (model != null) {
      await _config.setSelectedModel(providerId, model);
    }
  }
}

class ProviderMetadata {
  final String id;
  final String displayName;
  final String description;
  final String emoji;

  const ProviderMetadata({
    required this.id,
    required this.displayName,
    required this.description,
    required this.emoji,
  });
}
