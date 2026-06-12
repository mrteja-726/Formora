// lib/features/ocr/data/ocr_service.dart
//
// On-device OCR using Google ML Kit Text Recognition.
// Runs in a background isolate via Flutter's compute() to keep UI at 60 FPS.
//
// Pipeline:
//   1. Receive a decrypted temp file path
//   2. Run ML Kit text recognition (isolate)
//   3. Return raw text + per-block confidence scores
//   4. Caller passes to OcrFieldMapper

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

final ocrServiceProvider = Provider<OcrService>((ref) => OcrService());

class OcrService {
  /// Runs ML Kit OCR on a decrypted temp file.
  /// Returns [OcrRawResult] with the extracted text and confidence.
  ///
  /// Uses compute() to run on a background isolate.
  Future<OcrRawResult> recognizeText(File imageFile) async {
    final path = imageFile.path;
    return compute(_runOcr, path);
  }

  /// Entry point for the background isolate.
  static Future<OcrRawResult> _runOcr(String filePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFilePath(filePath);

    try {
      final recognized = await recognizer.processImage(inputImage);

      // Compute average confidence across all text blocks
      final blocks = recognized.blocks;
      double totalConf = 0.0;
      int blockCount = 0;

      final lines = <OcrLine>[];

      for (final block in blocks) {
        for (final line in block.lines) {
          final lineConf = line.confidence ?? 0.8; // ML Kit may not expose confidence directly
          lines.add(OcrLine(
            text: line.text,
            confidence: lineConf * 100,
            boundingBox: OcrRect(
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              right: line.boundingBox.right,
              bottom: line.boundingBox.bottom,
            ),
          ));
          totalConf += lineConf;
          blockCount++;
        }
      }

      final avgConfidence =
          blockCount > 0 ? (totalConf / blockCount) * 100 : 0.0;

      return OcrRawResult(
        fullText: recognized.text,
        lines: lines,
        overallConfidence: avgConfidence,
        blockCount: blockCount,
      );
    } finally {
      await recognizer.close();
    }
  }
}

// ── Value Objects ─────────────────────────────────────────────────────────

class OcrRawResult {
  final String fullText;
  final List<OcrLine> lines;
  final double overallConfidence; // 0–100
  final int blockCount;

  const OcrRawResult({
    required this.fullText,
    required this.lines,
    required this.overallConfidence,
    required this.blockCount,
  });

  OcrConfidenceTier get confidenceTier {
    if (overallConfidence >= 80) return OcrConfidenceTier.high;
    if (overallConfidence >= 50) return OcrConfidenceTier.medium;
    return OcrConfidenceTier.low;
  }

  bool get hasText => fullText.trim().isNotEmpty;
}

class OcrLine {
  final String text;
  final double confidence; // 0–100
  final OcrRect boundingBox;

  const OcrLine({
    required this.text,
    required this.confidence,
    required this.boundingBox,
  });
}

class OcrRect {
  final double left, top, right, bottom;
  const OcrRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
}

enum OcrConfidenceTier {
  high,   // ≥80% → auto-fill
  medium, // 50–79% → review required
  low,    // <50% → manual confirmation
}
