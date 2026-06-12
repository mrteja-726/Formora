// ============================================================
// Formora — Documents Service
// Upload, virus check, thumbnail generation, CRUD, presigned URLs
// ============================================================

import {
  Injectable,
  Logger,
  BadRequestException,
  NotFoundException,
  PayloadTooLargeException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../common/storage/storage.service';
import sharp from 'sharp';

// ── Constants ─────────────────────────────────────────────
const MAX_FILE_SIZE_BYTES = 25 * 1024 * 1024; // 25 MB
const ALLOWED_MIME_TYPES = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/tiff',
  'image/webp',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
]);

const IMAGE_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/tiff']);

export type DocumentType =
  | 'PASSPORT'
  | 'DRIVERS_LICENSE'
  | 'NATIONAL_ID'
  | 'RESUME'
  | 'CERTIFICATE'
  | 'OTHER';

@Injectable()
export class DocumentsService {
  private readonly logger = new Logger(DocumentsService.name);

  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
  ) {}

  // ── UPLOAD ────────────────────────────────────────────────

  async upload(userId: string, file: Express.Multer.File, documentType?: DocumentType) {
    // ── Validate ────────────────────────────────────────────
    if (file.size > MAX_FILE_SIZE_BYTES) {
      throw new PayloadTooLargeException('File exceeds 25 MB limit');
    }

    if (!ALLOWED_MIME_TYPES.has(file.mimetype)) {
      throw new BadRequestException(
        `Unsupported file type: ${file.mimetype}. Allowed: PDF, JPEG, PNG, TIFF, WEBP, DOCX`,
      );
    }

    // ── Check user storage quota ──────────────────────────
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { storageUsedBytes: true, storageLimitBytes: true },
    });

    if (BigInt(user.storageUsedBytes) + BigInt(file.size) > BigInt(user.storageLimitBytes)) {
      throw new BadRequestException('Storage quota exceeded');
    }

    // ── Get/create profile ────────────────────────────────
    const profile = await this.prisma.profile.findUniqueOrThrow({ where: { userId } });

    // ── Upload to S3 ──────────────────────────────────────
    const storageKey = await this.storage.upload(
      file.buffer,
      file.originalname,
      file.mimetype,
      `documents/${userId}`,
    );

    // ── Generate thumbnail for images ─────────────────────
    let thumbnailKey: string | undefined;
    if (IMAGE_MIME_TYPES.has(file.mimetype)) {
      try {
        const thumbBuffer = await sharp(file.buffer)
          .resize(400, 400, { fit: 'inside', withoutEnlargement: true })
          .jpeg({ quality: 80 })
          .toBuffer();
        thumbnailKey = await this.storage.upload(
          thumbBuffer,
          `thumb_${file.originalname}`,
          'image/jpeg',
          `thumbnails/${userId}`,
        );
      } catch (err) {
        this.logger.warn(`Thumbnail generation failed: ${(err as Error).message}`);
      }
    }

    // ── Persist to DB ─────────────────────────────────────
    const doc = await this.prisma.$transaction(async (tx) => {
      const document = await tx.profileDocument.create({
        data: {
          profileId: profile.id,
          filename: file.originalname,
          contentType: file.mimetype,
          sizeBytes: BigInt(file.size),
          storageKey,
          thumbnailKey,
          documentType: documentType ?? 'OTHER',
          virusScanned: false,
        },
      });

      // Update storage usage
      await tx.user.update({
        where: { id: userId },
        data: { storageUsedBytes: { increment: BigInt(file.size) } },
      });

      return document;
    });

    this.logger.log(`Document uploaded: ${doc.id} for user ${userId}`);

    return {
      documentId: doc.id,
      filename: doc.filename,
      contentType: doc.contentType,
      sizeBytes: doc.sizeBytes.toString(),
      documentType: doc.documentType,
      status: 'uploaded',
      hasThumbnail: !!thumbnailKey,
    };
  }

  // ── LIST ──────────────────────────────────────────────────

  async list(userId: string, page = 1, limit = 20) {
    const profile = await this.getProfileOrThrow(userId);

    const [total, documents] = await this.prisma.$transaction([
      this.prisma.profileDocument.count({
        where: { profileId: profile.id, deletedAt: null },
      }),
      this.prisma.profileDocument.findMany({
        where: { profileId: profile.id, deletedAt: null },
        select: {
          id: true,
          filename: true,
          contentType: true,
          sizeBytes: true,
          documentType: true,
          virusScanned: true,
          virusClean: true,
          createdAt: true,
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    return {
      data: documents.map((d) => ({ ...d, sizeBytes: d.sizeBytes.toString() })),
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  // ── GET ONE ───────────────────────────────────────────────

  async findOne(userId: string, documentId: string) {
    const profile = await this.getProfileOrThrow(userId);

    const doc = await this.prisma.profileDocument.findFirst({
      where: { id: documentId, profileId: profile.id, deletedAt: null },
      include: {
        ocrResults: {
          select: {
            id: true,
            provider: true,
            overallConfidence: true,
            processedAt: true,
          },
        },
      },
    });

    if (!doc) throw new NotFoundException('Document not found');

    return {
      ...doc,
      sizeBytes: doc.sizeBytes.toString(),
    };
  }

  // ── DOWNLOAD URL ─────────────────────────────────────────

  async getDownloadUrl(userId: string, documentId: string) {
    const profile = await this.getProfileOrThrow(userId);

    const doc = await this.prisma.profileDocument.findFirst({
      where: { id: documentId, profileId: profile.id, deletedAt: null },
      select: { storageKey: true, filename: true },
    });

    if (!doc) throw new NotFoundException('Document not found');

    const url = await this.storage.getDownloadUrl(doc.storageKey);
    return { url, expiresInSeconds: 900, filename: doc.filename };
  }

  // ── SOFT DELETE ───────────────────────────────────────────

  async softDelete(userId: string, documentId: string) {
    const profile = await this.getProfileOrThrow(userId);

    const doc = await this.prisma.profileDocument.findFirst({
      where: { id: documentId, profileId: profile.id, deletedAt: null },
      select: { id: true, sizeBytes: true },
    });

    if (!doc) throw new NotFoundException('Document not found');

    await this.prisma.$transaction([
      this.prisma.profileDocument.update({
        where: { id: doc.id },
        data: { deletedAt: new Date() },
      }),
      this.prisma.user.update({
        where: { id: userId },
        data: { storageUsedBytes: { decrement: doc.sizeBytes } },
      }),
    ]);

    return { message: 'Document deleted' };
  }

  // ── PRIVATE HELPERS ────────────────────────────────────────

  private async getProfileOrThrow(userId: string) {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException('Profile not found');
    return profile;
  }
}
