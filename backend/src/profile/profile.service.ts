// ============================================================
// Formora — Profile Service
// CRUD for profile fields with AES-256-GCM encryption,
// completeness scoring, and audit logging
// ============================================================

import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EncryptionService } from '../common/encryption/encryption.service';
import {
  UpsertProfileFieldDto,
  BulkUpsertFieldsDto,
  ProfileSection,
  FieldVisibility,
} from './dto/profile.dto';

// ── Completeness scoring weights per section ────────────────
const SECTION_WEIGHTS: Record<string, number> = {
  PERSONAL: 30,
  CONTACT: 25,
  EMPLOYMENT: 20,
  EDUCATION: 15,
  MEDICAL: 10,
};

// Required fields per section to consider it "complete"
const REQUIRED_FIELDS: Record<string, string[]> = {
  PERSONAL: ['first_name', 'last_name', 'date_of_birth', 'gender'],
  CONTACT:  ['email', 'phone', 'address_line1', 'city', 'country'],
  EMPLOYMENT: ['current_job_title', 'employer', 'years_experience'],
  EDUCATION: ['highest_degree', 'institution', 'graduation_year'],
  MEDICAL: ['blood_type', 'allergies', 'emergency_contact'],
};

@Injectable()
export class ProfileService {
  private readonly logger = new Logger(ProfileService.name);

  constructor(
    private prisma: PrismaService,
    private encryption: EncryptionService,
  ) {}

  // ── GET PROFILE (metadata only, no decrypted values) ────────

  async getProfile(userId: string) {
    const profile = await this.prisma.profile.findUnique({
      where: { userId },
      include: {
        fields: {
          select: {
            id: true,
            section: true,
            fieldKey: true,
            dataType: true,
            visibility: true,
            source: true,
            confidence: true,
            updatedAt: true,
            // NOTE: valueEnc intentionally excluded from list view
          },
          orderBy: [{ section: 'asc' }, { fieldKey: 'asc' }],
        },
        _count: { select: { documents: true } },
      },
    });

    if (!profile) throw new NotFoundException('Profile not found');

    // Group fields by section
    const sections = this.groupBySection(profile.fields);

    return {
      id: profile.id,
      completenessScore: profile.completenessScore,
      documentCount: profile._count.documents,
      sections,
      updatedAt: profile.updatedAt,
    };
  }

  // ── GET SINGLE FIELD (decrypted) ────────────────────────────

  async getField(userId: string, fieldKey: string, requestingUserId: string) {
    const profile = await this.getProfileOrThrow(userId);
    
    const field = await this.prisma.profileField.findFirst({
      where: { profileId: profile.id, fieldKey },
    });

    if (!field) throw new NotFoundException(`Field '${fieldKey}' not found`);

    // Visibility check
    if (field.visibility === FieldVisibility.PRIVATE && userId !== requestingUserId) {
      throw new ForbiddenException('This field is private');
    }

    // Decrypt value
    const value = this.encryption.safeDecrypt(field.valueEnc);

    // Audit log the access
    await this.logAccess(requestingUserId, 'profile.field.read', 'ProfileField', field.id);

    return {
      id: field.id,
      section: field.section,
      fieldKey: field.fieldKey,
      value: field.visibility === FieldVisibility.MASKED && userId !== requestingUserId
        ? this.maskValue(value ?? '')
        : value,
      dataType: field.dataType,
      visibility: field.visibility,
      source: field.source,
      confidence: field.confidence,
      updatedAt: field.updatedAt,
    };
  }

  // ── UPSERT SINGLE FIELD ──────────────────────────────────────

  async upsertField(userId: string, dto: UpsertProfileFieldDto) {
    const profile = await this.getProfileOrThrow(userId);

    const valueEnc = this.encryption.encrypt(dto.value);

    const field = await this.prisma.profileField.upsert({
      where: {
        profileId_section_fieldKey: {
          profileId: profile.id,
          section: dto.section as any,
          fieldKey: dto.fieldKey,
        },
      },
      create: {
        profileId: profile.id,
        section: dto.section as any,
        fieldKey: dto.fieldKey,
        valueEnc,
        dataType: dto.dataType ?? 'string',
        visibility: (dto.visibility ?? FieldVisibility.PRIVATE) as any,
        source: 'MANUAL',
      },
      update: {
        valueEnc,
        dataType: dto.dataType ?? 'string',
        visibility: (dto.visibility ?? FieldVisibility.PRIVATE) as any,
      },
    });

    // Recalculate completeness score async
    await this.recalculateCompleteness(profile.id, userId);
    await this.logAccess(userId, 'profile.field.write', 'ProfileField', field.id);

    return {
      id: field.id,
      section: field.section,
      fieldKey: field.fieldKey,
      dataType: field.dataType,
      visibility: field.visibility,
      updatedAt: field.updatedAt,
    };
  }

  // ── BULK UPSERT ──────────────────────────────────────────────

