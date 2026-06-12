// test/features/ocr/ocr_field_mapper_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:formora/features/ocr/data/ocr_service.dart';
import 'package:formora/features/ocr/domain/ocr_field_mapper.dart';

void main() {
  const mapper = OcrFieldMapper();

  OcrRawResult makeResult(String text, {double confidence = 85.0}) {
    return OcrRawResult(
      fullText: text,
      lines: [],
      overallConfidence: confidence,
      blockCount: 5,
    );
  }

  group('OcrFieldMapper — Passport', () {
    test('extracts passport number', () {
      final result = makeResult('Passport No: A1234567\nSurname: SHARMA');
      final mapped = mapper.mapToProfileFields(result, 'passport');
      final field = mapped.firstWhere(
          (f) => f.fieldKey == 'passportNumber',
          orElse: () => throw Exception('not found'));
      expect(field.value, 'A1234567');
    });

    test('extracts surname', () {
      final result = makeResult('Surname: SHARMA\nGiven Names: RAHUL');
      final mapped = mapper.mapToProfileFields(result, 'passport');
      final lastName = mapped.firstWhere(
          (f) => f.fieldKey == 'lastName',
          orElse: () => throw Exception('not found'));
      expect(lastName.value.trim(), 'SHARMA');
    });

    test('extracts date of birth', () {
      final result =
          makeResult('Date of Birth: 15/08/1990\nNationality: INDIAN');
      final mapped = mapper.mapToProfileFields(result, 'passport');
      final dob = mapped.firstWhere(
          (f) => f.fieldKey == 'dateOfBirth',
          orElse: () => throw Exception('not found'));
      expect(dob.value, contains('15'));
    });
  });

  group('OcrFieldMapper — PAN Card', () {
    test('extracts PAN number', () {
      final result = makeResult('ABCDE1234F\nIncome Tax Department');
      final mapped = mapper.mapToProfileFields(result, 'pan_card');
      final pan = mapped.firstWhere(
          (f) => f.fieldKey == 'taxId',
          orElse: () => throw Exception('not found'));
      expect(pan.value, 'ABCDE1234F');
    });
  });

  group('OcrFieldMapper — Aadhaar', () {
    test('extracts Aadhaar number', () {
      final result = makeResult('1234 5678 9012\nMale\nDOB: 01/01/1990');
      final mapped = mapper.mapToProfileFields(result, 'aadhaar_card');
      final id = mapped.firstWhere(
          (f) => f.fieldKey == 'nationalIdNumber',
          orElse: () => throw Exception('not found'));
      expect(id.value, '123456789012'); // spaces removed
    });

    test('extracts gender from Aadhaar', () {
      final result = makeResult('RAHUL SHARMA\nMale\n1234 5678 9012');
      final mapped = mapper.mapToProfileFields(result, 'aadhaar_card');
      final gender = mapped.firstWhere(
          (f) => f.fieldKey == 'gender',
          orElse: () => throw Exception('not found'));
      expect(gender.value.toLowerCase(), 'male');
    });
  });

  group('OcrFieldMapper — Bank Statement', () {
    test('extracts IFSC code', () {
      final result = makeResult('HDFC Bank\nIFSC: HDFC0001234\nAccount: 12345678901');
      final mapped = mapper.mapToProfileFields(result, 'bank_statement');
      final ifsc = mapped.firstWhere(
          (f) => f.fieldKey == 'ifscCode',
          orElse: () => throw Exception('not found'));
      expect(ifsc.value, 'HDFC0001234');
    });

    test('extracts account number', () {
      final result = makeResult('Account No.: 12345678901\nBranch: Mumbai');
      final mapped = mapper.mapToProfileFields(result, 'bank_statement');
      final acc = mapped.firstWhere(
          (f) => f.fieldKey == 'accountNumber',
          orElse: () => throw Exception('not found'));
      expect(acc.value, '12345678901');
    });
  });

  group('OcrFieldMapper — Confidence tiers', () {
    test('high confidence (≥80%) maps to high tier', () {
      final result = makeResult('A1234567', confidence: 90.0);
      final mapped = mapper.mapToProfileFields(result, 'passport');
      for (final f in mapped) {
        if (f.confidence >= 80) {
          expect(f.tier, OcrConfidenceTier.high);
        }
      }
    });

    test('low confidence (<50%) maps to low tier', () {
      final result = makeResult('A1234567', confidence: 30.0);
      final mapped = mapper.mapToProfileFields(result, 'passport');
      for (final f in mapped) {
        if (f.confidence < 50) {
          expect(f.tier, OcrConfidenceTier.low);
        }
      }
    });
  });
}
