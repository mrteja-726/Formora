import {
  Controller,
  Get,
  Patch,
  Delete,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { JwtAuthGuard } from '../auth/guards/auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@ApiTags('Users')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller({ path: 'users', version: '1' })
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get current authenticated user' })
  async getMe(@CurrentUser() user: { id: string }) {
    return { success: true, data: await this.usersService.findById(user.id) };
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update current user (name, avatar)' })
  async updateMe(@CurrentUser() user: { id: string }, @Body() dto: UpdateUserDto) {
    return { success: true, data: await this.usersService.update(user.id, dto) };
  }

  @Delete('me')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Soft-delete account (30-day grace period)' })
  async deleteMe(@CurrentUser() user: { id: string }) {
    return { success: true, data: await this.usersService.softDelete(user.id) };
  }
}
