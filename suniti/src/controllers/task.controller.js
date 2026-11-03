import { query, getClient } from '../config/db.js';
import { isValidUuid } from '../utils/validators.js';

/**
 * Controller: Fetch Daily Tasks (Scheduled Calls for Today)
 * Route: GET /api/tasks/today
 * Query Params:
 *  - date: YYYY-MM-DD (defaults to current server date)
 *  - include_overdue: boolean ('true'/'false', defaults to false)
 */
export const getTodayTasks = async (req, res, next) => {
  try {
    const { date, include_overdue = 'false' } = req.query;

    let targetDate = new Date();
    if (date) {
      const parsed = new Date(date);
      if (!isNaN(parsed.getTime())) {
        targetDate = parsed;
      }
    }

    const startOfDay = new Date(targetDate);
    startOfDay.setHours(0, 0, 0, 0);

    const endOfDay = new Date(targetDate);
    endOfDay.setHours(23, 59, 59, 999);

    const isIncludeOverdue = include_overdue === 'true';

    // Query tasks matching today's scheduled calls (or overdue if requested)
    const sql = `
      SELECT 
        n.note_id AS task_id,
        n.opportunity_id,
        n.conclusion_notes AS task_instruction,
        n.next_call_date,
        o.is_completed,
        n.completed_at,
        n.created_at AS task_created_at,
        -- Scheduled by Employee
        n.employee_id AS scheduled_by_id,
        creator.name AS scheduled_by_name,
        creator.email AS scheduled_by_email,
        -- Completed by Employee
        n.completed_by AS completed_by_id,
        completer.name AS completed_by_name,
        -- Opportunity Details
        o.project_title,
        o.location_name,
        o.lead_temperature,
        o.deal_status,
        -- Customer Details
        c.customer_id,
        c.name AS company_name,
        c.customer_type,
        c.tier AS customer_tier,
        c.phone AS contact_phone,
        c.billing_address,
        -- Prior Conversation History (excluding current task note)
        COALESCE(
          (
            SELECT json_agg(
              json_build_object(
                'note_id', h.note_id,
                'conclusion_notes', h.conclusion_notes,
                'next_call_date', h.next_call_date,
                'is_completed', h.is_completed,
                'created_at', h.created_at,
                'recorded_by', he.name
              ) ORDER BY h.created_at DESC
            )
            FROM lead_notes h
            LEFT JOIN employees he ON h.employee_id = he.employee_id
            WHERE h.opportunity_id = o.opportunity_id AND h.note_id != n.note_id
          ),
          '[]'::json
        ) AS prior_history
      FROM lead_notes n
      JOIN opportunities o ON n.opportunity_id = o.opportunity_id
      JOIN customers c ON o.customer_id = c.customer_id
      LEFT JOIN employees creator ON n.employee_id = creator.employee_id
      LEFT JOIN employees completer ON n.completed_by = completer.employee_id
      WHERE (
        (n.next_call_date >= $1 AND n.next_call_date <= $2)
        ${isIncludeOverdue ? 'OR (n.next_call_date < $1 AND o.is_completed = FALSE)' : ''}
      )
      ORDER BY o.is_completed ASC, n.next_call_date ASC;
    `;

    const result = await query(sql, [startOfDay.toISOString(), endOfDay.toISOString()]);

    let pendingCount = 0;
    let completedCount = 0;

    const formattedTasks = result.rows.map((row) => {
      if (row.is_completed) completedCount++;
      else pendingCount++;

      return {
        task_id: row.task_id,
        company_name: row.company_name,
        location: row.location_name,
        contact_details: {
          customer_id: row.customer_id,
          phone: row.contact_phone,
          billing_address: row.billing_address,
          customer_type: row.customer_type,
          customer_tier: row.customer_tier,
        },
        opportunity: {
          opportunity_id: row.opportunity_id,
          project_title: row.project_title,
          lead_temperature: row.lead_temperature,
          deal_status: row.deal_status,
        },
        scheduled_call_date: row.next_call_date,
        task_instruction: row.task_instruction,
        is_completed: row.is_completed,
        completed_at: row.completed_at,
        scheduled_by: row.scheduled_by_id
          ? {
              employee_id: row.scheduled_by_id,
              name: row.scheduled_by_name,
              email: row.scheduled_by_email,
            }
          : null,
        completed_by: row.completed_by_id
          ? {
              employee_id: row.completed_by_id,
              name: row.completed_by_name,
            }
          : null,
        prior_history: row.prior_history,
      };
    });

    return res.status(200).json({
      success: true,
      query_date: startOfDay.toISOString().split('T')[0],
      total_tasks: result.rowCount,
      pending_tasks: pendingCount,
      completed_tasks: completedCount,
      tasks: formattedTasks,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Controller: Mark Daily Task as Done and Update Tracking Statuses
 * Route: PATCH /api/tasks/:id/complete
 * Body (Optional):
 *  - conclusion_notes: string
 *  - lead_temperature: 'HOT' | 'WARM' | 'COLD'
 *  - deal_status: 'PIPELINE' | 'CLOSED_WON' | 'CLOSED_LOST'
 *  - next_call_date: ISO timestamp
 */
export const completeTask = async (req, res, next) => {
  const { id } = req.params;
  const { conclusion_notes, lead_temperature, deal_status, next_call_date } = req.body || {};
  const employeeId = req.user?.employee_id || null;

 const taskId = parseInt(id, 10);
if (isNaN(taskId)) {
  return res.status(400).json({
    success: false,
    message: "Invalid task ID. Must be an integer."
  });
}

  const client = await getClient();

  try {
    // 1. Locate the task by note_id (or latest pending note for opportunity_id)
    let noteRes = await client.query(
      `SELECT n.*, o.customer_id, o.project_title
       FROM lead_notes n
       JOIN opportunities o ON n.opportunity_id = o.opportunity_id
       WHERE n.note_id = $1
       LIMIT 1`,
      [id]
    );

    if (noteRes.rows.length === 0) {
      // Fallback: check if id passed was opportunity_id
      noteRes = await client.query(
        `SELECT n.*, o.customer_id, o.project_title
         FROM lead_notes n
         JOIN opportunities o ON n.opportunity_id = o.opportunity_id
         WHERE n.opportunity_id = $1 AND o.is_completed = FALSE
         ORDER BY n.created_at DESC
         LIMIT 1`,
        [id]
      );
    }

    if (noteRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `Task with ID ${id} was not found.`,
      });
    }

    const task = noteRes.rows[0];
    const targetNoteId = task.note_id;
    const opportunityId = task.opportunity_id;

    await client.query('BEGIN');

    // 2. Mark task as completed
    const updatedNoteContent = conclusion_notes
      ? `${task.conclusion_notes} | Completion note: ${conclusion_notes.trim()}`
      : task.conclusion_notes;

    const taskUpdateRes = await client.query(
      `UPDATE lead_notes
       SET is_completed = TRUE,
           completed_at = CURRENT_TIMESTAMP,
           completed_by = $1,
           conclusion_notes = $2
       WHERE note_id = $3
       RETURNING note_id, opportunity_id, employee_id, conclusion_notes, next_call_date, is_completed, completed_at, completed_by`,
      [employeeId, updatedNoteContent, targetNoteId]
    );
    const completedTask = taskUpdateRes.rows[0];

    // 3. Update Opportunity Tracking Statuses if provided
    let updatedOpportunity = null;
    const updates = [];
    const values = [];
    let idx = 1;

    if (lead_temperature) {
      const allowedTemps = ['HOT', 'WARM', 'COLD'];
      if (!allowedTemps.includes(lead_temperature)) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          success: false,
          message: `Invalid lead_temperature. Allowed values: ${allowedTemps.join(', ')}.`,
        });
      }
      updates.push(`lead_temperature = $${idx++}`);
      values.push(lead_temperature);
    }

    if (deal_status) {
      const allowedStatuses = ['PIPELINE', 'CLOSED_WON', 'CLOSED_LOST'];
      if (!allowedStatuses.includes(deal_status)) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          success: false,
          message: `Invalid deal_status. Allowed values: ${allowedStatuses.join(', ')}.`,
        });
      }
      updates.push(`deal_status = $${idx++}`);
      values.push(deal_status);
    }

    if (updates.length > 0) {
      values.push(opportunityId);
      const oppUpdateRes = await client.query(
        `UPDATE opportunities
         SET ${updates.join(', ')}
         WHERE opportunity_id = $${idx}
         RETURNING opportunity_id, customer_id, project_title, location_name, lead_temperature, deal_status`,
        values
      );
      updatedOpportunity = oppUpdateRes.rows[0];
    }

    // 4. Schedule next follow-up task if next_call_date provided
    let nextScheduledNote = null;
    if (next_call_date && !isNaN(new Date(next_call_date).getTime())) {
      const nextNoteRes = await client.query(
        `INSERT INTO lead_notes (opportunity_id, employee_id, conclusion_notes, next_call_date)
         VALUES ($1, $2, $3, $4)
         RETURNING note_id, opportunity_id, employee_id, conclusion_notes, next_call_date, is_completed, created_at`,
        [
          opportunityId,
          employeeId,
          conclusion_notes?.trim() || 'Subsequent follow-up scheduled after task completion.',
          new Date(next_call_date).toISOString(),
        ]
      );
      nextScheduledNote = nextNoteRes.rows[0];
    }

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      message: 'Daily task marked as done and tracking statuses updated.',
      task: completedTask,
      ...(updatedOpportunity && { opportunity: updatedOpportunity }),
      ...(nextScheduledNote && { next_follow_up: nextScheduledNote }),
    });
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
};
export const createTask = async (req, res, next) => {
  const { opportunity_id, conclusion_notes, next_call_date } = req.body;
  const employeeId = req.user?.employee_id; // From authenticated token

  // 1. Validate required fields
  if (!opportunity_id || !conclusion_notes) {
    return res.status(400).json({
      success: false,
      message: "opportunity_id and conclusion_notes are required."
    });
  }

  if (!employeeId) {
    return res.status(401).json({
      success: false,
      message: "Authentication required to attribute task."
    });
  }

  let formattedDate = null;
  if (next_call_date) {
    const parsedDate = new Date(next_call_date);
    if (isNaN(parsedDate.getTime())) {
      return res.status(400).json({
        success: false,
        message: "Invalid next_call_date format."
      });
    }
    formattedDate = parsedDate.toISOString();
  }

  const client = await getClient();

  try {
    await client.query('BEGIN');

    // 2. Insert new lead note/task
    const result = await client.query(
      `INSERT INTO lead_notes (opportunity_id, employee_id, conclusion_notes, next_call_date, is_completed)
       VALUES ($1, $2, $3, $4, FALSE)
       RETURNING note_id, opportunity_id, employee_id, conclusion_notes, next_call_date, is_completed, created_at`,
      [opportunity_id, employeeId, conclusion_notes.trim(), formattedDate]
    );

    await client.query('COMMIT');

    return res.status(201).json({
      success: true,
      message: "Task / lead note created successfully.",
      task: result.rows[0]
    });

  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
};

export default {
  getTodayTasks,
  completeTask,
  createTask
};
