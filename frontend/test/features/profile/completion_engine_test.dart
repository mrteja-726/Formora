// test/features/profile/completion_engine_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:formora/features/profile/domain/completion_engine.dart';
import 'package:formora/features/profile/domain/profile_field_schema.dart';

void main() {
  const engine = CompletionEngine();

  group('CompletionEngine', () {
    test('returns zero for empty fields', () {
      final result = engine.calculate({});
      expect(result.overallPercent, 0.0);
      expect(result.filledFieldCount, 0);
    });

    test('returns 100% when all sections fully filled', () {
      // Build a map where each section has all its fields filled
      final filled = {
        for (final s in ProfileFieldSchema.sections) s.key: s.totalFields
      };
      final result = engine.calculate(filled);
      expect(result.overallPercent, closeTo(100.0, 0.01));
    });

    test('section weights sum to 1.0', () {
      final totalWeight = ProfileFieldSchema.sections
          .fold(0.0, (sum, s) => sum + s.weight);
      expect(totalWeight, closeTo(1.0, 0.001));
    });

    test('identity_documents carries 25% max weight', () {
      // Only fill identity_documents fully
      final idSection = ProfileFieldSchema.sections
          .firstWhere((s) => s.key == 'identity_documents');
      final result = engine.calculate({'identity_documents': idSection.totalFields});
      expect(result.overallPercent, closeTo(25.0, 0.1));
    });

    test('personal_info carries 20% max weight', () {
      final pInfo = ProfileFieldSchema.sections
          .firstWhere((s) => s.key == 'personal_info');
      final result = engine.calculate({'personal_info': pInfo.totalFields});
      expect(result.overallPercent, closeTo(20.0, 0.1));
    });

    test('detects 25% threshold crossing', () {
      final before = engine.calculate({'personal_info': 0});
      final after = engine.calculate({
        'personal_info':
            ProfileFieldSchema.sections.firstWhere((s) => s.key == 'personal_info').totalFields,
        'address': ProfileFieldSchema.sections.firstWhere((s) => s.key == 'address').totalFields,
      });
      final threshold = engine.detectNewThreshold(previous: before, current: after);
      expect(threshold, 25);
    });

    test('does not re-detect threshold if already past it', () {
      final before = engine.calculate({
        'personal_info':
            ProfileFieldSchema.sections.firstWhere((s) => s.key == 'personal_info').totalFields,
        'address': ProfileFieldSchema.sections.firstWhere((s) => s.key == 'address').totalFields,
      });
      final after = before; // Same state
      expect(
          engine.detectNewThreshold(previous: before, current: after), isNull);
    });

    test('clamps to 100% even if overfilled', () {
      final overFilled = {
        for (final s in ProfileFieldSchema.sections) s.key: s.totalFields * 10
      };
      final result = engine.calculate(overFilled);
      expect(result.overallPercent, lessThanOrEqualTo(100.0));
    });

    test('emergency section carries 5% weight', () {
      final emergency = ProfileFieldSchema.sections
          .firstWhere((s) => s.key == 'emergency');
      final result = engine.calculate({'emergency': emergency.totalFields});
      expect(result.overallPercent, closeTo(5.0, 0.1));
    });

    test('sectionPercents contain all 8 sections', () {
      final result = engine.calculate({});
      expect(result.sectionPercents.length, 8);
    });

    test('partial fill gives proportional section percent', () {
      final pInfo = ProfileFieldSchema.sections
          .firstWhere((s) => s.key == 'personal_info');
      final halfFilled = pInfo.totalFields ~/ 2;
      final result = engine.calculate({'personal_info': halfFilled});
      final sectionPct = result.sectionPercents['personal_info']!;
      expect(sectionPct, closeTo(50.0, 5.0)); // ~50% of section
    });
  });
}
