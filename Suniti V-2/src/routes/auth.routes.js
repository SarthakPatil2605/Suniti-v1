import { Router } from 'express';
import { login, getMe, register } from '../controllers/auth.controller.js';
import { verifyToken, verifyAdmin } from '../middlewares/auth.middleware.js';

const router = Router();

/**
 * Public Routes
 */
// POST /api/auth/login - Authenticate employee with email/password and obtain JWT
router.post('/login', login);

/**
 * Protected Routes
 */
// GET /api/auth/me - Retrieve authenticated employee profile
router.get('/me', verifyToken, getMe);

// POST /api/auth/register - Register new staff member (Restricted to ADMIN role)
router.post('/register', verifyToken, verifyAdmin, register);

export default router;
