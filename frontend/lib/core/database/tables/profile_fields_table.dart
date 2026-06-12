// lib/core/database/tables/profile_fields_table.dart
import 'package:drift/drift.dart';

/// Stores individual profile field values, keyed by section + fieldKey.
/// [sourceDocumentId] links the field back to the document that populated it.
class ProfileFieldsTable extends Table {
  @override
  String get tableName => 'profile_fields';

  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get section => text()();       // e.g. 'personal_info'
  TextColumn get fieldKey => text()();      // e.g. 'firstName'
  TextColumn get value => text().withDefault(const Constant(''))();
  TextColumn get dataType =>
      text().withDefault(const Constant('string'))();
  TextColumn get visibility =>
      text().withDefault(const Constant('private'))();
  RealColumn get ocrConfidence =>
      real().withDefault(const Constant(0.0))();
  TextColumn get source =>
      text().withDefault(const Constant('manual'))();
  TextColumn get sourceDocumentId => text().nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  /// Unique index: one value per profile+section+fieldKey.
  @override
  List<String> get customConstraints => [
        'UNIQUE (profile_id, section, field_key)',
      ];
}
