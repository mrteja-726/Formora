// ============================================================
// OCR Queue Processor (BullMQ)
// Processes document OCR jobs asynchronously
// ============================================================

import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Logger } from '@nestjs/common';
import { OcrService } from './ocr.service';

export const OCR_QUEUE = 'ocr';

export interface OcrJobData {
  documentId: string;
  userId: string;
}

@Processor(OCR_QUEUE)
export class OcrProcessor extends WorkerHost {
  private readonly logger = new Logger(OcrProcessor.name);

  constructor(private ocrService: OcrService) {
    super();
  }

  async process(job: Job<OcrJobData>) {
    const { documentId, userId } = job.data;
    this.logger.log(`Processing OCR job ${job.id} for document ${documentId}`);

    try {
      const result = await this.ocrService.processDocument(documentId, userId);
      this.logger.log(
        `OCR job ${job.id} complete — confidence: ${result.overallConfidence}% fields: ${result.extractedFields.length}`,
      );
      return result;
    } catch (err) {
      this.logger.error(`OCR job ${job.id} failed: ${(err as Error).message}`);
      throw err;
    }
  }
}
