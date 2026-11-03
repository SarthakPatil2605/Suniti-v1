import { query, getClient } from '../config/db.js';
import { isValidUuid } from '../utils/validators.js';
import pool from '../config/db.js';
/**
 * Controller: Get Existing Customers Grouped by Tier & Company Name
 * Route: GET /api/customers/existing
 */
export const getExistingCustomers = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT 
         c.customer_id,
         c.name,
         c.customer_type,
         c.tier,
         c.phone,
         c.billing_address,
         c.is_blocklisted,
         c.created_at,
         COUNT(o.opportunity_id)::int AS total_opportunities
       FROM customers c
       LEFT JOIN opportunities o ON c.customer_id = o.customer_id
       WHERE c.customer_type = 'EXISTING'
       GROUP BY c.customer_id
       ORDER BY c.tier ASC, c.name ASC`
    );

    // Grouping by tier ('PREMIUM', 'LOYAL', 'INTERIOR_DESIGNER')
    const grouped = {
      PREMIUM: [],
      LOYAL: [],
      INTERIOR_DESIGNER: [],
    };

    const counts = {
      PREMIUM: 0,
      LOYAL: 0,
      INTERIOR_DESIGNER: 0,
    };

    result.rows.forEach((customer) => {
      const tierKey = customer.tier;
      if (grouped[tierKey]) {
        grouped[tierKey].push(customer);
        counts[tierKey] += 1;
      } else {
        // Fallback for edge cases with unassigned tier
        if (!grouped.UNASSIGNED) grouped.UNASSIGNED = [];
        grouped.UNASSIGNED.push(customer);
      }
    });

    return res.status(200).json({
      success: true,
      total: result.rowCount,
      counts,
      data: grouped,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Controller: Get Plant Locations / Opportunities for a Specific Company
 * Route: GET /api/customers/:companyId/opportunities
 */
export const getCustomerOpportunities = async (req, res, next) => {
  const { id } = req.params; // or company_id

  // 1. Validate that company ID is a valid integer
  const companyId = parseInt(id, 10);
  if (isNaN(companyId)) {
    return res.status(400).json({
      success: false,
      message: "Invalid company ID. Must be an integer."
    });
  }

  try {
    // 2. Fetch customer and their opportunities/plants
    const result = await pool.query(
      `SELECT 
         c.customer_id,
         c.name AS company_name,
         c.customer_type,
         c.tier,
         o.opportunity_id,
         o.project_title,
         o.location_name,
         o.lead_temperature,
         o.deal_status
       FROM customers c
       LEFT JOIN opportunities o ON c.customer_id = o.customer_id
       WHERE c.customer_id = $1`,
      [companyId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `Company with ID ${companyId} not found.`
      });
    }

    return res.status(200).json({
      success: true,
      company_id: companyId,
      company_name: result.rows[0].company_name,
      opportunities: result.rows.map(row => ({
        opportunity_id: row.opportunity_id,
        project_title: row.project_title,
        location_name: row.location_name,
        lead_temperature: row.lead_temperature,
        deal_status: row.deal_status
      })).filter(o => o.opportunity_id !== null)
    });

  } catch (error) {
    next(error);
  }
};
export const createNewCustomerWithOpportunity = async (req, res, next) => {
  const client = await getClient();

  try {
    const {
      name,
      phone,
      billing_address,
      project_title,
      location_name,
      lead_temperature = 'WARM',
      conclusion_notes,
      next_call_date,
    } = req.body;

    // 1. Validation
    if (!name || !String(name).trim()) {
      return res.status(400).json({
        success: false,
        message: 'Customer company name is required.',
      });
    }

    if (!project_title || !String(project_title).trim()) {
      return res.status(400).json({
        success: false,
        message: 'Project title is required for the initial opportunity.',
      });
    }

    if (!location_name || !String(location_name).trim()) {
      return res.status(400).json({
        success: false,
        message: 'Location name (e.g., Pune, Pimpri, Mumbai) is required.',
      });
    }

    const allowedTemperatures = ['HOT', 'WARM', 'COLD'];
    if (lead_temperature && !allowedTemperatures.includes(lead_temperature)) {
      return res.status(400).json({
        success: false,
        message: `Invalid lead_temperature. Allowed values: ${allowedTemperatures.join(', ')}.`,
      });
    }

    // 2. Rule 1: Auto-schedule next_call_date
    let finalCallDate;
    if (next_call_date && !isNaN(new Date(next_call_date).getTime())) {
      finalCallDate = new Date(next_call_date).toISOString();
    } else {
      // Automatically calculate current timestamp + 30 days
      const targetDate = new Date();
      targetDate.setDate(targetDate.getDate() + 30);
      finalCallDate = targetDate.toISOString();
    }

    // Identify creator employee if authenticated
    const employeeId = req.user?.employee_id || null;

    // 3. Execute atomic transaction
    await client.query('BEGIN');

    // Step A: Insert customer (type='NEW', tier=NULL)
    const custInsert = await client.query(
      `INSERT INTO customers (name, customer_type, tier, phone, billing_address)
       VALUES ($1, 'NEW', NULL, $2, $3)
       RETURNING customer_id, name, customer_type, tier, phone, billing_address, is_blocklisted, created_at`,
      [name.trim(), phone?.trim() || null, billing_address?.trim() || null]
    );
    const newCustomer = custInsert.rows[0];

    // Step B: Insert initial opportunity (status='PIPELINE')
    const oppInsert = await client.query(
      `INSERT INTO opportunities (customer_id, project_title, location_name, lead_temperature, deal_status)
       VALUES ($1, $2, $3, $4, 'PIPELINE')
       RETURNING opportunity_id, customer_id, project_title, location_name, lead_temperature, deal_status, created_at`,
      [newCustomer.customer_id, project_title.trim(), location_name.trim(), lead_temperature]
    );
    const newOpportunity = oppInsert.rows[0];

    // Step C: Insert initial lead note with auto-scheduled follow-up date
    const noteContent = conclusion_notes?.trim() || `Initial opportunity intake for "${project_title.trim()}".`;
    const noteInsert = await client.query(
      `INSERT INTO lead_notes (opportunity_id, employee_id, conclusion_notes, next_call_date)
       VALUES ($1, $2, $3, $4)
       RETURNING note_id, opportunity_id, employee_id, conclusion_notes, next_call_date, created_at`,
      [newOpportunity.opportunity_id, employeeId, noteContent, finalCallDate]
    );
    const initialNote = noteInsert.rows[0];

    await client.query('COMMIT');

    return res.status(201).json({
      success: true,
      message: 'New customer, initial opportunity, and follow-up note created successfully.',
      customer: newCustomer,
      opportunity: newOpportunity,
      lead_note: initialNote,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
};


/**
 * Controller: Create a New Opportunity
 * Route: POST /api/opportunities
 */
export const createOpportunity = async (req, res, next) => {
  const { customer_id, project_title, location_name, lead_temperature, deal_status } = req.body;
  const employeeId = req.user?.employee_id; // Extracted from Bearer Token

  const result = await client.query(
    `INSERT INTO opportunities (customer_id, employee_id, project_title, location_name, lead_temperature, deal_status, is_completed)
     VALUES ($1, $2, $3, $4, $5, $6, FALSE)
     RETURNING *`,
    [customer_id, employeeId, project_title, location_name, lead_temperature || 'HOT', deal_status || 'PIPELINE']
  );

  // Return opportunity along with creator info
  return res.status(201).json({
    success: true,
    opportunity: result.rows[0],
    created_by: {
      employee_id: req.user.employee_id,
      name: req.user.name,
      role: req.user.role
    }
  });
};;

export default {
  getExistingCustomers,
  getCustomerOpportunities,
  createNewCustomerWithOpportunity,
  createOpportunity
};
