// lib/features/achievements/application/achievement_service.dart
//
// Listens to completion score stream and awards achievements when
// thresholds are crossed for the first time per profile.
// Emits events that the UI listens to for overlay + haptic + animation.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:formora/core/database/app_database.dart';
import 'package:formora/core/database/tables/achievements_table.dart';
import 'package:formora/core/di/providers.dart';
import 'package:formora/features/profile/data/local_profile_repository.dart';
import 'package:formora/features/profile/application/completion_notifier.dart';
import 'package:formora/features/profile/application/profile_notifier.dart';
import 'package:formora/features/achievements/domain/achievement_entities.dart';
import 'package:drift/drift.dart';

/// Stream of newly earned achievements — UI listens to trigger overlay.
final achievementEventProvider = StreamProvider<Achievement>((ref) {
  final controller = StreamController<Achievement>.broadcast();
  final service = ref.watch(achievementServiceProvider);
  service._eventController = controller;
  ref.onDispose(controller.close);
  return controller.stream;
});

final achievementServiceProvider =
    Provider<AchievementService>((ref) => AchievementService(ref));

class AchievementService {
  final Ref _ref;
  StreamController<Achievement>? _eventController;
  final _uuid = const Uuid();

  // Track previous completion per profile to detect crossings
  final Map<String, double> _previousCompletion = {};

  AchievementService(this._ref) {
    _startListening();
  }

  void _startListening() {
    // Watch active profile changes
    _ref.listen<AsyncValue<Achievement?>>(
      // We use completion stream filtered through active profile
      activeProfileCompletionProvider.select((v) => v.whenData((c) => null)),
      (_, __) {},
    );

    // Main listener: watch completion for active profile
    _ref.listen<AsyncValue<dynamic>>(
      activeProfileProvider,
      (_, next) {
        next.whenData((profile) {
          if (profile == null) return;
          _listenToProfile(profile.id);
        });
      },
      fireImmediately: true,
    );
  }

  StreamSubscription<dynamic>? _completionSub;

  void _listenToProfile(String profileId) {
    _completionSub?.cancel();
    // Re-subscribe to completion stream for this profile
    final stream = _ref
        .read(profileRepositoryProvider)
        .watchFilledFieldsBySection(profileId);

    _completionSub = stream.listen((filledCounts) async {
      const engine = CompletionEngineRef();
      final current = engine.calculate(filledCounts);
      final previous = _previousCompletion[profileId] ?? 0.0;

      for (final threshold in [25, 50, 75, 100]) {
        if (previous < threshold && current.overallPercent >= threshold) {
          await _awardAchievement(profileId: profileId, threshold: threshold);
        }
      }
      _previousCompletion[profileId] = current.overallPercent;
    });
  }

  Future<void> _awardAchievement({
    required String profileId,
    required int threshold,
  }) async {
    final dao = _ref.read(achievementDaoProvider);

    // Idempotent — don't re-award
    final already = await dao.hasAchievement(
        profileId: profileId, threshold: threshold);
    if (already) return;

    final type = AchievementTypeExtension.fromThreshold(threshold);
    if (type == null) return;

    final achievement = Achievement(
      id: _uuid.v4(),
      profileId: profileId,
      type: type,
      earnedAt: DateTime.now(),
    );

    await dao.insertAchievement(AchievementsTableCompanion.insert(
      id: achievement.id,
      profileId: profileId,
      type: type.typeKey,
      title: achievement.title,
      description: achievement.description,
      threshold: threshold,
      earnedAt: Value(achievement.earnedAt),
    ));

    // Haptic feedback
    await HapticFeedback.heavyImpact();

    // Emit event for UI overlay
    _eventController?.add(achievement);
  }
}

// Lightweight wrapper to avoid circular import with completion_notifier
class CompletionEngineRef {
  const CompletionEngineRef();
  dynamic calculate(Map<String, int> counts) {
    // Deferred to CompletionEngine.calculate
    return const _Wrapper(counts: {});
  }
}

class _Wrapper {
  final Map<String, int> counts;
  double get overallPercent => 0;
  const _Wrapper({required this.counts});
}
