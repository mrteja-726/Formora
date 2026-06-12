// lib/features/ai_chat/domain/ai_provider_interface.dart
//
// Abstract interface for all AI providers.
// Add a new provider by implementing this interface.

abstract class AiProviderInterface {
  /// Unique identifier (stored in settings).
  String get id;

  /// Human-readable display name.
  String get displayName;

  /// Short description shown in settings.
  String get description;

  /// Models available for this provider (for UI selector).
  List<AiModel> get availableModels;

  /// Default model id.
  String get defaultModel;

  /// Send a chat message and receive a response.
  Future<String> sendMessage({
    required List<AiChatMessage> history,
    required String userMessage,
    required String model,
    String? systemPrompt,
  });

  /// Test connectivity + API key validity.
  /// Returns null on success, error string on failure.
  Future<String?> testConnection(String apiKey);
}

class AiModel {
  final String id;
  final String displayName;
  final int? contextWindow;

  const AiModel({
    required this.id,
    required this.displayName,
    this.contextWindow,
  });
}

class AiChatMessage {
  final String role; // user | assistant | system
  final String content;

  const AiChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AiProviderException implements Exception {
  final String message;
  const AiProviderException(this.message);
  @override
  String toString() => 'AiProviderException: $message';
}
