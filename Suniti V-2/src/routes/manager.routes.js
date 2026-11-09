import { Router } from 'express';
import {
  getEmployees,
  getEmployeeById,
  createEmployee,
  updateEmployee,
  deleteEmployee,
  getTeamWorkload,
  getOverdueTaskAlerts,
  getLeadHistoryAudit,
  getAnalyticsReport,
} from '../controllers/manager.controller.js';
import {
  verifyToken,
  verifyManagerOrAdmin,
  verifyAdmin,
} from '../middlewares/auth.middleware.js';

const router = Router();

// All manager routes require Manager or Admin authentication
router.use(verifyToken, verifyManagerOrAdmin);

/**
 * 1. Workload Tracking & Capacity
 */
// GET /api/manager/workload - Team workload overview across sales reps
router.get('/workload', getTeamWorkload);

/**
 * 2. Overdue Alerts
 */
// GET /api/manager/alerts/overdue-tasks - Overdue tasks alerts with duration & urgency
router.get('/alerts/overdue-tasks', getOverdueTaskAlerts);

/**
 * 3. Audit Attribution
 */
// GET /api/manager/audit/lead-history/:opportunity_id - Full lead timeline and actor attribution
router.get('/audit/lead-history/:opportunity_id', getLeadHistoryAudit);

/**
 * 4. Analytics & Reporting (Supports ?format=csv)
 */
// GET /api/manager/analytics - Aggregated pipeline counts, conversion rates & team activity
router.get('/analytics', getAnalyticsReport);
router.get('/analytics/export', getAnalyticsReport);

/**
 * 5. Employee CRUD Operations
 */
// GET /api/manager/employees - List all staff members
router.get('/employees', getEmployees);

// POST /api/manager/employees - Create new staff member
router.post('/employees', createEmployee);

// GET /api/manager/employees/:id - Get specific staff member by ID
router.get('/employees/:id', getEmployeeById);

// PATCH /api/manager/employees/:id - Update staff profile / role
router.patch('/employees/:id', updateEmployee);

// DELETE /api/manager/employees/:id - Delete staff member (Restricted to Admin)
router.delete('/employees/:id', verifyAdmin, deleteEmployee);

export default router;
