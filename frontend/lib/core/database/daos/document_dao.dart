// lib/core/database/daos/document_dao.dart
import 'package:drift/drift.dart';

import 'package:formora/core/database/app_database.dart';
import 'package:formora/core/database/tables/documents_table.dart';

part 'document_dao.g.dart';

@DriftAccessor(tables: [DocumentsTable])
class DocumentDao extends DatabaseAccessor<AppDatabase>
    with _$DocumentDaoMixin {
  DocumentDao(super.db);

  /// Watch all documents for a profile, newest first.
  Stream<List<DocumentsTableData>> watchDocumentsForProfile(
          String profileId) =>
      (select(documentsTable)
            ..where((t) => t.profileId.equals(profileId))
            ..orderBy([(t) => OrderingTerm.desc(t.uploadedAt)]))
          .watch();

  /// Get all documents for a profile.
  Future<List<DocumentsTableData>> getDocumentsForProfile(
          String profileId) =>
      (select(documentsTable)
            ..where((t) => t.profileId.equals(profileId))
            ..orderBy([(t) => OrderingTerm.desc(t.uploadedAt)]))
          .get();

  /// Get a single document by id.
  Future<DocumentsTableData?> getDocumentById(String id) =>
      (select(documentsTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Insert a new document record.
  Future<void> insertDocument(DocumentsTableCompanion document) =>
      into(documentsTable).insert(document);

  /// Update a document (e.g. after OCR completes, update ocrStatus).
  Future<bool> updateDocument(DocumentsTableCompanion document) =>
      update(documentsTable).replace(document);

  /// Update only the OCR status of a document.
  Future<void> updateOcrStatus(String documentId, String status) =>
      (update(documentsTable)..where((t) => t.id.equals(documentId)))
          .write(DocumentsTableCompanion(ocrStatus: Value(status)));

  /// Update thumbnail path after thumbnail generation.
  Future<void> updateThumbnailPath(
          String documentId, String thumbnailPath) =>
      (update(documentsTable)..where((t) => t.id.equals(documentId))).write(
          DocumentsTableCompanion(thumbnailPath: Value(thumbnailPath)));

  /// Delete a document record (caller is responsible for deleting the file).
  Future<void> deleteDocument(String documentId) =>
      (delete(documentsTable)..where((t) => t.id.equals(documentId))).go();

  /// Get total document count for a profile.
  Future<int> getDocumentCount(String profileId) async {
    final countExp = documentsTable.id.count();
    final query = selectOnly(documentsTable)
      ..addColumns([countExp])
      ..where(documentsTable.profileId.equals(profileId));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Get documents with pending/failed OCR for retry.
  Future<List<DocumentsTableData>> getPendingOcrDocuments(
          String profileId) =>
      (select(documentsTable)
            ..where((t) =>
                t.profileId.equals(profileId) &
                (t.ocrStatus.equals('pending') |
                    t.ocrStatus.equals('failed'))))
          .get();

  /// Get all documents across all profiles (for backup).
  Future<List<DocumentsTableData>> getAllDocuments() =>
      select(documentsTable).get();
}
