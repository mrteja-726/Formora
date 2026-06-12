// ============================================================
// Profile DTOs
// ============================================================

import { IsString, IsNotEmpty, IsOptional, IsEnum, MaxLength, IsIn } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum ProfileSection {
  PERSONAL = 'PERSONAL',
  CONTACT = 'CONTACT',
  EMPLOYMENT = 'EMPLOYMENT',
  EDUCATION = 'EDUCATION',
  MEDICAL = 'MEDICAL',
}

export enum FieldVisibility {
  PUBLIC = 'PUBLIC',
  PRIVATE = 'PRIVATE',
  MASKED = 'MASKED',
}

export enum FieldDataType {
  STRING = 'string',
  DATE = 'date',
  PHONE = 'phone',
  EMAIL = 'email',
  NUMBER = 'number',
  URL = 'url',
}

// ── Upsert a single profile field ──────────────────────────

export class UpsertProfileFieldDto {
  @ApiProperty({ enum: ProfileSection, example: ProfileSection.PERSONAL })
  @IsEnum(ProfileSection)
  section: ProfileSection;

  @ApiProperty({ example: 'first_name' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  fieldKey: string;

  @ApiProperty({ example: 'Jane' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(5000) // supports multiline values (e.g. address)
  value: string;

  @ApiPropertyOptional({ enum: FieldDataType, default: FieldDataType.STRING })
  @IsOptional()
  @IsIn(Object.values(FieldDataType))
  dataType?: string = FieldDataType.STRING;

  @ApiPropertyOptional({ enum: FieldVisibility, default: FieldVisibility.PRIVATE })
  @IsOptional()
  @IsEnum(FieldVisibility)
  visibility?: FieldVisibility = FieldVisibility.PRIVATE;
}

// ── Bulk upsert ───────────────────────────────────────────

export class BulkUpsertFieldsDto {
  @ApiProperty({ type: [UpsertProfileFieldDto] })
  fields: UpsertProfileFieldDto[];
}
