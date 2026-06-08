// ============================================================
// Formora — App Root Module
// ============================================================

import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { BullModule } from '@nestjs/bullmq';
import { APP_GUARD } from '@nestjs/core';

import { PrismaModule } from './prisma/prisma.module';
import { EncryptionModule } from './common/encryption/encryption.module';
import { StorageModule } from './common/storage/storage.module';
import { MailModule } from './mail/mail.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ProfileModule } from './profile/profile.module';
import { DocumentsModule } from './documents/documents.module';
import { OcrModule } from './ocr/ocr.module';
import { MappingModule } from './mapping/mapping.module';

@Module({
  imports: [
    // ── Config (loads .env) ───────────────────────────────
    ConfigModule.forRoot({ isGlobal: true }),

    // ── Rate limiting ─────────────────────────────────────
    ThrottlerModule.forRoot([
      { name: 'short',  ttl: 60_000,      limit: 100 },
      { name: 'medium', ttl: 60_000 * 10, limit: 500 },
    ]),

    // ── BullMQ (Redis-backed queues) ──────────────────────
    BullModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        connection: {
          host: config.get('REDIS_HOST', 'localhost'),
          port: config.get<number>('REDIS_PORT', 6379),
          password: config.get<string>('REDIS_PASSWORD'),
        },
      }),
      inject: [ConfigService],
    }),

    // ── Infrastructure ────────────────────────────────────
    PrismaModule,
    EncryptionModule,
    StorageModule,
    MailModule,

    // ── Feature modules ───────────────────────────────────
    AuthModule,
    UsersModule,
    ProfileModule,
    DocumentsModule,
    OcrModule,
    MappingModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule {}
