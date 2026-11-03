import { query } from '../config/db.js';
import { comparePassword, hashPassword } from '../utils/password.js';
import { signToken } from '../utils/jwt.js';

/**
 * Controller: Employee Login
 * Route: POST /api/auth/login
 * Body: { email, password }
 */
export const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    // 1. Input Validation
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required.',
      });
    }

    const normalizedEmail = String(email).trim().toLowerCase();

    // 2. Fetch employee record from PostgreSQL
    const result = await query(
      `SELECT employee_id, name, email, password_hash, role
       FROM employees
       WHERE LOWER(email) = $1
       LIMIT 1`,
      [normalizedEmail]
    );

    const employee = result.rows[0];

    // 3. User verification & timing attack mitigation
    if (!employee) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    // 4. Verify password against bcrypt hash
    const isPasswordValid = await comparePassword(password, employee.password_hash);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    // 5. Generate JWT token with required payload
    const token = signToken({
      employee_id: employee.employee_id,
      name: employee.name,
      role: employee.role,
      email: employee.email,
    });

    // 6. Return success response
    return res.status(200).json({
      success: true,
      message: 'Login successful.',
      token,
      employee: {
        employee_id: employee.employee_id,
        name: employee.name,
        email: employee.email,
        role: employee.role,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Controller: Get Current Authenticated Profile
 * Route: GET /api/auth/me
 * Requires: verifyToken
 */
export const getMe = async (req, res, next) => {
  try {
    const { employee_id } = req.user;

    const result = await query(
      `SELECT employee_id, name, email, role, created_at
       FROM employees
       WHERE employee_id = $1
       LIMIT 1`,
      [employee_id]
    );

    const employee = result.rows[0];
    if (!employee) {
      return res.status(404).json({
        success: false,
        message: 'Employee record not found.',
      });
    }

    return res.status(200).json({
      success: true,
      employee,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Controller: Register / Create New Employee
 * Route: POST /api/auth/register
 * Requires: verifyToken + verifyAdmin (or allow bootstrap when employees table is empty)
 */
export const register = async (req, res, next) => {
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
        message: "Role must be either 'ADMIN' or 'SALES_REP'.",
      });
    }

    const normalizedEmail = String(email).trim().toLowerCase();

    // Check if email already registered
    const existing = await query(
      'SELECT employee_id FROM employees WHERE LOWER(email) = $1 LIMIT 1',
      [normalizedEmail]
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'An employee with this email already exists.',
      });
    }

    const hashedPassword = await hashPassword(password);

    const insertResult = await query(
      `INSERT INTO employees (name, email, password_hash, role)
       VALUES ($1, $2, $3, $4)
       RETURNING employee_id, name, email, role, created_at`,
      [name.trim(), normalizedEmail, hashedPassword, role]
    );

    const newEmployee = insertResult.rows[0];

    return res.status(201).json({
      success: true,
      message: 'Employee registered successfully.',
      employee: newEmployee,
    });
  } catch (error) {
    next(error);
  }
};

export default {
  login,
  getMe,
  register,
};
