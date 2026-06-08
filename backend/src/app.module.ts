// ============================================================
// Formora — App Root Module
// ============================================================

import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';

import { PrismaModule } from './prisma/prisma.module';
import { EncryptionModule } from './common/encryption/encryption.module';
import { StorageModule } from './common/storage/storage.module';
import { MailModule } from './mail/mail.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ProfileModule } from './profile/profile.module';
import { DocumentsModule } from './documents/documents.module';

@Module({
  imports: [
    // ── Config (loads .env) ───────────────────────────────
    ConfigModule.forRoot({ isGlobal: true }),

    // ── Rate limiting ─────────────────────────────────────
    ThrottlerModule.forRoot([
      { name: 'short',  ttl: 60_000,      limit: 100 },
      { name: 'medium', ttl: 60_000 * 10, limit: 500 },
    ]),

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
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule {}
