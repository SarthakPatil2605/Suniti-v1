import { Router } from 'express';
import { verifyToken, verifyAdmin, verifyEmployee } from '../middlewares/auth.middleware.js';

const router = Router();

/**
 * Operational Routes (accessible to any authenticated employee: ADMIN or SALES_REP)
 */
router.get('/operational/pipeline', verifyToken, verifyEmployee, (req, res) => {
  return res.status(200).json({
    success: true,
    message: 'Operational access granted.',
    accessLevel: 'EMPLOYEE_OPERATIONAL',
    currentUser: req.user,
  });
});

/**
 * Admin-Only Routes (accessible exclusively to ADMIN role)
 */
router.get('/admin/security-audit', verifyToken, verifyAdmin, (req, res) => {
  return res.status(200).json({
    success: true,
    message: 'Admin access granted.',
    accessLevel: 'ADMIN_EXCLUSIVE',
    currentUser: req.user,
  });
});

export default router;
