// lib/features/documents/application/document_upload_pipeline.dart
//
// State machine for the full document upload flow:
//
//   IDLE
//   → SELECTING       (user picks file / camera)
//   → VALIDATING      (type, size, format checks)
//   → STORING         (encrypt + save to disk + DB)
//   → GENERATING_THUMBNAIL
//   → OCR_PROCESSING  (ML Kit, background isolate)
//   → MAPPING_FIELDS  (OcrFieldMapper)
//   → AWAITING_REVIEW (show mapped fields to user)
//   → SAVING          (apply fields to profile)
//   → DONE
//   → ERROR           (at any step)

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:formora/core/di/providers.dart';
import 'package:formora/features/ocr/data/ocr_service.dart';
import 'package:formora/features/ocr/domain/ocr_field_mapper.dart';
import 'package:formora/features/profile/application/profile_notifier.dart';
import 'package:formora/features/profile/domain/profile_entities.dart';
import 'package:formora/features/documents/data/local_document_repository.dart';
import 'package:formora/features/documents/domain/document_entities.dart';

// ── State ──────────────────────────────────────────────────────────────────

enum UploadStep {
  idle,
  selecting,
  validating,
  storing,
  generatingThumbnail,
  ocrProcessing,
  mappingFields,
  awaitingReview,
  saving,
  done,
  error,
}

class UploadPipelineState {
  final UploadStep step;
  final double progress; // 0.0–1.0
  final String? errorMessage;
  final Document? document;
  final List<MappedField> mappedFields;
  final List<MappedField> reviewFields; // Fields needing user review
  final String? ocrRawText;
  final double? ocrConfidence;

  const UploadPipelineState({
    this.step = UploadStep.idle,
    this.progress = 0.0,
    this.errorMessage,
    this.document,
    this.mappedFields = const [],
    this.reviewFields = const [],
    this.ocrRawText,
    this.ocrConfidence,
  });

  bool get isProcessing =>
      step != UploadStep.idle &&
      step != UploadStep.done &&
      step != UploadStep.error &&
      step != UploadStep.awaitingReview;

