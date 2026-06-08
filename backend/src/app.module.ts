// ============================================================
// Formora — App Root Module
// ============================================================

import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { PrismaModule } from './prisma/prisma.module';
import { MailModule } from './mail/mail.module';

@Module({
  imports: [
    // ── Config (load .env) ────────────────────────────────
    ConfigModule.forRoot({ isGlobal: true }),

    // ── Rate limiting ─────────────────────────────────────
    ThrottlerModule.forRoot([
      { name: 'short', ttl: 60_000, limit: 100 },
      { name: 'medium', ttl: 60_000 * 10, limit: 500 },
    ]),

    // ── Feature modules ───────────────────────────────────
    PrismaModule,
    MailModule,
    AuthModule,
    UsersModule,
  ],
  providers: [
    // Apply throttling globally
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule {}
