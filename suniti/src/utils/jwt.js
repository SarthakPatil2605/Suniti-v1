import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';

dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET || 'fallback_secret_change_in_production';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';

/**
 * Sign a JWT token containing employee identity and role
 * @param {Object} payload
 * @param {string} payload.employee_id
 * @param {string} payload.name
 * @param {('ADMIN'|'SALES_REP')} payload.role
 * @returns {string} Signed JWT token
 */
export const signToken = ({ employee_id, name, role, email }) => {
  return jwt.sign(
    {
      employee_id,
      name,
      role,
      ...(email && { email }),
    },
    JWT_SECRET,
    {
      expiresIn: JWT_EXPIRES_IN,
      algorithm: 'HS256',
    }
  );
};

/**
 * Verify and decode a JWT token
 * @param {string} token
 * @returns {Object} Decoded payload
 */
export const verifyJwt = (token) => {
  return jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
};

export default {
  signToken,
  verifyJwt,
};
