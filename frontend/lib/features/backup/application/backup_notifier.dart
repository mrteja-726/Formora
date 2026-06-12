// lib/features/backup/application/backup_notifier.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:formora/features/backup/data/backup_service.dart';
import 'package:formora/features/backup/data/restore_service.dart';
import 'package:formora/features/backup/domain/backup_manifest.dart';

enum BackupStatus { idle, inProgress, done, error }

class BackupNotifierState {
  final BackupStatus status;
  final double progress;
  final String statusMessage;
  final String? errorMessage;
  final File? lastBackupFile;
  final BackupManifest? validatedManifest;
  final File? pendingRestoreFile;

  const BackupNotifierState({
    this.status = BackupStatus.idle,
    this.progress = 0.0,
    this.statusMessage = '',
    this.errorMessage,
    this.lastBackupFile,
    this.validatedManifest,
    this.pendingRestoreFile,
  });

  BackupNotifierState copyWith({
    BackupStatus? status,
    double? progress,
    String? statusMessage,
    String? errorMessage,
    File? lastBackupFile,
    BackupManifest? validatedManifest,
    File? pendingRestoreFile,
  }) {
    return BackupNotifierState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage,
      lastBackupFile: lastBackupFile ?? this.lastBackupFile,
      validatedManifest: validatedManifest ?? this.validatedManifest,
      pendingRestoreFile: pendingRestoreFile ?? this.pendingRestoreFile,
    );
  }
}

final backupNotifierProvider =
    NotifierProvider<BackupNotifier, BackupNotifierState>(BackupNotifier.new);

class BackupNotifier extends Notifier<BackupNotifierState> {
  @override
  BackupNotifierState build() => const BackupNotifierState();

  BackupService get _backup => ref.read(backupServiceProvider);
  RestoreService get _restore => ref.read(restoreServiceProvider);

  // ── Backup ────────────────────────────────────────────────────────────────

  Future<void> createAndShareBackup() async {
    state = state.copyWith(
        status: BackupStatus.inProgress, progress: 0.0, statusMessage: 'Starting...');
    try {
      final file = await _backup.createBackup(
        onProgress: (p, msg) =>
            state = state.copyWith(progress: p, statusMessage: msg),
      );
      await _backup.shareBackup(file);
      state = state.copyWith(
          status: BackupStatus.done, progress: 1.0,
          statusMessage: 'Backup shared!', lastBackupFile: file);
    } catch (e) {
      state = state.copyWith(
          status: BackupStatus.error,
          errorMessage: 'Backup failed: $e');
    }
  }

  // ── Restore ───────────────────────────────────────────────────────────────

  /// Step 1: User picks a file — validate without restoring.
  Future<void> selectRestoreFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any, // .formora has no registered MIME
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    state = state.copyWith(
        status: BackupStatus.inProgress, statusMessage: 'Validating backup...');

    try {
      final manifest = await _restore.validateBackup(file);
      state = state.copyWith(
        status: BackupStatus.idle,
        validatedManifest: manifest,
        pendingRestoreFile: file,
        statusMessage: 'Backup validated — ready to restore',
      );
    } on RestoreException catch (e) {
      state = state.copyWith(
          status: BackupStatus.error, errorMessage: e.message);
    }
  }

  /// Step 2: Biometric auth has been done by caller. Execute restore.
  Future<void> executeRestore({required String mode}) async {
    final file = state.pendingRestoreFile;
    if (file == null) return;

    state = state.copyWith(
        status: BackupStatus.inProgress, progress: 0.0,
        statusMessage: 'Restoring...');
    try {
      await _restore.restoreBackup(
        file,
        mode: mode,
        onProgress: (p, msg) =>
            state = state.copyWith(progress: p, statusMessage: msg),
      );
      state = state.copyWith(
          status: BackupStatus.done, progress: 1.0,
          statusMessage: 'Restore complete!');
    } on RestoreException catch (e) {
      state = state.copyWith(
          status: BackupStatus.error, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
          status: BackupStatus.error, errorMessage: 'Restore failed: $e');
    }
  }

  void reset() => state = const BackupNotifierState();
}
