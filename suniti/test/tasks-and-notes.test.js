import test, { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import createApp from '../src/app.js';
import { signToken } from '../src/utils/jwt.js';
import { pool } from '../src/config/db.js';

describe('Daily Tasks and Call Logging API Tests', () => {
  let server;
  let baseUrl;
  let authToken;
  let employeeId = 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22'; // Priya Patil (SALES_REP)
  let testOpportunityId;
  let testNoteId;

  before(async () => {
    const app = createApp();
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://127.0.0.1:${port}`;
        resolve();
      });
    });

    authToken = signToken({
      employee_id: employeeId,
      name: 'Priya Patil',
      role: 'SALES_REP',
      email: 'priya.patil@suniticonstruction.com',
    });

    // Create a dedicated prospect customer & opportunity for this test suite
    const newCustRes = await fetch(`${baseUrl}/api/customers/new`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${authToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name: 'Prestige Metro Builders',
        phone: '+91-9123456789',
        billing_address: 'Shivaji Nagar, Pune',
        project_title: 'Commercial Plaza Structural Shell',
        location_name: 'Pune',
        lead_temperature: 'WARM',
        conclusion_notes: 'Initial blueprint submitted by lead architect.',
      }),
    });

    const custData = await newCustRes.json();
    testOpportunityId = custData.opportunity.opportunity_id;
    testNoteId = custData.lead_note.note_id;
  });

  after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await pool.end();
  });

  // --------------------------------------------------------------------------
  // 1. POST /api/opportunities/:id/notes
  // --------------------------------------------------------------------------
  describe('POST /api/opportunities/:id/notes', () => {
    it('should reject unauthenticated request with 401', async () => {
      const res = await fetch(`${baseUrl}/api/opportunities/${testOpportunityId}/notes`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ conclusion_notes: 'Spoke with chief engineer.' }),
      });
      assert.equal(res.status, 401);
    });

    it('should reject when conclusion_notes is missing', async () => {
      const res = await fetch(`${baseUrl}/api/opportunities/${testOpportunityId}/notes`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ next_call_date: new Date().toISOString() }),
      });
      assert.equal(res.status, 400);
      const data = await res.json();
      assert.match(data.message, /Conclusion notes are required/);
    });

    it('should add a conversation note with authenticated employee attribution and schedule next follow-up', async () => {
      const scheduledFollowUp = new Date();
      // Set scheduled follow-up to today's date for subsequent GET /api/tasks/today test
      scheduledFollowUp.setHours(14, 30, 0, 0);

      const res = await fetch(`${baseUrl}/api/opportunities/${testOpportunityId}/notes`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          conclusion_notes: 'Completed structural site survey. Client requested revised steel reinforcement estimate.',
          next_call_date: scheduledFollowUp.toISOString(),
          lead_temperature: 'HOT',
        }),
      });

      assert.equal(res.status, 201);
      const data = await res.json();

      assert.equal(data.success, true);
      assert.ok(data.note.note_id);
      assert.equal(data.note.opportunity_id, testOpportunityId);

      // Verify WHO made the call: extracted from JWT token
      assert.equal(data.note.employee_id, employeeId);
      assert.equal(data.note.logged_by.name, 'Priya Patil');
      assert.equal(data.note.logged_by.role, 'SALES_REP');

      // Verify temperature tracking updated to HOT
      assert.equal(data.opportunity.lead_temperature, 'HOT');

      // Save note_id for task completion test
      testNoteId = data.note.note_id;
    });
  });

  // --------------------------------------------------------------------------
  // 2. GET /api/tasks/today
  // --------------------------------------------------------------------------
  describe('GET /api/tasks/today', () => {
    it('should reject unauthenticated request with 401', async () => {
      const res = await fetch(`${baseUrl}/api/tasks/today`);
      assert.equal(res.status, 401);
    });

    it('should fetch all scheduled calls for today with company, location, contact, and prior history', async () => {
      const todayStr = new Date().toISOString().split('T')[0];
      const res = await fetch(`${baseUrl}/api/tasks/today?date=${todayStr}`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });

      assert.equal(res.status, 200);
      const data = await res.json();

      assert.equal(data.success, true);
      assert.ok(Array.isArray(data.tasks));
      assert.ok(data.total_tasks >= 1);

      // Locate our test task in today's task list
      const matchedTask = data.tasks.find((t) => t.task_id === testNoteId);
      assert.ok(matchedTask, 'Scheduled task must appear in today list');

      // Verify company name & location
      assert.equal(matchedTask.company_name, 'Prestige Metro Builders');
      assert.equal(matchedTask.location, 'Pune');

      // Verify contact details
      assert.equal(matchedTask.contact_details.phone, '+91-9123456789');
      assert.equal(matchedTask.contact_details.billing_address, 'Shivaji Nagar, Pune');

      // Verify opportunity details
      assert.equal(matchedTask.opportunity.project_title, 'Commercial Plaza Structural Shell');
      assert.equal(matchedTask.opportunity.lead_temperature, 'HOT');

      // Verify WHO scheduled the task
      assert.equal(matchedTask.scheduled_by.name, 'Priya Patil');

      // Verify prior conversation history is populated
      assert.ok(Array.isArray(matchedTask.prior_history));
      assert.ok(matchedTask.prior_history.length >= 1, 'Should include prior intake note in history');
      const priorNote = matchedTask.prior_history[0];
      assert.ok(priorNote.conclusion_notes.includes('blueprint submitted'));
    });
  });

  // --------------------------------------------------------------------------
  // 3. PATCH /api/tasks/:id/complete
  // --------------------------------------------------------------------------
  describe('PATCH /api/tasks/:id/complete', () => {
    it('should return 400 for invalid task UUID', async () => {
      const res = await fetch(`${baseUrl}/api/tasks/not-a-valid-uuid/complete`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${authToken}` },
      });
      assert.equal(res.status, 400);
    });

    it('should return 404 for non-existent task ID', async () => {
      const nonExistent = '00000000-0000-0000-0000-000000000000';
      const res = await fetch(`${baseUrl}/api/tasks/${nonExistent}/complete`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${authToken}` },
      });
      assert.equal(res.status, 404);
    });

    it('should mark task as completed and update tracking statuses', async () => {
      const nextFollowUpDate = new Date();
      nextFollowUpDate.setDate(nextFollowUpDate.getDate() + 7);

      const res = await fetch(`${baseUrl}/api/tasks/${testNoteId}/complete`, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          conclusion_notes: 'Phone call concluded. Client approved revised estimate.',
          lead_temperature: 'HOT',
          deal_status: 'PIPELINE',
          next_call_date: nextFollowUpDate.toISOString(),
        }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();

      assert.equal(data.success, true);
      assert.equal(data.task.is_completed, true);
      assert.ok(data.task.completed_at);
      assert.equal(data.task.completed_by, employeeId);

      // Verify tracking statuses updated on opportunity
      assert.equal(data.opportunity.lead_temperature, 'HOT');
      assert.equal(data.opportunity.deal_status, 'PIPELINE');

      // Verify subsequent follow-up note was scheduled
      assert.ok(data.next_follow_up);
      assert.equal(data.next_follow_up.is_completed, false);
      assert.equal(data.next_follow_up.employee_id, employeeId);
    });
  });
});
