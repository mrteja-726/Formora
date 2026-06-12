// lib/core/database/daos/ocr_dao.dart
import 'package:drift/drift.dart';

import 'package:formora/core/database/app_database.dart';
import 'package:formora/core/database/tables/ocr_results_table.dart';

part 'ocr_dao.g.dart';

@DriftAccessor(tables: [OcrResultsTable])
class OcrDao extends DatabaseAccessor<AppDatabase> with _$OcrDaoMixin {
  OcrDao(super.db);

  /// Get all OCR results for a specific document.
  Future<List<OcrResultsTableData>> getResultsForDocument(
          String documentId) =>
      (select(ocrResultsTable)
            ..where((t) => t.documentId.equals(documentId))
            ..orderBy([(t) => OrderingTerm.desc(t.processedAt)]))
          .get();

  /// Get the most recent OCR result for a document.
  Future<OcrResultsTableData?> getLatestResultForDocument(
          String documentId) =>
      (select(ocrResultsTable)
            ..where((t) => t.documentId.equals(documentId))
            ..orderBy([(t) => OrderingTerm.desc(t.processedAt)])
            ..limit(1))
          .getSingleOrNull();

  /// Get all unreviewed OCR results for a profile.
  Future<List<OcrResultsTableData>> getPendingReviewResults(
          String profileId) =>
      (select(ocrResultsTable)
            ..where((t) =>
                t.profileId.equals(profileId) &
                t.userReviewed.equals(false) &
                t.appliedToProfile.equals(false)))
          .get();

  /// Insert a new OCR result.
  Future<void> insertOcrResult(OcrResultsTableCompanion result) =>
      into(ocrResultsTable).insert(result);

  /// Mark an OCR result as reviewed by the user.
  Future<void> markReviewed(String resultId) =>
      (update(ocrResultsTable)..where((t) => t.id.equals(resultId)))
          .write(const OcrResultsTableCompanion(userReviewed: Value(true)));

  /// Mark an OCR result as applied to the profile.
  Future<void> markApplied(String resultId) =>
      (update(ocrResultsTable)..where((t) => t.id.equals(resultId))).write(
          const OcrResultsTableCompanion(
              userReviewed: Value(true), appliedToProfile: Value(true)));

  /// Delete OCR results for a document.
  Future<void> deleteResultsForDocument(String documentId) =>
      (delete(ocrResultsTable)
            ..where((t) => t.documentId.equals(documentId)))
          .go();

  /// Get all OCR results (for backup export).
  Future<List<OcrResultsTableData>> getAllResults() =>
      select(ocrResultsTable).get();
}
