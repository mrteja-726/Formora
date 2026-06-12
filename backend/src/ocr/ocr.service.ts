// ============================================================
// Formora — OCR Service (Phase 1.4)
// Primary: Google Vision API
// Fallback: Tesseract.js
// Extracts structured fields from ID documents, passports, resumes
// ============================================================

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../common/storage/storage.service';
import { EncryptionService } from '../common/encryption/encryption.service';
import { ImageAnnotatorClient } from '@google-cloud/vision';

// ── Field extractor regex patterns ─────────────────────────
const FIELD_PATTERNS: Record<string, RegExp[]> = {
  first_name: [
    /(?:first\s*name|given\s*name)[:\s]+([A-Za-z\-']+)/i,
    /^([A-Z][a-z]+)\s+[A-Z][a-z]+/m,
  ],
  last_name: [
    /(?:last\s*name|surname|family\s*name)[:\s]+([A-Za-z\-']+)/i,
    /^[A-Z][a-z]+\s+([A-Z][a-z]+)/m,
  ],
  date_of_birth: [
    /(?:date\s*of\s*birth|dob|born)[:\s]+(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})/i,
    /(\d{2}[-/.]\d{2}[-/.]\d{4})/,
  ],
  passport_number: [/(?:passport\s*no?\.?|document\s*no?\.?)[:\s]*([A-Z0-9]{6,12})/i],
  nationality: [/(?:nationality|citizenship)[:\s]+([A-Za-z\s]+)/i],
  expiry_date: [
    /(?:expiry|expiration|valid\s*until|expires?)[:\s]+(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})/i,
  ],
  license_number: [/(?:license\s*no?\.?|dl\s*no?\.?)[:\s]*([A-Z0-9-]{5,15})/i],
  address: [/(?:address|addr\.?)[:\s]+(.{10,80})/i],
  email: [/\b([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\b/],
  phone: [/\b(\+?[\d\s\-().]{7,20})\b/],
};

export interface OcrExtractedField {
  key: string;
  value: string;
  confidence: number;
}

export interface OcrResult {
  provider: 'google_vision' | 'tesseract';
  rawText: string;
  extractedFields: OcrExtractedField[];
  overallConfidence: number;
  error?: string;
}

@Injectable()
export class OcrService {
  private readonly logger = new Logger(OcrService.name);
  private visionClient: ImageAnnotatorClient | null = null;

  constructor(
    private config: ConfigService,
    private prisma: PrismaService,
    private storage: StorageService,
    private encryption: EncryptionService,
  ) {
    // Initialise Google Vision if credentials are available
    const credentialsJson = this.config.get<string>('GOOGLE_VISION_CREDENTIALS_JSON');
    if (credentialsJson) {
      try {
        this.visionClient = new ImageAnnotatorClient({
          credentials: JSON.parse(credentialsJson) as Record<string, unknown>,
        });
        this.logger.log('Google Vision client initialised');
      } catch {
        this.logger.warn(
          'Failed to parse GOOGLE_VISION_CREDENTIALS_JSON — falling back to Tesseract',
        );
      }
    } else {
      this.logger.warn('GOOGLE_VISION_CREDENTIALS_JSON not set — OCR will use Tesseract fallback');
    }
  }

  // ── PROCESS DOCUMENT ────────────────────────────────────

  async processDocument(documentId: string, userId: string): Promise<OcrResult> {
    const doc = await this.prisma.profileDocument.findFirst({
      where: { id: documentId, deletedAt: null },
      include: { profile: { select: { userId: true } } },
    });

    if (!doc || doc.profile.userId !== userId) {
      throw new Error('Document not found');
    }

    // Download file buffer from S3
    const fileBuffer = await this.downloadBuffer(doc.storageKey);

    let result: OcrResult;

    if (this.visionClient) {
      result = await this.runGoogleVision(fileBuffer);
    } else {
      result = await this.runTesseract(fileBuffer);
    }

    // Persist OCR result
    await this.prisma.ocrResult.create({
      data: {
        documentId,
        provider: result.provider === 'google_vision' ? 'GOOGLE_VISION' : 'TESSERACT',
        rawResponse: { rawText: result.rawText, error: result.error ?? null },
        extractedFields: result.extractedFields as unknown as Prisma.InputJsonValue,
        overallConfidence: result.overallConfidence,
      },
    });

    // Auto-populate profile fields from OCR
    await this.populateProfileFields(userId, result.extractedFields);

    this.logger.log(
      `OCR complete for doc ${documentId}: provider=${result.provider} ` +
        `fields=${result.extractedFields.length} confidence=${result.overallConfidence}%`,
    );

    return result;
  }

  // ── GOOGLE VISION ────────────────────────────────────────

  private async runGoogleVision(buffer: Buffer): Promise<OcrResult> {
    try {
      const [response] = await this.visionClient!.documentTextDetection({
        image: { content: buffer },
        imageContext: {
          languageHints: ['en'],
        },
      });

      const fullText = response.fullTextAnnotation?.text ?? '';
      const pages = response.fullTextAnnotation?.pages ?? [];

      // Compute per-block confidence
      const blockConfidences: number[] = [];
      for (const page of pages) {
        for (const block of page.blocks ?? []) {
          if (block.confidence != null) {
            blockConfidences.push(block.confidence * 100);
          }
        }
      }
      const overallConfidence =
        blockConfidences.length > 0
          ? Math.round(blockConfidences.reduce((a, b) => a + b, 0) / blockConfidences.length)
          : 70;

      const extractedFields = this.extractFields(fullText, overallConfidence);

      return {
        provider: 'google_vision',
        rawText: fullText,
        extractedFields,
        overallConfidence,
      };
    } catch (err) {
      this.logger.error(
        `Google Vision failed: ${(err as Error).message} — falling back to Tesseract`,
      );
      return this.runTesseract(buffer);
    }
  }

  // ── TESSERACT FALLBACK ────────────────────────────────────

  private async runTesseract(buffer: Buffer): Promise<OcrResult> {
    try {
      // Dynamic import to avoid loading Tesseract on startup
      const Tesseract = await import('tesseract.js');
      const worker = await Tesseract.createWorker('eng');
      const {
        data: { text, confidence },
      } = await worker.recognize(buffer);
      await worker.terminate();

      const extractedFields = this.extractFields(text, confidence);

      return {
        provider: 'tesseract',
        rawText: text,
        extractedFields,
        overallConfidence: Math.round(confidence),
      };
    } catch (err) {
      this.logger.error(`Tesseract failed: ${(err as Error).message}`);
      return {
        provider: 'tesseract',
        rawText: '',
        extractedFields: [],
        overallConfidence: 0,
        error: (err as Error).message,
      };
    }
  }

  // ── FIELD EXTRACTION ──────────────────────────────────────

  private extractFields(text: string, baseConfidence: number): OcrExtractedField[] {
    const fields: OcrExtractedField[] = [];

    for (const [key, patterns] of Object.entries(FIELD_PATTERNS)) {
      for (const pattern of patterns) {
        const match = text.match(pattern);
        if (match?.[1]) {
          const value = match[1].trim();
          if (value.length >= 2) {
            // Slightly lower confidence than the doc-level for extracted fields
            const confidence = Math.min(baseConfidence, Math.round(baseConfidence * 0.95));
            fields.push({ key, value, confidence });
            break; // First matching pattern wins
          }
        }
      }
    }

    return fields;
  }

  // ── AUTO POPULATE PROFILE ─────────────────────────────────

  private async populateProfileFields(userId: string, fields: OcrExtractedField[]) {
    if (fields.length === 0) return;

    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) return;

    const PERSONAL_KEYS = new Set([
      'first_name',
      'last_name',
      'date_of_birth',
      'nationality',
      'passport_number',
      'license_number',
      'email',
      'phone',
    ]);

    for (const field of fields) {
      if (!PERSONAL_KEYS.has(field.key) || field.confidence < 60) continue;

      const valueEnc = this.encryption.encrypt(field.value);

      await this.prisma.profileField.upsert({
        where: {
          profileId_section_fieldKey: {
            profileId: profile.id,
            section: 'PERSONAL',
            fieldKey: field.key,
          },
        },
        create: {
          profileId: profile.id,
          section: 'PERSONAL',
          fieldKey: field.key,
          valueEnc,
          dataType: 'string',
          visibility: 'PRIVATE',
          source: 'OCR',
          confidence: field.confidence,
        },
        update: {
          source: 'OCR',
          confidence: field.confidence,
        },
      });
    }
  }

  // ── DOWNLOAD BUFFER FROM S3 ────────────────────────────────

  private async downloadBuffer(storageKey: string): Promise<Buffer> {
    const { GetObjectCommand, S3Client } = await import('@aws-sdk/client-s3');
    const s3 = new S3Client({
      region: this.config.get('AWS_REGION', 'us-east-1'),
      credentials: {
        accessKeyId: this.config.getOrThrow('AWS_ACCESS_KEY_ID'),
        secretAccessKey: this.config.getOrThrow('AWS_SECRET_ACCESS_KEY'),
      },
    });

    const command = new GetObjectCommand({
      Bucket: this.config.getOrThrow('S3_BUCKET'),
      Key: storageKey,
    });

    const response = await s3.send(command);
    const stream = response.Body as NodeJS.ReadableStream;

    return new Promise((resolve, reject) => {
      const chunks: Buffer[] = [];
      stream.on('data', (chunk: Buffer) => chunks.push(chunk));
      stream.on('end', () => resolve(Buffer.concat(chunks)));
      stream.on('error', reject);
    });
  }

  // ── GET OCR RESULTS ────────────────────────────────────────

  async getResults(documentId: string) {
    const results = await this.prisma.ocrResult.findMany({
      where: { documentId },
      orderBy: { processedAt: 'desc' },
      select: {
        id: true,
        provider: true,
        extractedFields: true,
        overallConfidence: true,
        processedAt: true,
      },
    });

    return results;
  }
}
