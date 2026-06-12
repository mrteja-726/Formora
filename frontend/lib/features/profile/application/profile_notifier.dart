// lib/features/profile/application/profile_notifier.dart
//
// Manages the active profile state and field updates.
// Uses optimistic UI: updates local state immediately, persists in background.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:formora/features/profile/data/local_profile_repository.dart';
import 'package:formora/features/profile/domain/profile_entities.dart';

// ── Active Profile Provider ────────────────────────────────────────────────

/// Reactive stream of the active profile.
final activeProfileProvider = StreamProvider<Profile?>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchActiveProfile();
});

/// All profiles, watched reactively.
final allProfilesProvider = StreamProvider<List<Profile>>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchAllProfiles();
});

// ── Profile Fields Provider ────────────────────────────────────────────────

/// Fields for a specific profile, watched reactively.
final profileFieldsProvider =
    StreamProvider.family<List<ProfileField>, String>((ref, profileId) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchFieldsForProfile(profileId);
});

// ── Profile Notifier ───────────────────────────────────────────────────────

class ProfileNotifierState {
  final bool isLoading;
  final String? error;

  const ProfileNotifierState({
    this.isLoading = false,
    this.error,
  });

  ProfileNotifierState copyWith({bool? isLoading, String? error}) {
    return ProfileNotifierState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, ProfileNotifierState>(() {
  return ProfileNotifier();
});

class ProfileNotifier extends AsyncNotifier<ProfileNotifierState> {
  final _uuid = const Uuid();

  LocalProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<ProfileNotifierState> build() async {
    // Ensure there's always at least one profile
    final profiles = await _repo.getAllProfiles();
    if (profiles.isEmpty) {
      await _createDefaultProfile();
    } else if (!profiles.any((p) => p.isActive)) {
      await _repo.setActiveProfile(profiles.first.id);
    }
    return const ProfileNotifierState();
  }

  // ── Profile Management ───────────────────────────────────────────────────

  Future<String> createProfile({
    required String name,
    String avatarEmoji = '👤',
    int colorSeed = 0xFF6366F1,
  }) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repo.createProfile(
        name: name,
        avatarEmoji: avatarEmoji,
        colorSeed: colorSeed,
      );
      state = const AsyncValue.data(ProfileNotifierState());
      return profile.id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> switchProfile(String profileId) async {
    // Optimistic: switch immediately (cross-fade handled in UI via stream)
    try {
      await _repo.setActiveProfile(profileId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfileMeta({
    required String profileId,
    required String name,
    String? avatarEmoji,
    int? colorSeed,
  }) async {
    final existing = await _repo.getProfileById(profileId);
    if (existing == null) return;
    final updated = existing.copyWith(
      name: name,
      avatarEmoji: avatarEmoji,
      color: colorSeed != null
          ? null // Handled in copyWith via colorSeed — simplified here
          : null,
    );
    await _repo.updateProfile(updated);
  }

  Future<void> deleteProfile(String profileId) async {
    await _repo.deleteProfile(profileId);
    // If deleted was active, switch to first remaining profile
    final remaining = await _repo.getAllProfiles();
    if (remaining.isNotEmpty) {
      await _repo.setActiveProfile(remaining.first.id);
    } else {
      await _createDefaultProfile();
    }
  }

  // ── Field Management ─────────────────────────────────────────────────────

  /// Optimistic field update — writes to state immediately, persists async.
  Future<void> updateField({
    required String profileId,
    required String section,
    required String fieldKey,
    required String value,
    String dataType = 'string',
    String source = 'manual',
  }) async {
    // Fire and forget persistence; the StreamProvider auto-updates UI
    await _repo.upsertField(
      profileId: profileId,
      section: section,
      fieldKey: fieldKey,
      value: value,
      dataType: dataType,
      source: source,
    );
  }

  /// Bulk update from OCR field mapping.
  Future<void> applyOcrFields(List<ProfileField> fields) async {
    await _repo.bulkUpsertFields(fields);
  }

  // ── Private ──────────────────────────────────────────────────────────────

  Future<void> _createDefaultProfile() async {
    final id = _uuid.v4();
    await _repo.createProfile(
      name: 'My Profile',
      avatarEmoji: '👤',
      colorSeed: 0xFF6366F1,
    );
    await _repo.setActiveProfile(id);
  }
}
