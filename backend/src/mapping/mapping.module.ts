import { Module } from '@nestjs/common';
import { MappingService } from './mapping.service';
import { AutofillController } from './autofill.controller';

@Module({
  controllers: [AutofillController],
  providers: [MappingService],
  exports: [MappingService],
})
export class MappingModule {}
