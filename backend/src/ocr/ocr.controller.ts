// ============================================================
// OCR Controller — /api/v1/ocr/*
// ============================================================

import {
  Controller,
  Post,
  Get,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

import { OcrService } from './ocr.service';
import { OCR_QUEUE, OcrJobData } from './ocr.processor';
import { JwtAuthGuard } from '../auth/guards/auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@ApiTags('OCR')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller({ path: 'ocr', version: '1' })
export class OcrController {
  constructor(
    private ocrService: OcrService,
    @InjectQueue(OCR_QUEUE) private ocrQueue: Queue<OcrJobData>,
  ) {}

  // ── TRIGGER OCR (async, queued) ────────────────────────

  @Post('documents/:documentId/process')
  @HttpCode(HttpStatus.ACCEPTED)
  @ApiOperation({ summary: 'Queue a document for OCR processing (async)' })
  @ApiParam({ name: 'documentId', description: 'UUID of the uploaded document' })
  async triggerOcr(
    @CurrentUser() user: { id: string },
    @Param('documentId') documentId: string,
  ) {
    const job = await this.ocrQueue.add(
      'process-document',
      { documentId, userId: user.id },
      {
        attempts: 3,
        backoff: { type: 'exponential', delay: 5000 },
        removeOnComplete: 100,
        removeOnFail: 50,
      },
    );

    return {
      success: true,
      data: {
        jobId: job.id,
        documentId,
        status: 'queued',
        message: 'OCR processing started. Poll /ocr/documents/:id/results for status.',
      },
    };
  }

  // ── GET OCR RESULTS ────────────────────────────────────

  @Get('documents/:documentId/results')
  @ApiOperation({ summary: 'Get OCR results for a document' })
  @ApiParam({ name: 'documentId', description: 'UUID of the document' })
  async getResults(
    @CurrentUser() _user: { id: string },
    @Param('documentId') documentId: string,
  ) {
    return {
      success: true,
      data: await this.ocrService.getResults(documentId),
    };
  }

  // ── SYNC OCR (for testing/small docs) ─────────────────

  @Post('documents/:documentId/process/sync')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Run OCR synchronously (development / small documents)' })
  @ApiParam({ name: 'documentId' })
  async processSynchronously(
    @CurrentUser() user: { id: string },
    @Param('documentId') documentId: string,
  ) {
    const result = await this.ocrService.processDocument(documentId, user.id);
    return { success: true, data: result };
  }
}
