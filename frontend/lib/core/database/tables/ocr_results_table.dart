// lib/core/database/tables/ocr_results_table.dart
import 'package:drift/drift.dart';

/// Stores OCR extraction results per document.
/// [extractedFieldsJson] is a JSON string of field→value mappings.
/// [fieldMappingsJson] maps OCR fields to profile schema fields.
class OcrResultsTable extends Table {
  @override
  String get tableName => 'ocr_results';

  TextColumn get id => text()();
  TextColumn get documentId => text()();
  TextColumn get profileId => text()();
  TextColumn get rawText => text().withDefault(const Constant(''))();
  TextColumn get extractedFieldsJson => text().withDefault(const Constant('{}'))();
  TextColumn get fieldMappingsJson => text().withDefault(const Constant('{}'))();
  RealColumn get overallConfidence =>
      real().withDefault(const Constant(0.0))(); // 0.0–100.0
  TextColumn get confidenceTier =>
      text().withDefault(const Constant('low'))(); // high | medium | low
  BoolColumn get userReviewed =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get appliedToProfile =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get processedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
