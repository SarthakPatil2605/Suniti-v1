import test, { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import createApp from '../src/app.js';
import { signToken } from '../src/utils/jwt.js';

describe('HTTP Route Integration Tests', () => {
  let server;
  let baseUrl;

  before(async () => {
    const app = createApp();
    await new Promise((resolve) => {
      // Listen on ephemeral port (0 selects an available system port)
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://127.0.0.1:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    await new Promise((resolve) => server.close(resolve));
  });

  it('GET /api/health should return UP status', async () => {
    const res = await fetch(`${baseUrl}/api/health`);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.status, 'UP');
  });

  it('POST /api/auth/login should return 400 when missing credentials', async () => {
    const res = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    assert.equal(res.status, 400);
    const data = await res.json();
    assert.equal(data.success, false);
    assert.match(data.message, /Email and password are required/);
  });

  it('GET /api/operational/pipeline should reject unauthenticated request with 401', async () => {
    const res = await fetch(`${baseUrl}/api/operational/pipeline`);
    assert.equal(res.status, 401);
    const data = await res.json();
    assert.equal(data.success, false);
  });

  it('GET /api/operational/pipeline should accept SALES_REP token', async () => {
    const repToken = signToken({
      employee_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
      name: 'Priya Patil',
      role: 'SALES_REP',
    });

    const res = await fetch(`${baseUrl}/api/operational/pipeline`, {
      headers: { Authorization: `Bearer ${repToken}` },
    });
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.success, true);
    assert.equal(data.accessLevel, 'EMPLOYEE_OPERATIONAL');
  });

  it('GET /api/admin/security-audit should reject SALES_REP with 403 Forbidden', async () => {
    const repToken = signToken({
      employee_id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
      name: 'Priya Patil',
      role: 'SALES_REP',
    });

    const res = await fetch(`${baseUrl}/api/admin/security-audit`, {
      headers: { Authorization: `Bearer ${repToken}` },
    });
    assert.equal(res.status, 403);
    const data = await res.json();
    assert.equal(data.success, false);
    assert.match(data.message, /Requires ADMIN role/);
  });

  it('GET /api/admin/security-audit should accept ADMIN token with 200 OK', async () => {
    const adminToken = signToken({
      employee_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      name: 'Rahul Sharma',
      role: 'ADMIN',
    });

    const res = await fetch(`${baseUrl}/api/admin/security-audit`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.success, true);
    assert.equal(data.accessLevel, 'ADMIN_EXCLUSIVE');
  });
});
