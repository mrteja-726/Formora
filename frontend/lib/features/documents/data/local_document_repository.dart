// lib/features/documents/data/local_document_repository.dart
//
// Handles encrypted document storage on device.
// Files are AES-256-GCM encrypted before saving.
// Database only stores encrypted file paths + metadata.

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:formora/core/di/providers.dart';
import 'package:formora/core/security/encryption_service.dart';
import 'package:formora/features/documents/domain/document_entities.dart';
import 'package:formora/features/documents/data/document_mapper.dart';
import 'package:formora/features/profile/application/profile_notifier.dart';

final documentRepositoryProvider = Provider<LocalDocumentRepository>((ref) {
  return LocalDocumentRepository(
    dao: ref.watch(documentDaoProvider),
    encryption: ref.watch(encryptionServiceProvider),
    mapper: const DocumentMapper(),
  );
});

final activeProfileDocumentsProvider = StreamProvider<List<Document>>((ref) {
  final activeProfileAsync = ref.watch(activeProfileProvider);
  final profile = activeProfileAsync.value;
  if (profile == null) return Stream.value([]);

  final repo = ref.watch(documentRepositoryProvider);
  return repo.watchDocumentsForProfile(profile.id);
});

class LocalDocumentRepository {
  final dynamic _dao; // DocumentDao
  final EncryptionService _encryption;
  final DocumentMapper _mapper;
  final _uuid = const Uuid();

  LocalDocumentRepository({
    required dynamic dao,
    required EncryptionService encryption,
    required DocumentMapper mapper,
  })  : _dao = dao,
        _encryption = encryption,
        _mapper = mapper;

  // ── Storage directories ───────────────────────────────────────────────────

  Future<Directory> _documentsDir(String profileId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'formora', 'docs', profileId));
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _thumbnailsDir(String profileId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir =
        Directory(p.join(base.path, 'formora', 'thumbnails', profileId));
    await dir.create(recursive: true);
    return dir;
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Stream<List<Document>> watchDocumentsForProfile(String profileId) =>
      _dao
          .watchDocumentsForProfile(profileId)
          .map((rows) => rows.map(_mapper.fromRow).toList());

  Future<List<Document>> getDocumentsForProfile(String profileId) async {
    final rows = await _dao.getDocumentsForProfile(profileId);
    return rows.map(_mapper.fromRow).toList();
  }

  Future<Document?> getDocumentById(String id) async {
    final row = await _dao.getDocumentById(id);
    return row == null ? null : _mapper.fromRow(row);
  }

  // ── Write / Encrypt ───────────────────────────────────────────────────────

  /// Store a document file encrypted at rest.
  /// [sourceFile] is the original (unencrypted) file from the picker.
  Future<Document> addDocument({
    required String profileId,
    required File sourceFile,
    required DocumentType documentType,
  }) async {
    final id = _uuid.v4();
    final filename = p.basename(sourceFile.path);
    final contentType =
        lookupMimeType(sourceFile.path) ?? 'application/octet-stream';
    final sizeBytes = await sourceFile.length();

    // 1. Compute SHA-256 checksum of the ORIGINAL file
    final originalBytes = await sourceFile.readAsBytes();
    final checksum = sha256.convert(originalBytes).toString();

    // 2. Encrypt and save to private app directory
    final docsDir = await _documentsDir(profileId);
    final encryptedPath = p.join(docsDir.path, '$id.enc');
    await _encryption.encryptFile(sourceFile, encryptedPath);

    // 3. Insert record into Drift
    final doc = Document(
      id: id,
      profileId: profileId,
      filename: filename,
      documentType: documentType,
      contentType: contentType,
      sizeBytes: sizeBytes,
      encryptedFilePath: encryptedPath,
      ocrStatus: OcrStatus.pending,
      checksum: checksum,
      uploadedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _dao.insertDocument(_mapper.toInsertCompanion(doc));
    return doc;
  }

  /// Decrypt a stored document to a temporary file for viewing/OCR.
  /// ⚠️ Caller MUST delete the temp file after use.
  Future<File> decryptToTemp(Document doc) async {
    final encFile = File(doc.encryptedFilePath);
    return _encryption.decryptFileToTemp(encFile, doc.filename);
  }

  /// Returns the decrypted bytes of a document (for thumbnail generation).
  Future<Uint8List> decryptBytes(Document doc) async {
    final encFile = File(doc.encryptedFilePath);
    return _encryption.decryptFileBytes(encFile);
  }

  /// Verify integrity by re-computing checksum on decrypted bytes.
  Future<bool> verifyIntegrity(Document doc) async {
    try {
      final bytes = await decryptBytes(doc);
      final checksum = sha256.convert(bytes).toString();
      return checksum == doc.checksum;
    } catch (_) {
      return false;
    }
  }

  // ── Thumbnail ─────────────────────────────────────────────────────────────

  /// Save an encrypted thumbnail and update the document record.
  Future<void> saveThumbnail(
      String documentId, String profileId, Uint8List thumbnailBytes) async {
    final dir = await _thumbnailsDir(profileId);
    final thumbPath = p.join(dir.path, '$documentId.thumb.enc');

    // Write raw bytes to temp file, then encrypt
    final tmp = File(p.join(dir.path, '_tmp_$documentId'));
    await tmp.writeAsBytes(thumbnailBytes);
    await _encryption.encryptFile(tmp, thumbPath);
    await tmp.delete();

    await _dao.updateThumbnailPath(documentId, thumbPath);
  }

  /// Decrypt and return thumbnail bytes.
  Future<Uint8List?> getThumbnailBytes(Document doc) async {
    if (doc.thumbnailPath == null) return null;
    final encFile = File(doc.thumbnailPath!);
    if (!await encFile.exists()) return null;
    try {
      return await _encryption.decryptFileBytes(encFile);
    } catch (_) {
      return null;
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Deletes the document record AND the encrypted files from disk.
  Future<void> deleteDocument(Document doc) async {
    // Delete encrypted file
    final encFile = File(doc.encryptedFilePath);
    if (await encFile.exists()) await encFile.delete();

    // Delete thumbnail
    if (doc.thumbnailPath != null) {
      final thumbFile = File(doc.thumbnailPath!);
      if (await thumbFile.exists()) await thumbFile.delete();
    }

    // Delete DB record
    await _dao.deleteDocument(doc.id);
  }

  // ── OCR Status ────────────────────────────────────────────────────────────

  Future<void> updateOcrStatus(String documentId, OcrStatus status) async {
    await _dao.updateOcrStatus(documentId, status.dbKey);
  }

  // ── Backup support ────────────────────────────────────────────────────────

  Future<List<Document>> getAllDocuments() async {
    final rows = await _dao.getAllDocuments();
    return rows.map(_mapper.fromRow).toList();
  }
}
