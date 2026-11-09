import { Router } from 'express';
import {
  createOpportunity,
  updateOpportunityStatus,
  getOpportunities,
  getOpportunityById,
} from '../controllers/opportunity.controller.js';
import { logConclusionNoteAndScheduleCall } from '../controllers/task.controller.js';
import {
  verifyToken,
  verifyEmployee,
} from '../middlewares/auth.middleware.js';

const router = Router();

// All opportunity routes require an authenticated employee session
router.use(verifyToken, verifyEmployee);

/**
 * Opportunity & Pipeline Endpoints
 */

// POST /api/opportunities - Create new opportunity with employee attribution
router.post('/', createOpportunity);

// GET /api/opportunities - List opportunities (filterable by status, phase, employee, customer)
router.get('/', getOpportunities);

// GET /api/opportunities/:id - Get specific opportunity with customer and lead note history
router.get('/:id', getOpportunityById);

// PATCH /api/opportunities/:id/status - Update deal status, pipeline lifecycle stage (Rule 2 graduation)
router.patch('/:id/status', updateOpportunityStatus);

// POST /api/opportunities/:id/notes - Log conversation conclusion notes & schedule next call
router.post('/:id/notes', logConclusionNoteAndScheduleCall);
router.post('/:opportunity_id/notes', logConclusionNoteAndScheduleCall);

export default router;
