// lib/features/ocr/domain/ocr_field_mapper.dart
//
// Maps raw OCR text → profile schema fields.
// Uses regex patterns tuned for common ID documents (Indian + international).
// Returns a list of MappedField objects with per-field confidence scores.

import 'package:formora/features/profile/domain/profile_field_schema.dart';
import 'package:formora/features/ocr/data/ocr_service.dart';

class OcrFieldMapper {
  const OcrFieldMapper();

  /// Maps raw OCR result to profile fields.
  List<MappedField> mapToProfileFields(OcrRawResult ocr, String documentTypeKey) {
    final text = ocr.fullText;
    final patterns = _getPatternsForDocumentType(documentTypeKey);
    final results = <MappedField>[];

    for (final pattern in patterns) {
      final match = pattern.regex.firstMatch(text);
      if (match != null) {
        final rawValue = (match.groupCount >= 1 ? match.group(1) : match.group(0)) ?? '';
        final cleaned = _cleanValue(rawValue, pattern.dataType);
        if (cleaned.isNotEmpty) {
          // Field confidence = OCR overall × pattern match confidence
          final fieldConf =
              (ocr.overallConfidence * pattern.patternConfidenceWeight)
                  .clamp(0.0, 100.0);
          results.add(MappedField(
            section: pattern.section,
            fieldKey: pattern.fieldKey,
            value: cleaned,
            confidence: fieldConf,
            dataType: pattern.dataType,
            source: 'ocr',
          ));
        }
      }
    }

    return results;
  }

  // ── Pattern Registry ───────────────────────────────────────────────────────

  List<_FieldPattern> _getPatternsForDocumentType(String docType) {
    switch (docType) {
      case 'passport':
        return _passportPatterns;
      case 'aadhaar_card':
      case 'national_id':
        return _aadhaarPatterns;
      case 'pan_card':
        return _panPatterns;
      case 'driving_license':
        return _drivingLicensePatterns;
      case 'bank_statement':
        return _bankStatementPatterns;
      default:
        return _genericPatterns;
    }
  }

