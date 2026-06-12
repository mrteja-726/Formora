// lib/features/profile/domain/profile_entities.dart
//
// Pure domain entities (no Drift/Hive imports).
// UI and notifiers work exclusively with these types.

import 'package:flutter/material.dart';

/// Top-level profile — one person's data island.
class Profile {
  final String id;
  final String name;
  final String avatarEmoji;
  final Color color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int sortOrder;

  const Profile({
    required this.id,
    required this.name,
    this.avatarEmoji = '👤',
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = false,
    this.sortOrder = 0,
  });

  Profile copyWith({
    String? name,
    String? avatarEmoji,
    Color? color,
    bool? isActive,
    int? sortOrder,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      color: color ?? this.color,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Profile && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// A single data point within a profile section.
class ProfileField {
  final String id;
  final String profileId;
  final String section;
  final String fieldKey;
  final String value;
  final String dataType;   // string | date | number | phone | email | id
  final String visibility; // private | shared
  final double ocrConfidence; // 0–100
  final String source;        // manual | ocr | import
  final String? sourceDocumentId;
  final DateTime updatedAt;

  const ProfileField({
    required this.id,
    required this.profileId,
    required this.section,
    required this.fieldKey,
    required this.value,
    this.dataType = 'string',
    this.visibility = 'private',
    this.ocrConfidence = 0.0,
    this.source = 'manual',
    this.sourceDocumentId,
    required this.updatedAt,
  });

  bool get isEmpty => value.trim().isEmpty;
  bool get isFilled => !isEmpty;

  ProfileField copyWith({
    String? value,
    double? ocrConfidence,
    String? source,
    String? sourceDocumentId,
  }) {
    return ProfileField(
      id: id,
      profileId: profileId,
      section: section,
      fieldKey: fieldKey,
      value: value ?? this.value,
      dataType: dataType,
      visibility: visibility,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      source: source ?? this.source,
      sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
      updatedAt: DateTime.now(),
    );
  }
}

/// Overall completion state for a profile.
class ProfileCompletion {
  final double overallPercent;     // 0.0 – 100.0
  final Map<String, double> sectionPercents; // section key → 0.0–100.0
  final int filledFieldCount;
  final int totalFieldCount;

  const ProfileCompletion({
    required this.overallPercent,
    required this.sectionPercents,
    required this.filledFieldCount,
    required this.totalFieldCount,
  });

  static const zero = ProfileCompletion(
    overallPercent: 0.0,
    sectionPercents: {},
    filledFieldCount: 0,
    totalFieldCount: 0,
  );

  int get overallRounded => overallPercent.round();

  /// Has a new achievement threshold been crossed since [previous]?
  int? newAchievementThreshold(ProfileCompletion previous) {
    for (final threshold in [25, 50, 75, 100]) {
      if (previous.overallPercent < threshold &&
          overallPercent >= threshold) {
        return threshold;
      }
    }
    return null;
  }
}
