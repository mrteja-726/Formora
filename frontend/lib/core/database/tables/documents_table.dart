// lib/core/database/tables/documents_table.dart
import 'package:drift/drift.dart';

/// Stores document metadata. The actual file is stored encrypted at rest
/// in the app's private directory. [encryptedFilePath] points to the
/// AES-256-GCM encrypted file on disk.
class DocumentsTable extends Table {
  @override
  String get tableName => 'documents';

  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get filename => text()();
  TextColumn get documentType => text()();  // passport | national_id | driving_license | bank_statement | ...
  TextColumn get contentType => text()();   // image/jpeg | application/pdf | ...
  IntColumn get sizeBytes => integer()();
  TextColumn get encryptedFilePath => text()(); // Path to AES-encrypted file on disk
  TextColumn get thumbnailPath => text().nullable()(); // Path to encrypted thumbnail
  TextColumn get ocrStatus =>
      text().withDefault(const Constant('pending'))(); // pending | processing | completed | failed
  TextColumn get checksum => text()(); // SHA-256 of original file for integrity
  DateTimeColumn get uploadedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
