// lib/core/database/tables/profiles_table.dart
import 'package:drift/drift.dart';

/// Stores top-level profile metadata (name, avatar, color).
/// Each profile has complete data isolation — no fields are shared across profiles.
class ProfilesTable extends Table {
  @override
  String get tableName => 'profiles';

  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get avatarEmoji => text().withDefault(const Constant('👤'))();
  IntColumn get colorSeed => integer().withDefault(const Constant(0xFF6366F1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
