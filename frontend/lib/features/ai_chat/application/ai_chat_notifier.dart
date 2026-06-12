// lib/features/ai_chat/application/ai_chat_notifier.dart
//
// Manages AI chat state for a single conversation.
// Injects profile context into system prompt.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:formora/core/database/tables/ai_tables.dart';
import 'package:formora/core/database/app_database.dart';
import 'package:formora/core/di/providers.dart';
import 'package:formora/features/profile/application/profile_notifier.dart';
import 'package:formora/features/profile/domain/profile_entities.dart';
import 'package:formora/features/ai_chat/data/ai_config_repository.dart';
import 'package:formora/features/ai_chat/data/ai_provider_registry.dart';
import 'package:formora/features/ai_chat/domain/ai_provider_interface.dart';
import 'package:drift/drift.dart';

// ── State ──────────────────────────────────────────────────────────────────

class AiChatState {
  final List<AiChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;
  final String? conversationId;
  final String? providerId;
  final String? model;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
    this.conversationId,
    this.providerId,
    this.model,
  });

  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    String? conversationId,
    String? providerId,
    String? model,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      conversationId: conversationId ?? this.conversationId,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
    );
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final aiChatNotifierProvider =
    NotifierProvider<AiChatNotifier, AiChatState>(AiChatNotifier.new);

/// Conversations list for the active profile.
final conversationsProvider = StreamProvider<List<dynamic>>((ref) {
  final activeProfile = ref.watch(activeProfileProvider);
  return activeProfile.when(
    data: (profile) {
      if (profile == null) return Stream.value([]);
      return ref.watch(aiDaoProvider).watchConversationsForProfile(profile.id);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// ── Notifier ──────────────────────────────────────────────────────────────

class AiChatNotifier extends Notifier<AiChatState> {
  final _uuid = const Uuid();

  AiProviderRegistry get _registry => ref.read(aiProviderRegistryProvider);
  AiConfigRepository get _config => ref.read(aiConfigRepositoryProvider);

  @override
  AiChatState build() {
    final providerId = _config.activeProviderId;
    final model = providerId != null ? _config.getSelectedModel(providerId) : null;
    return AiChatState(providerId: providerId, model: model);
  }

  // ── Conversation ──────────────────────────────────────────────────────────

  Future<void> startNewConversation(String profileId) async {
    final convoId = _uuid.v4();
    final providerId = _config.activeProviderId ?? 'gemini';
    final model = _config.getSelectedModel(providerId) ?? 'gemini-1.5-flash';

    await ref.read(aiDaoProvider).insertConversation(
      AiConversationsTableCompanion.insert(
        id: convoId,
        profileId: profileId,
        provider: providerId,
        model: Value(model),
      ),
    );

    state = state.copyWith(
      conversationId: convoId,
      messages: [],
      isLoading: false,
      errorMessage: null,
      providerId: providerId,
      model: model,
    );
  }

  Future<void> loadConversation(String conversationId) async {
    final dao = ref.read(aiDaoProvider);
    final rawMessages = await dao.getMessagesForConversation(conversationId);
    final messages = rawMessages
        .map((m) => AiChatMessage(role: m.role, content: m.content))
        .toList();

    final convo = await dao.getConversationById(conversationId);
    state = state.copyWith(
      conversationId: conversationId,
      messages: messages,
      providerId: convo?.provider,
      model: convo?.model,
    );
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  Future<void> sendMessage(String userText, String profileId) async {
    if (userText.trim().isEmpty) return;

    final provider = await _registry.getActiveProvider();
    if (provider == null) {
      state = state.copyWith(
          errorMessage: 'No AI provider configured. Go to Settings → AI.');
      return;
    }

    // Ensure we have a conversation
    if (state.conversationId == null) {
      await startNewConversation(profileId);
    }

    // Optimistic UI: add user message immediately
    final userMsg = AiChatMessage(role: 'user', content: userText);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      errorMessage: null,
    );

    // Persist user message
    await _persistMessage(state.conversationId!, userMsg, provider.id, state.model ?? '');

    try {
      final systemPrompt = await _buildSystemPrompt(profileId);
      final selectedModel =
          state.model ?? _config.getSelectedModel(provider.id) ?? provider.defaultModel;

      final response = await provider.sendMessage(
        history: state.messages.sublist(0, state.messages.length - 1),
        userMessage: userText,
        model: selectedModel,
        systemPrompt: systemPrompt,
      );

      final assistantMsg =
          AiChatMessage(role: 'assistant', content: response);
      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
      );

      await _persistMessage(state.conversationId!, assistantMsg, provider.id, selectedModel);

      // Update conversation title from first user message
      if (state.messages.where((m) => m.role == 'user').length == 1) {
        await _updateConversationTitle(
            state.conversationId!, userText.substring(0, userText.length.clamp(0, 50)));
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to get response: $e',
      );
    }
  }

  void clearError() => state = state.copyWith(errorMessage: null);

  // ── Private Helpers ───────────────────────────────────────────────────────

  Future<String> _buildSystemPrompt(String profileId) async {
    // Inject non-sensitive profile context
    final profileAsync = ref.read(activeProfileProvider);
    final profileName = profileAsync.value?.name ?? 'User';
    return '''You are a helpful AI assistant integrated into Formora, a personal data management app.
The user's name is $profileName.
You help users understand their profile data, fill in missing information, and manage their personal documents.
Be concise, helpful, and privacy-conscious. Never ask for sensitive data like passwords.''';
  }

  Future<void> _persistMessage(
      String convoId, AiChatMessage msg, String providerId, String model) async {
    await ref.read(aiDaoProvider).insertMessage(
      AiMessagesTableCompanion.insert(
        id: _uuid.v4(),
        conversationId: convoId,
        role: msg.role,
        content: msg.content,
        provider: Value(providerId),
        model: Value(model),
      ),
    );
  }

  Future<void> _updateConversationTitle(String convoId, String title) async {
    final dao = ref.read(aiDaoProvider);
    final convo = await dao.getConversationById(convoId);
    if (convo == null) return;
    await dao.updateConversation(
      AiConversationsTableCompanion(
        id: Value(convoId),
        title: Value('$title...'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
