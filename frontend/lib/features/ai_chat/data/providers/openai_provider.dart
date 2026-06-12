// lib/features/ai_chat/data/providers/openai_provider.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:formora/features/ai_chat/domain/ai_provider_interface.dart';

class OpenAiProvider implements AiProviderInterface {
  final String _apiKey;

  OpenAiProvider(this._apiKey);

  @override
  String get id => 'openai';

  @override
  String get displayName => 'OpenAI';

  @override
  String get description => 'OpenAI GPT-4o and GPT-4 models';

  @override
  List<AiModel> get availableModels => const [
        AiModel(id: 'gpt-4o', displayName: 'GPT-4o', contextWindow: 128000),
        AiModel(id: 'gpt-4o-mini', displayName: 'GPT-4o Mini', contextWindow: 128000),
        AiModel(id: 'gpt-4-turbo', displayName: 'GPT-4 Turbo', contextWindow: 128000),
      ];

  @override
  String get defaultModel => 'gpt-4o-mini';

  @override
  Future<String> sendMessage({
    required List<AiChatMessage> history,
    required String userMessage,
    required String model,
    String? systemPrompt,
  }) async {
    final messages = [
      if (systemPrompt != null)
        {'role': 'system', 'content': systemPrompt},
      for (final msg in history) msg.toJson(),
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'max_tokens': 4096,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw AiProviderException(
          'OpenAI error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List;
    return (choices[0]['message']['content'] as String? ?? '').trim();
  }

  @override
  Future<String?> testConnection(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return null;
      return 'Invalid API key (status ${response.statusCode})';
    } catch (e) {
      return 'Connection failed: $e';
    }
  }
}
