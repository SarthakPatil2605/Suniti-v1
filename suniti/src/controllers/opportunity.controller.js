import { query, getClient } from '../config/db.js';

const ALLOWED_DEAL_STATUSES = ['PIPELINE', 'CLOSED_WON', 'CLOSED_LOST'];
const ALLOWED_CUSTOMER_TIERS = ['PREMIUM', 'LOYAL', 'INTERIOR_DESIGNER'];

/**
 * Controller: Update Opportunity Deal Status
 * Route: PATCH /api/opportunities/:id/status
 * 
 * Rule 2 (Deal Closure Migration):
 * If deal_status is updated to 'CLOSED_WON', automatically update the parent
 * customer's type from 'NEW' to 'EXISTING' and require/assign a customer tier
 * ('PREMIUM', 'LOYAL', or 'INTERIOR_DESIGNER').
 */
export const updateOpportunityStatus = async (req, res, next) => {
  const { id } = req.params;
  const { deal_status, tier, conclusion_notes } = req.body;

  // 1. Validate opportunity ID is a valid integer
  const oppId = parseInt(id, 10);
  if (isNaN(oppId)) {
    return res.status(400).json({
      success: false,
      message: 'Invalid opportunity ID. Must be an integer.',
    });
  }

  // 2. Validate deal_status
  if (!deal_status || !ALLOWED_DEAL_STATUSES.includes(deal_status)) {
    return res.status(400).json({
      success: false,
      message: `Invalid deal_status. Allowed values: ${ALLOWED_DEAL_STATUSES.join(', ')}.`,
    });
  }

  const client = await getClient();

  try {
    // 3. Fetch opportunity and associated parent customer
    const oppRes = await client.query(
      `SELECT 
         o.opportunity_id,
         o.customer_id,
         o.project_title,
         o.location_name,
         o.lead_temperature,
         o.deal_status,
         c.customer_type,
         c.tier AS customer_tier,
         c.name AS customer_name
       FROM opportunities o
       JOIN customers c ON o.customer_id = c.customer_id
       WHERE o.opportunity_id = $1
       LIMIT 1`,
      [oppId]
    );

    if (oppRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `Opportunity with ID ${oppId} was not found.`,
      });
    }

    const currentOpp = oppRes.rows[0];
    const isClosingWon = deal_status === 'CLOSED_WON';
    let assignedTier = tier;

    // 4. Rule 2 Validation: Closing deal as WON
    if (isClosingWon) {
      if (currentOpp.customer_type === 'NEW') {
        if (!assignedTier || !ALLOWED_CUSTOMER_TIERS.includes(assignedTier)) {
          return res.status(400).json({
            success: false,
            message: `A valid customer tier (${ALLOWED_CUSTOMER_TIERS.join(', ')}) is required when closing deal as WON to graduate customer to EXISTING.`,
          });
        }
      } else {
        if (assignedTier && !ALLOWED_CUSTOMER_TIERS.includes(assignedTier)) {
          return res.status(400).json({
            success: false,
            message: `Invalid customer tier. Allowed values: ${ALLOWED_CUSTOMER_TIERS.join(', ')}.`,
          });
        }
        if (!assignedTier) {
          assignedTier = currentOpp.customer_tier || 'LOYAL';
        }
      }
    }

    // 5. Atomic Transaction Execution
    await client.query('BEGIN');

    let updatedCustomer = null;

    if (isClosingWon) {
      const custUpdate = await client.query(
        `UPDATE customers
         SET customer_type = 'EXISTING',
             tier = $1
         WHERE customer_id = $2
         RETURNING customer_id, name, customer_type, tier, phone, billing_address, is_blocklisted, created_at`,
        [assignedTier, currentOpp.customer_id]
      );
      updatedCustomer = custUpdate.rows[0];
    }

    const oppUpdate = await client.query(
      `UPDATE opportunities
       SET deal_status = $1
       WHERE opportunity_id = $2
       RETURNING opportunity_id, customer_id, project_title, location_name, lead_temperature, deal_status, created_at`,
      [deal_status, oppId]
    );
    const updatedOpportunity = oppUpdate.rows[0];

    if (conclusion_notes) {
      const employeeId = req.user?.employee_id || null;
      await client.query(
        `INSERT INTO lead_notes (opportunity_id, employee_id, conclusion_notes, next_call_date)
         VALUES ($1, $2, $3, NULL)`,
        [
          oppId,
          employeeId,
          `Deal status updated to ${deal_status}. Notes: ${conclusion_notes.trim()}`,
        ]
      );
    }

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      message: isClosingWon
        ? `Deal won! Parent customer "${currentOpp.customer_name}" graduated to EXISTING [${assignedTier}].`
        : `Opportunity status updated to ${deal_status}.`,
      opportunity: updatedOpportunity,
      ...(updatedCustomer && { customer: updatedCustomer }),
    });
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
};

