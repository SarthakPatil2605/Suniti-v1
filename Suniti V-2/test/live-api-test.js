/**
 * Suniti CRM - Milestone 5 Live API Integration & Contract Verification Test Suite
 * Executes real HTTP requests against the live running backend on http://localhost:5000.
 */

import assert from 'node:assert/strict';

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:5000';

console.log(`\n===============================================================`);
console.log(`🚀 SUNITI CRM MILESTONE 5: LIVE API INTEGRATION TEST SUITE`);
console.log(`📡 Target Backend: ${BASE_URL}`);
console.log(`===============================================================\n`);

let passed = 0;
let failed = 0;
const results = [];

async function runTest(category, name, fn) {
  try {
    await fn();
    console.log(`  ✅ [PASS] ${category} > ${name}`);
    passed++;
    results.push({ category, name, status: 'PASS' });
  } catch (err) {
    console.error(`  ❌ [FAIL] ${category} > ${name}`);
    console.error(`     Reason: ${err.message}`);
    failed++;
    results.push({ category, name, status: 'FAIL', error: err.message });
  }
}

async function api(path, options = {}) {
  const url = `${BASE_URL}${path}`;
  const headers = {
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };
  const fetchOpts = {
    method: options.method || 'GET',
    headers,
  };
  if (options.body) {
    fetchOpts.body = typeof options.body === 'string' ? options.body : JSON.stringify(options.body);
  }
  const res = await fetch(url, fetchOpts);
  let data;
  const contentType = res.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    data = await res.json();
  } else {
    data = await res.text();
  }
  return { status: res.status, headers: res.headers, data };
}

