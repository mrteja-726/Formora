import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { OcrService } from './ocr.service';
import { OcrController } from './ocr.controller';
import { OcrProcessor, OCR_QUEUE } from './ocr.processor';

@Module({
  imports: [BullModule.registerQueue({ name: OCR_QUEUE })],
  controllers: [OcrController],
  providers: [OcrService, OcrProcessor],
  // EncryptionService is provided globally via EncryptionModule (@Global)
  exports: [OcrService],
})
export class OcrModule {}
