import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:formora/features/documents/data/local_document_repository.dart';
import 'package:formora/features/documents/domain/document_entities.dart';
import 'package:formora/features/documents/application/document_upload_pipeline.dart';
import 'package:formora/features/profile/application/profile_notifier.dart';
import 'package:formora/features/ocr/domain/ocr_field_mapper.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  Future<void> _pickAndUpload() async {
    final type = await showDialog<DocumentType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Document Type', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A2E),
        children: [
          _typeOption(context, DocumentType.passport, 'Passport'),
          _typeOption(context, DocumentType.drivingLicense, "Driver's License"),
          _typeOption(context, DocumentType.nationalId, 'National ID'),
          _typeOption(context, DocumentType.aadhaarCard, 'Aadhaar Card (India)'),
          _typeOption(context, DocumentType.panCard, 'PAN Card (India)'),
          _typeOption(context, DocumentType.bankStatement, 'Bank Statement'),
          _typeOption(context, DocumentType.other, 'Other'),
        ],
      ),
    );

    if (type == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final file = File(path);

      final activeProfile = ref.read(activeProfileProvider).value;
      if (activeProfile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please create or select an active profile first.'),
              backgroundColor: Color(0xFFBA1A1A),
            ),
          );
        }
        return;
      }

      await ref.read(uploadPipelineProvider.notifier).startUpload(
            file: file,
            documentType: type,
            profileId: activeProfile.id,
          );
    }
  }

  Widget _typeOption(BuildContext context, DocumentType value, String label) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, UploadPipelineState uploadState) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return OcrReviewDialog(uploadState: uploadState);
      },
    );
  }

  Future<void> _deleteDocument(Document doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${doc.filename}"? This will permanently remove the encrypted file from your device.', style: const TextStyle(color: Colors.white70)),
        backgroundColor: const Color(0xFF1A1A2E),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(documentRepositoryProvider).deleteDocument(doc);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(activeProfileDocumentsProvider);
    final uploadState = ref.watch(uploadPipelineProvider);

    // Listen to upload pipeline state transitions
    ref.listen<UploadPipelineState>(uploadPipelineProvider, (prev, next) {
      if (next.step == UploadStep.awaitingReview && next.reviewFields.isNotEmpty) {
        _showReviewDialog(context, next);
      } else if (next.step == UploadStep.done && prev?.step != UploadStep.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document processed successfully!'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        ref.read(uploadPipelineProvider.notifier).reset();
      } else if (next.step == UploadStep.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process document: ${next.errorMessage}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        ref.read(uploadPipelineProvider.notifier).reset();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text('Document Vault', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Upload Button ──
            ElevatedButton.icon(
              onPressed: uploadState.isProcessing ? null : _pickAndUpload,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF00478D),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF00478D).withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: uploadState.isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                uploadState.isProcessing
                    ? 'Processing (${(uploadState.progress * 100).round()}%)...'
                    : 'Upload Document',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),

            // ── Documents List ──
            Expanded(
              child: docsAsync.when(
                data: (documents) {
                  if (documents.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          Text(
                            'Your vault is empty',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final doc = documents[index];
                      return _documentCard(doc);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: Color(0xFFEF4444)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentCard(Document doc) {
    IconData icon;
    switch (doc.documentType) {
      case DocumentType.passport:
        icon = Icons.import_contacts_outlined;
        break;
      case DocumentType.drivingLicense:
        icon = Icons.drive_eta_outlined;
        break;
      case DocumentType.nationalId:
      case DocumentType.aadhaarCard:
      case DocumentType.voterId:
        icon = Icons.badge_outlined;
        break;
      case DocumentType.bankStatement:
        icon = Icons.account_balance_wallet_outlined;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
    }

    final dateStr = DateFormat.yMMMd().format(doc.uploadedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00478D).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF00478D), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.filename,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${doc.displaySize} • $dateStr',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 8),

                // OCR Status Tag
                _buildStatusTag(doc.ocrStatus),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteDocument(doc),
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(OcrStatus status) {
    String text;
    Color color;
    switch (status) {
      case OcrStatus.pending:
        text = 'Pending OCR';
        color = const Color(0xFFF59E0B);
        break;
      case OcrStatus.processing:
        text = 'Processing...';
        color = const Color(0xFF6366F1);
        break;
      case OcrStatus.completed:
        text = 'OCR Completed';
        color = const Color(0xFF22C55E);
        break;
      case OcrStatus.failed:
        text = 'OCR Failed';
        color = const Color(0xFFEF4444);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class OcrReviewDialog extends ConsumerStatefulWidget {
  final UploadPipelineState uploadState;

  const OcrReviewDialog({
    super.key,
    required this.uploadState,
  });

  @override
  ConsumerState<OcrReviewDialog> createState() => _OcrReviewDialogState();
}

class _OcrReviewDialogState extends ConsumerState<OcrReviewDialog> {
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    for (final field in widget.uploadState.reviewFields) {
      _controllers.add(TextEditingController(text: field.value));
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatLabel(String key) {
    // Convert camelCase or snake_case to human readable Title Case
    final exp = RegExp(r'(?<=[a-z])[A-Z]|_');
    var result = key.replaceAllMapped(exp, (Match m) => ' ${m.group(0) == '_' ? '' : m.group(0)}');
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.uploadState.reviewFields;
    final doc = widget.uploadState.document!;

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Extracted Data',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'OCR matched values from "${doc.filename}". Please verify before saving.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: fields.length,
          itemBuilder: (context, index) {
            final field = fields[index];
            final controller = _controllers[index];

            // Badge color based on confidence
            final Color confidenceColor = field.confidence >= 80
                ? const Color(0xFF22C55E)
                : field.confidence >= 50
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatLabel(field.fieldKey).toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: confidenceColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${field.confidence.round()}% Match',
                          style: TextStyle(color: confidenceColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F0F1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(uploadPipelineProvider.notifier).discardOcrResults();
            Navigator.pop(context);
          },
          child: const Text('Discard', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
        ElevatedButton(
          onPressed: () async {
            final List<MappedField> editedFields = [];
            for (var i = 0; i < fields.length; i++) {
              editedFields.add(MappedField(
                section: fields[i].section,
                fieldKey: fields[i].fieldKey,
                value: _controllers[i].text.trim(),
                confidence: fields[i].confidence,
                dataType: fields[i].dataType,
                source: fields[i].source,
              ));
            }
            await ref.read(uploadPipelineProvider.notifier).confirmReviewedFields(
                  confirmedFields: editedFields,
                  profileId: doc.profileId,
                  documentId: doc.id,
                );
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00478D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save to Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
