import { query } from '../config/db.js';
import { hashPassword } from '../utils/password.js';
import { isValidUuid } from '../utils/validators.js';

// ============================================================================
// 1. EMPLOYEES CRUD
// ============================================================================

/**
 * Controller: List All Employees (Staff Directory)
 * Route: GET /api/admin/employees
 */
export const getAllEmployees = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT employee_id, name, email, role, created_at
       FROM employees
       ORDER BY role ASC, name ASC`
    );

    return res.status(200).json({
      success: true,
      total_employees: result.rowCount,
      employees: result.rows,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Controller: Create New Employee / Sales Rep
 * Route: POST /api/admin/employees
 */
export const createEmployee = async (req, res, next) => {
  try {
    const { name, email, password, role = 'SALES_REP' } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Name, email, and password are required.',
      });
    }

    if (!['ADMIN', 'SALES_REP'].includes(role)) {
      return res.status(400).json({
        success: false,
        message: "Invalid role. Role must be 'ADMIN' or 'SALES_REP'.",
      });
    }

    const normalizedEmail = String(email).trim().toLowerCase();

    // Check unique email
    const existing = await query(
      `SELECT employee_id FROM employees WHERE LOWER(email) = $1 LIMIT 1`,
      [normalizedEmail]
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'An employee with this email already exists.',
      });
    }

    const hashedPassword = await hashPassword(password);

    const result = await query(
      `INSERT INTO employees (name, email, password_hash, role)
       VALUES ($1, $2, $3, $4)
       RETURNING employee_id, name, email, role, created_at`,
      [name.trim(), normalizedEmail, hashedPassword, role]
    );

    return res.status(201).json({
      success: true,
      message: 'Employee created successfully.',
      employee: result.rows[0],
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Controller: Update Employee Role or Details
 * Route: PUT /api/admin/employees/:id
 */
export const updateEmployee = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { name, email, role, password } = req.body;

    if (!isValidUuid(id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid employee ID. Must be a valid UUID.',
      });
    }

    // Check if employee exists
    const checkRes = await query(
      `SELECT employee_id, name, email, role FROM employees WHERE employee_id = $1 LIMIT 1`,
      [id]
    );

    if (checkRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `Employee with ID ${id} was not found.`,
      });
    }

    const current = checkRes.rows[0];
    const updates = [];
    const values = [];
    let idx = 1;

    if (name && name.trim()) {
      updates.push(`name = $${idx++}`);
      values.push(name.trim());
    }

    if (email && email.trim()) {
      const normalizedEmail = email.trim().toLowerCase();
      // Check duplicate email
      const duplicateRes = await query(
        `SELECT employee_id FROM employees WHERE LOWER(email) = $1 AND employee_id != $2 LIMIT 1`,
        [normalizedEmail, id]
      );
      if (duplicateRes.rows.length > 0) {
        return res.status(409).json({
          success: false,
          message: 'Email address is already in use by another employee.',
        });
      }
      updates.push(`email = $${idx++}`);
      values.push(normalizedEmail);
    }

    if (role) {
      if (!['ADMIN', 'SALES_REP'].includes(role)) {
        return res.status(400).json({
          success: false,
          message: "Invalid role. Role must be 'ADMIN' or 'SALES_REP'.",
        });
      }
      updates.push(`role = $${idx++}`);
      values.push(role);
    }

    if (password && password.trim()) {
      const hashedPassword = await hashPassword(password);
      updates.push(`password_hash = $${idx++}`);
      values.push(hashedPassword);
    }

    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No fields provided for update.',
      });
    }

    values.push(id);
    const updateRes = await query(
      `UPDATE employees
       SET ${updates.join(', ')}
       WHERE employee_id = $${idx}
       RETURNING employee_id, name, email, role, created_at`,
      values
    );

    return res.status(200).json({
      success: true,
      message: 'Employee updated successfully.',
      employee: updateRes.rows[0],
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Controller: Delete / Deactivate Employee
 * Route: DELETE /api/admin/employees/:id
 */
export const deleteEmployee = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!isValidUuid(id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid employee ID. Must be a valid UUID.',
      });
    }

    // Safety check: Prevent admin self-deletion
    if (req.user?.employee_id === id) {
      return res.status(400).json({
        success: false,
        message: 'Action forbidden. You cannot delete your own active administrator account.',
      });
    }

    const checkRes = await query(
      `SELECT employee_id, name, email FROM employees WHERE employee_id = $1 LIMIT 1`,
      [id]
    );

    if (checkRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `Employee with ID ${id} was not found.`,
      });
    }

    await query(`DELETE FROM employees WHERE employee_id = $1`, [id]);

    return res.status(200).json({
      success: true,
      message: `Employee ${checkRes.rows[0].name} (${checkRes.rows[0].email}) deleted successfully.`,
      deleted_employee_id: id,
    });
  } catch (error) {
    next(error);
  }
};

// ============================================================================
// 2. CUSTOMER & RECORD OVERRIDE CRUD
// ============================================================================

/**
 * Controller: Full Edit of Customer Details or Tier Override
 * Route: PUT /api/admin/customers/:id
 */
export const updateCustomerOverride = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { name, customer_type, tier, phone, billing_address, is_blocklisted } = req.body;

    if (!isValidUuid(id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid customer ID. Must be a valid UUID.',
      });
    }

    const checkRes = await query(
      `SELECT * FROM customers WHERE customer_id = $1 LIMIT 1`,
      [id]
    );

    if (checkRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `Customer with ID ${id} was not found.`,
      });
    }

    const current = checkRes.rows[0];

    // Determine target customer_type and tier
    let targetType = customer_type !== undefined ? customer_type : current.customer_type;
    let targetTier = tier !== undefined ? tier : current.tier;

    if (!['NEW', 'EXISTING'].includes(targetType)) {
      return res.status(400).json({
        success: false,
        message: "Invalid customer_type. Must be 'NEW' or 'EXISTING'.",
      });
    }

    const allowedTiers = ['PREMIUM', 'LOYAL', 'INTERIOR_DESIGNER', null];
    if (targetTier !== null && !allowedTiers.includes(targetTier)) {
      return res.status(400).json({
        success: false,
        message: `Invalid tier. Allowed values: PREMIUM, LOYAL, INTERIOR_DESIGNER, or null.`,
      });
    }

    // Constraint handling: If tier is assigned, customer cannot be 'NEW'
    if (targetTier && targetType === 'NEW') {
      targetType = 'EXISTING'; // Automatically promote customer to EXISTING if tier is set
    } else if (targetType === 'NEW') {
      targetTier = null;
    }

    const targetName = name !== undefined ? name.trim() : current.name;
    const targetPhone = phone !== undefined ? (phone ? phone.trim() : null) : current.phone;
    const targetAddress = billing_address !== undefined ? (billing_address ? billing_address.trim() : null) : current.billing_address;
    const targetBlocklisted = is_blocklisted !== undefined ? Boolean(is_blocklisted) : current.is_blocklisted;

    const result = await query(
      `UPDATE customers
       SET name = $1,
           customer_type = $2,
           tier = $3,
           phone = $4,
           billing_address = $5,
           is_blocklisted = $6
       WHERE customer_id = $7
       RETURNING *`,
      [targetName, targetType, targetTier, targetPhone, targetAddress, targetBlocklisted, id]
    );

    return res.status(200).json({
      success: true,
      message: 'Customer record overridden and updated successfully.',
      customer: result.rows[0],
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Controller: Delete Invalid or Erroneous Opportunity
 * Route: DELETE /api/admin/opportunities/:id
 */
export const deleteOpportunityOverride = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!isValidUuid(id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid opportunity ID. Must be a valid UUID.',
      });
    }

    const checkRes = await query(
      `SELECT opportunity_id, project_title, location_name FROM opportunities WHERE opportunity_id = $1 LIMIT 1`,
      [id]
    );

    if (checkRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `Opportunity with ID ${id} was not found.`,
      });
    }

    const opportunity = checkRes.rows[0];

    // Deleting opportunity automatically cascades to delete lead_notes
    await query(`DELETE FROM opportunities WHERE opportunity_id = $1`, [id]);

    return res.status(200).json({
      success: true,
      message: `Opportunity "${opportunity.project_title}" (${opportunity.location_name}) and associated notes deleted successfully.`,
      deleted_opportunity_id: id,
    });
  } catch (error) {
    next(error);
  }
};

// ============================================================================
// 3. BLOCKLIST MANAGEMENT
// ============================================================================

/**
 * Controller: Toggle Customer Blocklist Status
 * Route: PATCH /api/admin/customers/:id/blocklist
 * Body (Optional): { is_blocklisted: boolean } (if omitted, toggles current value)
 */
export const toggleCustomerBlocklist = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { is_blocklisted } = req.body || {};

    if (!isValidUuid(id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid customer ID. Must be a valid UUID.',
      });
    }

    const checkRes = await query(
      `SELECT customer_id, name, is_blocklisted FROM customers WHERE customer_id = $1 LIMIT 1`,
      [id]
    );

    if (checkRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `Customer with ID ${id} was not found.`,
      });
    }

    const currentCustomer = checkRes.rows[0];

    // Determine new status: explicit boolean if provided, otherwise toggle
    const newBlocklistStatus =
      typeof is_blocklisted === 'boolean'
        ? is_blocklisted
        : !currentCustomer.is_blocklisted;

    const result = await query(
      `UPDATE customers
       SET is_blocklisted = $1
       WHERE customer_id = $2
       RETURNING customer_id, name, customer_type, tier, phone, billing_address, is_blocklisted, created_at`,
      [newBlocklistStatus, id]
    );

    const updated = result.rows[0];

    return res.status(200).json({
      success: true,
      message: newBlocklistStatus
        ? `Customer "${updated.name}" has been placed on the blocklist.`
        : `Customer "${updated.name}" has been removed from the blocklist.`,
      customer: updated,
    });
  } catch (error) {
    next(error);
  }
};

export default {
  getAllEmployees,
  createEmployee,
  updateEmployee,
  deleteEmployee,
  updateCustomerOverride,
  deleteOpportunityOverride,
  toggleCustomerBlocklist,
};
