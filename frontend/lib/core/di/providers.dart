// lib/core/di/providers.dart
//
// Central Dependency Injection — all global providers live here.
// Feature-level providers are defined in their own files.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:formora/core/database/app_database.dart';
import 'package:formora/core/database/daos/achievement_dao.dart';
import 'package:formora/core/database/daos/ai_dao.dart';
import 'package:formora/core/database/daos/backup_dao.dart';
import 'package:formora/core/database/daos/document_dao.dart';
import 'package:formora/core/database/daos/ocr_dao.dart';
import 'package:formora/core/database/daos/profile_dao.dart';
import 'package:formora/core/security/biometric_service.dart';
import 'package:formora/core/security/encryption_service.dart';
import 'package:formora/core/storage/hive_storage.dart';

// ── Database ─────────────────────────────────────────────────────────────

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ── DAOs ──────────────────────────────────────────────────────────────────

final profileDaoProvider = Provider<ProfileDao>((ref) {
  return ref.watch(appDatabaseProvider).profileDao;
});

final documentDaoProvider = Provider<DocumentDao>((ref) {
  return ref.watch(appDatabaseProvider).documentDao;
});

final ocrDaoProvider = Provider<OcrDao>((ref) {
  return ref.watch(appDatabaseProvider).ocrDao;
});

final achievementDaoProvider = Provider<AchievementDao>((ref) {
  return ref.watch(appDatabaseProvider).achievementDao;
});

final aiDaoProvider = Provider<AiDao>((ref) {
  return ref.watch(appDatabaseProvider).aiDao;
});

final backupDaoProvider = Provider<BackupDao>((ref) {
  return ref.watch(appDatabaseProvider).backupDao;
});

// ── Core Services ─────────────────────────────────────────────────────────

/// Singleton HiveStorage — must be initialized via HiveStorage.init() in main()
/// before the ProviderScope is created.
final hiveStorageProvider = Provider<HiveStorage>((ref) {
  // Returned from the override in main.dart after init
  throw StateError('hiveStorageProvider must be overridden in main()');
});
