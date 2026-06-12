// lib/features/achievements/domain/achievement_entities.dart

enum AchievementType { quarter, half, threeQuarter, complete }

extension AchievementTypeExtension on AchievementType {
  int get threshold {
    switch (this) {
      case AchievementType.quarter: return 25;
      case AchievementType.half: return 50;
      case AchievementType.threeQuarter: return 75;
      case AchievementType.complete: return 100;
    }
  }

  String get typeKey {
    switch (this) {
      case AchievementType.quarter: return 'quarter';
      case AchievementType.half: return 'half';
      case AchievementType.threeQuarter: return 'three_quarter';
      case AchievementType.complete: return 'complete';
    }
  }

  String get title {
    switch (this) {
      case AchievementType.quarter: return 'Getting Started!';
      case AchievementType.half: return 'Halfway There!';
      case AchievementType.threeQuarter: return 'Almost Complete!';
      case AchievementType.complete: return 'Profile Complete!';
    }
  }

  String get description {
    switch (this) {
      case AchievementType.quarter:
        return 'You\'ve filled 25% of your profile. Keep going!';
      case AchievementType.half:
        return 'Your profile is 50% complete. Excellent progress!';
      case AchievementType.threeQuarter:
        return '75% done! You\'re almost there.';
      case AchievementType.complete:
        return 'Your profile is 100% complete. You\'re a Formora pro!';
    }
  }

  String get lottieAsset {
    switch (this) {
      case AchievementType.quarter:
        return 'assets/lottie/achievement_25.json';
      case AchievementType.half:
        return 'assets/lottie/achievement_50.json';
      case AchievementType.threeQuarter:
        return 'assets/lottie/achievement_75.json';
      case AchievementType.complete:
        return 'assets/lottie/achievement_100.json';
    }
  }

  static AchievementType? fromThreshold(int threshold) {
    switch (threshold) {
      case 25: return AchievementType.quarter;
      case 50: return AchievementType.half;
      case 75: return AchievementType.threeQuarter;
      case 100: return AchievementType.complete;
      default: return null;
    }
  }
}

class Achievement {
  final String id;
  final String profileId;
  final AchievementType type;
  final DateTime earnedAt;
  final bool seen;

  const Achievement({
    required this.id,
    required this.profileId,
    required this.type,
    required this.earnedAt,
    this.seen = false,
  });

  String get title => type.title;
  String get description => type.description;
  int get threshold => type.threshold;
  String get lottieAsset => type.lottieAsset;
}
