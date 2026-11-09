-- CreateEnum
CREATE TYPE "EmployeeRole" AS ENUM ('ADMIN', 'MANAGER', 'SALES_REP');

-- CreateEnum
CREATE TYPE "CustomerType" AS ENUM ('NEW', 'EXISTING');

-- CreateEnum
CREATE TYPE "CustomerTier" AS ENUM ('PREMIUM', 'LOYAL', 'INTERIOR_DESIGNER');

-- CreateEnum
CREATE TYPE "LeadTemperature" AS ENUM ('HOT', 'WARM', 'COLD');

-- CreateEnum
CREATE TYPE "DealStatus" AS ENUM ('PIPELINE', 'CLOSED_WON', 'CLOSED_LOST');

-- CreateEnum
CREATE TYPE "ProjectPhase" AS ENUM ('TALKING', 'PROCESSING', 'DEAL_CLOSED');

-- CreateTable
CREATE TABLE "employees" (
    "employee_id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "role" "EmployeeRole" NOT NULL DEFAULT 'SALES_REP',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "employees_pkey" PRIMARY KEY ("employee_id")
);

-- CreateTable
CREATE TABLE "customers" (
    "customer_id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "customer_type" "CustomerType" NOT NULL DEFAULT 'NEW',
    "tier" "CustomerTier",
    "phone" TEXT,
    "billing_address" TEXT,
    "is_blocklisted" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "customers_pkey" PRIMARY KEY ("customer_id")
);

-- CreateTable
CREATE TABLE "opportunities" (
    "opportunity_id" SERIAL NOT NULL,
    "customer_id" INTEGER NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "project_title" TEXT NOT NULL,
    "location_name" TEXT,
    "lead_temperature" "LeadTemperature" NOT NULL DEFAULT 'WARM',
    "deal_status" "DealStatus" NOT NULL DEFAULT 'PIPELINE',
    "project_phase" "ProjectPhase" NOT NULL DEFAULT 'TALKING',
    "is_completed" BOOLEAN NOT NULL DEFAULT false,
    "completed_at" TIMESTAMP(3),
    "completed_by" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "opportunities_pkey" PRIMARY KEY ("opportunity_id")
);

-- CreateTable
CREATE TABLE "lead_notes" (
    "note_id" SERIAL NOT NULL,
    "opportunity_id" INTEGER NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "conclusion_notes" TEXT,
    "next_call_date" TIMESTAMP(3),
    "is_completed" BOOLEAN NOT NULL DEFAULT false,
    "completed_at" TIMESTAMP(3),
    "completed_by" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "lead_notes_pkey" PRIMARY KEY ("note_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "employees_email_key" ON "employees"("email");

-- CreateIndex
CREATE INDEX "customers_customer_type_idx" ON "customers"("customer_type");

-- CreateIndex
CREATE INDEX "customers_tier_idx" ON "customers"("tier");

-- CreateIndex
CREATE INDEX "customers_phone_idx" ON "customers"("phone");

-- CreateIndex
CREATE INDEX "opportunities_customer_id_idx" ON "opportunities"("customer_id");

-- CreateIndex
CREATE INDEX "opportunities_employee_id_idx" ON "opportunities"("employee_id");

-- CreateIndex
CREATE INDEX "opportunities_deal_status_idx" ON "opportunities"("deal_status");

-- CreateIndex
CREATE INDEX "opportunities_project_phase_idx" ON "opportunities"("project_phase");

-- CreateIndex
CREATE INDEX "opportunities_lead_temperature_idx" ON "opportunities"("lead_temperature");

-- CreateIndex
CREATE INDEX "lead_notes_opportunity_id_idx" ON "lead_notes"("opportunity_id");

-- CreateIndex
CREATE INDEX "lead_notes_employee_id_idx" ON "lead_notes"("employee_id");

-- CreateIndex
CREATE INDEX "lead_notes_next_call_date_idx" ON "lead_notes"("next_call_date");

-- CreateIndex
CREATE INDEX "lead_notes_is_completed_idx" ON "lead_notes"("is_completed");

-- AddForeignKey
ALTER TABLE "opportunities" ADD CONSTRAINT "opportunities_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("customer_id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "opportunities" ADD CONSTRAINT "opportunities_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("employee_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "opportunities" ADD CONSTRAINT "opportunities_completed_by_fkey" FOREIGN KEY ("completed_by") REFERENCES "employees"("employee_id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lead_notes" ADD CONSTRAINT "lead_notes_opportunity_id_fkey" FOREIGN KEY ("opportunity_id") REFERENCES "opportunities"("opportunity_id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lead_notes" ADD CONSTRAINT "lead_notes_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("employee_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lead_notes" ADD CONSTRAINT "lead_notes_completed_by_fkey" FOREIGN KEY ("completed_by") REFERENCES "employees"("employee_id") ON DELETE SET NULL ON UPDATE CASCADE;
