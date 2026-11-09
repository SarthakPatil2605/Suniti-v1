import { verifyJwt } from '../utils/jwt.js';

/**
 * Middleware: verifyToken
 * Validates the Authorization Bearer header, verifies the token, and attaches the
 * decoded employee payload to `req.user` (and `req.employee`).
 */
export function verifyToken(req, res, next) {
  try {
    const authHeader = req.headers.authorization || req.headers.Authorization;

    if (!authHeader) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Authorization header is missing. Please provide a Bearer token.',
      });
    }

    // Expect format: Bearer <token>
    const parts = authHeader.trim().split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid token format. Format must be "Bearer <token>".',
      });
    }

    const token = parts[1];
    if (!token) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Bearer token string is missing.',
      });
    }

    // Verify token using secret
    const decoded = verifyJwt(token);

    // Attach user payload to request
    req.user = decoded;
    req.employee = decoded;

    return next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Authentication token has expired. Please log in again.',
      });
    }

    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or malformed authentication token.',
      });
    }

    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Token verification failed.',
    });
  }
}

/**
 * Generic role authorization factory
 * @param {...string} allowedRoles - Roles permitted to access the resource
 */
export function authorizeRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user || !req.user.role) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Authentication required. No user identity found.',
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        error: 'Forbidden',
        message: `Access denied. Requires one of the following roles: [${allowedRoles.join(', ')}]. Current role: ${req.user.role}`,
      });
    }

    return next();
  };
}

/**
 * Middleware: verifyAdmin
 * Restricts access exclusively to ADMIN role.
 */
export const verifyAdmin = authorizeRoles('ADMIN');

/**
 * Middleware: verifyManagerOrAdmin
 * Restricts access to MANAGER or ADMIN roles.
 */
export const verifyManagerOrAdmin = authorizeRoles('ADMIN', 'MANAGER');

/**
 * Middleware: verifyEmployee
 * Restricts access to all registered employee roles (ADMIN, MANAGER, SALES_REP).
 */
export const verifyEmployee = authorizeRoles('ADMIN', 'MANAGER', 'SALES_REP');

export default {
  verifyToken,
  verifyAdmin,
  verifyManagerOrAdmin,
  verifyEmployee,
  authorizeRoles,
};