  async bulkUpsertFields(userId: string, dto: BulkUpsertFieldsDto) {
    const profile = await this.getProfileOrThrow(userId);
    const results: Array<{ fieldKey: string; section: string }> = [];

    // Use a transaction for atomicity
    await this.prisma.$transaction(async (tx) => {
      for (const f of dto.fields) {
        const valueEnc = this.encryption.encrypt(f.value);
        const field = await tx.profileField.upsert({
          where: {
            profileId_section_fieldKey: {
              profileId: profile.id,
              section: f.section as any,
              fieldKey: f.fieldKey,
            },
          },
          create: {
            profileId: profile.id,
            section: f.section as any,
            fieldKey: f.fieldKey,
            valueEnc,
            dataType: f.dataType ?? 'string',
            visibility: (f.visibility ?? FieldVisibility.PRIVATE) as any,
            source: 'MANUAL',
          },
          update: {
            valueEnc,
            dataType: f.dataType ?? 'string',
            visibility: (f.visibility ?? FieldVisibility.PRIVATE) as any,
          },
        });
        results.push({ fieldKey: field.fieldKey, section: field.section });
      }
    });

    await this.recalculateCompleteness(profile.id, userId);
    return { updated: results.length, fields: results };
  }

  // ── DELETE FIELD ─────────────────────────────────────────────

  async deleteField(userId: string, fieldKey: string) {
    const profile = await this.getProfileOrThrow(userId);
    
    const deleted = await this.prisma.profileField.deleteMany({
      where: { profileId: profile.id, fieldKey },
    });

    if (deleted.count === 0) throw new NotFoundException(`Field '${fieldKey}' not found`);

    await this.recalculateCompleteness(profile.id, userId);
    await this.logAccess(userId, 'profile.field.delete', 'Profile', profile.id);

    return { message: `Field '${fieldKey}' deleted` };
  }

  // ── UPDATE FIELD VISIBILITY ──────────────────────────────────

  async updateFieldVisibility(
    userId: string,
    fieldKey: string,
    visibility: FieldVisibility,
  ) {
    const profile = await this.getProfileOrThrow(userId);

    const field = await this.prisma.profileField.findFirst({
      where: { profileId: profile.id, fieldKey },
    });

    if (!field) throw new NotFoundException(`Field '${fieldKey}' not found`);

    await this.prisma.profileField.update({
      where: { id: field.id },
      data: { visibility: visibility as any },
    });

    return { fieldKey, visibility, updated: true };
  }

  // ── COMPLETENESS SCORE ────────────────────────────────────────

  async getCompleteness(userId: string) {
    const profile = await this.getProfileOrThrow(userId);
    const fields = await this.prisma.profileField.findMany({
      where: { profileId: profile.id },
      select: { section: true, fieldKey: true },
    });

    const fieldMap = new Map<string, Set<string>>();
    for (const f of fields) {
      if (!fieldMap.has(f.section)) fieldMap.set(f.section, new Set());
      fieldMap.get(f.section)!.add(f.fieldKey);
    }

    const sectionBreakdown: Record<string, { filled: number; required: number; pct: number }> = {};
    let totalScore = 0;

    for (const [section, requiredFields] of Object.entries(REQUIRED_FIELDS)) {
      const userFields = fieldMap.get(section) ?? new Set();
      const filled = requiredFields.filter((f) => userFields.has(f)).length;
      const pct = Math.round((filled / requiredFields.length) * 100);
      sectionBreakdown[section] = { filled, required: requiredFields.length, pct };
      totalScore += (pct / 100) * (SECTION_WEIGHTS[section] ?? 0);
    }

    const score = Math.round(totalScore);
    const missingSections = Object.entries(sectionBreakdown)
      .filter(([, v]) => v.pct < 100)
      .map(([k]) => k);

    return { score, missingSections, sectionBreakdown, requiredFields: REQUIRED_FIELDS };
  }

  // ── EXPORT PROFILE (decrypted) ───────────────────────────────

  async exportProfile(userId: string) {
    const profile = await this.getProfileOrThrow(userId);
    const fields = await this.prisma.profileField.findMany({
      where: { profileId: profile.id },
      orderBy: [{ section: 'asc' }, { fieldKey: 'asc' }],
    });

    const decrypted = fields.map((f) => ({
      section: f.section,
      fieldKey: f.fieldKey,
      value: this.encryption.safeDecrypt(f.valueEnc),
      dataType: f.dataType,
      visibility: f.visibility,
    }));

    await this.logAccess(userId, 'profile.export', 'Profile', profile.id);
    return { exportedAt: new Date().toISOString(), fields: decrypted };
  }

  // ── PRIVATE HELPERS ───────────────────────────────────────────

  private async getProfileOrThrow(userId: string) {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) {
      // Auto-create if missing (edge case)
      return this.prisma.profile.create({ data: { userId } });
    }
    return profile;
  }

  private groupBySection(
    fields: Array<{ section: string; fieldKey: string; dataType: string; visibility: string; source: string; confidence: number | null; updatedAt: Date }>,
  ) {
    const sections: Record<string, typeof fields> = {};
    for (const f of fields) {
      if (!sections[f.section]) sections[f.section] = [];
      sections[f.section].push(f);
    }
    return sections;
  }

  private async recalculateCompleteness(profileId: string, userId: string) {
    const { score } = await this.getCompleteness(userId);
    await this.prisma.profile.update({
      where: { id: profileId },
      data: { completenessScore: score },
    });
  }

  private maskValue(value: string): string {
    if (value.length <= 4) return '****';
    return value.slice(0, 2) + '*'.repeat(value.length - 4) + value.slice(-2);
  }

  private async logAccess(
    userId: string,
    action: string,
    resourceType: string,
    resourceId: string,
  ) {
    await this.prisma.auditLog.create({
      data: { userId, action, resourceType, resourceId },
    }).catch(() => {
      // Non-critical — never let audit logging break the main flow
      this.logger.warn(`Failed to write audit log: ${action}`);
    });
  }
}
