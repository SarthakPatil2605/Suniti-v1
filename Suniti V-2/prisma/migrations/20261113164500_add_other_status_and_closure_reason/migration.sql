-- AlterEnum
ALTER TYPE "DealStatus" ADD VALUE 'OTHER';

-- AlterTable
ALTER TABLE "opportunities" ADD COLUMN "closure_reason" TEXT;
