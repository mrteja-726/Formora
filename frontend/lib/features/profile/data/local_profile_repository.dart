// lib/features/profile/data/local_profile_repository.dart
//
// Implements all profile + field persistence via Drift DAOs.
// This is the ONLY place that talks to the database for profile data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:formora/core/di/providers.dart';
import 'package:formora/features/profile/domain/profile_entities.dart';
import 'package:formora/features/profile/data/profile_mapper.dart';

final profileRepositoryProvider = Provider<LocalProfileRepository>((ref) {
  final dao = ref.watch(profileDaoProvider);
  return LocalProfileRepository(dao, const ProfileMapper());
});

class LocalProfileRepository {
  final dynamic _dao; // ProfileDao — typed via import in real code
  final ProfileMapper _mapper;
  final _uuid = const Uuid();

  LocalProfileRepository(this._dao, this._mapper);

  // ── Profile CRUD ──────────────────────────────────────────────────────────

  Stream<List<Profile>> watchAllProfiles() =>
      _dao.watchAllProfiles().map((rows) => rows.map(_mapper.fromRow).toList());

  Future<List<Profile>> getAllProfiles() async {
    final rows = await _dao.getAllProfiles();
    return rows.map(_mapper.fromRow).toList();
  }

  Future<Profile?> getProfileById(String id) async {
    final row = await _dao.getProfileById(id);
    return row == null ? null : _mapper.fromRow(row);
  }

  Stream<Profile?> watchActiveProfile() =>
      _dao.watchActiveProfile().map((row) => row == null ? null : _mapper.fromRow(row));

  Future<Profile?> getActiveProfile() async {
    final row = await _dao.getActiveProfile();
    return row == null ? null : _mapper.fromRow(row);
  }

  Future<Profile> createProfile({
    required String name,
    String avatarEmoji = '👤',
    required int colorSeed,
  }) async {
    final now = DateTime.now();
    final existing = await _dao.getAllProfiles();
    final profile = Profile(
      id: _uuid.v4(),
      name: name,
      avatarEmoji: avatarEmoji,
      color: Color(colorSeed),
      createdAt: now,
      updatedAt: now,
      sortOrder: existing.length,
    );
    // Use raw companion insert
    await _dao.insertProfile(_mapper.toInsertCompanion(profile));
    return profile;
  }

  Future<void> updateProfile(Profile profile) async {
    await _dao.updateProfile(_mapper.toUpdateCompanion(profile));
  }

  Future<void> deleteProfile(String profileId) async {
    await _dao.deleteProfile(profileId);
  }

  Future<void> setActiveProfile(String profileId) async {
    await _dao.setActiveProfile(profileId);
  }

  Future<void> reorderProfiles(List<String> orderedIds) async {
    await _dao.reorderProfiles(orderedIds);
  }

  // ── Profile Fields ─────────────────────────────────────────────────────────

  Stream<List<ProfileField>> watchFieldsForProfile(String profileId) =>
      _dao
          .watchFieldsForProfile(profileId)
          .map((rows) => rows.map(_mapper.fieldFromRow).toList());

  Future<List<ProfileField>> getFieldsForProfile(String profileId) async {
    final rows = await _dao.getFieldsForProfile(profileId);
    return rows.map(_mapper.fieldFromRow).toList();
  }

  Future<Map<String, List<ProfileField>>> getFieldsBySection(
      String profileId) async {
    final fieldMap = await _dao.getFieldsBySection(profileId);
    return fieldMap.map(
      (key, rows) => MapEntry(key, rows.map(_mapper.fieldFromRow).toList()),
    );
  }

  Future<void> upsertField({
    required String profileId,
    required String section,
    required String fieldKey,
    required String value,
    String dataType = 'string',
    String source = 'manual',
    double ocrConfidence = 0.0,
    String? sourceDocumentId,
  }) async {
    final existing = await _dao.getField(
      profileId: profileId,
      section: section,
      fieldKey: fieldKey,
    );

    final field = ProfileField(
      id: existing?.id ?? _uuid.v4(),
      profileId: profileId,
      section: section,
      fieldKey: fieldKey,
      value: value,
      dataType: dataType,
      source: source,
      ocrConfidence: ocrConfidence,
      sourceDocumentId: sourceDocumentId,
      updatedAt: DateTime.now(),
    );
    await _dao.upsertField(_mapper.fieldToCompanion(field));
  }

  Future<void> bulkUpsertFields(List<ProfileField> fields) async {
    final companions = fields.map(_mapper.fieldToCompanion).toList();
    await _dao.bulkUpsertFields(companions);
  }

  Future<void> deleteField(String fieldId) async {
    await _dao.deleteField(fieldId);
  }

  /// Reactive stream of filled-field counts per section (drives completion engine).
  Stream<Map<String, int>> watchFilledFieldsBySection(String profileId) =>
      _dao.watchFilledFieldsBySection(profileId);

  /// Export all profile data as JSON (for backup).
  Future<Map<String, dynamic>> exportProfileToJson(String profileId) async {
    final profile = await getProfileById(profileId);
    final fields = await getFieldsForProfile(profileId);
    return {
      'id': profile?.id,
      'name': profile?.name,
      'avatarEmoji': profile?.avatarEmoji,
      'colorSeed': profile?.color.value,
      'createdAt': profile?.createdAt.toIso8601String(),
      'fields': fields
          .map((f) => {
                'section': f.section,
                'fieldKey': f.fieldKey,
                'value': f.value,
                'dataType': f.dataType,
                'source': f.source,
                'updatedAt': f.updatedAt.toIso8601String(),
              })
          .toList(),
    };
  }
}
