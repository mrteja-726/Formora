// lib/features/documents/domain/document_entities.dart

enum DocumentType {
  passport('passport', 'Passport', '🛂'),
  nationalId('national_id', 'National ID', '🪪'),
  drivingLicense('driving_license', 'Driving Licence', '🚗'),
  bankStatement('bank_statement', 'Bank Statement', '🏦'),
  utilityBill('utility_bill', 'Utility Bill', '💡'),
  taxReturn('tax_return', 'Tax Return', '🧾'),
  degreeCertificate('degree_certificate', 'Degree Certificate', '🎓'),
  employmentLetter('employment_letter', 'Employment Letter', '💼'),
  panCard('pan_card', 'PAN Card', '💳'),
  aadhaarCard('aadhaar_card', 'Aadhaar Card', '🪪'),
  voterId('voter_id', 'Voter ID', '🗳️'),
  birthCertificate('birth_certificate', 'Birth Certificate', '👶'),
  marriageCertificate('marriage_certificate', 'Marriage Certificate', '💍'),
  other('other', 'Other', '📄');

  final String dbKey;
  final String label;
  final String emoji;

  const DocumentType(this.dbKey, this.label, this.emoji);

  static DocumentType fromDbKey(String key) {
    return DocumentType.values.firstWhere(
      (t) => t.dbKey == key,
      orElse: () => DocumentType.other,
    );
  }
}

enum OcrStatus {
  pending('pending'),
  processing('processing'),
  completed('completed'),
  failed('failed');

  final String dbKey;
  const OcrStatus(this.dbKey);

  static OcrStatus fromDbKey(String key) {
    return OcrStatus.values.firstWhere(
      (s) => s.dbKey == key,
      orElse: () => OcrStatus.pending,
    );
  }
}

class Document {
  final String id;
  final String profileId;
  final String filename;
  final DocumentType documentType;
  final String contentType;
  final int sizeBytes;
  final String encryptedFilePath;
  final String? thumbnailPath;
  final OcrStatus ocrStatus;
  final String checksum;
  final DateTime uploadedAt;
  final DateTime updatedAt;

  const Document({
    required this.id,
    required this.profileId,
    required this.filename,
    required this.documentType,
    required this.contentType,
    required this.sizeBytes,
    required this.encryptedFilePath,
    this.thumbnailPath,
    this.ocrStatus = OcrStatus.pending,
    required this.checksum,
    required this.uploadedAt,
    required this.updatedAt,
  });

  bool get isImage =>
      contentType.startsWith('image/');

  bool get isPdf => contentType == 'application/pdf';

  String get displaySize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Document copyWith({OcrStatus? ocrStatus, String? thumbnailPath}) {
    return Document(
      id: id,
      profileId: profileId,
      filename: filename,
      documentType: documentType,
      contentType: contentType,
      sizeBytes: sizeBytes,
      encryptedFilePath: encryptedFilePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      ocrStatus: ocrStatus ?? this.ocrStatus,
      checksum: checksum,
      uploadedAt: uploadedAt,
      updatedAt: DateTime.now(),
    );
  }
}
