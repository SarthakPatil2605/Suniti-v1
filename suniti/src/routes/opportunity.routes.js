import { Router } from 'express';
import {
  updateOpportunityStatus,
  addOpportunityNote,
} from '../controllers/opportunity.controller.js';
import { verifyToken, verifyEmployee } from '../middlewares/auth.middleware.js';

const router = Router();

// Apply auth & operational role verification to opportunity endpoints
router.use(verifyToken, verifyEmployee);

/**
 * POST /api/opportunities/:id/notes
 * Add a new conversation conclusion note with authenticated employee attribution and subsequent follow-up scheduling.
 */
router.post('/:opportunity_id/notes', addOpportunityNote);

/**
 * PATCH /api/opportunities/:id/status
 * Update deal status. Triggers Rule 2 (Customer Graduation) when deal_status === 'CLOSED_WON'.
 */
router.patch('/:opportunity_id/status', updateOpportunityStatus);

export default router;
