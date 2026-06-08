class UserDocument {
  final String id;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final String documentType;
  final bool? virusScanned;
  final bool? virusClean;
  final int? ocrConfidence;
  final Map<String, dynamic>? ocrFields;
  final DateTime createdAt;

  UserDocument({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    required this.documentType,
    this.virusScanned,
    this.virusClean,
    this.ocrConfidence,
    this.ocrFields,
    required this.createdAt,
  });

  factory UserDocument.fromJson(Map<String, dynamic> json) {
    int? ocrConf;
    Map<String, dynamic>? ocrFlds;
    if (json['ocrResults'] is List && (json['ocrResults'] as List).isNotEmpty) {
      final ocr = (json['ocrResults'] as List).first;
      ocrConf = ocr['overallConfidence'] as int?;
      ocrFlds = ocr['extractedFields'] as Map<String, dynamic>?;
    }

    return UserDocument(
      id: json['id'] as String,
      filename: json['filename'] as String,
      contentType: json['contentType'] as String,
      sizeBytes: json['sizeBytes'] is String
          ? int.tryParse(json['sizeBytes'] as String) ?? 0
          : (json['sizeBytes'] as num?)?.toInt() ?? 0,
      documentType: json['documentType'] as String? ?? 'OTHER',
      virusScanned: json['virusScanned'] as bool?,
      virusClean: json['virusClean'] as bool?,
      ocrConfidence: ocrConf,
      ocrFields: ocrFlds,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
