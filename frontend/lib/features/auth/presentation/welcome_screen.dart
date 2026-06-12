import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:formora/features/backup/application/backup_notifier.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _handleBackupImport(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(backupNotifierProvider.notifier);
    await notifier.selectRestoreFile();
    
    // Check if validation succeeded
    final state = ref.read(backupNotifierProvider);
    if (state.pendingRestoreFile != null && state.validatedManifest != null) {
      if (!context.mounted) return;
      // Show confirmation dialog before executing
      final mode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Restore Backup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            'A valid backup from ${state.validatedManifest!.createdAt} was found.\n\n'
            'How would you like to restore conflicts?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'OVERWRITE'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Overwrite Local Data'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'MERGE'),
              child: const Text('Merge Profiles'),
            ),
          ],
        ),
      );

      if (mode != null) {
        await notifier.executeRestore(mode: mode);
        // Navigate home on completion
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup restored successfully!')),
          );
          context.go('/');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // Wordmark & Tagline
              Text(
                'FORMORA',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              // Hero Illustration/Header
              Text(
                "Manage Your Life's Information Securely",
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Store documents, organize profiles, and automate forms using your own AI.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  fontFamily: 'Inter',
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),

              // Bento Cards Grid
              _buildBentoGrid(context),

              const SizedBox(height: 48),
              // Actions Section
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => context.go('/profiles/create'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get Started',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => _handleBackupImport(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.outline),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Import Existing Backup',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.upload, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBentoGrid(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Grid Card 1: Privacy First (Full Width)
        _buildBentoCard(
          context,
          icon: Icons.shield_outlined,
          iconColor: colorScheme.primary,
          iconBgColor: colorScheme.primary.withOpacity(0.1),
          title: 'Privacy First',
          description:
              'Secure, end-to-end encryption for all your data. Your vault is a fortress designed to protect your most sensitive information.',
        ),
        const SizedBox(height: 16),
        // Row 2: Two columns
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                context,
                icon: Icons.person_off_outlined,
                title: 'No Accounts',
                description: 'No login required. Your identity stays entirely on your device.',
                height: 160,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildBentoCard(
                context,
                icon: Icons.storage_outlined,
                title: 'Local Storage',
                description: 'All documents are stored locally, never sent to the cloud.',
                height: 160,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Grid Card 4: Bring Your Own AI
        _buildBentoCard(
          context,
          icon: Icons.smart_toy_outlined,
          iconColor: colorScheme.tertiary,
          iconBgColor: colorScheme.tertiaryContainer.withOpacity(0.2),
          title: 'Bring Your Own AI',
          description:
              'Connect your preferred AI models to intelligently categorize, search, and parse your documents without sacrificing privacy.',
        ),
      ],
    );
  }

  Widget _buildBentoCard(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    Color? iconBgColor,
    required String title,
    required String description,
    double? height,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor ?? colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? colorScheme.onSurface,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
