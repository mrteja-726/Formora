// ============================================================
// Formora — Profile Controller
// Routes: /api/v1/profile/*
// ============================================================

import {
  Controller,
  Get,
  Put,
  Post,
  Delete,
  Patch,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiParam,
  ApiResponse,
} from '@nestjs/swagger';

import { ProfileService } from './profile.service';
import { JwtAuthGuard } from '../auth/guards/auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import {
  UpsertProfileFieldDto,
  BulkUpsertFieldsDto,
  FieldVisibility,
} from './dto/profile.dto';
import { IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

class UpdateVisibilityDto {
  @ApiProperty({ enum: FieldVisibility })
  @IsEnum(FieldVisibility)
  visibility: FieldVisibility;
}

@ApiTags('Profile')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller({ path: 'profile', version: '1' })
export class ProfileController {
  constructor(private profileService: ProfileService) {}

  // ── GET PROFILE (metadata) ──────────────────────────────────

  @Get()
  @ApiOperation({ summary: 'Get profile metadata (field keys, sections, visibility — no decrypted values)' })
  @ApiResponse({ status: 200, description: 'Profile metadata with field index and completeness score' })
  async getProfile(@CurrentUser() user: { id: string }) {
    return {
      success: true,
      data: await this.profileService.getProfile(user.id),
    };
  }

  // ── GET SINGLE FIELD (decrypted) ─────────────────────────────

  @Get('fields/:fieldKey')
  @ApiOperation({ summary: 'Get a single decrypted profile field (access is audit-logged)' })
  @ApiParam({ name: 'fieldKey', example: 'first_name' })
  async getField(
    @CurrentUser() user: { id: string },
    @Param('fieldKey') fieldKey: string,
  ) {
    return {
      success: true,
      data: await this.profileService.getField(user.id, fieldKey, user.id),
    };
  }

  // ── UPSERT SINGLE FIELD ──────────────────────────────────────

  @Put('fields/:fieldKey')
  @ApiOperation({ summary: 'Create or update a single encrypted profile field' })
  @ApiParam({ name: 'fieldKey', example: 'first_name' })
  async upsertField(
    @CurrentUser() user: { id: string },
    @Body() dto: UpsertProfileFieldDto,
  ) {
    return {
      success: true,
      data: await this.profileService.upsertField(user.id, dto),
    };
  }

  // ── BULK UPSERT ──────────────────────────────────────────────

  @Post('fields/bulk')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Upsert multiple profile fields in one atomic transaction' })
  async bulkUpsert(
    @CurrentUser() user: { id: string },
    @Body() dto: BulkUpsertFieldsDto,
  ) {
    return {
      success: true,
      data: await this.profileService.bulkUpsertFields(user.id, dto),
    };
  }

  // ── DELETE FIELD ─────────────────────────────────────────────

  @Delete('fields/:fieldKey')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete a profile field' })
  @ApiParam({ name: 'fieldKey', example: 'middle_name' })
  async deleteField(
    @CurrentUser() user: { id: string },
    @Param('fieldKey') fieldKey: string,
  ) {
    return {
      success: true,
      data: await this.profileService.deleteField(user.id, fieldKey),
    };
  }

  // ── UPDATE VISIBILITY ─────────────────────────────────────────

  @Patch('fields/:fieldKey/visibility')
  @ApiOperation({ summary: "Update a field's visibility (public / private / masked)" })
  @ApiParam({ name: 'fieldKey', example: 'phone' })
  async updateVisibility(
    @CurrentUser() user: { id: string },
    @Param('fieldKey') fieldKey: string,
    @Body() dto: UpdateVisibilityDto,
  ) {
    return {
      success: true,
      data: await this.profileService.updateFieldVisibility(user.id, fieldKey, dto.visibility),
    };
  }

  // ── COMPLETENESS ──────────────────────────────────────────────

  @Get('completeness')
  @ApiOperation({ summary: 'Get profile completeness score with section breakdown' })
  async getCompleteness(@CurrentUser() user: { id: string }) {
    return {
      success: true,
      data: await this.profileService.getCompleteness(user.id),
    };
  }

  // ── EXPORT ───────────────────────────────────────────────────

  @Get('export')
  @ApiOperation({ summary: 'Export full decrypted profile as JSON (audit-logged)' })
  async exportProfile(@CurrentUser() user: { id: string }) {
    return {
      success: true,
      data: await this.profileService.exportProfile(user.id),
    };
  }
}
