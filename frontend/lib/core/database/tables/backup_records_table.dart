// lib/core/database/tables/backup_records_table.dart
import 'package:drift/drift.dart';

/// Tracks backup history for user visibility.
class BackupRecordsTable extends Table {
  @override
  String get tableName => 'backup_records';

  TextColumn get id => text()();
  TextColumn get filePath => text()();     // Path to .formora file
  IntColumn get sizeBytes => integer()();
  IntColumn get profileCount => integer()();
  IntColumn get documentCount => integer()();
  TextColumn get checksum => text()();     // SHA-256 of backup
  TextColumn get appVersion => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isValid => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
