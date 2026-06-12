import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:formora/features/ai_chat/application/ai_chat_notifier.dart';
import 'package:formora/features/ai_chat/data/ai_config_repository.dart';
import 'package:formora/features/profile/application/profile_notifier.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  final String? conversationId;
  const AiChatScreen({super.key, this.conversationId});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.conversationId != null) {
        ref.read(aiChatNotifierProvider.notifier).loadConversation(widget.conversationId!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant AiChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversationId != oldWidget.conversationId && widget.conversationId != null) {
      ref.read(aiChatNotifierProvider.notifier).loadConversation(widget.conversationId!);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final profile = ref.read(activeProfileProvider).value;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a profile first')),
      );
      return;
    }

    _messageController.clear();
    final chatNotifier = ref.read(aiChatNotifierProvider.notifier);
    await chatNotifier.sendMessage(text, profile.id);

    // Scroll to bottom after state updates
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatNotifierProvider);
    final convoId = widget.conversationId ?? chatState.conversationId;

    if (convoId == null) {
      return _buildAiHubDashboard(context);
    }

    return _buildChatInterface(context, convoId, chatState);
  }

  // ── AI HUB DASHBOARD (No active conversation) ─────────────────────────────
  Widget _buildAiHubDashboard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = ref.watch(aiConfigRepositoryProvider);
    final activeProviderId = config.activeProviderId;
    final selectedModel = activeProviderId != null ? config.getSelectedModel(activeProviderId) : null;
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formora AI Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings/ai'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AI Provider status card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.04),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome, color: colorScheme.primary, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeProviderId == null
                                  ? 'No AI Connected'
                                  : (activeProviderId == 'gemini'
                                      ? 'Google Gemini'
                                      : activeProviderId.toUpperCase()),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              activeProviderId == null
                                  ? 'Click Settings to add API Key'
                                  : 'Model: ${selectedModel ?? "Default"}',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => context.push('/settings/ai'),
                      ),
                    ],
                  ),
                  if (activeProviderId != null) ...[
                    const Divider(height: 32),
                    Row(
                      children: [
                        const Icon(Icons.circle, size: 10, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Connected locally',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Suggestion categories
            const Text(
              'Intelligent Actions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildActionCard(
                  context,
                  icon: Icons.analytics_outlined,
                  label: 'Analyze Docs',
                  onTap: () => _startNewChatWithMessage('Analyze my uploaded documents for key fields.'),
                ),
                _buildActionCard(
                  context,
                  icon: Icons.account_tree_outlined,
                  label: 'Check Profile',
                  onTap: () => _startNewChatWithMessage('Are there any missing details in my profile?'),
                ),
                _buildActionCard(
                  context,
                  icon: Icons.edit_note,
                  label: 'Fill Help',
                  onTap: () => _startNewChatWithMessage('Explain how to autofill the forms using the browser extension.'),
                ),
                _buildActionCard(
                  context,
                  icon: Icons.search,
                  label: 'Find Info',
                  onTap: () => _startNewChatWithMessage('Search for my phone number or email in the vault documents.'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent chats list
            const Text(
              'Recent Conversations',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            conversationsAsync.when(
              data: (convos) {
                if (convos.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'No previous chats',
                        style: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: convos.length,
                  itemBuilder: (context, idx) {
                    final convo = convos[idx];
                    return Card(
                      color: colorScheme.surfaceContainerLow,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(
                          convo.title ?? 'New Conversation',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () => ref.read(aiChatNotifierProvider.notifier).loadConversation(convo.id),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Failed to load conversations'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startNewChatWithMessage(''),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colorScheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNewChatWithMessage(String message) async {
    final profile = ref.read(activeProfileProvider).value;
    if (profile == null) return;
    
    final notifier = ref.read(aiChatNotifierProvider.notifier);
    await notifier.startNewConversation(profile.id);
    if (message.isNotEmpty) {
      await notifier.sendMessage(message, profile.id);
    }
  }

  // ── AI CHAT INTERFACE (With active conversation) ──────────────────────────
  Widget _buildChatInterface(BuildContext context, String convoId, AiChatState chatState) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(aiChatNotifierProvider.notifier).startNewConversation(''); // Reset
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings/ai'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: chatState.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 48, color: colorScheme.primary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          'Ask anything about your documents or profile details',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, idx) {
                      final msg = chatState.messages[idx];
                      final isUser = msg.role == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? colorScheme.primary : colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.content,
                                style: TextStyle(
                                  color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          if (chatState.isLoading) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ],

          if (chatState.errorMessage != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(10),
              color: Colors.red.shade900.withOpacity(0.1),
              child: Text(
                chatState.errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],

          // Suggestions / Composer row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your documents...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: colorScheme.primary,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