  static final List<_FieldPattern> _passportPatterns = [
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'firstName',
      regex: RegExp(r'(?:Given\s+Names?|First\s+Name)[:\s]+([A-Z][A-Z\s]+)', caseSensitive: false),
      dataType: 'string',
      patternConfidenceWeight: 0.9,
    ),
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'lastName',
      regex: RegExp(r'(?:Surname|Last\s+Name)[:\s]+([A-Z][A-Z\s]+)', caseSensitive: false),
      dataType: 'string',
      patternConfidenceWeight: 0.9,
    ),
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'dateOfBirth',
      regex: RegExp(r'(?:Date\s+of\s+Birth|D\.O\.B|DOB)[:\s]+(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})'),
      dataType: 'date',
      patternConfidenceWeight: 0.85,
    ),
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'nationality',
      regex: RegExp(r'Nationality[:\s]+([A-Z][A-Za-z]+)'),
      dataType: 'string',
      patternConfidenceWeight: 0.9,
    ),
    _FieldPattern(
      section: 'identity_documents',
      fieldKey: 'passportNumber',
      regex: RegExp(r'\b([A-Z]\d{7})\b'),
      dataType: 'id',
      patternConfidenceWeight: 0.95,
    ),
    _FieldPattern(
      section: 'identity_documents',
      fieldKey: 'passportExpiry',
      regex: RegExp(r'(?:Date\s+of\s+Expiry|Expiry)[:\s]+(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})'),
      dataType: 'date',
      patternConfidenceWeight: 0.85,
    ),
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'gender',
      regex: RegExp(r'\b(MALE|FEMALE|M|F)\b'),
      dataType: 'string',
      patternConfidenceWeight: 0.8,
    ),
  ];

  static final List<_FieldPattern> _aadhaarPatterns = [
    _FieldPattern(
      section: 'identity_documents',
      fieldKey: 'nationalIdNumber',
      regex: RegExp(r'\b(\d{4}\s\d{4}\s\d{4})\b'),
      dataType: 'id',
      patternConfidenceWeight: 0.95,
    ),
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'firstName',
      regex: RegExp(r'^([A-Z][a-z]+)\s+[A-Z]', multiLine: true),
      dataType: 'string',
      patternConfidenceWeight: 0.75,
    ),
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'dateOfBirth',
      regex: RegExp(r'(?:DOB|Date\s+of\s+Birth)[:\s]+(\d{2}/\d{2}/\d{4})'),
      dataType: 'date',
      patternConfidenceWeight: 0.85,
    ),
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'gender',
      regex: RegExp(r'\b(Male|Female)\b', caseSensitive: false),
      dataType: 'string',
      patternConfidenceWeight: 0.9,
    ),
  ];

  static final List<_FieldPattern> _panPatterns = [
    _FieldPattern(
      section: 'identity_documents',
      fieldKey: 'taxId',
      regex: RegExp(r'\b([A-Z]{5}[0-9]{4}[A-Z])\b'),
      dataType: 'id',
      patternConfidenceWeight: 0.98,
    ),
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'firstName',
      regex: RegExp(r'^([A-Z][A-Z\s]+)$', multiLine: true),
      dataType: 'string',
      patternConfidenceWeight: 0.7,
    ),
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'dateOfBirth',
      regex: RegExp(r'\b(\d{2}/\d{2}/\d{4})\b'),
      dataType: 'date',
      patternConfidenceWeight: 0.85,
    ),
  ];

  static final List<_FieldPattern> _drivingLicensePatterns = [
    _FieldPattern(
      section: 'identity_documents',
      fieldKey: 'drivingLicenseNumber',
      regex: RegExp(r'\b([A-Z]{2}\d{2}\s?\d{11})\b'),
      dataType: 'id',
      patternConfidenceWeight: 0.9,
    ),
    _FieldPattern(
      section: 'identity_documents',
      fieldKey: 'drivingLicenseExpiry',
      regex: RegExp(r'(?:Valid\s+Till|Expiry|Exp\.)[:\s]+(\d{2}/\d{2}/\d{4})'),
      dataType: 'date',
      patternConfidenceWeight: 0.85,
    ),
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'dateOfBirth',
      regex: RegExp(r'(?:DOB|Date\s+of\s+Birth)[:\s]+(\d{2}/\d{2}/\d{4})'),
      dataType: 'date',
      patternConfidenceWeight: 0.85,
    ),
  ];

  static final List<_FieldPattern> _bankStatementPatterns = [
    _FieldPattern(
      section: 'banking',
      fieldKey: 'bankName',
      regex: RegExp(r'^([A-Z][A-Za-z\s]+(?:Bank|Financial|Credit))', multiLine: true),
      dataType: 'string',
      patternConfidenceWeight: 0.8,
    ),
    _FieldPattern(
      section: 'banking',
      fieldKey: 'accountNumber',
      regex: RegExp(r'(?:Account\s+No\.?|A/C\s+No\.?)[:\s]+(\d{9,18})'),
      dataType: 'id',
      patternConfidenceWeight: 0.9,
    ),
    _FieldPattern(
      section: 'banking',
      fieldKey: 'ifscCode',
      regex: RegExp(r'\b([A-Z]{4}0[A-Z0-9]{6})\b'),
      dataType: 'string',
      patternConfidenceWeight: 0.95,
    ),
  ];

  static final List<_FieldPattern> _genericPatterns = [
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'firstName',
      regex: RegExp(r'(?:Name|Full\s+Name)[:\s]+([A-Z][a-z]+)\s', caseSensitive: false),
      dataType: 'string',
      patternConfidenceWeight: 0.7,
    ),
    _FieldPattern(
      section: 'personal_info',
      fieldKey: 'dateOfBirth',
      regex: RegExp(r'(?:DOB|Date\s+of\s+Birth)[:\s]+(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})', caseSensitive: false),
      dataType: 'date',
      patternConfidenceWeight: 0.75,
    ),
  ];

  // ── Value Cleaning ─────────────────────────────────────────────────────────

  String _cleanValue(String raw, String dataType) {
    var cleaned = raw.trim();
    switch (dataType) {
      case 'date':
        // Normalize date separators
        cleaned = cleaned.replaceAll(RegExp(r'[-.]'), '/');
        break;
      case 'id':
        // Remove spaces from ID numbers
        cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
        break;
      case 'number':
        cleaned = cleaned.replaceAll(RegExp(r'[^\d.]'), '');
        break;
    }
    return cleaned;
  }
}

// ── Data Classes ─────────────────────────────────────────────────────────────

class MappedField {
  final String section;
  final String fieldKey;
  final String value;
  final double confidence; // 0–100
  final String dataType;
  final String source;

  const MappedField({
    required this.section,
    required this.fieldKey,
    required this.value,
    required this.confidence,
    required this.dataType,
    this.source = 'ocr',
  });

  OcrConfidenceTier get tier {
    if (confidence >= 80) return OcrConfidenceTier.high;
    if (confidence >= 50) return OcrConfidenceTier.medium;
    return OcrConfidenceTier.low;
  }
}

class _FieldPattern {
  final String section;
  final String fieldKey;
  final RegExp regex;
  final String dataType;
  final double patternConfidenceWeight; // 0.0–1.0

  const _FieldPattern({
    required this.section,
    required this.fieldKey,
    required this.regex,
    required this.dataType,
    this.patternConfidenceWeight = 0.8,
  });
}
