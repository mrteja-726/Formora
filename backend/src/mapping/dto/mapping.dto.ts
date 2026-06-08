import {
  IsString, IsNotEmpty, IsArray, IsOptional,
  ValidateNested, IsEnum, IsNumber, Min, Max,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

// ── Individual form field descriptor ───────────────────────

export class FormFieldDto {
  @ApiProperty({ example: '#first-name', description: 'CSS selector for the field' })
  @IsString() @IsNotEmpty()
  selector: string;

  @ApiProperty({ example: 'First Name' })
  @IsString() @IsNotEmpty()
  label: string;

  @ApiProperty({ example: 'text', description: 'HTML input type' })
  @IsString() @IsNotEmpty()
  type: string;

  @ApiPropertyOptional({ example: 'Enter your first name' })
  @IsOptional() @IsString()
  placeholder?: string;

  @ApiPropertyOptional({ example: 'first_name', description: 'HTML name attribute' })
  @IsOptional() @IsString()
  name?: string;
}

// ── Analyze form request ────────────────────────────────────

export class AnalyzeFormDto {
  @ApiProperty({ example: 'linkedin.com' })
  @IsString() @IsNotEmpty()
  domain: string;

  @ApiProperty({ type: [FormFieldDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => FormFieldDto)
  fields: FormFieldDto[];
}

// ── Execute fill request ────────────────────────────────────

export class ExecuteFillDto {
  @ApiProperty({ example: ['#first-name', '#last-name'] })
  @IsArray()
  @IsString({ each: true })
  confirmedSelectors: string[];
}

// ── Rate session request ────────────────────────────────────

export class RateSessionDto {
  @ApiProperty({ example: 95, minimum: 0, maximum: 100 })
  @IsNumber() @Min(0) @Max(100)
  accuracy: number;

  @ApiPropertyOptional({ example: 'Phone field was wrong' })
  @IsOptional() @IsString()
  feedback?: string;
}
