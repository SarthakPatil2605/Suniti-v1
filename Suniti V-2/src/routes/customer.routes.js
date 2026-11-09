import { Router } from 'express';
import {
  createCustomerWithOpportunity,
  getExistingCustomersByTier,
  getCustomerOpportunitiesAndPlants,
  getBlocklistedCustomers,
  toggleCustomerBlocklist,
  updateCustomerTier,
  getAllCustomers,
  getCustomerById,
} from '../controllers/customer.controller.js';
import {
  verifyToken,
  verifyEmployee,
  verifyManagerOrAdmin,
} from '../middlewares/auth.middleware.js';

const router = Router();

// All customer routes require authenticated employee session
router.use(verifyToken, verifyEmployee);

/**
 * Specific / Static Routes (Defined before /:id parameterized routes)
 */

// POST /api/customers/new - Create new customer & initial opportunity
router.post('/new', createCustomerWithOpportunity);

// GET /api/customers/existing - Get existing customers grouped by tier
router.get('/existing', getExistingCustomersByTier);

// GET /api/customers/blocklisted - Retrieve blocklisted customers (Manager/Admin)
router.get('/blocklisted', verifyManagerOrAdmin, getBlocklistedCustomers);

// GET /api/customers - General customer list with search & filters
router.get('/', getAllCustomers);

/**
 * Parameterized Routes (/:id)
 */

// GET /api/customers/:id/opportunities - Opportunities & plant locations for specific company ID
router.get('/:id/opportunities', getCustomerOpportunitiesAndPlants);

// PATCH /api/customers/:id/blocklist - Toggle customer blocklist status (Admin/Manager)
router.patch('/:id/blocklist', verifyManagerOrAdmin, toggleCustomerBlocklist);

// PATCH /api/customers/:id/tier - Modify / upgrade customer tier (Manager/Admin)
router.patch('/:id/tier', verifyManagerOrAdmin, updateCustomerTier);

// GET /api/customers/:id - Retrieve specific customer details
router.get('/:id', getCustomerById);

export default router;
