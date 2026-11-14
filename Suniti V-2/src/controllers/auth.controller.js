import bcrypt from 'bcrypt';
import prisma from '../config/prisma.js';
import { signToken } from '../utils/jwt.js';

const VALID_ROLES = ['ADMIN', 'MANAGER', 'SALES_REP'];

/**
 * Controller: Employee Login
 * Route: POST /api/auth/login
 *
 * Authenticates an employee via email and password, returning a signed JWT.
 */
export async function login(req, res, next) {
  try {
    const { email, password } = req.body;

    // 1. Validate required fields
    if (!email || !password) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Both "email" and "password" fields are required.',
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // 2. Fetch employee by email
    const employee = await prisma.employee.findUnique({
      where: { email: normalizedEmail },
    });

    // 3. Prevent timing attacks and user enumeration with consistent message
    if (!employee) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid email or password.',
      });
    }

    // 4. Compare candidate password with stored hash
    const isPasswordValid = await bcrypt.compare(password, employee.password_hash);
    if (!isPasswordValid) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid email or password.',
      });
    }

    // 5. Generate signed JWT token
    const token = signToken(employee);

    // 6. Return response excluding sensitive password_hash
    return res.status(200).json({
      status: 'success',
      message: 'Login successful',
      token,
      token_type: 'Bearer',
      expires_in: process.env.JWT_EXPIRES_IN || '7d',
      user: {
        employee_id: employee.employee_id,
        name: employee.name,
        email: employee.email,
        role: employee.role,
        created_at: employee.created_at,
      },
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Current Employee Profile
 * Route: GET /api/auth/me
 *
 * Retrieves the currently authenticated employee's profile and high-level stats.
 */
export async function getMe(req, res, next) {
  try {
    const employeeId = req.user?.employee_id;

    if (!employeeId) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'No authenticated employee session found.',
      });
    }

    const employee = await prisma.employee.findUnique({
      where: { employee_id: employeeId },
      select: {
        employee_id: true,
        name: true,
        email: true,
        role: true,
        created_at: true,
        _count: {
          select: {
            assigned_opportunities: true,
            authored_notes: true,
          },
        },
      },
    });

    if (!employee) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'Employee record no longer exists.',
      });
    }

    return res.status(200).json({
      status: 'success',
      user: employee,
      employee,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Register New Employee (Admin Only)
 * Route: POST /api/auth/register
 *
 * Allows administrators to provision new accounts for staff members.
 */
export async function register(req, res, next) {
  try {
    const { name, email, password, role } = req.body;

    // 1. Validate required inputs
    if (!name || !email || !password) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Fields "name", "email", and "password" are required.',
      });
    }

    const normalizedEmail = email.trim().toLowerCase();
    const assignedRole = role ? role.toUpperCase() : 'SALES_REP';

    if (!VALID_ROLES.includes(assignedRole)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Invalid role "${role}". Allowed roles: ${VALID_ROLES.join(', ')}`,
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Password must be at least 6 characters long.',
      });
    }

    // 2. Check if email already registered
    const existing = await prisma.employee.findUnique({
      where: { email: normalizedEmail },
    });

    if (existing) {
      return res.status(409).json({
        error: 'Conflict',
        message: `An employee with email "${normalizedEmail}" is already registered.`,
      });
    }

    // 3. Hash password
    const saltRounds = 10;
    const password_hash = await bcrypt.hash(password, saltRounds);

    // 4. Create new employee record
    const newEmployee = await prisma.employee.create({
      data: {
        name: name.trim(),
        email: normalizedEmail,
        password_hash,
        role: assignedRole,
      },
      select: {
        employee_id: true,
        name: true,
        email: true,
        role: true,
        created_at: true,
      },
    });

    return res.status(201).json({
      status: 'success',
      message: 'Employee account created successfully.',
      user: newEmployee,
    });
  } catch (error) {
    return next(error);
  }
}

export default {
  login,
  getMe,
  register,
};