/**
 * Controller: Add a New Conversation Conclusion Note
 * Route: POST /api/opportunities/:opportunity_id/notes
 */
export const addOpportunityNote = async (req, res, next) => {
  const { opportunity_id } = req.params;
  const { conclusion_notes, next_call_date, lead_temperature } = req.body;
  const employeeId = req.user?.employee_id; // From JWT

  // 1. Validate opportunity ID is a valid integer
  const oppId = parseInt(opportunity_id, 10);
  if (isNaN(oppId)) {
    return res.status(400).json({
      success: false,
      message: 'Invalid opportunity ID. Must be an integer.',
    });
  }

  // 2. Validate conclusion_notes
  if (!conclusion_notes || !String(conclusion_notes).trim()) {
    return res.status(400).json({
      success: false,
      message: 'Conclusion notes are required to log a conversation.',
    });
  }

  // 3. Ensure employee authenticated
  if (!employeeId) {
    return res.status(401).json({
      success: false,
      message: 'Authentication required. Unable to determine employee ID.',
    });
  }

  // 4. Validate next_call_date if provided
  let formattedNextCallDate = null;
  if (next_call_date) {
    const parsedDate = new Date(next_call_date);
    if (isNaN(parsedDate.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'Invalid next_call_date format. Please provide a valid date/timestamp.',
      });
    }
    formattedNextCallDate = parsedDate.toISOString();
  }

  const client = await getClient();

  try {
    // 5. Verify opportunity exists
    const oppRes = await client.query(
      `SELECT opportunity_id, customer_id, project_title, location_name, lead_temperature, deal_status
       FROM opportunities
       WHERE opportunity_id = $1
       LIMIT 1`,
      [oppId]
    );

    if (oppRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `Opportunity with ID ${oppId} was not found.`,
      });
    }

    const currentOpp = oppRes.rows[0];

    await client.query('BEGIN');

    // 6. Insert new lead note with authenticated employee attribution
    const noteInsertRes = await client.query(
      `INSERT INTO lead_notes (opportunity_id, employee_id, conclusion_notes, next_call_date)
       VALUES ($1, $2, $3, $4)
       RETURNING note_id, opportunity_id, employee_id, conclusion_notes, next_call_date, is_completed, created_at`,
      [oppId, employeeId, conclusion_notes.trim(), formattedNextCallDate]
    );
    const newNote = noteInsertRes.rows[0];

    // 7. Mark prior pending tasks for this opportunity as completed
    await client.query(
      `UPDATE lead_notes
       SET is_completed = TRUE,
           completed_at = CURRENT_TIMESTAMP,
           completed_by = $1
       WHERE opportunity_id = $2
         AND note_id != $3
         AND is_completed = FALSE`,
      [employeeId, oppId, newNote.note_id]
    );

    // 8. Update lead temperature if provided
    let updatedOpportunity = currentOpp;
    if (lead_temperature) {
      const allowedTemps = ['HOT', 'WARM', 'COLD'];
      if (!allowedTemps.includes(lead_temperature)) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          success: false,
          message: `Invalid lead_temperature. Allowed values: ${allowedTemps.join(', ')}.`,
        });
      }

      const oppUpdateRes = await client.query(
        `UPDATE opportunities
         SET lead_temperature = $1
         WHERE opportunity_id = $2
         RETURNING opportunity_id, customer_id, project_title, location_name, lead_temperature, deal_status`,
        [lead_temperature, oppId]
      );
      updatedOpportunity = oppUpdateRes.rows[0];
    }

    await client.query('COMMIT');

    return res.status(201).json({
      success: true,
      message: 'Conversation conclusion note logged successfully.',
      note: {
        ...newNote,
        logged_by: {
          employee_id: req.user.employee_id,
          name: req.user.name,
          role: req.user.role,
        },
      },
      opportunity: updatedOpportunity,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
};

export default {
  updateOpportunityStatus,
  addOpportunityNote,
};