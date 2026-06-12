// lib/core/database/app_database.dart
//
// Central Drift database for Formora.
// Run code generation: flutter pub run build_runner build --delete-conflicting-outputs
//
// Bump schemaVersion + add migration steps for any schema changes.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:formora/core/database/tables/profiles_table.dart';
import 'package:formora/core/database/tables/profile_fields_table.dart';
import 'package:formora/core/database/tables/documents_table.dart';
import 'package:formora/core/database/tables/ocr_results_table.dart';
import 'package:formora/core/database/tables/achievements_table.dart';
import 'package:formora/core/database/tables/ai_tables.dart';
import 'package:formora/core/database/tables/backup_records_table.dart';

import 'package:formora/core/database/daos/profile_dao.dart';
import 'package:formora/core/database/daos/document_dao.dart';
import 'package:formora/core/database/daos/ocr_dao.dart';
import 'package:formora/core/database/daos/achievement_dao.dart';
import 'package:formora/core/database/daos/ai_dao.dart';
import 'package:formora/core/database/daos/backup_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ProfilesTable,
    ProfileFieldsTable,
    DocumentsTable,
    OcrResultsTable,
    AchievementsTable,
    AiConversationsTable,
    AiMessagesTable,
    BackupRecordsTable,
  ],
  daos: [
    ProfileDao,
    DocumentDao,
    OcrDao,
    AchievementDao,
    AiDao,
    BackupDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Default constructor — opens the database at the platform default location.
  AppDatabase() : super(driftDatabase(name: 'formora_db'));

  /// Used in tests: pass an in-memory connection.
  /// Example: AppDatabase.forTesting(NativeDatabase.memory())
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        // Enable WAL mode and foreign keys on first open
        await _applyPragmas();
      },
      onUpgrade: (m, from, to) async {
        // Future migrations go here.
        // Example: if (from < 2) { await m.addColumn(table, column); }
      },
      beforeOpen: (details) async {
        await _applyPragmas();
      },
    );
  }

  Future<void> _applyPragmas() async {
    await customStatement('PRAGMA journal_mode = WAL');
    await customStatement('PRAGMA foreign_keys = ON');
  }
}
