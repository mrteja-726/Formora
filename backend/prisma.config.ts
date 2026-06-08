// ============================================================
// Prisma Config (Prisma v7+)
// The DATABASE_URL is read directly by PrismaService via PrismaPg adapter
// This file is required for Prisma CLI commands (migrate, generate, etc.)
// ============================================================

import path from 'node:path';
import { defineConfig } from 'prisma/config';

export default defineConfig({
  schema: path.join('prisma', 'schema.prisma'),
});
