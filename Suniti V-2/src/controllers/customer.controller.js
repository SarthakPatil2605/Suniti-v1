import prisma from '../config/prisma.js';

const VALID_TIERS = ['PREMIUM', 'LOYAL', 'INTERIOR_DESIGNER'];
const VALID_TEMPERATURES = ['HOT', 'WARM', 'COLD'];

/**
 * Helper: Parse integer ID safely
 */
function parseIntegerId(param, paramName = 'id') {
  const parsed = parseInt(param, 10);
  if (isNaN(parsed) || parsed <= 0) {
    return null;
  }
  return parsed;
}

/**
 * Controller: Create New Customer & Initial Opportunity
 * Route: POST /api/customers/new
 *
 * Business Rules:
 * - Creates Customer record (customer_type defaults to 'NEW').
 * - Creates Initial Opportunity linked to customer with:
 *     * project_phase default: 'TALKING'
 *     * deal_status default: 'PIPELINE'
 *     * employee attribution: authenticated user or provided employee_id.
 * - Automatically creates initial follow-up task/note:
 *     * If next_call_date is blank/missing, automatically schedules 30 days from creation.
 * - All executed atomically within a database transaction.
 */
export async function createCustomerWithOpportunity(req, res, next) {
  try {
    const {
      // Customer fields
      name,
      phone,
      billing_address,
      tier,
      // Opportunity fields
      project_title,
      location_name,
      lead_temperature,
      employee_id,
      // Initial follow-up note fields
      conclusion_notes,
      next_call_date,
    } = req.body;

    // 1. Validation
    if (!name || typeof name !== 'string' || !name.trim()) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Customer "name" is required.',
      });
    }

    if (!project_title || typeof project_title !== 'string' || !project_title.trim()) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Initial opportunity "project_title" is required.',
      });
    }

    if (tier && !VALID_TIERS.includes(tier)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Invalid tier "${tier}". Must be one of: ${VALID_TIERS.join(', ')}`,
      });
    }

    const assignedTemp = lead_temperature
      ? lead_temperature.toUpperCase()
      : 'WARM';

    if (!VALID_TEMPERATURES.includes(assignedTemp)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Invalid lead_temperature "${lead_temperature}". Allowed: ${VALID_TEMPERATURES.join(', ')}`,
      });
    }

    // Determine assigned employee
    const assignedEmployeeId =
      employee_id && ['ADMIN', 'MANAGER'].includes(req.user?.role)
        ? parseInt(employee_id, 10)
        : req.user?.employee_id;

    if (!assignedEmployeeId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'A valid employee_id must be assigned to this opportunity.',
      });
    }

    // Calculate next_call_date (Default: 30 days from creation if blank)
    let callDate;
    if (next_call_date && !isNaN(new Date(next_call_date).getTime())) {
      callDate = new Date(next_call_date);
    } else {
      const thirtyDaysAhead = new Date();
      thirtyDaysAhead.setDate(thirtyDaysAhead.getDate() + 30);
      callDate = thirtyDaysAhead;
    }

    // 2. Atomic Database Transaction
    const result = await prisma.$transaction(async (tx) => {
      // Step A: Create Customer
      const customer = await tx.customer.create({
        data: {
          name: name.trim(),
          phone: phone ? phone.trim() : null,
          billing_address: billing_address ? billing_address.trim() : null,
          tier: tier || null,
          customer_type: 'NEW',
          is_blocklisted: false,
        },
      });

      // Step B: Create Initial Opportunity
      const opportunity = await tx.opportunity.create({
        data: {
          customer_id: customer.customer_id,
          employee_id: assignedEmployeeId,
          project_title: project_title.trim(),
          location_name: location_name ? location_name.trim() : null,
          lead_temperature: assignedTemp,
          deal_status: 'PIPELINE',
          project_phase: 'TALKING', // Default lifecycle phase
          is_completed: false,
        },
        include: {
          assigned_employee: {
            select: { employee_id: true, name: true, email: true, role: true },
          },
        },
      });

      // Step C: Create Initial Follow-up Lead Note / Task
      const initialNote = await tx.leadNote.create({
        data: {
          opportunity_id: opportunity.opportunity_id,
          employee_id: assignedEmployeeId,
          conclusion_notes: conclusion_notes
            ? conclusion_notes.trim()
            : 'Initial customer onboarded. Initial outreach scheduled.',
          next_call_date: callDate,
          is_completed: false,
        },
      });

      return {
        customer,
        opportunity: {
          ...opportunity,
          lead_notes: [initialNote],
        },
        lead_note: initialNote,
      };
    });

    return res.status(201).json({
      status: 'success',
      message: 'Customer and initial opportunity created successfully.',
      customer: result.customer,
      opportunity: result.opportunity,
      lead_note: result.lead_note,
      data: result,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Get Existing Customers Grouped by Tier
 * Route: GET /api/customers/existing
 *
 * Retrieves all existing customers (customer_type = 'EXISTING') partitioned by tier:
 * - PREMIUM
 * - LOYAL
 * - INTERIOR_DESIGNER
 * Also returns counts and new customers count for dashboard tiles.
 */
export async function getExistingCustomersByTier(req, res, next) {
  try {
    const [existingCustomers, newCustomersCount] = await Promise.all([
      prisma.customer.findMany({
        where: {
          customer_type: 'EXISTING',
        },
        include: {
          _count: {
            select: {
              opportunities: true,
            },
          },
        },
        orderBy: {
          name: 'asc',
        },
      }),
      prisma.customer.count({
        where: {
          customer_type: 'NEW',
        },
      }),
    ]);

    // Grouping
    const grouped = {
      PREMIUM: [],
      LOYAL: [],
      INTERIOR_DESIGNER: [],
      UNASSIGNED: [],
    };

    existingCustomers.forEach((cust) => {
      if (cust.tier && grouped[cust.tier]) {
        grouped[cust.tier].push(cust);
      } else {
        grouped.UNASSIGNED.push(cust);
      }
    });

    return res.status(200).json({
      status: 'success',
      total: existingCustomers.length,
      total_existing_customers: existingCustomers.length,
      new_customers_count: newCustomersCount,
      counts: {
        PREMIUM: grouped.PREMIUM.length,
        LOYAL: grouped.LOYAL.length,
        INTERIOR_DESIGNER: grouped.INTERIOR_DESIGNER.length,
        NEW: newCustomersCount,
        UNASSIGNED: grouped.UNASSIGNED.length,
      },
      data: grouped,
      by_tier: grouped,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Get Opportunities & Plant Locations for Specific Company ID
 * Route: GET /api/customers/:id/opportunities
 */
export async function getCustomerOpportunitiesAndPlants(req, res, next) {
  try {
    const customerId = parseIntegerId(req.params.id, 'customer_id');

    if (!customerId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid customer ID. Must be a positive integer.',
      });
    }

    const customer = await prisma.customer.findUnique({
      where: { customer_id: customerId },
      include: {
        opportunities: {
          include: {
            assigned_employee: {
              select: { employee_id: true, name: true, email: true },
            },
            lead_notes: {
              orderBy: { created_at: 'desc' },
              take: 5,
            },
          },
          orderBy: { created_at: 'desc' },
        },
      },
    });

    if (!customer) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Customer with ID ${customerId} does not exist.`,
      });
    }

    // Extract unique plant / location names from all customer opportunities
    const plantLocations = [
      ...new Set(
        customer.opportunities
          .map((opp) => opp.location_name)
          .filter((loc) => Boolean(loc && loc.trim()))
      ),
    ];

    return res.status(200).json({
      status: 'success',
      company_id: customer.customer_id,
      company_name: customer.name,
      customer_id: customer.customer_id,
      customer_type: customer.customer_type,
      tier: customer.tier,
      phone: customer.phone,
      billing_address: customer.billing_address,
      is_blocklisted: customer.is_blocklisted,
      blocklist_reason: customer.blocklist_reason,
      created_at: customer.created_at,
      plant_locations: plantLocations,
      total_opportunities: customer.opportunities.length,
      opportunities: customer.opportunities,
      data: customer.opportunities,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Retrieve Blocklisted Customers
 * Route: GET /api/customers/blocklisted
 */
export async function getBlocklistedCustomers(req, res, next) {
  try {
    const blocklisted = await prisma.customer.findMany({
      where: {
        is_blocklisted: true,
      },
      include: {
        _count: {
          select: { opportunities: true },
        },
      },
      orderBy: { created_at: 'desc' },
    });

    return res.status(200).json({
      status: 'success',
      count: blocklisted.length,
      customers: blocklisted,
      data: blocklisted,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Toggle / Set Customer Blocklist Status
 * Route: PATCH /api/admin/customers/:id/blocklist
 * Also: PATCH /api/customers/:id/blocklist
 * Permission: Admin or Manager only
 */
export async function toggleCustomerBlocklist(req, res, next) {
  try {
    const customerId = parseIntegerId(req.params.id, 'customer_id');

    if (!customerId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid customer ID. Must be a positive integer.',
      });
    }

    const customer = await prisma.customer.findUnique({
      where: { customer_id: customerId },
    });

    if (!customer) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Customer with ID ${customerId} not found.`,
      });
    }

    // If explicit boolean provided in body, use it; otherwise toggle current value
    const targetStatus =
      typeof req.body?.is_blocklisted === 'boolean'
        ? req.body.is_blocklisted
        : !customer.is_blocklisted;

    const blocklistReason = req.body?.blocklist_reason;

    // When blacklisting, reason can be captured
    const updateData = { is_blocklisted: targetStatus };
    if (targetStatus && blocklistReason) {
      updateData.blocklist_reason = blocklistReason.trim();
    } else if (!targetStatus) {
      // When unblacklisting, clear the blocklist reason
      updateData.blocklist_reason = null;
    }

    const updated = await prisma.customer.update({
      where: { customer_id: customerId },
      data: updateData,
    });

    return res.status(200).json({
      status: 'success',
      message: `Customer "${updated.name}" has been ${
        targetStatus ? 'BLOCKLISTED' : 'REMOVED from blocklist'
      }.`,
      customer: updated,
      data: updated,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Modify / Upgrade / Switch Customer Tier
 * Route: PATCH /api/customers/:id/tier
 * Permission: Manager or Admin only
 */
export async function updateCustomerTier(req, res, next) {
  try {
    const customerId = parseIntegerId(req.params.id, 'customer_id');
    const { tier } = req.body;

    if (!customerId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid customer ID. Must be a positive integer.',
      });
    }

    if (!tier || !VALID_TIERS.includes(tier.toUpperCase())) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Invalid or missing tier. Must be one of: [${VALID_TIERS.join(', ')}].`,
      });
    }

    const assignedTier = tier.toUpperCase();

    const customer = await prisma.customer.findUnique({
      where: { customer_id: customerId },
    });

    if (!customer) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Customer with ID ${customerId} not found.`,
      });
    }

    const previousTier = customer.tier;

    const updated = await prisma.customer.update({
      where: { customer_id: customerId },
      data: { tier: assignedTier },
    });

    return res.status(200).json({
      status: 'success',
      message: `Customer tier updated from "${previousTier || 'NONE'}" to "${assignedTier}".`,
      customer: updated,
      data: updated,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: List all customers with optional filters
 * Route: GET /api/customers
 *
 * Query Params:
 * - customer_type: 'NEW' | 'EXISTING'
 * - tier: 'PREMIUM' | 'LOYAL' | 'INTERIOR_DESIGNER'
 * - is_blocklisted: 'true' | 'false'
 * - search: text matching name, phone, billing_address, or linked opportunity location_name
 * - location: text matching billing_address or linked opportunity location_name
 */
export async function getAllCustomers(req, res, next) {
  try {
    const { search, tier, customer_type, is_blocklisted, location } = req.query;

    const where = {};

    if (tier && VALID_TIERS.includes(tier.toUpperCase())) {
      where.tier = tier.toUpperCase();
    }

    if (customer_type && ['NEW', 'EXISTING'].includes(customer_type.toUpperCase())) {
      where.customer_type = customer_type.toUpperCase();
    }

    if (typeof is_blocklisted !== 'undefined') {
      where.is_blocklisted = is_blocklisted === 'true';
    }

    const conditions = [];

    if (search && search.trim()) {
      conditions.push({
        OR: [
          { name: { contains: search.trim(), mode: 'insensitive' } },
          { phone: { contains: search.trim(), mode: 'insensitive' } },
          { billing_address: { contains: search.trim(), mode: 'insensitive' } },
          {
            opportunities: {
              some: {
                location_name: { contains: search.trim(), mode: 'insensitive' },
              },
            },
          },
        ],
      });
    }

    if (location && location.trim()) {
      conditions.push({
        OR: [
          { billing_address: { contains: location.trim(), mode: 'insensitive' } },
          {
            opportunities: {
              some: {
                location_name: { contains: location.trim(), mode: 'insensitive' },
              },
            },
          },
        ],
      });
    }

    if (conditions.length > 0) {
      where.AND = conditions;
    }

    const customers = await prisma.customer.findMany({
      where,
      include: {
        _count: {
          select: { opportunities: true },
        },
      },
      orderBy: { created_at: 'desc' },
    });

    return res.status(200).json({
      status: 'success',
      count: customers.length,
      customers,
      data: customers,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Get Single Customer Details
 * Route: GET /api/customers/:id
 */
export async function getCustomerById(req, res, next) {
  try {
    const customerId = parseIntegerId(req.params.id, 'customer_id');

    if (!customerId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid customer ID. Must be a positive integer.',
      });
    }

    const customer = await prisma.customer.findUnique({
      where: { customer_id: customerId },
      include: {
        opportunities: {
          include: {
            assigned_employee: {
              select: { employee_id: true, name: true, email: true },
            },
          },
          orderBy: { created_at: 'desc' },
        },
      },
    });

    if (!customer) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Customer with ID ${customerId} not found.`,
      });
    }

    return res.status(200).json({
      status: 'success',
      customer,
      data: customer,
    });
  } catch (error) {
    return next(error);
  }
}

export default {
  createCustomerWithOpportunity,
  getExistingCustomersByTier,
  getCustomerOpportunitiesAndPlants,
  getBlocklistedCustomers,
  toggleCustomerBlocklist,
  updateCustomerTier,
  getAllCustomers,
  getCustomerById,
};
