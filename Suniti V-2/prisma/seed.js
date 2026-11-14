import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting Suniti Construction CRM database seed...');

  // 1. Seed initial admin user
  const adminPasswordHash = await bcrypt.hash('Admin@Suniti2026', 10);
  const admin = await prisma.employee.upsert({
    where: { email: 'admin@suniticonstruction.com' },
    update: {},
    create: {
      name: 'Admin User',
      email: 'admin@suniticonstruction.com',
      password_hash: adminPasswordHash,
      role: 'ADMIN',
    },
  });
  console.log(`👤 Admin Employee ready: ${admin.name} (${admin.email}, ID: ${admin.employee_id})`);

  // 2. Seed initial manager
  const managerPasswordHash = await bcrypt.hash('Manager@Suniti2026', 10);
  const manager = await prisma.employee.upsert({
    where: { email: 'priya.manager@suniticonstruction.com' },
    update: {},
    create: {
      name: 'Priya Manager',
      email: 'priya.manager@suniticonstruction.com',
      password_hash: managerPasswordHash,
      role: 'MANAGER',
    },
  });
  console.log(`👤 Manager Employee ready: ${manager.name} (${manager.email}, ID: ${manager.employee_id})`);

  // 3. Seed initial sales rep
  const salesPasswordHash = await bcrypt.hash('Sales@Suniti2026', 10);
  const salesRep = await prisma.employee.upsert({
    where: { email: 'rahul.sales@suniticonstruction.com' },
    update: {},
    create: {
      name: 'Rahul Sharma',
      email: 'rahul.sales@suniticonstruction.com',
      password_hash: salesPasswordHash,
      role: 'SALES_REP',
    },
  });
  console.log(`👤 Sales Rep ready: ${salesRep.name} (${salesRep.email}, ID: ${salesRep.employee_id})`);

  // 4. Seed sample customer
  const customer = await prisma.customer.create({
    data: {
      name: 'Oberoi Sky Heights Interiors',
      customer_type: 'EXISTING',
      tier: 'PREMIUM',
      phone: '+919876543210',
      billing_address: 'Tower 4, Worli, Mumbai, Maharashtra 400018',
      is_blocklisted: false,
    },
  });
  console.log(`🏢 Sample Customer created: ${customer.name} (ID: ${customer.customer_id})`);

  // 4. Seed sample opportunity
  const opportunity = await prisma.opportunity.create({
    data: {
      customer_id: customer.customer_id,
      employee_id: salesRep.employee_id,
      project_title: 'Luxury Villa Construction - Phase 2',
      location_name: 'Worli Sea Face, Mumbai',
      lead_temperature: 'HOT',
      deal_status: 'PIPELINE',
      project_phase: 'TALKING',
      is_completed: false,
    },
  });
  console.log(`💼 Sample Opportunity created: ${opportunity.project_title} (ID: ${opportunity.opportunity_id})`);

  // 5. Seed sample lead note / task
  const note = await prisma.leadNote.create({
    data: {
      opportunity_id: opportunity.opportunity_id,
      employee_id: salesRep.employee_id,
      conclusion_notes: 'Initial requirements gathered. Architectural blueprint review scheduled.',
      next_call_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000), // In 3 days
      is_completed: false,
    },
  });
  console.log(`📝 Sample Lead Note/Task created (ID: ${note.note_id})`);

  console.log('✅ Seeding completed successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Seeding error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
