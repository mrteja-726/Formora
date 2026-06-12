// ============================================================
// Formora — Autofill Controller (Phase 1.6)
// Routes: /api/v1/autofill/*
// Called by the browser extension to analyze and fill forms
// ============================================================

import { Controller, Post, Body, Param, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiParam, ApiResponse } from '@nestjs/swagger';

import { MappingService } from './mapping.service';
import { AnalyzeFormDto, ExecuteFillDto, RateSessionDto } from './dto/mapping.dto';
import { JwtAuthGuard } from '../auth/guards/auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@ApiTags('Autofill')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller({ path: 'autofill', version: '1' })
export class AutofillController {
  constructor(private mappingService: MappingService) {}

  // ── STEP 1: ANALYZE FORM ───────────────────────────────────

  @Post('analyze')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Analyze form fields and return profile field mappings',
    description: `
The browser extension sends all detected form fields.
Formora returns a mapping of CSS selectors → profile field keys.
Uses cache → rules → LLM (3-tier resolution).
    `.trim(),
  })
  @ApiResponse({
    status: 200,
    description: 'Returns sessionId and array of field mappings with confidence scores',
  })
  async analyzeForm(@CurrentUser() user: { id: string }, @Body() dto: AnalyzeFormDto) {
    const result = await this.mappingService.analyzeForm(user.id, dto.domain, dto.fields);
    return { success: true, data: result };
  }

  // ── STEP 2: EXECUTE FILL ───────────────────────────────────

  @Post('sessions/:sessionId/fill')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Get decrypted field values for confirmed mappings',
    description: `
The extension confirms which fields to fill.
Formora decrypts and returns the values as a selector→value map.
Each fill is logged in the audit trail.
    `.trim(),
  })
  @ApiParam({ name: 'sessionId' })
  async executeFill(
    @CurrentUser() user: { id: string },
    @Param('sessionId') sessionId: string,
    @Body() dto: ExecuteFillDto,
  ) {
    const result = await this.mappingService.executeFill(
      user.id,
      sessionId,
      dto.confirmedSelectors,
    );
    return { success: true, data: result };
  }

  // ── STEP 3: RATE SESSION ────────────────────────────────────

  @Post('sessions/:sessionId/rate')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Rate autofill accuracy for a session (improves future mappings)',
  })
  @ApiParam({ name: 'sessionId' })
  async rateSession(
    @CurrentUser() user: { id: string },
    @Param('sessionId') sessionId: string,
    @Body() dto: RateSessionDto,
  ) {
    const result = await this.mappingService.rateSession(
      sessionId,
      user.id,
      dto.accuracy,
      dto.feedback,
    );
    return { success: true, data: result };
  }
}
