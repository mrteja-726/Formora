// lib/core/database/tables/ai_tables.dart
import 'package:drift/drift.dart';

/// Stores AI chat conversations (one per profile, can have many).
class AiConversationsTable extends Table {
  @override
  String get tableName => 'ai_conversations';

  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get title => text().withDefault(const Constant('New Chat'))();
  TextColumn get provider => text()(); // gemini | openai | openrouter | anthropic
  TextColumn get model => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stores individual messages within a conversation.
class AiMessagesTable extends Table {
  @override
  String get tableName => 'ai_messages';

  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get role => text()(); // user | assistant | system
  TextColumn get content => text()();
  TextColumn get provider => text().nullable()();
  TextColumn get model => text().nullable()();
  IntColumn get tokenCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
