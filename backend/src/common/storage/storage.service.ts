// ============================================================
// Formora — Storage Service (AWS S3 / MinIO)
// Handles file uploads, pre-signed download URLs, deletions
// ============================================================

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
  GetObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v4 as uuidv4 } from 'uuid';
import * as path from 'path';

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly s3: S3Client;
  private readonly bucket: string;

  constructor(private config: ConfigService) {
    const endpoint = this.config.get<string>('S3_ENDPOINT'); // For MinIO local dev

    this.s3 = new S3Client({
      region: this.config.get('AWS_REGION', 'us-east-1'),
      credentials: {
        accessKeyId: this.config.getOrThrow('AWS_ACCESS_KEY_ID'),
        secretAccessKey: this.config.getOrThrow('AWS_SECRET_ACCESS_KEY'),
      },
      ...(endpoint ? { endpoint, forcePathStyle: true } : {}),
    });

    this.bucket = this.config.getOrThrow('S3_BUCKET');
  }

  /**
   * Upload a file buffer to S3/MinIO
   * Returns the storage key for the uploaded file
   */
  async upload(
    buffer: Buffer,
    originalName: string,
    contentType: string,
    prefix = 'documents',
  ): Promise<string> {
    const ext = path.extname(originalName).toLowerCase();
    const key = `${prefix}/${uuidv4()}${ext}`;

    await this.s3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: buffer,
        ContentType: contentType,
        ServerSideEncryption: 'AES256',
      }),
    );

    this.logger.log(`Uploaded: ${key} (${buffer.length} bytes)`);
    return key;
  }

  /**
   * Generate a pre-signed download URL (default 15 min TTL)
   */
  async getDownloadUrl(key: string, expiresInSeconds = 900): Promise<string> {
    const command = new GetObjectCommand({ Bucket: this.bucket, Key: key });
    return getSignedUrl(this.s3, command, { expiresIn: expiresInSeconds });
  }

  /**
   * Delete an object from S3
   */
  async delete(key: string): Promise<void> {
    await this.s3.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
    this.logger.log(`Deleted: ${key}`);
  }
}
