import { Router } from 'express';
import {
  getExistingCustomers,
  getCustomerOpportunities,
  createNewCustomerWithOpportunity,
} from '../controllers/customer.controller.js';
import { verifyToken, verifyEmployee } from '../middlewares/auth.middleware.js';

const router = Router();

// Apply auth & operational role verification to customer endpoints
router.use(verifyToken, verifyEmployee);

/**
 * GET /api/customers/existing
 * Fetch existing customers grouped by tier ('PREMIUM', 'LOYAL', 'INTERIOR_DESIGNER') and company name.
 */
router.get('/existing', getExistingCustomers);

/**
 * GET /api/customers/:companyId/opportunities
 * Fetch all plant locations / opportunities for a specific customer company.
 */
router.get('/:id/opportunities', getCustomerOpportunities);

/**
 * POST /api/customers/new
 * Create a new customer, initial opportunity, and auto-scheduled follow-up note (Rule 1).
 */
router.post('/new', createNewCustomerWithOpportunity);

export default router;
