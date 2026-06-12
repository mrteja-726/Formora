// lib/features/profile/application/completion_notifier.dart
//
// Provides real-time completion scores driven by Drift watch streams.
// Updates instantly when any field changes.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:formora/features/profile/data/local_profile_repository.dart';
import 'package:formora/features/profile/domain/completion_engine.dart';
import 'package:formora/features/profile/domain/profile_entities.dart';
import 'package:formora/features/profile/application/profile_notifier.dart';

final _completionEngine = const CompletionEngine();

/// Real-time completion for the active profile.
/// Watches field changes via Drift stream → recalculates on every change.
final activeProfileCompletionProvider = StreamProvider<ProfileCompletion>((ref) {
  final activeProfileAsync = ref.watch(activeProfileProvider);
  return activeProfileAsync.when(
    data: (profile) {
      if (profile == null) {
        return Stream.value(ProfileCompletion.zero);
      }
      final repo = ref.watch(profileRepositoryProvider);
      return repo
          .watchFilledFieldsBySection(profile.id)
          .map((counts) => _completionEngine.calculate(counts));
    },
    loading: () => Stream.value(ProfileCompletion.zero),
    error: (_, __) => Stream.value(ProfileCompletion.zero),
  );
});

/// Completion for any specific profile id (for profile list display).
final profileCompletionProvider =
    StreamProvider.family<ProfileCompletion, String>((ref, profileId) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo
      .watchFilledFieldsBySection(profileId)
      .map((counts) => _completionEngine.calculate(counts));
});
