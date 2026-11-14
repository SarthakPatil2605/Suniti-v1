import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

/**
 * Prisma Client Singleton Instance
 *
 * Prevents multiple PrismaClient instances during hot-reloading in development
 * (such as nodemon restarts) and prevents exhausting database connection limits
 * on Supabase PostgreSQL.
 */
const globalForPrisma = globalThis;

const rawPrisma =
  globalForPrisma.prismaInstance ||
  new PrismaClient({
    log:
      process.env.NODE_ENV === 'development'
        ? ['warn', 'error']
        : ['error'],
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prismaInstance = rawPrisma;
}

/**
 * Proxy wrapper providing natural model aliases:
 * - prisma.employees  -> prisma.employee
 * - prisma.customers  -> prisma.customer
 * - prisma.opportunities -> prisma.opportunity
 * - prisma.lead_notes / prisma.tasks -> prisma.leadNote
 */
export const prisma = new Proxy(rawPrisma, {
  get(target, prop, receiver) {
    if (prop === 'employees') return target.employee;
    if (prop === 'customers') return target.customer;
    if (prop === 'opportunities') return target.opportunity;
    if (prop === 'lead_notes' || prop === 'leadNotes' || prop === 'tasks') {
      return target.leadNote;
    }
    return Reflect.get(target, prop, receiver);
  },
});

/**
 * Helper to verify database connectivity
 */
export async function testDatabaseConnection() {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return { ok: true, message: 'Database connection verified' };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

export default prisma;
