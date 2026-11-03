import { Router } from 'express';
import { getTodayTasks, completeTask } from '../controllers/task.controller.js';
import { verifyToken, verifyEmployee } from '../middlewares/auth.middleware.js';

const router = Router();

// Apply auth & operational role verification to all task endpoints
router.use(verifyToken, verifyEmployee);

/**
 * GET /api/tasks/today
 * Fetch all opportunities/leads where next_call_date falls on the current date,
 * returning company name, location, contact details, and prior history.
 */
router.get('/today', getTodayTasks);

/**
 * PATCH /api/tasks/:id/complete
 * Mark a daily task as done and update tracking statuses.
 */
router.patch('/:id/complete', completeTask);

export default router;
