// ============================================================
// Formora — Auth Service
// Full: register, email verify, login, refresh, logout,
//        Google OAuth, MFA (TOTP), forgot/reset password
// ============================================================

import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';
import * as bcrypt from 'bcrypt';
import * as speakeasy from 'speakeasy';
import * as qrcode from 'qrcode';
import { v4 as uuidv4 } from 'uuid';
import * as crypto from 'crypto';

import {
  RegisterDto,
  LoginDto,
  VerifyEmailDto,
  RefreshTokenDto,
  ForgotPasswordDto,
  ResetPasswordDto,
  MfaVerifyDto,
} from './dto/auth.dto';

// ── Token TTLs ───────────────────────────────────────────
const BCRYPT_ROUNDS = 12;
const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL_DAYS = 30;
const EMAIL_TOKEN_TTL_HOURS = 24;
const RESET_TOKEN_TTL_MINUTES = 60;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
    private mail: MailService,
  ) {}

  // ── REGISTRATION ────────────────────────────────────────

  async register(dto: RegisterDto) {
    const existing = await this.prisma.user.findFirst({
      where: { email: dto.email.toLowerCase(), deletedAt: null },
    });

    if (existing) throw new ConflictException('Email already in use');

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);

    const user = await this.prisma.user.create({
      data: {
        email: dto.email.toLowerCase(),
        passwordHash,
        fullName: dto.fullName,
        profile: { create: {} }, // Auto-create empty profile
      },
      select: { id: true, email: true },
    });

    await this.sendVerificationEmail(user.email);

    this.logger.log(`New user registered: ${user.email}`);
    return { userId: user.id, email: user.email, message: 'Verification email sent' };
  }

  // ── EMAIL VERIFICATION ───────────────────────────────────

  async sendVerificationEmail(email: string) {
    // Invalidate previous tokens
    await this.prisma.emailVerificationToken.updateMany({
      where: { email: email.toLowerCase() },
      data: { usedAt: new Date() },
    });

    const token = uuidv4();
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + EMAIL_TOKEN_TTL_HOURS);

    await this.prisma.emailVerificationToken.create({
      data: { email: email.toLowerCase(), token, expiresAt },
    });

    await this.mail.sendVerificationEmail(email, token);
  }

  async verifyEmail(dto: VerifyEmailDto) {
    const record = await this.prisma.emailVerificationToken.findUnique({
      where: { token: dto.token },
    });

    if (!record || record.usedAt || record.expiresAt < new Date()) {
      throw new BadRequestException('Invalid or expired verification token');
    }

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { email: record.email },
        data: { emailVerifiedAt: new Date() },
      }),
      this.prisma.emailVerificationToken.update({
        where: { id: record.id },
        data: { usedAt: new Date() },
      }),
    ]);

    return { message: 'Email verified successfully' };
  }

  // ── LOCAL LOGIN ──────────────────────────────────────────

  async validateLocalUser(email: string, password: string) {
    const user = await this.prisma.user.findFirst({
      where: { email: email.toLowerCase(), isActive: true, deletedAt: null },
      select: { id: true, email: true, passwordHash: true, emailVerifiedAt: true, fullName: true },
    });

    if (!user || !user.passwordHash) return null;
    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) return null;

    const result = { ...user };
    delete (result as { passwordHash?: string | null }).passwordHash;
    return result;
  }

  async login(dto: LoginDto, ipAddress?: string, userAgent?: string) {
    const user = await this.validateLocalUser(dto.email, dto.password);
    if (!user) throw new UnauthorizedException('Invalid credentials');

    if (!user.emailVerifiedAt) {
      throw new UnauthorizedException('Please verify your email before logging in');
    }

    // ── MFA check ─────────────────────────────────────────
    const mfaConfig = await this.prisma.userMfaConfig.findUnique({
      where: { userId: user.id },
    });

    const requiresMfa = !!mfaConfig?.enabledAt;

    if (requiresMfa) {
      if (!dto.mfaCode) {
        return { requiresMfa: true, message: 'MFA code required' };
      }

      const valid = speakeasy.totp.verify({
        secret: mfaConfig.totpSecret,
        encoding: 'base32',
        token: dto.mfaCode,
        window: 1,
      });

      if (!valid) throw new UnauthorizedException('Invalid MFA code');
    }

    return this.issueTokens(user.id, user.email, ipAddress, userAgent);
  }

  // ── TOKEN MANAGEMENT ─────────────────────────────────────

  async issueTokens(userId: string, email: string, ipAddress?: string, userAgent?: string) {
    const accessToken = this.jwt.sign(
      { sub: userId, email },
      {
        secret: this.config.getOrThrow('JWT_ACCESS_SECRET'),
        expiresIn: ACCESS_TOKEN_TTL,
      },
    );

    const refreshToken = uuidv4();
    const refreshTokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + REFRESH_TOKEN_TTL_DAYS);

    await this.prisma.userSession.create({
      data: { userId, refreshTokenHash, ipAddress, userAgent, expiresAt },
    });

    return {
      accessToken,
      refreshToken,
      expiresIn: 900, // 15 minutes in seconds
      requiresMfa: false,
    };
  }

  async refreshToken(dto: RefreshTokenDto) {
    const tokenHash = crypto.createHash('sha256').update(dto.refreshToken).digest('hex');

    const session = await this.prisma.userSession.findUnique({
      where: { refreshTokenHash: tokenHash },
      include: { user: { select: { id: true, email: true, isActive: true, deletedAt: true } } },
    });

    if (
      !session ||
      session.revokedAt ||
      session.expiresAt < new Date() ||
      !session.user.isActive ||
      session.user.deletedAt
    ) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    // Rotate refresh token
    await this.prisma.userSession.update({
      where: { id: session.id },
      data: { revokedAt: new Date() },
    });

    return this.issueTokens(session.user.id, session.user.email);
  }

  async logout(refreshToken: string) {
    const tokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    await this.prisma.userSession.updateMany({
      where: { refreshTokenHash: tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { message: 'Logged out successfully' };
  }

  // ── GOOGLE OAUTH ─────────────────────────────────────────

  async handleGoogleAuth(googleUser: {
    providerId: string;
    email: string;
    fullName: string;
    avatarUrl?: string;
    accessToken: string;
  }) {
    let user = await this.prisma.user.findFirst({
      where: { email: googleUser.email.toLowerCase(), deletedAt: null },
    });

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          email: googleUser.email.toLowerCase(),
          fullName: googleUser.fullName,
          avatarUrl: googleUser.avatarUrl,
          emailVerifiedAt: new Date(), // Google emails are pre-verified
          profile: { create: {} },
          oauthProviders: {
            create: {
              provider: 'GOOGLE',
              providerUserId: googleUser.providerId,
            },
          },
        },
      });
    } else {
      // Upsert OAuth link
      await this.prisma.userOAuthProvider.upsert({
        where: {
          provider_providerUserId: {
            provider: 'GOOGLE',
            providerUserId: googleUser.providerId,
          },
        },
        create: {
          userId: user.id,
          provider: 'GOOGLE',
          providerUserId: googleUser.providerId,
        },
        update: {},
      });
    }

    return this.issueTokens(user.id, user.email);
  }

  // ── PASSWORD RESET ────────────────────────────────────────

  async forgotPassword(dto: ForgotPasswordDto) {
    const user = await this.prisma.user.findFirst({
      where: { email: dto.email.toLowerCase(), deletedAt: null },
    });

    // Always return success to avoid email enumeration
    if (!user) return { message: 'If that email exists, a reset link has been sent' };

    const token = crypto.randomBytes(32).toString('hex');
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + RESET_TOKEN_TTL_MINUTES);

    await this.prisma.passwordResetToken.create({
      data: { userId: user.id, tokenHash, expiresAt },
    });

    await this.mail.sendPasswordResetEmail(user.email, token);

    return { message: 'If that email exists, a reset link has been sent' };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const tokenHash = crypto.createHash('sha256').update(dto.token).digest('hex');

    const record = await this.prisma.passwordResetToken.findUnique({
      where: { tokenHash },
    });

    if (!record || record.usedAt || record.expiresAt < new Date()) {
      throw new BadRequestException('Invalid or expired reset token');
    }

    const passwordHash = await bcrypt.hash(dto.newPassword, BCRYPT_ROUNDS);

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: record.userId },
        data: { passwordHash },
      }),
      this.prisma.passwordResetToken.update({
        where: { id: record.id },
        data: { usedAt: new Date() },
      }),
      // Revoke all active sessions on password change
      this.prisma.userSession.updateMany({
        where: { userId: record.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);

    return { message: 'Password reset successfully. Please log in again.' };
  }

  // ── MFA ────────────────────────────────────────────────

  async setupMfa(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { email: true },
    });

    const secret = speakeasy.generateSecret({
      name: `Formora (${user.email})`,
      length: 32,
    });

    // Store TOTP secret (not yet enabled — enabled after confirmation)
    await this.prisma.userMfaConfig.upsert({
      where: { userId },
      create: {
        userId,
        totpSecret: secret.base32,
        backupCodes: [],
      },
      update: {
        totpSecret: secret.base32,
        enabledAt: null,
      },
    });

    const qrCodeUrl = await qrcode.toDataURL(secret.otpauth_url!);

    return { secret: secret.base32, qrCodeUrl };
  }

  async confirmMfa(userId: string, dto: MfaVerifyDto) {
    const config = await this.prisma.userMfaConfig.findUnique({ where: { userId } });
    if (!config) throw new NotFoundException('MFA setup not initiated');

    const valid = speakeasy.totp.verify({
      secret: config.totpSecret,
      encoding: 'base32',
      token: dto.code,
      window: 1,
    });

    if (!valid) throw new BadRequestException('Invalid TOTP code');

    // Generate 10 backup codes
    const backupPlain = Array.from({ length: 10 }, () =>
      crypto.randomBytes(4).toString('hex').toUpperCase(),
    );
    const backupHashes = await Promise.all(
      backupPlain.map((code) => bcrypt.hash(code, BCRYPT_ROUNDS)),
    );

    await this.prisma.userMfaConfig.update({
      where: { userId },
      data: { enabledAt: new Date(), backupCodes: backupHashes },
    });

    return { message: 'MFA enabled', backupCodes: backupPlain };
  }

  async disableMfa(userId: string, dto: MfaVerifyDto) {
    const config = await this.prisma.userMfaConfig.findUnique({ where: { userId } });
    if (!config?.enabledAt) throw new BadRequestException('MFA is not enabled');

    const valid = speakeasy.totp.verify({
      secret: config.totpSecret,
      encoding: 'base32',
      token: dto.code,
      window: 1,
    });

    if (!valid) throw new UnauthorizedException('Invalid TOTP code');

    await this.prisma.userMfaConfig.delete({ where: { userId } });
    return { message: 'MFA disabled' };
  }
}
