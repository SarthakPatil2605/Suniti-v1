import test, { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import createApp from '../src/app.js';
import { signToken } from '../src/utils/jwt.js';
import { pool } from '../src/config/db.js';

describe('Customer & Opportunity Hierarchy API Tests', () => {
  let server;
  let baseUrl;
  let authToken;

  before(async () => {
    const app = createApp();
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://127.0.0.1:${port}`;
        resolve();
      });
    });

    // Create a valid Sales Rep token for requests
    authToken = signToken({
      employee_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
      name: 'Priya Patil',
      role: 'SALES_REP',
      email: 'priya.patil@suniticonstruction.com',
    });
  });

  after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await pool.end();
  });

  // --------------------------------------------------------------------------
  // 1. GET /api/customers/existing
  // --------------------------------------------------------------------------
  describe('GET /api/customers/existing', () => {
    it('should reject unauthenticated requests with 401', async () => {
      const res = await fetch(`${baseUrl}/api/customers/existing`);
      assert.equal(res.status, 401);
    });

    it('should return existing customers grouped by tier and company name', async () => {
      const res = await fetch(`${baseUrl}/api/customers/existing`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      assert.equal(res.status, 200);
      const body = await res.json();

      assert.equal(body.success, true);
      assert.ok(body.data.PREMIUM, 'Should have PREMIUM tier group');
      assert.ok(body.data.LOYAL, 'Should have LOYAL tier group');
      assert.ok(body.data.INTERIOR_DESIGNER, 'Should have INTERIOR_DESIGNER tier group');

      // Check seed data presence
      const hasPremium = body.data.PREMIUM.some((c) => c.name.includes('Vikas Oberoi'));
      assert.equal(hasPremium, true, 'PREMIUM group should contain Vikas Oberoi Enterprises');

      const hasLoyal = body.data.LOYAL.some((c) => c.name.includes('Rajesh Kulkarni'));
      assert.equal(hasLoyal, true, 'LOYAL group should contain Rajesh Kulkarni');

      const hasDesigner = body.data.INTERIOR_DESIGNER.some((c) => c.name.includes('Studio DesignWorks'));
      assert.equal(hasDesigner, true, 'INTERIOR_DESIGNER group should contain Studio DesignWorks');
    });
  });

  // --------------------------------------------------------------------------
  // 2. GET /api/customers/:companyId/opportunities
  // --------------------------------------------------------------------------
  describe('GET /api/customers/:companyId/opportunities', () => {
    it('should return 400 for invalid UUID companyId', async () => {
      const res = await fetch(`${baseUrl}/api/customers/invalid-id/opportunities`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      assert.equal(res.status, 400);
      const body = await res.json();
      assert.match(body.message, /valid UUID/);
    });

    it('should return 404 for non-existent companyId', async () => {
      const nonExistentId = '00000000-0000-0000-0000-000000000000';
      const res = await fetch(`${baseUrl}/api/customers/${nonExistentId}/opportunities`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      assert.equal(res.status, 404);
    });

    it('should return plant locations/opportunities for a specific company', async () => {
      const vikasOberoiId = 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55';
      const res = await fetch(`${baseUrl}/api/customers/${vikasOberoiId}/opportunities`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      assert.equal(res.status, 200);
      const body = await res.json();

      assert.equal(body.success, true);
      assert.equal(body.company.name, 'Vikas Oberoi Enterprises');
      assert.ok(Array.isArray(body.opportunities));
      assert.ok(body.opportunities.length >= 1);
      assert.equal(body.opportunities[0].location_name, 'Mumbai');
    });
  });

  // --------------------------------------------------------------------------
  // 3. POST /api/customers/new & Rule 1 (Auto-schedule)
  // --------------------------------------------------------------------------
  describe('POST /api/customers/new', () => {
    it('should validate required fields', async () => {
      const res = await fetch(`${baseUrl}/api/customers/new`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ name: 'Incomplete Client' }),
      });
      assert.equal(res.status, 400);
      const body = await res.json();
      assert.match(body.message, /Project title is required/);
    });

    it('Rule 1: should auto-schedule next_call_date to ~30 days ahead when null/empty', async () => {
      const beforeTime = Date.now();

      const res = await fetch(`${baseUrl}/api/customers/new`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: 'Apex Horizon Developers',
          phone: '+91-9988776655',
          billing_address: 'Kalyani Nagar, Pune',
          project_title: 'Corporate Tower Glass Facade',
          location_name: 'Pune',
          lead_temperature: 'HOT',
          conclusion_notes: 'Client requested architectural blueprint review.',
          // next_call_date intentionally omitted to test Rule 1
        }),
      });

      assert.equal(res.status, 201);
      const body = await res.json();

      assert.equal(body.success, true);
      assert.equal(body.customer.name, 'Apex Horizon Developers');
      assert.equal(body.customer.customer_type, 'NEW');
      assert.equal(body.customer.tier, null);

      assert.equal(body.opportunity.project_title, 'Corporate Tower Glass Facade');
      assert.equal(body.opportunity.deal_status, 'PIPELINE');
      assert.equal(body.opportunity.location_name, 'Pune');

      // Verify Rule 1: Auto-scheduled date is ~30 days from now
      assert.ok(body.lead_note.next_call_date, 'next_call_date should not be null');
      const scheduledMs = new Date(body.lead_note.next_call_date).getTime();
      const diffDays = (scheduledMs - beforeTime) / (1000 * 60 * 60 * 24);
      assert.ok(diffDays >= 29 && diffDays <= 31, `Difference should be approx 30 days, got ${diffDays.toFixed(2)}`);
    });
  });

  // --------------------------------------------------------------------------
  // 4. PATCH /api/opportunities/:id/status & Rule 2 (Deal Closure Migration)
  // --------------------------------------------------------------------------
  describe('PATCH /api/opportunities/:id/status', () => {
    let newCustomerId;
    let newOpportunityId;

    // Create a new prospect and opportunity for Rule 2 testing
    before(async () => {
      const createRes = await fetch(`${baseUrl}/api/customers/new`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: 'Zenith Infra Projects',
          project_title: 'Warehouse Structural Shed',
          location_name: 'Pimpri',
          lead_temperature: 'WARM',
        }),
      });

      const data = await createRes.json();
      newCustomerId = data.customer.customer_id;
      newOpportunityId = data.opportunity.opportunity_id;
    });

    it('should reject invalid deal_status value with 400', async () => {
      const res = await fetch(`${baseUrl}/api/opportunities/${newOpportunityId}/status`, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ deal_status: 'INVALID_STATUS' }),
      });
      assert.equal(res.status, 400);
      const body = await res.json();
      assert.match(body.message, /Invalid deal_status/);
    });

    it('Rule 2: should reject CLOSED_WON if customer is NEW and tier is missing', async () => {
      const res = await fetch(`${baseUrl}/api/opportunities/${newOpportunityId}/status`, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          deal_status: 'CLOSED_WON',
          // tier omitted
        }),
      });

      assert.equal(res.status, 400);
      const body = await res.json();
      assert.match(body.message, /customer tier.*required/i);
    });

    it('Rule 2: should reject CLOSED_WON with invalid tier', async () => {
      const res = await fetch(`${baseUrl}/api/opportunities/${newOpportunityId}/status`, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          deal_status: 'CLOSED_WON',
          tier: 'GOLD_VIP_INVALID',
        }),
      });

      assert.equal(res.status, 400);
    });

    it('Rule 2: should successfully close deal as WON, migrate customer to EXISTING, and assign tier', async () => {
      const res = await fetch(`${baseUrl}/api/opportunities/${newOpportunityId}/status`, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          deal_status: 'CLOSED_WON',
          tier: 'PREMIUM',
          conclusion_notes: 'Advance milestone received and agreement signed.',
        }),
      });

      assert.equal(res.status, 200);
      const body = await res.json();

      assert.equal(body.success, true);
      assert.equal(body.opportunity.deal_status, 'CLOSED_WON');

      // Verify Rule 2: Parent customer migrated to EXISTING with tier PREMIUM
      assert.ok(body.customer);
      assert.equal(body.customer.customer_type, 'EXISTING');
      assert.equal(body.customer.tier, 'PREMIUM');

      // Verify customer now appears in /api/customers/existing under PREMIUM
      const existingRes = await fetch(`${baseUrl}/api/customers/existing`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      const existingBody = await existingRes.json();
      const graduatedCustomer = existingBody.data.PREMIUM.find((c) => c.customer_id === newCustomerId);
      assert.ok(graduatedCustomer, 'Graduated customer must now appear under PREMIUM existing customers');
      assert.equal(graduatedCustomer.name, 'Zenith Infra Projects');
    });
  });
});
