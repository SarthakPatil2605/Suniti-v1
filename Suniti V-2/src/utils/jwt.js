import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';

dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET || 'suniti-crm-default-jwt-secret-replace-in-production';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

/**
 * Generate a signed JWT token containing employee identity and authorization role
 *
 * @param {Object} employee - Employee object
 * @param {number} employee.employee_id - Primary key
 * @param {string} employee.name - Full employee name
 * @param {string} employee.email - Work email address
 * @param {string} employee.role - Employee role ('ADMIN', 'MANAGER', 'SALES_REP')
 * @param {Object} [options] - Additional jsonwebtoken sign options
 * @returns {string} Signed JWT token
 */
export function signToken(employee, options = {}) {
  if (!employee || !employee.employee_id) {
    throw new Error('Cannot sign JWT token: employee object with employee_id is required');
  }

  const payload = {
    employee_id: employee.employee_id,
    name: employee.name,
    email: employee.email,
    role: employee.role,
  };

  const signOptions = {
    expiresIn: options.expiresIn || JWT_EXPIRES_IN,
    ...options,
  };

  return jwt.sign(payload, JWT_SECRET, signOptions);
}

// Alias for signToken
export const generateToken = signToken;

/**
 * Verify and decode an incoming JWT token
 *
 * @param {string} token - The raw JWT token string
 * @returns {Object} Decoded payload containing employee_id, name, email, role, iat, exp
 * @throws {jwt.JsonWebTokenError | jwt.TokenExpiredError}
 */
export function verifyToken(token) {
  if (!token) {
    throw new Error('Token string is required for verification');
  }

  return jwt.verify(token, JWT_SECRET);
}

// Alias to avoid name collision with middleware
export const verifyJwt = verifyToken;

export default {
  signToken,
  generateToken,
  verifyToken,
  verifyJwt,
};
