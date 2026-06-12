// lib/features/ai_chat/data/providers/anthropic_provider.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:formora/features/ai_chat/domain/ai_provider_interface.dart';

class AnthropicProvider implements AiProviderInterface {
  final String _apiKey;

  AnthropicProvider(this._apiKey);

  @override
  String get id => 'anthropic';

  @override
  String get displayName => 'Anthropic Claude';

  @override
  String get description => 'Anthropic\'s Claude 3.5 and Claude 3 models';

  @override
  List<AiModel> get availableModels => const [
        AiModel(id: 'claude-3-5-sonnet-20241022', displayName: 'Claude 3.5 Sonnet', contextWindow: 200000),
        AiModel(id: 'claude-3-5-haiku-20241022', displayName: 'Claude 3.5 Haiku', contextWindow: 200000),
        AiModel(id: 'claude-3-opus-20240229', displayName: 'Claude 3 Opus', contextWindow: 200000),
      ];

  @override
  String get defaultModel => 'claude-3-5-haiku-20241022';

  @override
  Future<String> sendMessage({
    required List<AiChatMessage> history,
    required String userMessage,
    required String model,
    String? systemPrompt,
  }) async {
    // Anthropic uses a separate system parameter
    final messages = [
      for (final msg in history)
        if (msg.role != 'system') msg.toJson(),
      {'role': 'user', 'content': userMessage},
    ];

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': 4096,
      'messages': messages,
    };
    if (systemPrompt != null) {
      body['system'] = systemPrompt;
    }

    final response = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': _apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw AiProviderException(
          'Anthropic error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List;
    return (content[0]['text'] as String? ?? '').trim();
  }

  @override
  Future<String?> testConnection(String apiKey) async {
    try {
      // Minimal message to test auth
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-3-5-haiku-20241022',
          'max_tokens': 1,
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 400) {
        // 400 can mean model error but auth passed
        return null;
      }
      if (response.statusCode == 401) return 'Invalid API key';
      return 'Error ${response.statusCode}';
    } catch (e) {
      return 'Connection failed: $e';
    }
  }
}
