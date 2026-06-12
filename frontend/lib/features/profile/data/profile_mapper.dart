// lib/features/profile/data/profile_mapper.dart
//
// Maps between Drift table rows and domain entities.

import 'package:flutter/material.dart';
import 'package:drift/drift.dart';

import 'package:formora/core/database/app_database.dart';
import 'package:formora/features/profile/domain/profile_entities.dart';

class ProfileMapper {
  const ProfileMapper();

  // ── Profile ────────────────────────────────────────────────────────────────

  Profile fromRow(ProfilesTableData row) {
    return Profile(
      id: row.id,
      name: row.name,
      avatarEmoji: row.avatarEmoji,
      color: Color(row.colorSeed),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isActive: row.isActive,
      sortOrder: row.sortOrder,
    );
  }

  ProfilesTableCompanion toInsertCompanion(Profile profile) {
    return ProfilesTableCompanion.insert(
      id: profile.id,
      name: profile.name,
      avatarEmoji: Value(profile.avatarEmoji),
      colorSeed: Value(profile.color.value),
      createdAt: Value(profile.createdAt),
      updatedAt: Value(profile.updatedAt),
      isActive: Value(profile.isActive),
      sortOrder: Value(profile.sortOrder),
    );
  }

  ProfilesTableCompanion toUpdateCompanion(Profile profile) {
    return ProfilesTableCompanion(
      id: Value(profile.id),
      name: Value(profile.name),
      avatarEmoji: Value(profile.avatarEmoji),
      colorSeed: Value(profile.color.value),
      updatedAt: Value(DateTime.now()),
      isActive: Value(profile.isActive),
      sortOrder: Value(profile.sortOrder),
    );
  }

  // ── ProfileField ───────────────────────────────────────────────────────────

  ProfileField fieldFromRow(ProfileFieldsTableData row) {
    return ProfileField(
      id: row.id,
      profileId: row.profileId,
      section: row.section,
      fieldKey: row.fieldKey,
      value: row.value,
      dataType: row.dataType,
      visibility: row.visibility,
      ocrConfidence: row.ocrConfidence,
      source: row.source,
      sourceDocumentId: row.sourceDocumentId,
      updatedAt: row.updatedAt,
    );
  }

  ProfileFieldsTableCompanion fieldToCompanion(ProfileField field) {
    return ProfileFieldsTableCompanion.insert(
      id: field.id,
      profileId: field.profileId,
      section: field.section,
      fieldKey: field.fieldKey,
      value: Value(field.value),
      dataType: Value(field.dataType),
      visibility: Value(field.visibility),
      ocrConfidence: Value(field.ocrConfidence),
      source: Value(field.source),
      sourceDocumentId: Value(field.sourceDocumentId),
      updatedAt: Value(field.updatedAt),
    );
  }
}
