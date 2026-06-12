// ============================================================
// Formora — AI Mapping Service (Phase 1.5)
// Semantically maps form fields → profile fields using:
// 1. Rule-based exact/fuzzy matching (fast, no API cost)
// 2. LLM (OpenAI/Gemini) for ambiguous fields
// Results are cached per domain + field selector
// ============================================================

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { EncryptionService } from '../common/encryption/encryption.service';
import OpenAI from 'openai';

// ── Profile field catalogue (key → canonical aliases) ───────
const FIELD_ALIASES: Record<string, string[]> = {
  first_name: ['first name', 'given name', 'firstname', 'fname', 'forename', 'first'],
  last_name: ['last name', 'surname', 'family name', 'lastname', 'lname', 'second name'],
  full_name: ['full name', 'name', 'your name', 'complete name'],
  email: ['email', 'email address', 'e-mail', 'electronic mail'],
  phone: ['phone', 'telephone', 'mobile', 'cell', 'contact number', 'phone number'],
  date_of_birth: ['date of birth', 'dob', 'birth date', 'birthday', 'born on'],
  address_line1: ['address', 'street address', 'address line 1', 'street', 'addr1'],
  address_line2: ['address line 2', 'apt', 'suite', 'unit', 'apartment', 'addr2'],
  city: ['city', 'town', 'locality', 'suburb'],
  state: ['state', 'province', 'region', 'county'],
  zip_code: ['zip', 'postal code', 'zip code', 'postcode', 'pin code'],
  country: ['country', 'nation', 'country of residence'],
  gender: ['gender', 'sex', 'gender identity'],
  nationality: ['nationality', 'citizenship', 'national origin'],
  current_job_title: ['job title', 'position', 'role', 'occupation', 'title', 'current role'],
  employer: ['employer', 'company', 'organisation', 'organization', 'workplace', 'employer name'],
  linkedin_url: ['linkedin', 'linkedin url', 'linkedin profile'],
  website: ['website', 'portfolio', 'personal website', 'url', 'web page'],
  passport_number: ['passport number', 'passport no', 'document number'],
  license_number: ['license number', 'dl number', "driver's license"],
};

export interface FormField {
  selector: string;
  label: string;
  type: string;
  placeholder?: string;
  name?: string;
}

export interface FieldMapping {
  selector: string;
  profileFieldKey: string | null;
  confidence: number;
  source: 'rule' | 'llm' | 'cache';
  requiresConfirmation: boolean;
}

@Injectable()
export class MappingService {
  private readonly logger = new Logger(MappingService.name);
  private openai: OpenAI | null = null;

  constructor(
    private config: ConfigService,
    private prisma: PrismaService,
    private encryption: EncryptionService,
  ) {
    const apiKey = this.config.get<string>('OPENAI_API_KEY');
    if (apiKey) {
      this.openai = new OpenAI({ apiKey });
      this.logger.log('OpenAI client initialised for AI Mapping Engine');
    } else {
      this.logger.warn('OPENAI_API_KEY not set — AI mapping will use rules-only mode');
    }
  }

  // ── ANALYZE FORM ─────────────────────────────────────────

  async analyzeForm(
    userId: string,
    domain: string,
    formFields: FormField[],
  ): Promise<{ sessionId: string; mappings: FieldMapping[] }> {
    const mappings: FieldMapping[] = [];

    for (const field of formFields) {
      // 1. Check user's saved mappings (cache)
      const cached = await this.checkSavedMapping(userId, domain, field.selector);
      if (cached) {
        mappings.push({ ...cached, source: 'cache', requiresConfirmation: false });
        continue;
      }

      // 2. Rule-based matching
      const ruleMatch = this.applyRules(field);
      if (ruleMatch && ruleMatch.confidence >= 85) {
        mappings.push({ ...ruleMatch, source: 'rule', requiresConfirmation: false });
        continue;
      }

      // 3. LLM fallback for ambiguous fields
      if (this.openai && (ruleMatch === null || (ruleMatch?.confidence ?? 0) < 85)) {
        const llmMatch = await this.runLlmMapping(field);
        if (llmMatch) {
          mappings.push({
            ...llmMatch,
            source: 'llm',
            requiresConfirmation: llmMatch.confidence < 90,
          });
          continue;
        }
      }
      // 4. Use rule result even if low confidence
      if (ruleMatch) {
        mappings.push({ ...ruleMatch, source: 'rule', requiresConfirmation: true });
      } else {
        mappings.push({
          selector: field.selector,
          profileFieldKey: null,
          confidence: 0,
          source: 'rule',
          requiresConfirmation: true,
        });
      }
    }

    // Persist the session
    const session = await this.prisma.formFillSession.create({
      data: {
        userId,
        domain,
        fieldsDetected: formFields.length,
        fieldsFilled: mappings.filter((m) => m.profileFieldKey).length,
        platform: 'BROWSER_EXTENSION',
      },
    });

    // Save high-confidence mappings for future reuse
    await this.saveMappings(userId, domain, mappings);

    return { sessionId: session.id, mappings };
  }

  // ── EXECUTE FILL — return decrypted values ────────────────

