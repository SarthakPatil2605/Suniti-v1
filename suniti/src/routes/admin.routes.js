import { Router } from 'express';
import {
  getAllEmployees,
  createEmployee,
  updateEmployee,
  deleteEmployee,
  updateCustomerOverride,
  deleteOpportunityOverride,
  toggleCustomerBlocklist,
} from '../controllers/admin.controller.js';
import { verifyToken, verifyAdmin } from '../middlewares/auth.middleware.js';

const router = Router();

// Enforce authentication & strict ADMIN role on all /api/admin routes
router.use(verifyToken, verifyAdmin);

// ============================================================================
// 1. EMPLOYEES CRUD
// ============================================================================
router.get('/employees', getAllEmployees);
router.post('/employees', createEmployee);
router.put('/employees/:id', updateEmployee);
router.delete('/employees/:id', deleteEmployee);

// ============================================================================
// 2. CUSTOMER & RECORD OVERRIDE CRUD
// ============================================================================
router.put('/customers/:id', updateCustomerOverride);
router.delete('/opportunities/:id', deleteOpportunityOverride);

// ============================================================================
// 3. BLOCKLIST MANAGEMENT
// ============================================================================
router.patch('/customers/:id/blocklist', toggleCustomerBlocklist);

// ============================================================================
// 4. ADMIN AUDIT
// ============================================================================
router.get('/security-audit', (req, res) => {
  return res.status(200).json({
    success: true,
    message: 'Admin access granted.',
    accessLevel: 'ADMIN_EXCLUSIVE',
    currentUser: req.user,
  });
});

export default router;
