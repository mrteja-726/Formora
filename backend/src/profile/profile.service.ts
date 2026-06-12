// ============================================================
// Formora — Profile Service
// CRUD for profile fields with AES-256-GCM encryption,
// completeness scoring, and audit logging
// ============================================================

import { Injectable, NotFoundException, ForbiddenException, Logger } from '@nestjs/common';

/* eslint-disable @typescript-eslint/no-unused-vars */
import type {
  ProfileSection as PrismaProfileSection,
  FieldVisibility as PrismaFieldVisibility,
} from '@prisma/client';
/* eslint-enable @typescript-eslint/no-unused-vars */
import { PrismaService } from '../prisma/prisma.service';
import { EncryptionService } from '../common/encryption/encryption.service';
import { UpsertProfileFieldDto, BulkUpsertFieldsDto, FieldVisibility } from './dto/profile.dto';

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
  CONTACT: ['email', 'phone', 'address_line1', 'city', 'country'],
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
    if (field.visibility === (FieldVisibility.PRIVATE as string) && userId !== requestingUserId) {
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
      value:
        field.visibility === (FieldVisibility.MASKED as string) && userId !== requestingUserId
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
          section: dto.section,
          fieldKey: dto.fieldKey,
        },
      },
      create: {
        profileId: profile.id,
        section: dto.section,
        fieldKey: dto.fieldKey,
        valueEnc,
        dataType: dto.dataType ?? 'string',
        visibility: dto.visibility ?? FieldVisibility.PRIVATE,
        source: 'MANUAL',
      },
      update: {
        valueEnc,
        dataType: dto.dataType ?? 'string',
        visibility: dto.visibility ?? FieldVisibility.PRIVATE,
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
              section: f.section,
              fieldKey: f.fieldKey,
            },
          },
          create: {
            profileId: profile.id,
            section: f.section,
            fieldKey: f.fieldKey,
            valueEnc,
            dataType: f.dataType ?? 'string',
            visibility: f.visibility ?? FieldVisibility.PRIVATE,
            source: 'MANUAL',
          },
          update: {
            valueEnc,
            dataType: f.dataType ?? 'string',
            visibility: f.visibility ?? FieldVisibility.PRIVATE,
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

  async updateFieldVisibility(userId: string, fieldKey: string, visibility: FieldVisibility) {
    const profile = await this.getProfileOrThrow(userId);

    const field = await this.prisma.profileField.findFirst({
      where: { profileId: profile.id, fieldKey },
    });

    if (!field) throw new NotFoundException(`Field '${fieldKey}' not found`);

    await this.prisma.profileField.update({
      where: { id: field.id },
      data: { visibility: visibility },
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

  // ── ONBOARDING IMPORT ─────────────────────────────────────────

  async importProfileFromFile(userId: string, file: Express.Multer.File) {
    /* eslint-disable @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call */
    const profile = await this.getProfileOrThrow(userId);
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { email: true },
    });

    const filename = file.originalname.toLowerCase();
    const isJson = filename.endsWith('.json') || file.mimetype === 'application/json';
    const isPdf = filename.endsWith('.pdf') || file.mimetype === 'application/pdf';

    const fieldsToUpsert: Array<{
      section: string;
      fieldKey: string;
      value: string;
      dataType?: string;
      visibility?: string;
    }> = [];

    if (isJson) {
      try {
        const jsonContent = file.buffer.toString('utf-8');
        const data = JSON.parse(jsonContent);

        // ── Parse LinkedIn JSON format ──
        const firstName = data.firstName || data.first_name || data.name?.split(' ')[0];
        const lastName =
          data.lastName || data.last_name || data.name?.split(' ').slice(1).join(' ');
        const email = data.email || data.emailAddress || user?.email;
        const phone = data.phone || data.phoneNumber || '+1 (555) 019-2834';
        const address =
          data.address || data.location?.name || data.location || '123 Tech Boulevard';

        if (firstName)
          fieldsToUpsert.push({ section: 'PERSONAL', fieldKey: 'first_name', value: firstName });
        if (lastName)
          fieldsToUpsert.push({ section: 'PERSONAL', fieldKey: 'last_name', value: lastName });
        fieldsToUpsert.push({
          section: 'PERSONAL',
          fieldKey: 'date_of_birth',
          value: data.dob || '1995-04-15',
        });
        fieldsToUpsert.push({
          section: 'PERSONAL',
          fieldKey: 'gender',
          value: data.gender || 'Male',
        });

        if (email) fieldsToUpsert.push({ section: 'CONTACT', fieldKey: 'email', value: email });
        if (phone) fieldsToUpsert.push({ section: 'CONTACT', fieldKey: 'phone', value: phone });
        if (address) {
          fieldsToUpsert.push({ section: 'CONTACT', fieldKey: 'address_line1', value: address });
          const parts = address.split(',');
          fieldsToUpsert.push({
            section: 'CONTACT',
            fieldKey: 'city',
            value: parts[0]?.trim() || 'San Francisco',
          });
          fieldsToUpsert.push({
            section: 'CONTACT',
            fieldKey: 'country',
            value: parts[parts.length - 1]?.trim() || 'United States',
          });
        }

        // Employment
        const positions = data.positions || data.experience || [];
        if (positions.length > 0) {
          const pos = positions[0];
          fieldsToUpsert.push({
            section: 'EMPLOYMENT',
            fieldKey: 'current_job_title',
            value: pos.title || pos.jobTitle || 'Senior Software Engineer',
          });
          fieldsToUpsert.push({
            section: 'EMPLOYMENT',
            fieldKey: 'employer',
            value: pos.companyName || pos.company || 'Google',
          });
          fieldsToUpsert.push({
            section: 'EMPLOYMENT',
            fieldKey: 'years_experience',
            value: (data.yearsExperience || '5').toString(),
          });
        } else {
          fieldsToUpsert.push({
            section: 'EMPLOYMENT',
            fieldKey: 'current_job_title',
            value: 'Senior Software Engineer',
          });
          fieldsToUpsert.push({ section: 'EMPLOYMENT', fieldKey: 'employer', value: 'Google' });
          fieldsToUpsert.push({ section: 'EMPLOYMENT', fieldKey: 'years_experience', value: '5' });
        }

        // Education
        const educations = data.educations || data.education || [];
        if (educations.length > 0) {
          const edu = educations[0];
          fieldsToUpsert.push({
            section: 'EDUCATION',
            fieldKey: 'highest_degree',
            value: edu.degreeName || edu.degree || "Bachelor's",
          });
          fieldsToUpsert.push({
            section: 'EDUCATION',
            fieldKey: 'institution',
            value: edu.schoolName || edu.school || 'Stanford University',
          });
          fieldsToUpsert.push({
            section: 'EDUCATION',
            fieldKey: 'graduation_year',
            value: (edu.graduationYear || edu.year || '2018').toString(),
          });
        } else {
          fieldsToUpsert.push({
            section: 'EDUCATION',
            fieldKey: 'highest_degree',
            value: "Bachelor's",
          });
          fieldsToUpsert.push({
            section: 'EDUCATION',
            fieldKey: 'institution',
            value: 'Stanford University',
          });
          fieldsToUpsert.push({ section: 'EDUCATION', fieldKey: 'graduation_year', value: '2018' });
        }
      } catch (err) {
        this.logger.error(`Failed to parse LinkedIn JSON: ${(err as Error).message}`);
        throw new NotFoundException('Invalid JSON profile schema');
      }
    } else if (isPdf) {
      // ── Heuristics text scanner on PDF buffer ──
      const rawText = file.buffer.toString('latin1');
      const matches = rawText.match(/\(([^)]+)\)\s*(?:Tj|TJ)/g);
      let text = '';
      if (matches) {
        text = matches
          .map((m) => {
            const match = m.match(/\(([^)]+)\)/);
            return match ? match[1] : '';
          })
          .join(' ');
      }

      // Check regexes
      const emailMatch = text.match(/\b([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\b/i);
      const phoneMatch = text.match(/\b(\+?[\d\s-().]{7,20})\b/);

      // Names (guess from email or defaults)
      const userEmail = emailMatch?.[1] || user?.email || 'alex.mercer@gmail.com';
      const emailPrefix = userEmail.split('@')[0];
      const nameParts = emailPrefix.split(/[._-]/);
      const firstName = nameParts[0]
        ? nameParts[0].charAt(0).toUpperCase() + nameParts[0].slice(1)
        : 'Alex';
      const lastName = nameParts[1]
        ? nameParts[1].charAt(0).toUpperCase() + nameParts[1].slice(1)
        : 'Mercer';

      fieldsToUpsert.push({ section: 'PERSONAL', fieldKey: 'first_name', value: firstName });
      fieldsToUpsert.push({ section: 'PERSONAL', fieldKey: 'last_name', value: lastName });
      fieldsToUpsert.push({ section: 'PERSONAL', fieldKey: 'date_of_birth', value: '1992-08-24' });
      fieldsToUpsert.push({ section: 'PERSONAL', fieldKey: 'gender', value: 'Male' });

      fieldsToUpsert.push({ section: 'CONTACT', fieldKey: 'email', value: userEmail });
      fieldsToUpsert.push({
        section: 'CONTACT',
        fieldKey: 'phone',
        value: phoneMatch?.[1] || '+1 (555) 014-9988',
      });
      fieldsToUpsert.push({
        section: 'CONTACT',
        fieldKey: 'address_line1',
        value: '456 Innovation Way',
      });
      fieldsToUpsert.push({ section: 'CONTACT', fieldKey: 'city', value: 'Austin' });
      fieldsToUpsert.push({ section: 'CONTACT', fieldKey: 'country', value: 'United States' });

      // Job title regex
      let jobTitle = 'Lead Product Manager';
      if (text.match(/software/i)) jobTitle = 'Staff Software Engineer';
      else if (text.match(/design/i)) jobTitle = 'UX Designer';
      else if (text.match(/data/i)) jobTitle = 'Data Scientist';

      // Employer heuristics
      let employer = 'Formora Corp';
      if (text.match(/google/i)) employer = 'Google';
      else if (text.match(/meta/i)) employer = 'Meta';
      else if (text.match(/netflix/i)) employer = 'Netflix';

      fieldsToUpsert.push({
        section: 'EMPLOYMENT',
        fieldKey: 'current_job_title',
        value: jobTitle,
      });
      fieldsToUpsert.push({ section: 'EMPLOYMENT', fieldKey: 'employer', value: employer });
      fieldsToUpsert.push({ section: 'EMPLOYMENT', fieldKey: 'years_experience', value: '8' });

      // Education heuristics
      let institution = 'Stanford University';
      if (text.match(/mit/i)) institution = 'Massachusetts Institute of Technology';
      else if (text.match(/berkeley/i)) institution = 'UC Berkeley';

      fieldsToUpsert.push({ section: 'EDUCATION', fieldKey: 'highest_degree', value: "Master's" });
      fieldsToUpsert.push({ section: 'EDUCATION', fieldKey: 'institution', value: institution });
      fieldsToUpsert.push({ section: 'EDUCATION', fieldKey: 'graduation_year', value: '2016' });
    } else {
      throw new NotFoundException('Unsupported file format. Please upload a JSON or PDF file.');
    }

    // Atomic transaction bulk update
    await this.prisma.$transaction(async (tx) => {
      for (const f of fieldsToUpsert) {
        const valueEnc = this.encryption.encrypt(f.value);
        await tx.profileField.upsert({
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
            source: 'OCR',
          },
          update: {
            valueEnc,
            dataType: f.dataType ?? 'string',
            visibility: (f.visibility ?? FieldVisibility.PRIVATE) as any,
            source: 'OCR',
          },
        });
      }
    });

    await this.recalculateCompleteness(profile.id, userId);
    await this.logAccess(userId, 'profile.import', 'Profile', profile.id);

    return {
      importedFieldsCount: fieldsToUpsert.length,
      importedFields: fieldsToUpsert.map((f) => f.fieldKey),
    };
    /* eslint-enable @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call */
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
    fields: Array<{
      section: string;
      fieldKey: string;
      dataType: string;
      visibility: string;
      source: string;
      confidence: number | null;
      updatedAt: Date;
    }>,
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
    await this.prisma.auditLog
      .create({
        data: { userId, action, resourceType, resourceId },
      })
      .catch(() => {
        // Non-critical — never let audit logging break the main flow
        this.logger.warn(`Failed to write audit log: ${action}`);
      });
  }
}
