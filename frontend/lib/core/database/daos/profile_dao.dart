// lib/core/database/daos/profile_dao.dart
import 'package:drift/drift.dart';

import 'package:formora/core/database/app_database.dart';
import 'package:formora/core/database/tables/profiles_table.dart';
import 'package:formora/core/database/tables/profile_fields_table.dart';

part 'profile_dao.g.dart';

@DriftAccessor(tables: [ProfilesTable, ProfileFieldsTable])
class ProfileDao extends DatabaseAccessor<AppDatabase>
    with _$ProfileDaoMixin {
  ProfileDao(super.db);

  // ── Profiles ──────────────────────────────────────────────────────────────

  /// Watch all profiles ordered by [sortOrder].
  Stream<List<ProfilesTableData>> watchAllProfiles() =>
      (select(profilesTable)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  /// Get all profiles once.
  Future<List<ProfilesTableData>> getAllProfiles() =>
      (select(profilesTable)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  /// Get a single profile by id.
  Future<ProfilesTableData?> getProfileById(String id) =>
      (select(profilesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Get the currently active profile.
  Future<ProfilesTableData?> getActiveProfile() =>
      (select(profilesTable)..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  /// Watch the currently active profile.
  Stream<ProfilesTableData?> watchActiveProfile() =>
      (select(profilesTable)..where((t) => t.isActive.equals(true)))
          .watchSingleOrNull();

  /// Insert a new profile.
  Future<void> insertProfile(ProfilesTableCompanion profile) =>
      into(profilesTable).insert(profile);

  /// Update a profile.
  Future<bool> updateProfile(ProfilesTableCompanion profile) =>
      update(profilesTable).replace(profile);

  /// Delete a profile and all associated data.
  Future<void> deleteProfile(String profileId) async {
    await (delete(profileFieldsTable)
          ..where((t) => t.profileId.equals(profileId)))
        .go();
    await (delete(profilesTable)..where((t) => t.id.equals(profileId))).go();
  }

  /// Set exactly one profile as active (clears others).
  Future<void> setActiveProfile(String profileId) async {
    await transaction(() async {
      // Deactivate all
      await (update(profilesTable))
          .write(const ProfilesTableCompanion(isActive: Value(false)));
      // Activate the selected one
      await (update(profilesTable)
            ..where((t) => t.id.equals(profileId)))
          .write(const ProfilesTableCompanion(isActive: Value(true)));
    });
  }

  /// Reorder profiles by updating sortOrder.
  Future<void> reorderProfiles(List<String> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(profilesTable)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(ProfilesTableCompanion(sortOrder: Value(i)));
      }
    });
  }

  // ── Profile Fields ────────────────────────────────────────────────────────

  /// Watch all fields for a profile.
  Stream<List<ProfileFieldsTableData>> watchFieldsForProfile(String profileId) =>
      (select(profileFieldsTable)
            ..where((t) => t.profileId.equals(profileId)))
          .watch();

  /// Get all fields for a profile.
  Future<List<ProfileFieldsTableData>> getFieldsForProfile(String profileId) =>
      (select(profileFieldsTable)
            ..where((t) => t.profileId.equals(profileId)))
          .get();

  /// Get fields for a profile grouped by section.
  Future<Map<String, List<ProfileFieldsTableData>>> getFieldsBySection(
      String profileId) async {
    final fields = await getFieldsForProfile(profileId);
    final result = <String, List<ProfileFieldsTableData>>{};
    for (final field in fields) {
      result.putIfAbsent(field.section, () => []).add(field);
    }
    return result;
  }

  /// Get a single field by profileId + section + fieldKey.
  Future<ProfileFieldsTableData?> getField({
    required String profileId,
    required String section,
    required String fieldKey,
  }) =>
      (select(profileFieldsTable)
            ..where((t) =>
                t.profileId.equals(profileId) &
                t.section.equals(section) &
                t.fieldKey.equals(fieldKey)))
          .getSingleOrNull();

  /// Insert or replace a field (upsert by unique key).
  Future<void> upsertField(ProfileFieldsTableCompanion field) =>
      into(profileFieldsTable).insertOnConflictUpdate(field);

  /// Bulk upsert — used after OCR mapping.
  Future<void> bulkUpsertFields(
      List<ProfileFieldsTableCompanion> fields) async {
    await transaction(() async {
      for (final f in fields) {
        await into(profileFieldsTable).insertOnConflictUpdate(f);
      }
    });
  }

  /// Delete a specific field.
  Future<void> deleteField(String fieldId) =>
      (delete(profileFieldsTable)..where((t) => t.id.equals(fieldId))).go();

  /// Delete all fields in a section for a profile.
  Future<void> deleteSection({
    required String profileId,
    required String section,
  }) =>
      (delete(profileFieldsTable)
            ..where((t) =>
                t.profileId.equals(profileId) & t.section.equals(section)))
          .go();

  /// Count non-empty fields per section for completion calculation.
  Future<Map<String, int>> countFilledFieldsBySection(
      String profileId) async {
    final fields = await (select(profileFieldsTable)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.value.isNotValue('')))
        .get();

    final result = <String, int>{};
    for (final f in fields) {
      result[f.section] = (result[f.section] ?? 0) + 1;
    }
    return result;
  }

  /// Watch filled field counts reactively (for real-time completion).
  Stream<Map<String, int>> watchFilledFieldsBySection(String profileId) =>
      (select(profileFieldsTable)
            ..where((t) =>
                t.profileId.equals(profileId) &
                t.value.isNotValue('')))
          .watch()
          .map((fields) {
        final result = <String, int>{};
        for (final f in fields) {
          result[f.section] = (result[f.section] ?? 0) + 1;
        }
        return result;
      });
}
