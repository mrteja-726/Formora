// lib/features/backup/data/backup_service.dart
//
// Creates an encrypted .formora backup package:
//
// Package structure (as ZIP before encryption):
//   manifest.json
//   data/
//     profiles.json
//     profile_fields.json
//     documents.json
//     ocr_results.json
//     achievements.json
//     ai_conversations.json
//     ai_messages.json
//     settings.json
//   files/
//     <documentId>.enc   ← already encrypted (stored as-is)
//
// The ZIP is then AES-256-GCM encrypted → written as .formora file.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:formora/core/database/tables/backup_records_table.dart';
import 'package:formora/core/database/app_database.dart';
import 'package:formora/core/di/providers.dart';
import 'package:formora/core/security/encryption_service.dart';
import 'package:formora/core/storage/hive_storage.dart';
import 'package:formora/features/documents/domain/document_entities.dart';
import 'package:formora/features/documents/data/local_document_repository.dart';
import 'package:formora/features/profile/data/local_profile_repository.dart';
import 'package:formora/features/backup/domain/backup_manifest.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    encryption: ref.watch(encryptionServiceProvider),
    profileRepo: ref.watch(profileRepositoryProvider),
    documentRepo: ref.watch(documentRepositoryProvider),
    hive: ref.watch(hiveStorageProvider),
    ref: ref,
  );
});

class BackupService {
  final EncryptionService _encryption;
  final LocalProfileRepository _profileRepo;
  final LocalDocumentRepository _documentRepo;
  final HiveStorage _hive;
  final Ref _ref;
  final _uuid = const Uuid();

  BackupService({
    required EncryptionService encryption,
    required LocalProfileRepository profileRepo,
    required LocalDocumentRepository documentRepo,
    required HiveStorage hive,
    required Ref ref,
  })  : _encryption = encryption,
        _profileRepo = profileRepo,
        _documentRepo = documentRepo,
        _hive = hive,
        _ref = ref;

  // ── Create Backup ─────────────────────────────────────────────────────────

  /// Creates an encrypted .formora backup and shares it.
  /// [onProgress] receives 0.0–1.0 progress updates.
  Future<File> createBackup({
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.05, 'Gathering data...');

    // 1. Collect all data from Drift
    final db = _ref.read(appDatabaseProvider);
    final profiles = await db.profileDao.getAllProfiles();
    final fields = await db.profileDao
        .getFieldsBySection('') // Get all across all profiles
        .then((_) => db.profileDao.getFieldsForProfile('').then((_) async {
              // Get all profile fields
              List<dynamic> allFields = [];
              for (final p in profiles) {
                allFields.addAll(await db.profileDao.getFieldsForProfile(p.id));
              }
              return allFields;
            }));

    final documents = await _documentRepo.getAllDocuments();
    final achievements = await db.achievementDao.getAllAchievements();
    final conversations = await db.aiDao.getAllConversations();
    final messages = await db.aiDao.getAllMessages();

    onProgress?.call(0.20, 'Building archive...');

    // 2. Build in-memory ZIP
    final archive = Archive();

    void addJson(String filename, dynamic data) {
      final bytes = utf8.encode(jsonEncode(data));
      archive.addFile(ArchiveFile(filename, bytes.length, bytes));
    }

    addJson('data/profiles.json',
        profiles.map((p) => p.toJson()).toList());
    addJson('data/achievements.json',
        achievements.map((a) => a.toJson()).toList());
    addJson('data/ai_conversations.json',
        conversations.map((c) => c.toJson()).toList());
    addJson('data/ai_messages.json',
        messages.map((m) => m.toJson()).toList());
    addJson('data/documents.json',
        documents.map((d) => {
              'id': d.id,
              'profileId': d.profileId,
              'filename': d.filename,
              'documentType': d.documentType.dbKey,
              'contentType': d.contentType,
              'sizeBytes': d.sizeBytes,
              'ocrStatus': d.ocrStatus.dbKey,
              'checksum': d.checksum,
              'uploadedAt': d.uploadedAt.toIso8601String(),
            }).toList());

    // Settings (non-sensitive)
    addJson('data/settings.json', {
      'theme': _hive.getSetting<String>('theme'),
      'dynamicColor': _hive.getSetting<bool>('dynamic_color'),
      'aiProvider': _hive.getAiConfig<String>('ai_active_provider'),
    });

    onProgress?.call(0.40, 'Copying documents...');

    // 3. Copy already-encrypted document files into the archive
    for (final doc in documents) {
      final encFile = File(doc.encryptedFilePath);
      if (await encFile.exists()) {
        final bytes = await encFile.readAsBytes();
        archive.addFile(ArchiveFile(
            'files/${doc.id}.enc', bytes.length, bytes));
      }
      if (doc.thumbnailPath != null) {
        final thumbFile = File(doc.thumbnailPath!);
        if (await thumbFile.exists()) {
          final bytes = await thumbFile.readAsBytes();
          archive.addFile(ArchiveFile(
              'files/${doc.id}.thumb.enc', bytes.length, bytes));
        }
      }
    }

    onProgress?.call(0.60, 'Compressing...');

    // 4. Encode ZIP
    final zipBytes = ZipEncoder().encode(archive);
    final zipUint8 = Uint8List.fromList(zipBytes);

    // 5. Checksum of ZIP
    final checksum = _encryption.checksumBytes(zipUint8);

    // 6. Build manifest
    final manifest = BackupManifest(
      version: BackupManifest.currentVersion,
      createdAt: DateTime.now(),
      appVersion: '1.0.0',
      profileCount: profiles.length,
      documentCount: documents.length,
      achievementCount: achievements.length,
      conversationCount: conversations.length,
      dataChecksum: checksum,
      deviceId: 'anonymous',
    );

    // 7. Prepend manifest JSON to ZIP (stored as separate section before encryption)
    final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
    final manifestLen = manifestBytes.length;
    final combined = Uint8List(4 + manifestLen + zipUint8.length);
    combined.buffer.asByteData().setInt32(0, manifestLen, Endian.big);
    combined.setRange(4, 4 + manifestLen, manifestBytes);
    combined.setRange(4 + manifestLen, combined.length, zipUint8);

    onProgress?.call(0.75, 'Encrypting...');

    // 8. Encrypt the whole thing
    final encrypted = await _encryption.encryptBackupBytes(combined);

    onProgress?.call(0.90, 'Saving file...');

    // 9. Write to disk
    final backupDir = await _getBackupDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final filename = 'formora_backup_$timestamp${BackupManifest.fileExtension}';
    final backupFile = File(p.join(backupDir.path, filename));
    await backupFile.writeAsBytes(encrypted);

    // 10. Record in DB
    await _ref.read(backupDaoProvider).insertBackupRecord(
      BackupRecordsTableCompanion.insert(
        id: _uuid.v4(),
        filePath: backupFile.path,
        sizeBytes: encrypted.length,
        profileCount: profiles.length,
        documentCount: documents.length,
        checksum: checksum,
        appVersion: '1.0.0',
      ),
    );
    await _ref.read(backupDaoProvider).pruneBackupHistory();

    onProgress?.call(1.0, 'Done!');
    return backupFile;
  }

  /// Share the backup file via the share sheet.
  Future<void> shareBackup(File backupFile) async {
    await Share.shareXFiles(
      [XFile(backupFile.path)],
      subject: 'Formora Backup',
      text: 'Your encrypted Formora backup file.',
    );
  }

  Future<Directory> _getBackupDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'formora', 'backups'));
    await dir.create(recursive: true);
    return dir;
  }
}
