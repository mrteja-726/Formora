// lib/core/database/tables/achievements_table.dart
import 'package:drift/drift.dart';

/// Stores earned achievements per profile.
/// Achievements are non-repeatable per profile (unique on profileId + type).
class AchievementsTable extends Table {
  @override
  String get tableName => 'achievements';

  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get type => text()(); // quarter | half | three_quarter | complete
  TextColumn get title => text()();
  TextColumn get description => text()();
  IntColumn get threshold => integer()(); // 25 | 50 | 75 | 100
  DateTimeColumn get earnedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get seen => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