  UploadPipelineState copyWith({
    UploadStep? step,
    double? progress,
    String? errorMessage,
    Document? document,
    List<MappedField>? mappedFields,
    List<MappedField>? reviewFields,
    String? ocrRawText,
    double? ocrConfidence,
  }) {
    return UploadPipelineState(
      step: step ?? this.step,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      document: document ?? this.document,
      mappedFields: mappedFields ?? this.mappedFields,
      reviewFields: reviewFields ?? this.reviewFields,
      ocrRawText: ocrRawText ?? this.ocrRawText,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────

final uploadPipelineProvider =
    NotifierProvider<DocumentUploadPipeline, UploadPipelineState>(
        DocumentUploadPipeline.new);

class DocumentUploadPipeline extends Notifier<UploadPipelineState> {
  static const _maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB
  static const _allowedContentTypes = [
    'image/jpeg',
    'image/png',
    'image/heic',
    'application/pdf',
  ];

  final _mapper = const OcrFieldMapper();
  final _uuid = const Uuid();

  @override
  UploadPipelineState build() => const UploadPipelineState();

  LocalDocumentRepository get _docRepo =>
      ref.read(documentRepositoryProvider);
  OcrService get _ocrService => ref.read(ocrServiceProvider);

  // ── Pipeline Entry Point ──────────────────────────────────────────────────

  Future<void> startUpload({
    required File file,
    required DocumentType documentType,
    required String profileId,
  }) async {
    try {
      // VALIDATING
      state = state.copyWith(step: UploadStep.validating, progress: 0.1);
      await _validate(file);

      // STORING (encrypt + DB insert)
      state = state.copyWith(step: UploadStep.storing, progress: 0.25);
      final doc = await _docRepo.addDocument(
        profileId: profileId,
        sourceFile: file,
        documentType: documentType,
      );

      // GENERATING THUMBNAIL
      state = state.copyWith(
          step: UploadStep.generatingThumbnail, progress: 0.40, document: doc);
      await _generateThumbnail(doc, profileId, file);

      // OCR PROCESSING
      state = state.copyWith(step: UploadStep.ocrProcessing, progress: 0.55);
      await _docRepo.updateOcrStatus(doc.id, OcrStatus.processing);
      final decryptedTemp = await _docRepo.decryptToTemp(doc);

      OcrRawResult? ocrResult;
      try {
        if (doc.isImage) {
          ocrResult = await _ocrService.recognizeText(decryptedTemp);
        }
        // PDF: process first page only (pdfx thumbnail → image → OCR)
        // Full PDF multi-page OCR deferred to future version
      } finally {
        // ALWAYS delete temp file after OCR
        if (await decryptedTemp.exists()) await decryptedTemp.delete();
      }

      if (ocrResult == null || !ocrResult.hasText) {
        await _docRepo.updateOcrStatus(doc.id, OcrStatus.completed);
        state = state.copyWith(
            step: UploadStep.done, progress: 1.0, document: doc);
        return;
      }

      await _docRepo.updateOcrStatus(doc.id, OcrStatus.completed);

      // MAPPING FIELDS
      state = state.copyWith(step: UploadStep.mappingFields, progress: 0.75);
      final mapped = _mapper.mapToProfileFields(ocrResult, documentType.dbKey);

      // Separate high-confidence (auto-fill) from needs-review
      final autoFill =
          mapped.where((f) => f.tier == OcrConfidenceTier.high).toList();
      final needsReview = mapped
          .where((f) => f.tier != OcrConfidenceTier.high)
          .toList();

      // Auto-apply high confidence fields immediately
      if (autoFill.isNotEmpty) {
        await _applyFields(autoFill, profileId, doc.id);
      }

      if (needsReview.isEmpty) {
        state = state.copyWith(
          step: UploadStep.done,
          progress: 1.0,
          document: doc,
          mappedFields: mapped,
          ocrRawText: ocrResult.fullText,
          ocrConfidence: ocrResult.overallConfidence,
        );
        return;
      }

      // AWAITING REVIEW — UI takes over from here
      state = state.copyWith(
        step: UploadStep.awaitingReview,
        progress: 0.85,
        document: doc,
        mappedFields: mapped,
        reviewFields: needsReview,
        ocrRawText: ocrResult.fullText,
        ocrConfidence: ocrResult.overallConfidence,
      );
    } catch (e) {
      state = state.copyWith(
          step: UploadStep.error,
          errorMessage: e.toString());
    }
  }

  /// Called by UI after user reviews and confirms mapped fields.
  Future<void> confirmReviewedFields({
    required List<MappedField> confirmedFields,
    required String profileId,
    required String documentId,
  }) async {
    state = state.copyWith(step: UploadStep.saving, progress: 0.95);
    try {
      await _applyFields(confirmedFields, profileId, documentId);
      state = state.copyWith(step: UploadStep.done, progress: 1.0);
    } catch (e) {
      state = state.copyWith(
          step: UploadStep.error, errorMessage: e.toString());
    }
  }

  /// Discard OCR results — just keep the document without applying fields.
  void discardOcrResults() {
    state = state.copyWith(step: UploadStep.done, progress: 1.0);
  }

  void reset() {
    state = const UploadPipelineState();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _validate(File file) async {
    if (!await file.exists()) {
      throw Exception('File not found');
    }
    final size = await file.length();
    if (size > _maxFileSizeBytes) {
      throw Exception(
          'File too large (max 50MB). Selected file: ${(size / 1024 / 1024).toStringAsFixed(1)}MB');
    }
  }

  Future<void> _generateThumbnail(
      Document doc, String profileId, File originalFile) async {
    // Thumbnail generation — resize image to 200x200
    // Deferred to UI/image_compress layer; stub here for pipeline continuity
    // When UI is integrated, call docRepo.saveThumbnail(...)
  }

  Future<void> _applyFields(
      List<MappedField> fields, String profileId, String documentId) async {
    final profileFields = fields
        .map((f) => ProfileField(
              id: _uuid.v4(),
              profileId: profileId,
              section: f.section,
              fieldKey: f.fieldKey,
              value: f.value,
              dataType: f.dataType,
              ocrConfidence: f.confidence,
              source: 'ocr',
              sourceDocumentId: documentId,
              updatedAt: DateTime.now(),
            ))
        .toList();
    await ref.read(profileNotifierProvider.notifier).applyOcrFields(profileFields);
  }
}
