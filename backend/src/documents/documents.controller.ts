// ============================================================
// Formora — Documents Controller
// Routes: /api/v1/documents/*
// ============================================================

import {
  Controller,
  Post,
  Get,
  Delete,
  Param,
  Query,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  ParseIntPipe,
  DefaultValuePipe,
  HttpCode,
  HttpStatus,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiConsumes,
  ApiBody,
  ApiQuery,
} from '@nestjs/swagger';
import { memoryStorage } from 'multer';

import { DocumentsService, DocumentType } from './documents.service';
import { JwtAuthGuard } from '../auth/guards/auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

const DOCUMENT_TYPES: DocumentType[] = [
  'PASSPORT',
  'DRIVERS_LICENSE',
  'NATIONAL_ID',
  'RESUME',
  'CERTIFICATE',
  'OTHER',
];

@ApiTags('Documents')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller({ path: 'documents', version: '1' })
export class DocumentsController {
  constructor(private documentsService: DocumentsService) {}

  // ── UPLOAD ────────────────────────────────────────────────

  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: 25 * 1024 * 1024 }, // 25 MB guard at multer level
    }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
        documentType: {
          type: 'string',
          enum: DOCUMENT_TYPES,
          description: 'Type of document',
        },
      },
      required: ['file'],
    },
  })
  @ApiOperation({ summary: 'Upload a document (PDF, JPEG, PNG, TIFF, WEBP, DOCX — max 25 MB)' })
  async upload(
    @CurrentUser() user: { id: string },
    @UploadedFile() file: Express.Multer.File,
    @Query('documentType') documentType?: string,
  ) {
    if (!file) throw new BadRequestException('No file provided');

    const docType = DOCUMENT_TYPES.includes(documentType as DocumentType)
      ? (documentType as DocumentType)
      : 'OTHER';

    return {
      success: true,
      data: await this.documentsService.upload(user.id, file, docType),
    };
  }

  // ── LIST ──────────────────────────────────────────────────

  @Get()
  @ApiOperation({ summary: 'List all uploaded documents (paginated)' })
  @ApiQuery({ name: 'page',  required: false, example: 1 })
  @ApiQuery({ name: 'limit', required: false, example: 20 })
  async list(
    @CurrentUser() user: { id: string },
    @Query('page',  new DefaultValuePipe(1),  ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    return {
      success: true,
      data: await this.documentsService.list(user.id, page, Math.min(limit, 100)),
    };
  }

  // ── GET ONE ───────────────────────────────────────────────

  @Get(':id')
  @ApiOperation({ summary: 'Get document details and OCR results' })
  async findOne(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
  ) {
    return {
      success: true,
      data: await this.documentsService.findOne(user.id, id),
    };
  }

  // ── DOWNLOAD URL ──────────────────────────────────────────

  @Get(':id/download')
  @ApiOperation({ summary: 'Get a 15-minute pre-signed download URL' })
  async getDownloadUrl(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
  ) {
    return {
      success: true,
      data: await this.documentsService.getDownloadUrl(user.id, id),
    };
  }

  // ── DELETE ────────────────────────────────────────────────

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Soft-delete a document and reclaim storage quota' })
  async delete(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
  ) {
    return {
      success: true,
      data: await this.documentsService.softDelete(user.id, id),
    };
  }
}
