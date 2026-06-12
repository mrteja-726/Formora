// lib/features/profile/domain/completion_engine.dart
//
// Weighted completion calculation for a profile.
// Formula:
//   sectionScore(s) = filledFields(s) / totalFields(s)   [0.0–1.0]
//   overall         = Σ (sectionScore(s) × weight(s))    [0.0–1.0]
//   overallPercent  = overall × 100                       [0–100]
//
// Runs synchronously — call from async context or compute() if needed.

import 'package:formora/features/profile/domain/profile_entities.dart';
import 'package:formora/features/profile/domain/profile_field_schema.dart';

class CompletionEngine {
  const CompletionEngine();

  /// Calculates completion from a map of section → count of filled fields.
  /// [filledBySection] can be sparse — missing sections are treated as 0.
  ProfileCompletion calculate(Map<String, int> filledBySection) {
    final sections = ProfileFieldSchema.sections;
    final sectionPercents = <String, double>{};
    double weightedSum = 0.0;
    int totalFilled = 0;
    int totalFields = 0;

    for (final section in sections) {
      final filled = filledBySection[section.key] ?? 0;
      final total = section.totalFields;
      final sectionScore = total > 0 ? (filled / total).clamp(0.0, 1.0) : 0.0;

      sectionPercents[section.key] = sectionScore * 100;
      weightedSum += sectionScore * section.weight;
      totalFilled += filled;
      totalFields += total;
    }

    return ProfileCompletion(
      overallPercent: (weightedSum * 100).clamp(0.0, 100.0),
      sectionPercents: sectionPercents,
      filledFieldCount: totalFilled,
      totalFieldCount: totalFields,
    );
  }

  /// Convenience: checks which achievement threshold (25/50/75/100) was
  /// newly crossed when going from [previous] to [current].
  int? detectNewThreshold({
    required ProfileCompletion previous,
    required ProfileCompletion current,
  }) {
    for (final threshold in _thresholds) {
      if (previous.overallPercent < threshold &&
          current.overallPercent >= threshold) {
        return threshold;
      }
    }
    return null;
  }

  static const List<int> _thresholds = [25, 50, 75, 100];
}
