import { Router } from 'express';
import {
  getEmployees,
  createEmployee,
} from '../controllers/manager.controller.js';
import {
  verifyToken,
  verifyAdmin,
} from '../middlewares/auth.middleware.js';

const router = Router();

// Base authentication for all user management routes — ADMIN only!
router.use(verifyToken, verifyAdmin);

// GET /api/users - List CRM users (ADMIN only)
router.get('/', getEmployees);

// POST /api/users - Create new CRM user (ADMIN only)
router.post('/', createEmployee);

export default router;
