import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:formora/core/di/providers.dart';
import 'package:formora/features/profile/application/profile_notifier.dart';
import 'package:formora/features/achievements/domain/achievement_entities.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeProfileAsync = ref.watch(activeProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements & Badges'),
        centerTitle: true,
      ),
      body: activeProfileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text('No active profile. Create one to earn achievements.'),
            );
          }

          final dao = ref.watch(achievementDaoProvider);
          return StreamBuilder(
            stream: dao.watchAchievementsForProfile(profile.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final earnedList = snapshot.data ?? [];
              final earnedThresholds = earnedList.map((row) => row.threshold).toSet();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stats Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary.withOpacity(0.1), colorScheme.primary.withOpacity(0.02)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.emoji_events_outlined, size: 48, color: colorScheme.primary),
                          const SizedBox(height: 12),
                          Text(
                            '${earnedList.length} of 4 Unlocked',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Earn badges by filling out your profile sections.',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Badges Grid
                    const Text(
                      'Profile Badges',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                      children: [
                        _buildBadgeCard(
                          context,
                          threshold: 25,
                          title: 'Getting Started',
                          desc: 'Filled 25% of profile fields.',
                          isUnlocked: earnedThresholds.contains(25),
                          earnedAt: earnedThresholds.contains(25)
                              ? earnedList.firstWhere((r) => r.threshold == 25).earnedAt
                              : null,
                          color: const Color(0xFF00478D),
                          icon: Icons.explore_outlined,
                        ),
                        _buildBadgeCard(
                          context,
                          threshold: 50,
                          title: 'Halfway There',
                          desc: 'Filled 50% of profile fields.',
                          isUnlocked: earnedThresholds.contains(50),
                          earnedAt: earnedThresholds.contains(50)
                              ? earnedList.firstWhere((r) => r.threshold == 50).earnedAt
                              : null,
                          color: const Color(0xFF7E5361),
                          icon: Icons.navigation_outlined,
                        ),
                        _buildBadgeCard(
                          context,
                          threshold: 75,
                          title: 'Almost Complete',
                          desc: 'Filled 75% of profile fields.',
                          isUnlocked: earnedThresholds.contains(75),
                          earnedAt: earnedThresholds.contains(75)
                              ? earnedList.firstWhere((r) => r.threshold == 75).earnedAt
                              : null,
                          color: const Color(0xFFBA1A1A),
                          icon: Icons.verified_outlined,
                        ),
                        _buildBadgeCard(
                          context,
                          threshold: 100,
                          title: 'Profile Complete',
                          desc: 'Filled 100% of profile fields.',
                          isUnlocked: earnedThresholds.contains(100),
                          earnedAt: earnedThresholds.contains(100)
                              ? earnedList.firstWhere((r) => r.threshold == 100).earnedAt
                              : null,
                          color: const Color(0xFF565E71),
                          icon: Icons.star_outline,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildBadgeCard(
    BuildContext context, {
    required int threshold,
    required String title,
    required String desc,
    required bool isUnlocked,
    required DateTime? earnedAt,
    required Color color,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? colorScheme.surfaceContainer : colorScheme.surfaceContainerLow.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? color.withOpacity(0.3) : colorScheme.outlineVariant.withOpacity(0.2),
          width: isUnlocked ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon/Badge representation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUnlocked ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isUnlocked ? color : Colors.grey,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isUnlocked ? colorScheme.onSurface : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (isUnlocked && earnedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Earned: ${DateFormat.yMMMd().format(earnedAt)}',
              style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }
}
