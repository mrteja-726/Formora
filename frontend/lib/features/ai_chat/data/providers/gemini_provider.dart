// lib/features/ai_chat/data/providers/gemini_provider.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:formora/features/ai_chat/domain/ai_provider_interface.dart';

class GeminiProvider implements AiProviderInterface {
  final String _apiKey;

  GeminiProvider(this._apiKey);

  @override
  String get id => 'gemini';

  @override
  String get displayName => 'Google Gemini';

  @override
  String get description => 'Google\'s Gemini models via Gemini API';

  @override
  List<AiModel> get availableModels => const [
        AiModel(id: 'gemini-1.5-flash', displayName: 'Gemini 1.5 Flash', contextWindow: 1048576),
        AiModel(id: 'gemini-1.5-pro', displayName: 'Gemini 1.5 Pro', contextWindow: 2097152),
        AiModel(id: 'gemini-2.0-flash', displayName: 'Gemini 2.0 Flash', contextWindow: 1048576),
      ];

  @override
  String get defaultModel => 'gemini-1.5-flash';

  @override
  Future<String> sendMessage({
    required List<AiChatMessage> history,
    required String userMessage,
    required String model,
    String? systemPrompt,
  }) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey');

    final contents = [
      if (systemPrompt != null)
        {'role': 'user', 'parts': [{'text': systemPrompt}]},
      for (final msg in history)
        {
          'role': msg.role == 'assistant' ? 'model' : 'user',
          'parts': [{'text': msg.content}]
        },
      {
        'role': 'user',
        'parts': [{'text': userMessage}]
      },
    ];

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'contents': contents}),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw AiProviderException(
          'Gemini error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const AiProviderException('Gemini returned no candidates');
    }
    final content = candidates[0]['content'] as Map<String, dynamic>;
    final parts = content['parts'] as List;
    return (parts[0]['text'] as String? ?? '').trim();
  }

  @override
  Future<String?> testConnection(String apiKey) async {
    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return null;
      return 'Invalid API key (status ${response.statusCode})';
    } catch (e) {
      return 'Connection failed: $e';
    }
  }
}
