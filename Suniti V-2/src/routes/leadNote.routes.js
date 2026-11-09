import { Router } from 'express';
import {
  getTodayTaskQueue,
  logConclusionNoteAndScheduleCall,
  completeTask,
  assignTask,
  getTasks,
  getTaskById,
} from '../controllers/task.controller.js';
import {
  verifyToken,
  verifyEmployee,
  verifyManagerOrAdmin,
} from '../middlewares/auth.middleware.js';

const router = Router();

// Require authenticated employee session for all task endpoints
router.use(verifyToken, verifyEmployee);

/**
 * Task Queue & Log Endpoints
 */

// GET /api/tasks/today (or /api/lead-notes/today) - Today's prioritized task queue
router.get('/today', getTodayTaskQueue);

// POST /api/tasks/opportunity/:opportunity_id - Log conversation & schedule follow-up
router.post('/opportunity/:opportunity_id', logConclusionNoteAndScheduleCall);

// PATCH /api/tasks/:note_id/complete - Mark task as completed with attribution
router.patch('/:note_id/complete', completeTask);
router.post('/:note_id/complete', completeTask); // Alias for flexible clients

// PATCH /api/tasks/:note_id/assign - Manager task assignment to any employee
router.patch('/:note_id/assign', verifyManagerOrAdmin, assignTask);

// GET /api/tasks - General list of tasks/lead notes with filters
router.get('/', getTasks);

// GET /api/tasks/:id - Retrieve specific task details
router.get('/:id', getTaskById);

export default router;
