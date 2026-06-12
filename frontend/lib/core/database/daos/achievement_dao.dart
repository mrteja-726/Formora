// lib/core/database/daos/achievement_dao.dart
import 'package:drift/drift.dart';

import 'package:formora/core/database/app_database.dart';
import 'package:formora/core/database/tables/achievements_table.dart';

part 'achievement_dao.g.dart';

@DriftAccessor(tables: [AchievementsTable])
class AchievementDao extends DatabaseAccessor<AppDatabase>
    with _$AchievementDaoMixin {
  AchievementDao(super.db);

  /// Watch all achievements for a profile, newest first.
  Stream<List<AchievementsTableData>> watchAchievementsForProfile(
          String profileId) =>
      (select(achievementsTable)
            ..where((t) => t.profileId.equals(profileId))
            ..orderBy([(t) => OrderingTerm.desc(t.earnedAt)]))
          .watch();

  /// Get all achievements for a profile.
  Future<List<AchievementsTableData>> getAchievementsForProfile(
          String profileId) =>
      (select(achievementsTable)
            ..where((t) => t.profileId.equals(profileId)))
          .get();

  /// Check if a specific threshold achievement already exists for a profile.
  Future<bool> hasAchievement(
      {required String profileId, required int threshold}) async {
    final result = await (select(achievementsTable)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.threshold.equals(threshold)))
        .getSingleOrNull();
    return result != null;
  }

  /// Insert a new achievement.
  Future<void> insertAchievement(AchievementsTableCompanion achievement) =>
      into(achievementsTable).insert(achievement);

  /// Mark achievement as seen (after user views overlay).
  Future<void> markAsSeen(String achievementId) =>
      (update(achievementsTable)..where((t) => t.id.equals(achievementId)))
          .write(const AchievementsTableCompanion(seen: Value(true)));

  /// Watch unseen achievements — triggers overlay display.
  Stream<List<AchievementsTableData>> watchUnseenAchievements(
          String profileId) =>
      (select(achievementsTable)
            ..where((t) =>
                t.profileId.equals(profileId) & t.seen.equals(false)))
          .watch();

  /// Get all achievements for backup export.
  Future<List<AchievementsTableData>> getAllAchievements() =>
      select(achievementsTable).get();
}
