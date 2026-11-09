import { Router } from 'express';
import {
  getEmployees,
  getEmployeeById,
  createEmployee,
  updateEmployee,
  deleteEmployee,
} from '../controllers/manager.controller.js';
import {
  verifyToken,
  verifyManagerOrAdmin,
  verifyAdmin,
  verifyEmployee,
} from '../middlewares/auth.middleware.js';

const router = Router();

// Base authentication for all employee routes
router.use(verifyToken, verifyEmployee);

// GET /api/employees - List employees (accessible by staff for directory, filterable)
router.get('/', getEmployees);

// GET /api/employees/:id - Retrieve specific employee details
router.get('/:id', getEmployeeById);

// POST /api/employees - Provision new employee (Manager or Admin)
router.post('/', verifyManagerOrAdmin, createEmployee);

// PATCH /api/employees/:id - Update employee role/profile (Manager or Admin)
router.patch('/:id', verifyManagerOrAdmin, updateEmployee);

// DELETE /api/employees/:id - Delete employee (Admin only)
router.delete('/:id', verifyAdmin, deleteEmployee);

export default router;
