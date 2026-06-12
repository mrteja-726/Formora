import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:formora/features/backup/application/backup_notifier.dart';

class BackupCenterScreen extends ConsumerStatefulWidget {
  const BackupCenterScreen({super.key});

  @override
  ConsumerState<BackupCenterScreen> createState() => _BackupCenterScreenState();
}

class _BackupCenterScreenState extends ConsumerState<BackupCenterScreen> {
  bool _backupProfiles = true;
  bool _backupDocuments = true;
  bool _backupChats = true;
  bool _backupSettings = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backupNotifierProvider);
    final notifier = ref.read(backupNotifierProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.reset(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(context, state),
            const SizedBox(height: 24),

            // Backup settings / data selection
            if (state.status == BackupStatus.idle || state.status == BackupStatus.done || state.status == BackupStatus.error) ...[
              const Text(
                'Data Selection',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('Profiles & Local Fields'),
                      subtitle: const Text('All your encrypted profile details'),
                      value: _backupProfiles,
                      onChanged: (v) => setState(() => _backupProfiles = v ?? true),
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: const Text('Vault Documents'),
                      subtitle: const Text('Files scans, PDFs, and certificates'),
                      value: _backupDocuments,
                      onChanged: (v) => setState(() => _backupDocuments = v ?? true),
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: const Text('AI Conversation History'),
                      subtitle: const Text('All messages and helper chats'),
                      value: _backupChats,
                      onChanged: (v) => setState(() => _backupChats = v ?? true),
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: const Text('App Settings'),
                      subtitle: const Text('AI models and app lock status'),
                      value: _backupSettings,
                      onChanged: (v) => setState(() => _backupSettings = v ?? true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              ElevatedButton.icon(
                onPressed: () => notifier.createAndShareBackup(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Create & Share Encrypted Backup', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _handleRestore(context, notifier),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.outline),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                icon: const Icon(Icons.restore_outlined),
                label: const Text('Restore from Backup File', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],

            // In progress layout
            if (state.status == BackupStatus.inProgress) ...[
              const SizedBox(height: 32),
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    state.statusMessage,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: state.progress),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, BackupNotifierState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final isError = state.status == BackupStatus.error;
    final isDone = state.status == BackupStatus.done;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.shade900.withOpacity(0.1)
            : (isDone ? Colors.green.shade900.withOpacity(0.1) : colorScheme.surfaceContainer),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isError ? Colors.red : (isDone ? Colors.green : colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isError ? Icons.error_outline : (isDone ? Icons.check_circle_outline : Icons.cloud_sync_outlined),
                color: isError ? Colors.red : (isDone ? Colors.green : colorScheme.primary),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isError ? 'Backup Failed' : (isDone ? 'Backup Successful' : 'Local Backup Center'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isError ? Colors.red : (isDone ? Colors.green : colorScheme.onSurface),
                ),
              ),
            ],
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ] else if (isDone && state.lastBackupFile != null) ...[
            const SizedBox(height: 12),
            Text(
              'File saved at: ${state.lastBackupFile!.path}',
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              'No backups have been created during this session. Back up your data to prevent accidental loss.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleRestore(BuildContext context, BackupNotifier refNotifier) async {
    await refNotifier.selectRestoreFile();
    final state = ref.read(backupNotifierProvider);
    if (state.pendingRestoreFile != null && state.validatedManifest != null) {
      if (!context.mounted) return;

      // Conflict Resolution selection
      final mode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Conflict Resolution', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A backup file created on ${DateFormat.yMMMd().format(state.validatedManifest!.createdAt)} was validated.\n\n'
                'How would you like to handle local conflicts?',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
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
        await refNotifier.executeRestore(mode: mode);
        final finalState = ref.read(backupNotifierProvider);
        if (finalState.status == BackupStatus.done) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data restored successfully!')),
            );
          }
        }
      }
    }
  }
}