  async executeFill(userId: string, sessionId: string, confirmedSelectors: string[]) {
    const session = await this.prisma.formFillSession.findFirst({
      where: { id: sessionId, userId },
    });
    if (!session) throw new Error('Session not found');

    // Get the profile fields requested
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new Error('Profile not found');

    const values: Record<string, string | null> = {};

    // Build selector → fieldKey map from saved mappings
    const savedMappings = await this.prisma.autofillMapping.findMany({
      where: { userId, domain: session.domain, fieldSelector: { in: confirmedSelectors } },
    });

    for (const mapping of savedMappings) {
      if (!confirmedSelectors.includes(mapping.fieldSelector)) continue;

      const field = await this.prisma.profileField.findFirst({
        where: { profileId: profile.id, fieldKey: mapping.profileFieldKey },
        select: { valueEnc: true },
      });

      values[mapping.fieldSelector] = field ? this.encryption.safeDecrypt(field.valueEnc) : null;
    }

    // Update session stats
    await this.prisma.formFillSession.update({
      where: { id: sessionId },
      data: { fieldsFilled: Object.keys(values).length },
    });

    return { sessionId, filledCount: Object.keys(values).length, values };
  }

  // ── RATE SESSION ──────────────────────────────────────────

  async rateSession(sessionId: string, userId: string, accuracy: number, feedback?: string) {
    await this.prisma.formFillSession.updateMany({
      where: { id: sessionId, userId },
      data: { fillAccuracy: accuracy },
    });
    if (feedback) {
      this.logger.log(`Form fill session ${sessionId} feedback: ${feedback}`);
    }
    return { rated: true, accuracy };
  }

  // ── RULE-BASED MATCHING ───────────────────────────────────

  private applyRules(field: FormField): Omit<FieldMapping, 'source'> | null {
    const searchTerms = [
      field.label?.toLowerCase(),
      field.name?.toLowerCase(),
      field.placeholder?.toLowerCase(),
    ].filter(Boolean);

    let bestKey: string | null = null;
    let bestScore = 0;

    for (const [profileKey, aliases] of Object.entries(FIELD_ALIASES)) {
      for (const term of searchTerms) {
        if (!term) continue;

        // Exact match
        if (aliases.some((alias) => alias === term)) {
          return {
            selector: field.selector,
            profileFieldKey: profileKey,
            confidence: 99,
            requiresConfirmation: false,
          };
        }

        // Contains match
        for (const alias of aliases) {
          if (term.includes(alias) || alias.includes(term)) {
            const score = Math.round(
              (Math.min(alias.length, term.length) / Math.max(alias.length, term.length)) * 95,
            );
            if (score > bestScore) {
              bestScore = score;
              bestKey = profileKey;
            }
          }
        }
      }
    }

    // HTML type hints
    if (!bestKey) {
      if (field.type === 'email') {
        bestKey = 'email';
        bestScore = 95;
      }
      if (field.type === 'tel') {
        bestKey = 'phone';
        bestScore = 90;
      }
      if (field.type === 'date' && field.label?.toLowerCase().includes('birth')) {
        bestKey = 'date_of_birth';
        bestScore = 90;
      }
    }

    return bestKey
      ? {
          selector: field.selector,
          profileFieldKey: bestKey,
          confidence: bestScore,
          requiresConfirmation: bestScore < 85,
        }
      : null;
  }

  // ── LLM MAPPING ───────────────────────────────────────────

  private async runLlmMapping(field: FormField): Promise<Omit<FieldMapping, 'source'> | null> {
    const profileKeys = Object.keys(FIELD_ALIASES).join(', ');
    const prompt = `You are a form field mapper. Given a web form field, identify which user profile field it maps to.

Form field:
- Label: "${field.label}"
- HTML name attribute: "${field.name ?? 'unknown'}"  
- HTML type: "${field.type}"
- Placeholder: "${field.placeholder ?? 'none'}"

Available profile field keys: ${profileKeys}

Respond with JSON only:
{"profileFieldKey": "<key or null>", "confidence": <0-100>}

If none match well, return {"profileFieldKey": null, "confidence": 0}`;

    try {
      const response = await this.openai!.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [{ role: 'user', content: prompt }],
        response_format: { type: 'json_object' },
        temperature: 0,
        max_tokens: 100,
      });

      const parsed = JSON.parse(response.choices[0].message.content ?? '{}') as {
        profileFieldKey: string | null;
        confidence: number;
      };

      return {
        selector: field.selector,
        profileFieldKey: parsed.profileFieldKey,
        confidence: parsed.confidence,
        requiresConfirmation: parsed.confidence < 90,
      };
    } catch (err) {
      this.logger.warn(`LLM mapping failed for field "${field.label}": ${(err as Error).message}`);
      return null;
    }
  }

  // ── CACHE: CHECK SAVED MAPPINGS ────────────────────────────

  private async checkSavedMapping(userId: string, domain: string, selector: string) {
    const saved = await this.prisma.autofillMapping.findFirst({
      where: { userId, domain, fieldSelector: selector, userConfirmed: true },
      orderBy: { updatedAt: 'desc' },
    });
    if (!saved) return null;
    return {
      selector: saved.fieldSelector,
      profileFieldKey: saved.profileFieldKey,
      confidence: saved.aiConfidence,
      requiresConfirmation: false,
    };
  }

  // ── PERSIST MAPPINGS ──────────────────────────────────────

  private async saveMappings(userId: string, domain: string, mappings: FieldMapping[]) {
    const highConf = mappings.filter((m) => m.profileFieldKey && m.confidence >= 80);
    for (const m of highConf) {
      await this.prisma.autofillMapping
        .upsert({
          where: {
            // Using a composite unique identifier
            id: `${userId}_${domain}_${m.selector}`.slice(0, 36),
          },
          create: {
            id: `${userId}_${domain}_${m.selector}`.slice(0, 36),
            userId,
            domain,
            fieldSelector: m.selector,
            profileFieldKey: m.profileFieldKey!,
            aiConfidence: m.confidence,
            userConfirmed: m.source === 'cache',
          },
          update: {
            aiConfidence: m.confidence,
          },
        })
        .catch(() => {
          // Non-critical — mapping already exists
        });
    }
  }
}
