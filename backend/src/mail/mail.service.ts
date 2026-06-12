import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter;

  constructor(private config: ConfigService) {
    this.transporter = nodemailer.createTransport({
      host: this.config.get('SMTP_HOST', 'smtp.mailtrap.io'),
      port: this.config.get<number>('SMTP_PORT', 2525),
      auth: {
        user: this.config.get('SMTP_USER'),
        pass: this.config.get('SMTP_PASS'),
      },
    });
  }

  async sendVerificationEmail(email: string, token: string): Promise<void> {
    const appUrl = this.config.get<string>('APP_URL', 'http://localhost:3001');
    const link = `${appUrl}/auth/verify-email?token=${token}`;

    await this.transporter.sendMail({
      from: `"Formora" <${this.config.get('SMTP_FROM', 'noreply@formora.app')}>`,
      to: email,
      subject: 'Verify your Formora email',
      html: `
        <h2>Welcome to Formora!</h2>
        <p>Please verify your email address by clicking the button below.</p>
        <a href="${link}" style="background:#6366f1;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;display:inline-block;margin:16px 0;">
          Verify Email
        </a>
        <p>This link expires in 24 hours.</p>
        <p>If you didn't create a Formora account, you can safely ignore this email.</p>
      `,
    });

    this.logger.log(`Verification email sent to ${email}`);
  }

  async sendPasswordResetEmail(email: string, token: string): Promise<void> {
    const appUrl = this.config.get<string>('APP_URL', 'http://localhost:3001');
    const link = `${appUrl}/auth/reset-password?token=${token}`;

    await this.transporter.sendMail({
      from: `"Formora" <${this.config.get('SMTP_FROM', 'noreply@formora.app')}>`,
      to: email,
      subject: 'Reset your Formora password',
      html: `
        <h2>Password Reset Request</h2>
        <p>We received a request to reset your password.</p>
        <a href="${link}" style="background:#6366f1;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;display:inline-block;margin:16px 0;">
          Reset Password
        </a>
        <p>This link expires in 1 hour.</p>
        <p>If you didn't request this, please ignore this email — your password will not be changed.</p>
      `,
    });

    this.logger.log(`Password reset email sent to ${email}`);
  }
}
