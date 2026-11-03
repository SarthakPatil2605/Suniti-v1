import { Router } from 'express';
import { login, getMe, register } from '../controllers/auth.controller.js';
import { verifyToken, verifyAdmin } from '../middlewares/auth.middleware.js';

const router = Router();

/**
 * Public Authentication Routes
 */
// POST /api/auth/login - Authenticate employee and issue JWT
router.post('/login', login);

/**
 * Protected Routes
 */
// GET /api/auth/me - Retrieve current authenticated employee details
router.get('/me', verifyToken, getMe);

// POST /api/auth/register - Register a new employee (Admin-only)
router.post('/register', verifyToken, verifyAdmin, register);

export default router;
