import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';

dotenv.config();

/**
 * Middleware: Verify JWT Token
 * Ensures request includes a valid Bearer token and attaches decoded payload to req.user
 */
export const verifyToken = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Access denied. No token provided or invalid format.'
    });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // { employee_id, name, email, role }
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: 'Invalid authentication token.'
    });
  }
};

/**
 * Middleware: Verify Admin Role
 * Restricts access to users with role === 'ADMIN'
 */
export const verifyAdmin = (req, res, next) => {
  if (!req.user || req.user.role !== 'ADMIN') {
    return res.status(403).json({
      success: false,
      message: 'Access forbidden: Requires ADMIN role.'
    });
  }
  next();
};

/**
 * Middleware: Verify Employee Role (Admin or Sales Rep)
 * Restricts access to operational employees
 */
export const verifyEmployee = (req, res, next) => {
  if (!req.user || !['ADMIN', 'SALES_REP'].includes(req.user.role)) {
    return res.status(403).json({
      success: false,
      message: 'Access forbidden: Requires authorized employee role.'
    });
  }
  next();
};

export default {
  verifyToken,
  verifyAdmin,
  verifyEmployee
};