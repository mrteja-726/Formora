import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:formora/features/vault/presentation/vault_controller.dart';
import 'package:formora/features/vault/domain/user_document.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vaultProvider.notifier).fetchDocuments();
    });
  }

  Future<void> _pickAndUpload() async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Document Type', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
        children: [
          _typeOption(context, 'PASSPORT', 'Passport'),
          _typeOption(context, 'DRIVERS_LICENSE', "Driver's License"),
          _typeOption(context, 'NATIONAL_ID', 'National ID'),
          _typeOption(context, 'RESUME', 'Resume'),
          _typeOption(context, 'CERTIFICATE', 'Certificate'),
          _typeOption(context, 'OTHER', 'Other'),
        ],
      ),
    );

    if (type == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'tiff', 'webp', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = result.files.single.name;
      final success = await ref.read(vaultProvider.notifier).uploadDocument(
            filePath: path,
            filename: name,
            documentType: type,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully! Starting OCR mapping...'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    }
  }

  Widget _typeOption(BuildContext context, String value, String label) {
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

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text('Document Vault', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => ref.read(vaultProvider.notifier).fetchDocuments(),
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: vaultState.isLoading && vaultState.documents.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Action Header ──
                  ElevatedButton.icon(
                    onPressed: vaultState.isUploading ? null : _pickAndUpload,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: vaultState.isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      vaultState.isUploading ? 'Uploading & Processing…' : 'Upload Document',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Display
                  if (vaultState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: Text(
                        vaultState.errorMessage!,
                        style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Documents List ──
                  Expanded(
                    child: vaultState.documents.isEmpty
                        ? Center(
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
                          )
                        : ListView.builder(
                            itemCount: vaultState.documents.length,
                            itemBuilder: (context, index) {
                              final doc = vaultState.documents[index];
                              return _documentCard(doc);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _documentCard(UserDocument doc) {
    IconData icon;
    switch (doc.documentType) {
      case 'PASSPORT':
        icon = Icons.import_contacts_outlined;
        break;
      case 'DRIVERS_LICENSE':
        icon = Icons.drive_eta_outlined;
        break;
      case 'NATIONAL_ID':
        icon = Icons.badge_outlined;
        break;
      case 'RESUME':
        icon = Icons.description_outlined;
        break;
      case 'CERTIFICATE':
        icon = Icons.workspace_premium_outlined;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
    }

    final dateStr = DateFormat.yMMMd().format(doc.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Doc Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF6366F1), size: 24),
          ),
          const SizedBox(width: 16),

          // Details
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
                  '${_formatBytes(doc.sizeBytes)} • $dateStr',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 8),

                // OCR Confidence Tag
                if (doc.ocrConfidence != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'OCR Match: ${doc.ocrConfidence}%',
                      style: const TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (doc.virusScanned == true && doc.virusClean == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Processing OCR…',
                      style: TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Scanning file…',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),

          // Actions
          IconButton(
            onPressed: () => _confirmDelete(doc.id, doc.filename),
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String id, String filename) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "$filename"?', style: const TextStyle(color: Colors.white70)),
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
      await ref.read(vaultProvider.notifier).deleteDocument(id);
    }
  }
}
