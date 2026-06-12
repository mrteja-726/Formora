// lib/features/documents/data/document_mapper.dart

import 'package:drift/drift.dart';
import 'package:formora/core/database/app_database.dart';
import 'package:formora/features/documents/domain/document_entities.dart';

class DocumentMapper {
  const DocumentMapper();

  Document fromRow(DocumentsTableData row) {
    return Document(
      id: row.id,
      profileId: row.profileId,
      filename: row.filename,
      documentType: DocumentType.fromDbKey(row.documentType),
      contentType: row.contentType,
      sizeBytes: row.sizeBytes,
      encryptedFilePath: row.encryptedFilePath,
      thumbnailPath: row.thumbnailPath,
      ocrStatus: OcrStatus.fromDbKey(row.ocrStatus),
      checksum: row.checksum,
      uploadedAt: row.uploadedAt,
      updatedAt: row.updatedAt,
    );
  }

  DocumentsTableCompanion toInsertCompanion(Document doc) {
    return DocumentsTableCompanion.insert(
      id: doc.id,
      profileId: doc.profileId,
      filename: doc.filename,
      documentType: doc.documentType.dbKey,
      contentType: doc.contentType,
      sizeBytes: doc.sizeBytes,
      encryptedFilePath: doc.encryptedFilePath,
      thumbnailPath: Value(doc.thumbnailPath),
      ocrStatus: Value(doc.ocrStatus.dbKey),
      checksum: doc.checksum,
      uploadedAt: Value(doc.uploadedAt),
      updatedAt: Value(doc.updatedAt),
    );
  }
}
