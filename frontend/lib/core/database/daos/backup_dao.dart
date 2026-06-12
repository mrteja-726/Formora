// lib/core/database/daos/backup_dao.dart
import 'package:drift/drift.dart';

import 'package:formora/core/database/app_database.dart';
import 'package:formora/core/database/tables/backup_records_table.dart';

part 'backup_dao.g.dart';

@DriftAccessor(tables: [BackupRecordsTable])
class BackupDao extends DatabaseAccessor<AppDatabase>
    with _$BackupDaoMixin {
  BackupDao(super.db);

  /// Watch backup history, newest first.
  Stream<List<BackupRecordsTableData>> watchBackupHistory() =>
      (select(backupRecordsTable)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// Get backup history.
  Future<List<BackupRecordsTableData>> getBackupHistory() =>
      (select(backupRecordsTable)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Get the most recent backup record.
  Future<BackupRecordsTableData?> getLatestBackup() =>
      (select(backupRecordsTable)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  /// Insert a backup record.
  Future<void> insertBackupRecord(BackupRecordsTableCompanion record) =>
      into(backupRecordsTable).insert(record);

  /// Delete a backup record (e.g. after the file is deleted externally).
  Future<void> deleteBackupRecord(String id) =>
      (delete(backupRecordsTable)..where((t) => t.id.equals(id))).go();

  /// Keep only the N most recent backup records in history.
  Future<void> pruneBackupHistory({int keepCount = 20}) async {
    final all = await getBackupHistory();
    if (all.length > keepCount) {
      final toDelete = all.skip(keepCount);
      for (final record in toDelete) {
        await deleteBackupRecord(record.id);
      }
    }
  }
}