async function run() {
  let adminToken = '';
  let managerToken = '';
  let salesToken = '';
  let adminUser = null;
  let managerUser = null;
  let salesUser = null;

  // -----------------------------------------------------------------
  // 1. Health & Server Connectivity
  // -----------------------------------------------------------------
  await runTest('System', 'Health check returns 200 with healthy database', async () => {
    const res = await api('/health');
    assert.equal(res.status, 200);
    assert.equal(res.data.status, 'healthy');
    assert.equal(res.data.database.ok, true);
  });

  // -----------------------------------------------------------------
  // 2. Authentication & RBAC
  // -----------------------------------------------------------------
  await runTest('Auth', 'POST /api/auth/login validates invalid credentials', async () => {
    const res = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'admin@suniticonstruction.com', password: 'WrongPassword123' },
    });
    assert.equal(res.status, 401);
  });

  await runTest('Auth', 'POST /api/auth/login authenticates ADMIN and issues JWT', async () => {
    const res = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'admin@suniticonstruction.com', password: 'Admin@Suniti2026' },
    });
    assert.equal(res.status, 200);
    assert.ok(res.data.token);
    assert.equal(res.data.user.role, 'ADMIN');
    adminToken = res.data.token;
    adminUser = res.data.user;
  });

  await runTest('Auth', 'POST /api/auth/login authenticates MANAGER and issues JWT', async () => {
    const res = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'priya.manager@suniticonstruction.com', password: 'Manager@Suniti2026' },
    });
    assert.equal(res.status, 200);
    assert.ok(res.data.token);
    assert.equal(res.data.user.role, 'MANAGER');
    managerToken = res.data.token;
    managerUser = res.data.user;
  });

  await runTest('Auth', 'POST /api/auth/login authenticates SALES_REP and issues JWT', async () => {
    const res = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'rahul.sales@suniticonstruction.com', password: 'Sales@Suniti2026' },
    });
    assert.equal(res.status, 200);
    assert.ok(res.data.token);
    assert.equal(res.data.user.role, 'SALES_REP');
    salesToken = res.data.token;
    salesUser = res.data.user;
  });

  await runTest('Auth', 'GET /api/auth/me returns current user profile with valid JWT', async () => {
    const res = await api('/api/auth/me', {
      headers: { Authorization: `Bearer ${salesToken}` },
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.employee.email, 'rahul.sales@suniticonstruction.com');
    assert.equal(res.data.employee.role, 'SALES_REP');
  });

  await runTest('Auth', 'GET /api/auth/me rejects missing or invalid JWT', async () => {
    const res = await api('/api/auth/me', {
      headers: { Authorization: 'Bearer invalid.token.value' },
    });
    assert.equal(res.status, 401);
  });

  // -----------------------------------------------------------------
  // 3. Customer Workflows
  // -----------------------------------------------------------------
  await runTest('Customers', 'GET /api/customers fetches customer list with authorization', async () => {
    const res = await api('/api/customers', {
      headers: { Authorization: `Bearer ${salesToken}` },
    });
    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.data.customers));
    assert.ok(res.data.customers.length >= 1);
  });

  await runTest('Customers', 'GET /api/customers/existing returns tier counts (PREMIUM, LOYAL, INTERIOR_DESIGNER)', async () => {
    const res = await api('/api/customers/existing', {
      headers: { Authorization: `Bearer ${salesToken}` },
    });
    assert.equal(res.status, 200);
    assert.ok('counts' in res.data);
    assert.ok('PREMIUM' in res.data.counts);
    assert.ok('LOYAL' in res.data.counts);
    assert.ok('INTERIOR_DESIGNER' in res.data.counts);
  });

  await runTest('Customers', 'GET /api/customers?customer_type=NEW filters new leads correctly', async () => {
    const res = await api('/api/customers?customer_type=NEW', {
      headers: { Authorization: `Bearer ${salesToken}` },
    });
    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.data.customers));
    for (const c of res.data.customers) {
      assert.equal(c.customer_type, 'NEW');
    }
  });

  await runTest('Customers', 'GET /api/customers?location=Worli filters by location correctly', async () => {
    const res = await api('/api/customers?location=Worli', {
      headers: { Authorization: `Bearer ${salesToken}` },
    });
    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.data.customers));
    assert.ok(res.data.customers.length >= 1);
  });

  let createdNewCustomerId = null;
  let createdInitialOppId = null;

  await runTest('Customers', 'POST /api/customers/new creates NEW customer, initial opportunity and task in one transaction', async () => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);

    const payload = {
      name: 'Test Acme Corp Highrise',
      phone: '+919999888877',
      billing_address: 'Plot 42, Bandra Kurla Complex, Mumbai',
      project_title: 'Commercial HQ Glass Facade',
      location_name: 'BKC, Mumbai',
      lead_temperature: 'HOT',
      next_call_date: tomorrow.toISOString(),
      conclusion_notes: 'Spoke with lead architect, blueprint review pending.',
    };

    const res = await api('/api/customers/new', {
      method: 'POST',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: payload,
    });

    assert.equal(res.status, 201);
    assert.ok(res.data.customer);
    assert.ok(res.data.opportunity);
    assert.equal(res.data.customer.name, 'Test Acme Corp Highrise');
    assert.equal(res.data.customer.customer_type, 'NEW');
    assert.equal(res.data.opportunity.project_title, 'Commercial HQ Glass Facade');
    assert.equal(res.data.opportunity.lead_temperature, 'HOT');
    assert.equal(res.data.opportunity.project_phase, 'TALKING');
    assert.equal(res.data.opportunity.deal_status, 'PIPELINE');

    createdNewCustomerId = res.data.customer.customer_id;
    createdInitialOppId = res.data.opportunity.opportunity_id;
  });

  // -----------------------------------------------------------------
  // 4. Opportunity Workflows
  // -----------------------------------------------------------------
  let secondOppId = null;
  let thirdOppId = null;

  await runTest('Opportunities', 'POST /api/opportunities creates a new opportunity for existing customer', async () => {
    const payload = {
      customer_id: 1, // Oberoi Sky Heights Interiors
      project_title: 'Penthouse Interior Woodwork',
      location_name: 'Worli, Mumbai',
      lead_temperature: 'WARM',
      deal_status: 'PIPELINE',
    };

    const res = await api('/api/opportunities', {
      method: 'POST',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: payload,
    });

    assert.equal(res.status, 201);
    const opp = res.data.opportunity || res.data.data;
    assert.ok(opp);
    assert.equal(opp.project_title, 'Penthouse Interior Woodwork');
    assert.equal(opp.lead_temperature, 'WARM');
    secondOppId = opp.opportunity_id;
  });

  await runTest('Opportunities', 'GET /api/opportunities fetches list of pipeline opportunities', async () => {
    const res = await api('/api/opportunities?deal_status=PIPELINE', {
      headers: { Authorization: `Bearer ${salesToken}` },
    });
    assert.equal(res.status, 200);
    const list = res.data.opportunities || res.data.data;
    assert.ok(Array.isArray(list));
    assert.ok(list.length >= 2);
  });

  await runTest('Opportunities', 'PATCH /api/opportunities/:id/status updates lead temperature', async () => {
    const res = await api(`/api/opportunities/${secondOppId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: { lead_temperature: 'HOT' },
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.opportunity.lead_temperature, 'HOT');
  });

  await runTest('Opportunities', 'PATCH /api/opportunities/:id/status closes lead as CLOSED_WON and graduates NEW customer to EXISTING with tier', async () => {
    const res = await api(`/api/opportunities/${createdInitialOppId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: {
        deal_status: 'CLOSED_WON',
        tier: 'PREMIUM',
        conclusion_notes: 'Deal finalized after board approval.',
      },
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.opportunity.deal_status, 'CLOSED_WON');
    assert.equal(res.data.opportunity.project_phase, 'DEAL_CLOSED');
    assert.equal(res.data.opportunity.is_completed, true);
    assert.equal(res.data.customer.customer_type, 'EXISTING');
    assert.equal(res.data.customer.tier, 'PREMIUM');
  });

  await runTest('Opportunities', 'Opportunity closure supports CLOSED_LOST with closure_reason', async () => {
    // Create an opportunity for testing CLOSED_LOST
    const createRes = await api('/api/opportunities', {
      method: 'POST',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: {
        customer_id: 1,
        project_title: 'Clubhouse Renovation Project',
        location_name: 'Worli',
      },
    });
    const opp = createRes.data.opportunity || createRes.data.data;
    const testId = opp.opportunity_id;

    const res = await api(`/api/opportunities/${testId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: {
        deal_status: 'CLOSED_LOST',
        closure_reason: 'Client selected competitor due to timeline',
        conclusion_notes: 'Competitor promised 20% faster delivery.',
      },
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.opportunity.deal_status, 'CLOSED_LOST');
    assert.equal(res.data.opportunity.is_completed, true);
    assert.equal(res.data.opportunity.closure_reason, 'Client selected competitor due to timeline');
  });

  await runTest('Opportunities', 'Opportunity closure supports OTHER with closure_reason', async () => {
    // Create an opportunity for testing OTHER
    const createRes = await api('/api/opportunities', {
      method: 'POST',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: {
        customer_id: 1,
        project_title: 'Suburban Office Park',
        location_name: 'Thane',
      },
    });
    const opp = createRes.data.opportunity || createRes.data.data;
    const testId = opp.opportunity_id;

    const res = await api(`/api/opportunities/${testId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: {
        deal_status: 'OTHER',
        closure_reason: 'Project cancelled due to municipal zoning delay',
        conclusion_notes: 'Client putting site on hold for 12 months.',
      },
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.opportunity.deal_status, 'OTHER');
    assert.equal(res.data.opportunity.is_completed, true);
    assert.equal(res.data.opportunity.closure_reason, 'Project cancelled due to municipal zoning delay');
  });

  // -----------------------------------------------------------------
  // 5. Today's Calls & Task Workflows
  // -----------------------------------------------------------------
  let scheduledTaskId = null;

  await runTest("Today's Tasks", "Schedule a task for today and fetch GET /api/tasks/today (Asia/Kolkata boundaries)", async () => {
    // Schedule a task for today's IST date on secondOppId
    const now = new Date();
    const todayRes = await api(`/api/opportunities/${secondOppId}/notes`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: {
        conclusion_notes: 'Call customer regarding quotation revision.',
        next_call_date: now.toISOString(),
      },
    });
    assert.equal(todayRes.status, 201);
    scheduledTaskId = todayRes.data.note.note_id;

    // Fetch today tasks
    const res = await api('/api/tasks/today', {
      headers: { Authorization: `Bearer ${salesToken}` },
    });

    assert.equal(res.status, 200);
    assert.ok('tasks' in res.data);
    assert.ok(Array.isArray(res.data.tasks));
    assert.ok(res.data.tasks.length >= 1);

    const found = res.data.tasks.find((t) => t.task_id === scheduledTaskId || t.note_id === scheduledTaskId);
    assert.ok(found, `Expected task ${scheduledTaskId} in today queue`);
    assert.equal(found.is_completed, false);
    assert.ok(found.company_name);
  });

  await runTest("Today's Tasks", 'PATCH /api/tasks/:id/complete completes task with conclusion notes & chained follow-up', async () => {
    const nextWeek = new Date();
    nextWeek.setDate(nextWeek.getDate() + 7);

    const res = await api(`/api/tasks/${scheduledTaskId}/complete`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: {
        conclusion_notes: 'Customer accepted revisions, scheduled next check-in.',
        lead_temperature: 'HOT',
        next_call_date: nextWeek.toISOString(),
      },
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.task.is_completed, true);
    assert.equal(res.data.task.completed_by, salesUser.employee_id);
    assert.ok(res.data.task.completed_at);
  });

  // -----------------------------------------------------------------
  // 6. Blocklist & Role Permissions (ADMIN, MANAGER, SALES_REP)
  // -----------------------------------------------------------------
  await runTest('Permissions', 'SALES_REP cannot toggle customer blocklist (403 Forbidden)', async () => {
    const res = await api('/api/admin/customers/1/blocklist', {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: { is_blocklisted: true },
    });
    assert.equal(res.status, 403);
  });

  await runTest('Permissions', 'MANAGER can toggle customer blocklist', async () => {
    const res = await api('/api/admin/customers/1/blocklist', {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${managerToken}` },
      body: { is_blocklisted: true },
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.customer.is_blocklisted, true);
  });

  await runTest('Permissions', 'ADMIN can unblock customer', async () => {
    const res = await api('/api/admin/customers/1/blocklist', {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { is_blocklisted: false },
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.customer.is_blocklisted, false);
  });

  // -----------------------------------------------------------------
  // 7. Data Integrity, Validations & Error Handling
  // -----------------------------------------------------------------
  await runTest('Integrity', 'Invalid non-integer customer ID yields 400 Bad Request', async () => {
    const res = await api('/api/customers/not-an-integer/opportunities', {
      headers: { Authorization: `Bearer ${salesToken}` },
    });
    assert.equal(res.status, 400);
  });

  await runTest('Integrity', 'POST /api/customers/new rejects missing project_title without partial customer creation', async () => {
    const res = await api('/api/customers/new', {
      method: 'POST',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: {
        name: 'Should Not Be Created Corp',
        billing_address: 'Ghost Address',
      },
    });
    assert.equal(res.status, 400);

    // Verify it was not created
    const searchRes = await api('/api/customers?location=Ghost Address', {
      headers: { Authorization: `Bearer ${salesToken}` },
    });
    const found = searchRes.data.customers?.find((c) => c.name === 'Should Not Be Created Corp');
    assert.equal(found, undefined, 'Orphaned customer must not exist after validation failure');
  });

  await runTest('Integrity', 'Non-existent opportunity status update returns 404', async () => {
    const res = await api('/api/opportunities/9999999/status', {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${salesToken}` },
      body: { deal_status: 'CLOSED_LOST' },
    });
    assert.equal(res.status, 404);
  });

  // -----------------------------------------------------------------
  // Summary
  // -----------------------------------------------------------------
  console.log(`\n===============================================================`);
  console.log(`🏁 LIVE INTEGRATION TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log(`===============================================================\n`);

  if (failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

run().catch((err) => {
  console.error('Fatal Test Suite Error:', err);
  process.exit(1);
});
