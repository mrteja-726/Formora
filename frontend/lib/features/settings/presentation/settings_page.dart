import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:formora/features/settings/application/settings_notifier.dart';
import 'package:formora/features/settings/data/settings_repository.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  void _showUninstallWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('Uninstall & Data Warning', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Formora is 100% local-first. We do NOT store your profile data, documents, or keys on any cloud server.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'If you uninstall this app or clear its storage:\n'
              '• All encrypted profiles will be permanently deleted.\n'
              '• Stored files and ID cards in the vault will be lost.\n'
              '• AI chat histories will be purged.\n'
              '• There is NO way for us to restore your data.',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              '💡 Recommendation: Always export a backup file from the Backup Center and save it securely before deleting or updating the app.',
              style: TextStyle(color: Colors.amberAccent, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/backup');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00478D)),
            child: const Text('Go to Backup Center', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── APPEARANCE SECTION ─────────────────────────────────────────────
          _buildSectionHeader(context, 'Appearance'),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('Light'),
                  value: ThemeMode.light,
                  groupValue: settings.themeMode,
                  onChanged: (v) => notifier.setThemeMode(v ?? ThemeMode.system),
                ),
                const Divider(height: 1),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark'),
                  value: ThemeMode.dark,
                  groupValue: settings.themeMode,
                  onChanged: (v) => notifier.setThemeMode(v ?? ThemeMode.system),
                ),
                const Divider(height: 1),
                RadioListTile<ThemeMode>(
                  title: const Text('System Default'),
                  value: ThemeMode.system,
                  groupValue: settings.themeMode,
                  onChanged: (v) => notifier.setThemeMode(v ?? ThemeMode.system),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── SECURITY SECTION ───────────────────────────────────────────────
          _buildSectionHeader(context, 'Security'),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Biometric Unlock'),
                  subtitle: const Text('Use fingerprint or Face ID to unlock'),
                  value: settings.appLockEnabled,
                  onChanged: (v) => notifier.setAppLock(v),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Configure Lock Screen'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/lock'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── AI INTEGRATION SECTION ─────────────────────────────────────────
          _buildSectionHeader(context, 'AI Integration'),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('AI Providers'),
              subtitle: const Text('Manage API Keys and models'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/ai'),
            ),
          ),
          const SizedBox(height: 20),

          // ── ACCESSIBILITY SECTION ──────────────────────────────────────────
          _buildSectionHeader(context, 'Accessibility'),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Font Scaling', style: TextStyle(fontWeight: FontWeight.w500)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('100%', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.text_fields, size: 16),
                          Expanded(
                            child: Slider(
                              value: 1.0,
                              min: 0.8,
                              max: 1.4,
                              onChanged: (_) {},
                            ),
                          ),
                          const Icon(Icons.text_fields, size: 24),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Reduced Motion'),
                  value: false,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── DATA MANAGEMENT SECTION ────────────────────────────────────────
          _buildSectionHeader(context, 'Data Management'),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined),
                  title: const Text('Backup Center'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/backup'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  title: const Text('Uninstall & Storage Warning', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Important information about your local data'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
                  onTap: () => _showUninstallWarningDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── SUPPORT SECTION ───────────────────────────────────────────────
          _buildSectionHeader(context, 'Support & Feedback'),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Support Center'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/support'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Achievements & Badges'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/achievements'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // ── Footer ──
          Center(
            child: Column(
              children: [
                Text('Formora Vault', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Version v1.0.0 (Local-first)', style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
