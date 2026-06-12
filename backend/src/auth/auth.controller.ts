// ============================================================
// Formora — Auth Controller
// Routes: /api/v1/auth/*
// ============================================================

import { Controller, Post, Get, Body, Req, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';

import { AuthService } from './auth.service';
import { JwtAuthGuard, GoogleAuthGuard } from './guards/auth.guard';
import { Public } from './decorators/public.decorator';
import { CurrentUser } from './decorators/current-user.decorator';
import {
  RegisterDto,
  LoginDto,
  VerifyEmailDto,
  RefreshTokenDto,
  ForgotPasswordDto,
  ResetPasswordDto,
  MfaVerifyDto,
} from './dto/auth.dto';

@ApiTags('Auth')
@UseGuards(JwtAuthGuard)
@Controller({ path: 'auth', version: '1' })
export class AuthController {
  constructor(private authService: AuthService) {}

  // ── REGISTER ────────────────────────────────────────────

  @Public()
  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  @Throttle({ short: { limit: 5, ttl: 60_000 } })
  @ApiOperation({ summary: 'Register a new user' })
  @ApiResponse({ status: 201, description: 'User created, verification email sent' })
  @ApiResponse({ status: 409, description: 'Email already in use' })
  async register(@Body() dto: RegisterDto) {
    return {
      success: true,
      data: await this.authService.register(dto),
    };
  }

  // ── VERIFY EMAIL ─────────────────────────────────────────

  @Public()
  @Post('verify-email')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify email address with token' })
  async verifyEmail(@Body() dto: VerifyEmailDto) {
    return {
      success: true,
      data: await this.authService.verifyEmail(dto),
    };
  }

  // ── LOGIN ────────────────────────────────────────────────

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @Throttle({ short: { limit: 10, ttl: 60_000 } })
  @ApiOperation({ summary: 'Login with email and password' })
  @ApiResponse({ status: 200, description: 'Returns access and refresh tokens' })
  @ApiResponse({ status: 401, description: 'Invalid credentials' })
  async login(@Body() dto: LoginDto, @Req() req: { ip: string; headers: Record<string, string> }) {
    const result = await this.authService.login(dto, req.ip, req.headers['user-agent']);
    return { success: true, data: result };
  }

  // ── REFRESH ──────────────────────────────────────────────

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Rotate refresh token and get new access token' })
  async refresh(@Body() dto: RefreshTokenDto) {
    return { success: true, data: await this.authService.refreshToken(dto) };
  }

  // ── LOGOUT ───────────────────────────────────────────────

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Revoke current session' })
  async logout(@Body() dto: RefreshTokenDto) {
    return { success: true, data: await this.authService.logout(dto.refreshToken) };
  }

  // ── GOOGLE OAUTH ─────────────────────────────────────────

  @Public()
  @Get('oauth/google')
  @UseGuards(GoogleAuthGuard)
  @ApiOperation({ summary: 'Initiate Google OAuth2 flow' })
  googleAuth() {
    // Handled by Passport — redirects to Google
  }

  @Public()
  @Get('oauth/google/callback')
  @UseGuards(GoogleAuthGuard)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Google OAuth2 callback' })
  async googleCallback(@Req() req: { user: Record<string, unknown> }) {
    const result = await this.authService.handleGoogleAuth(
      req.user as unknown as {
        providerId: string;
        email: string;
        fullName: string;
        avatarUrl?: string;
        accessToken: string;
      },
    );
    return { success: true, data: result };
  }

  // ── MFA ──────────────────────────────────────────────────

  @Get('mfa/setup')
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Initiate MFA setup — returns TOTP secret and QR code' })
  async mfaSetup(@CurrentUser() user: { id: string }) {
    return { success: true, data: await this.authService.setupMfa(user.id) };
  }

  @Post('mfa/verify')
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Confirm MFA setup with TOTP code — enables MFA' })
  async mfaVerify(@CurrentUser() user: { id: string }, @Body() dto: MfaVerifyDto) {
    return { success: true, data: await this.authService.confirmMfa(user.id, dto) };
  }

  @Post('mfa/disable')
  @ApiBearerAuth('access-token')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Disable MFA (requires current TOTP code)' })
  async mfaDisable(@CurrentUser() user: { id: string }, @Body() dto: MfaVerifyDto) {
    return { success: true, data: await this.authService.disableMfa(user.id, dto) };
  }

  // ── PASSWORD RESET ────────────────────────────────────────

  @Public()
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  @Throttle({ short: { limit: 3, ttl: 60_000 } })
  @ApiOperation({ summary: 'Send password reset email' })
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    return { success: true, data: await this.authService.forgotPassword(dto) };
  }

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reset password using token from email' })
  async resetPassword(@Body() dto: ResetPasswordDto) {
    return { success: true, data: await this.authService.resetPassword(dto) };
  }
}
