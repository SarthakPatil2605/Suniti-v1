import test, { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import createApp from '../src/app.js';
import { signToken } from '../src/utils/jwt.js';
import { pool } from '../src/config/db.js';

describe('Admin Management API Tests (verifyAdmin RBAC)', () => {
  let server;
  let baseUrl;
  let adminToken;
  let salesRepToken;
  const adminId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'; // Rahul Sharma (ADMIN)
  const salesRepId = 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22'; // Priya Patil (SALES_REP)

  before(async () => {
    const app = createApp();
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://127.0.0.1:${port}`;
        resolve();
      });
    });

    adminToken = signToken({
      employee_id: adminId,
      name: 'Rahul Sharma',
      role: 'ADMIN',
      email: 'rahul.admin@suniticonstruction.com',
    });

    salesRepToken = signToken({
      employee_id: salesRepId,
      name: 'Priya Patil',
      role: 'SALES_REP',
      email: 'priya.patil@suniticonstruction.com',
    });
  });

  after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await pool.end();
  });

  // ==========================================================================
  // 1. RBAC PERMISSIONS ON ADMIN ROUTES
  // ==========================================================================
  describe('RBAC Authorization Guard', () => {
    it('should reject unauthenticated request with 401', async () => {
      const res = await fetch(`${baseUrl}/api/admin/employees`);
      assert.equal(res.status, 401);
    });

    it('should reject SALES_REP role with 403 Forbidden', async () => {
      const res = await fetch(`${baseUrl}/api/admin/employees`, {
        headers: { Authorization: `Bearer ${salesRepToken}` },
      });
      assert.equal(res.status, 403);
      const data = await res.json();
      assert.match(data.message, /Requires ADMIN role/);
    });
  });

  // ==========================================================================
  // 2. EMPLOYEES CRUD
  // ==========================================================================
  describe('Employees CRUD', () => {
    let createdStaffId;

    it('GET /api/admin/employees should list all employees omitting password_hash', async () => {
      const res = await fetch(`${baseUrl}/api/admin/employees`, {
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      assert.equal(res.status, 200);
      const data = await res.json();

      assert.equal(data.success, true);
      assert.ok(data.total_employees >= 2);
      assert.ok(Array.isArray(data.employees));

      // Assert password_hash is never leaked
      for (const emp of data.employees) {
        assert.equal(emp.password_hash, undefined);
      }
    });

    it('POST /api/admin/employees should create new employee/sales rep', async () => {
      const res = await fetch(`${baseUrl}/api/admin/employees`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: 'Rohan Shinde',
          email: 'rohan.shinde@suniticonstruction.com',
          password: 'TemporaryPassword@123',
          role: 'SALES_REP',
        }),
      });

      assert.equal(res.status, 201);
      const data = await res.json();

      assert.equal(data.success, true);
      assert.equal(data.employee.name, 'Rohan Shinde');
      assert.equal(data.employee.email, 'rohan.shinde@suniticonstruction.com');
      assert.equal(data.employee.role, 'SALES_REP');
      assert.equal(data.employee.password_hash, undefined);

      createdStaffId = data.employee.employee_id;
    });

    it('POST /api/admin/employees should reject duplicate email with 409', async () => {
      const res = await fetch(`${baseUrl}/api/admin/employees`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: 'Duplicate Rohan',
          email: 'rohan.shinde@suniticonstruction.com',
          password: 'Password@123',
          role: 'SALES_REP',
        }),
      });

      assert.equal(res.status, 409);
      const data = await res.json();
      assert.match(data.message, /already exists/);
    });

    it('PUT /api/admin/employees/:id should update employee role or details', async () => {
      const res = await fetch(`${baseUrl}/api/admin/employees/${createdStaffId}`, {
        method: 'PUT',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: 'Rohan M. Shinde',
          role: 'ADMIN',
        }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();

      assert.equal(data.success, true);
      assert.equal(data.employee.name, 'Rohan M. Shinde');
      assert.equal(data.employee.role, 'ADMIN');
    });

    it('DELETE /api/admin/employees/:id should prevent admin self-deletion', async () => {
      const res = await fetch(`${baseUrl}/api/admin/employees/${adminId}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${adminToken}` },
      });

      assert.equal(res.status, 400);
      const data = await res.json();
      assert.match(data.message, /cannot delete your own active administrator account/i);
    });

    it('DELETE /api/admin/employees/:id should delete employee', async () => {
      const res = await fetch(`${baseUrl}/api/admin/employees/${createdStaffId}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${adminToken}` },
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.deleted_employee_id, createdStaffId);

      // Verify employee no longer in database
      const checkRes = await fetch(`${baseUrl}/api/admin/employees`, {
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      const checkData = await checkRes.json();
      const exists = checkData.employees.some((e) => e.employee_id === createdStaffId);
      assert.equal(exists, false);
    });
  });

  // ==========================================================================
  // 3. CUSTOMER & RECORD OVERRIDE CRUD
  // ==========================================================================
  describe('Customer & Opportunity Record Overrides', () => {
    let customerId;
    let opportunityId;

    before(async () => {
      // Create a test customer & opportunity
      const createRes = await fetch(`${baseUrl}/api/customers/new`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: 'Vanguard Realty Corp',
          phone: '+91-9876500000',
          billing_address: 'Senapati Bapat Road, Pune',
          project_title: 'Erroneous Test Bid',
          location_name: 'Pune',
          lead_temperature: 'COLD',
        }),
      });

      const data = await createRes.json();
      customerId = data.customer.customer_id;
      opportunityId = data.opportunity.opportunity_id;
    });

    it('PUT /api/admin/customers/:id should override customer details and tier', async () => {
      const res = await fetch(`${baseUrl}/api/admin/customers/${customerId}`, {
        method: 'PUT',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: 'Vanguard Global Realty Corp',
          customer_type: 'EXISTING',
          tier: 'INTERIOR_DESIGNER',
          phone: '+91-9876599999',
          billing_address: 'Koregaon Park, Pune',
        }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();

      assert.equal(data.success, true);
      assert.equal(data.customer.name, 'Vanguard Global Realty Corp');
      assert.equal(data.customer.customer_type, 'EXISTING');
      assert.equal(data.customer.tier, 'INTERIOR_DESIGNER');
      assert.equal(data.customer.phone, '+91-9876599999');
    });

    it('DELETE /api/admin/opportunities/:id should delete erroneous opportunity and cascade notes', async () => {
      const res = await fetch(`${baseUrl}/api/admin/opportunities/${opportunityId}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${adminToken}` },
      });

      assert.equal(res.status, 200);
      const data = await res.json();

      assert.equal(data.success, true);
      assert.equal(data.deleted_opportunity_id, opportunityId);

      // Verify opportunity is deleted
      const checkRes = await fetch(`${baseUrl}/api/customers/${customerId}/opportunities`, {
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      const checkData = await checkRes.json();
      assert.equal(checkData.total_opportunities, 0);
    });
  });

  // ==========================================================================
  // 4. BLOCKLIST MANAGEMENT
  // ==========================================================================
  describe('Blocklist Management', () => {
    let customerId;

    before(async () => {
      const createRes = await fetch(`${baseUrl}/api/customers/new`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: 'Defaulter Construction Pvt Ltd',
          project_title: 'Unpaid Commercial Shell',
          location_name: 'Pimpri',
        }),
      });

      const data = await createRes.json();
      customerId = data.customer.customer_id;
    });

    it('PATCH /api/admin/customers/:id/blocklist should place customer on blocklist', async () => {
      const res = await fetch(`${baseUrl}/api/admin/customers/${customerId}/blocklist`, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ is_blocklisted: true }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();

      assert.equal(data.success, true);
      assert.equal(data.customer.is_blocklisted, true);
      assert.match(data.message, /placed on the blocklist/i);
    });

    it('PATCH /api/admin/customers/:id/blocklist should toggle blocklist status when body is empty', async () => {
      const res = await fetch(`${baseUrl}/api/admin/customers/${customerId}/blocklist`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${adminToken}` },
      });

      assert.equal(res.status, 200);
      const data = await res.json();

      assert.equal(data.success, true);
      // Toggled from true -> false
      assert.equal(data.customer.is_blocklisted, false);
      assert.match(data.message, /removed from the blocklist/i);
    });
  });
});
