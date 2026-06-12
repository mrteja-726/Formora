// lib/core/database/daos/ai_dao.dart
import 'package:drift/drift.dart';

import 'package:formora/core/database/app_database.dart';
import 'package:formora/core/database/tables/ai_tables.dart';

part 'ai_dao.g.dart';

@DriftAccessor(tables: [AiConversationsTable, AiMessagesTable])
class AiDao extends DatabaseAccessor<AppDatabase> with _$AiDaoMixin {
  AiDao(super.db);

  // ── Conversations ──────────────────────────────────────────────────────────

  /// Watch all conversations for a profile (not deleted), newest first.
  Stream<List<AiConversationsTableData>> watchConversationsForProfile(
          String profileId) =>
      (select(aiConversationsTable)
            ..where((t) =>
                t.profileId.equals(profileId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  /// Get all conversations for a profile.
  Future<List<AiConversationsTableData>> getConversationsForProfile(
          String profileId) =>
      (select(aiConversationsTable)
            ..where((t) =>
                t.profileId.equals(profileId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  /// Get a single conversation by id.
  Future<AiConversationsTableData?> getConversationById(String id) =>
      (select(aiConversationsTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Insert a new conversation.
  Future<void> insertConversation(
          AiConversationsTableCompanion conversation) =>
      into(aiConversationsTable).insert(conversation);

  /// Update conversation (title, model, updatedAt).
  Future<bool> updateConversation(
          AiConversationsTableCompanion conversation) =>
      update(aiConversationsTable).replace(conversation);

  /// Soft-delete a conversation.
  Future<void> deleteConversation(String conversationId) =>
      (update(aiConversationsTable)
            ..where((t) => t.id.equals(conversationId)))
          .write(const AiConversationsTableCompanion(isDeleted: Value(true)));

  /// Permanently delete old soft-deleted conversations.
  Future<void> purgeDeletedConversations() =>
      (delete(aiConversationsTable)
            ..where((t) => t.isDeleted.equals(true)))
          .go();

  // ── Messages ───────────────────────────────────────────────────────────────

  /// Watch messages for a conversation, oldest first.
  Stream<List<AiMessagesTableData>> watchMessagesForConversation(
          String conversationId) =>
      (select(aiMessagesTable)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  /// Get all messages for a conversation.
  Future<List<AiMessagesTableData>> getMessagesForConversation(
          String conversationId) =>
      (select(aiMessagesTable)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// Insert a message.
  Future<void> insertMessage(AiMessagesTableCompanion message) =>
      into(aiMessagesTable).insert(message);

  /// Delete all messages for a conversation.
  Future<void> deleteMessagesForConversation(String conversationId) =>
      (delete(aiMessagesTable)
            ..where((t) => t.conversationId.equals(conversationId)))
          .go();

  /// Get all conversations + messages for export/backup.
  Future<List<AiConversationsTableData>> getAllConversations() =>
      select(aiConversationsTable).get();

  Future<List<AiMessagesTableData>> getAllMessages() =>
      select(aiMessagesTable).get();
}
