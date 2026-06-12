// lib/features/ai_chat/data/providers/openrouter_provider.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:formora/features/ai_chat/domain/ai_provider_interface.dart';

class OpenRouterProvider implements AiProviderInterface {
  final String _apiKey;

  OpenRouterProvider(this._apiKey);

  @override
  String get id => 'openrouter';

  @override
  String get displayName => 'OpenRouter';

  @override
  String get description => 'Access 100+ models via OpenRouter';

  @override
  List<AiModel> get availableModels => const [
        AiModel(id: 'anthropic/claude-3.5-sonnet', displayName: 'Claude 3.5 Sonnet'),
        AiModel(id: 'google/gemini-flash-1.5', displayName: 'Gemini 1.5 Flash'),
        AiModel(id: 'openai/gpt-4o', displayName: 'GPT-4o'),
        AiModel(id: 'meta-llama/llama-3.1-70b-instruct', displayName: 'Llama 3.1 70B'),
        AiModel(id: 'mistralai/mistral-7b-instruct', displayName: 'Mistral 7B'),
        AiModel(id: 'deepseek/deepseek-r1', displayName: 'DeepSeek R1'),
      ];

  @override
  String get defaultModel => 'google/gemini-flash-1.5';

  @override
  Future<String> sendMessage({
    required List<AiChatMessage> history,
    required String userMessage,
    required String model,
    String? systemPrompt,
  }) async {
    final messages = [
      if (systemPrompt != null) {'role': 'system', 'content': systemPrompt},
      for (final msg in history) msg.toJson(),
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http
        .post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
            'HTTP-Referer': 'https://formora.app',
            'X-Title': 'Formora',
          },
          body: jsonEncode({'model': model, 'messages': messages}),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw AiProviderException(
          'OpenRouter error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List;
    return (choices[0]['message']['content'] as String? ?? '').trim();
  }

  @override
  Future<String?> testConnection(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse('https://openrouter.ai/api/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return null;
      return 'Invalid API key (status ${response.statusCode})';
    } catch (e) {
      return 'Connection failed: $e';
    }
  }
}
