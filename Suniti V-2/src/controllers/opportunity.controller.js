import prisma from '../config/prisma.js';

const VALID_DEAL_STATUSES = ['PIPELINE', 'CLOSED_WON', 'CLOSED_LOST'];
const VALID_PROJECT_PHASES = ['TALKING', 'PROCESSING', 'DEAL_CLOSED'];
const VALID_TEMPERATURES = ['HOT', 'WARM', 'COLD'];
const VALID_TIERS = ['PREMIUM', 'LOYAL', 'INTERIOR_DESIGNER'];

/**
 * Helper: Parse integer ID safely
 */
function parseIntegerId(param) {
  const parsed = parseInt(param, 10);
  if (isNaN(parsed) || parsed <= 0) {
    return null;
  }
  return parsed;
}

/**
 * Controller: Create New Opportunity with Employee Attribution
 * Route: POST /api/opportunities
 */
export async function createOpportunity(req, res, next) {
  try {
    const {
      customer_id,
      project_title,
      location_name,
      lead_temperature,
      employee_id,
      conclusion_notes,
      next_call_date,
    } = req.body;

    // 1. Validate inputs
    const parsedCustomerId = parseIntegerId(customer_id);
    if (!parsedCustomerId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'A valid numeric "customer_id" is required.',
      });
    }

    if (!project_title || typeof project_title !== 'string' || !project_title.trim()) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Field "project_title" is required.',
      });
    }

    // 2. Verify Customer existence and blocklist check
    const customer = await prisma.customer.findUnique({
      where: { customer_id: parsedCustomerId },
    });

    if (!customer) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Customer with ID ${parsedCustomerId} does not exist.`,
      });
    }

    if (customer.is_blocklisted) {
      return res.status(403).json({
        error: 'Forbidden',
        message: `Cannot create opportunity: Customer "${customer.name}" is blocklisted.`,
      });
    }

    // 3. Employee attribution
    const assignedEmployeeId =
      employee_id && ['ADMIN', 'MANAGER'].includes(req.user?.role)
        ? parseInt(employee_id, 10)
        : req.user?.employee_id;

    if (!assignedEmployeeId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'A valid employee_id is required to attribute this opportunity.',
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

    // Schedule next call (Default: 30 days from creation if blank)
    let callDate;
    if (next_call_date && !isNaN(new Date(next_call_date).getTime())) {
      callDate = new Date(next_call_date);
    } else {
      const thirtyDaysAhead = new Date();
      thirtyDaysAhead.setDate(thirtyDaysAhead.getDate() + 30);
      callDate = thirtyDaysAhead;
    }

    // 4. Create opportunity and initial task in transaction
    const result = await prisma.$transaction(async (tx) => {
      const opportunity = await tx.opportunity.create({
        data: {
          customer_id: parsedCustomerId,
          employee_id: assignedEmployeeId,
          project_title: project_title.trim(),
          location_name: location_name ? location_name.trim() : null,
          lead_temperature: assignedTemp,
          deal_status: 'PIPELINE',
          project_phase: 'TALKING', // Default lifecycle stage
          is_completed: false,
        },
        include: {
          customer: {
            select: { customer_id: true, name: true, customer_type: true, tier: true },
          },
          assigned_employee: {
            select: { employee_id: true, name: true, email: true, role: true },
          },
        },
      });

      const initialNote = await tx.leadNote.create({
        data: {
          opportunity_id: opportunity.opportunity_id,
          employee_id: assignedEmployeeId,
          conclusion_notes: conclusion_notes
            ? conclusion_notes.trim()
            : `Opportunity "${project_title.trim()}" created. Initial outreach scheduled.`,
          next_call_date: callDate,
          is_completed: false,
        },
      });

      return {
        ...opportunity,
        lead_notes: [initialNote],
      };
    });

    return res.status(201).json({
      status: 'success',
      message: 'Opportunity successfully created.',
      opportunity: result,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Update Opportunity Status & Pipeline Lifecycle Stage
 * Route: PATCH /api/opportunities/:id/status
 *
 * Business Rules & Rule 2 (Deal Closure Graduation):
 * - Sales Reps and Managers/Admins can advance lifecycle stages:
 *     TALKING -> PROCESSING -> DEAL_CLOSED.
 * - When deal_status is updated to 'CLOSED_WON':
 *     * Automatically update parent customer type from 'NEW' to 'EXISTING'.
 *     * Require/assign a valid customer tier ('PREMIUM', 'LOYAL', 'INTERIOR_DESIGNER').
 *     * Automatically transition project_phase to 'DEAL_CLOSED'.
 *     * Mark is_completed = true, completed_at = now, completed_by = req.user.employee_id.
 * - When deal_status is updated to 'CLOSED_LOST':
 *     * Mark project_phase = 'DEAL_CLOSED', is_completed = true.
 */
export async function updateOpportunityStatus(req, res, next) {
  try {
    const opportunityId = parseIntegerId(req.params.id);
    const { deal_status, project_phase, lead_temperature, tier } = req.body;

    if (!opportunityId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid opportunity ID. Must be a positive integer.',
      });
    }

    // 1. Fetch current opportunity and parent customer
    const opportunity = await prisma.opportunity.findUnique({
      where: { opportunity_id: opportunityId },
      include: {
        customer: true,
      },
    });

    if (!opportunity) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Opportunity with ID ${opportunityId} not found.`,
      });
    }

    // Role verification: Sales Reps can update deals assigned to them or if authorized; Managers/Admins can update any
    if (
      req.user.role === 'SALES_REP' &&
      opportunity.employee_id !== req.user.employee_id
    ) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'You can only update opportunities assigned to you.',
      });
    }

    const currentCustomer = opportunity.customer;
    const oppUpdateData = {};
    let customerUpdateData = null;

    // 2. Validate lead_temperature update if provided
    if (lead_temperature) {
      const upperTemp = lead_temperature.toUpperCase();
      if (!VALID_TEMPERATURES.includes(upperTemp)) {
        return res.status(400).json({
          error: 'Bad Request',
          message: `Invalid lead_temperature. Allowed: ${VALID_TEMPERATURES.join(', ')}`,
        });
      }
      oppUpdateData.lead_temperature = upperTemp;
    }

    // 3. Validate project_phase update if provided
    if (project_phase) {
      const upperPhase = project_phase.toUpperCase();
      if (!VALID_PROJECT_PHASES.includes(upperPhase)) {
        return res.status(400).json({
          error: 'Bad Request',
          message: `Invalid project_phase "${project_phase}". Allowed lifecycle stages: ${VALID_PROJECT_PHASES.join(', ')}`,
        });
      }
      oppUpdateData.project_phase = upperPhase;
    }

    // 4. Validate deal_status update if provided (Rule 2: Deal Closure Graduation)
    if (deal_status) {
      const upperStatus = deal_status.toUpperCase();
      if (!VALID_DEAL_STATUSES.includes(upperStatus)) {
        return res.status(400).json({
          error: 'Bad Request',
          message: `Invalid deal_status "${deal_status}". Allowed: ${VALID_DEAL_STATUSES.join(', ')}`,
        });
      }

      oppUpdateData.deal_status = upperStatus;

      // Handle CLOSED_WON
      if (upperStatus === 'CLOSED_WON') {
        oppUpdateData.project_phase = 'DEAL_CLOSED';
        oppUpdateData.is_completed = true;
        oppUpdateData.completed_at = new Date();
        oppUpdateData.completed_by = req.user.employee_id;

        // Rule 2: Determine customer tier assignment upon graduation
        let assignedTier = null;
        if (tier) {
          const upperTier = tier.toUpperCase();
          if (!VALID_TIERS.includes(upperTier)) {
            return res.status(400).json({
              error: 'Bad Request',
              message: `Invalid tier "${tier}". Closing a won deal requires one of: [${VALID_TIERS.join(', ')}].`,
            });
          }
          assignedTier = upperTier;
        } else if (currentCustomer.tier) {
          // Keep existing valid customer tier
          assignedTier = currentCustomer.tier;
        } else {
          // If customer has no tier assigned yet and none passed, default to LOYAL
          assignedTier = 'LOYAL';
        }

        // Rule 2: Graduate parent customer type from 'NEW' to 'EXISTING' with assigned tier
        customerUpdateData = {
          customer_type: 'EXISTING',
          tier: assignedTier,
        };
      }

      // Handle CLOSED_LOST
      if (upperStatus === 'CLOSED_LOST') {
        oppUpdateData.project_phase = 'DEAL_CLOSED';
        oppUpdateData.is_completed = true;
        oppUpdateData.completed_at = new Date();
        oppUpdateData.completed_by = req.user.employee_id;
      }
    }

    // Check if there is anything to update
    if (Object.keys(oppUpdateData).length === 0 && !customerUpdateData) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'No valid update fields provided (deal_status, project_phase, lead_temperature, tier).',
      });
    }

    // 5. Execute atomic transaction
    const updateResult = await prisma.$transaction(async (tx) => {
      let updatedCustomer = currentCustomer;

      if (customerUpdateData) {
        updatedCustomer = await tx.customer.update({
          where: { customer_id: currentCustomer.customer_id },
          data: customerUpdateData,
        });
      }

      const updatedOpportunity = await tx.opportunity.update({
        where: { opportunity_id: opportunityId },
        data: oppUpdateData,
        include: {
          customer: true,
          assigned_employee: {
            select: { employee_id: true, name: true, email: true, role: true },
          },
          completed_by_employee: {
            select: { employee_id: true, name: true, email: true },
          },
        },
      });

      return {
        opportunity: updatedOpportunity,
        customer_graduated: Boolean(customerUpdateData),
        customer: updatedCustomer,
      };
    });

    const isGraduated = updateResult.customer_graduated;
    return res.status(200).json({
      status: 'success',
      message: isGraduated
        ? `Deal CLOSED_WON! Parent customer "${updateResult.customer.name}" graduated to EXISTING with tier "${updateResult.customer.tier}".`
        : 'Opportunity updated successfully.',
      data: updateResult,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: List Opportunities with Filters
 * Route: GET /api/opportunities
 */
export async function getOpportunities(req, res, next) {
  try {
    const {
      deal_status,
      project_phase,
      lead_temperature,
      employee_id,
      customer_id,
      is_completed,
      search,
    } = req.query;

    const where = {};

    if (deal_status && VALID_DEAL_STATUSES.includes(deal_status.toUpperCase())) {
      where.deal_status = deal_status.toUpperCase();
    }

    if (project_phase && VALID_PROJECT_PHASES.includes(project_phase.toUpperCase())) {
      where.project_phase = project_phase.toUpperCase();
    }

    if (lead_temperature && VALID_TEMPERATURES.includes(lead_temperature.toUpperCase())) {
      where.lead_temperature = lead_temperature.toUpperCase();
    }

    if (employee_id) {
      where.employee_id = parseInt(employee_id, 10);
    }

    if (customer_id) {
      where.customer_id = parseInt(customer_id, 10);
    }

    if (typeof is_completed !== 'undefined') {
      where.is_completed = is_completed === 'true';
    }

    if (search && search.trim()) {
      where.OR = [
        { project_title: { contains: search.trim(), mode: 'insensitive' } },
        { location_name: { contains: search.trim(), mode: 'insensitive' } },
      ];
    }

    const opportunities = await prisma.opportunity.findMany({
      where,
      include: {
        customer: {
          select: {
            customer_id: true,
            name: true,
            customer_type: true,
            tier: true,
            is_blocklisted: true,
          },
        },
        assigned_employee: {
          select: { employee_id: true, name: true, email: true, role: true },
        },
        _count: {
          select: { lead_notes: true },
        },
      },
      orderBy: { created_at: 'desc' },
    });

    return res.status(200).json({
      status: 'success',
      count: opportunities.length,
      opportunities,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Get Single Opportunity with Full Lead Notes History
 * Route: GET /api/opportunities/:id
 */
export async function getOpportunityById(req, res, next) {
  try {
    const opportunityId = parseIntegerId(req.params.id);

    if (!opportunityId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid opportunity ID. Must be a positive integer.',
      });
    }

    const opportunity = await prisma.opportunity.findUnique({
      where: { opportunity_id: opportunityId },
      include: {
        customer: true,
        assigned_employee: {
          select: { employee_id: true, name: true, email: true, role: true },
        },
        completed_by_employee: {
          select: { employee_id: true, name: true, email: true },
        },
        lead_notes: {
          include: {
            author: {
              select: { employee_id: true, name: true, email: true },
            },
            completed_by_employee: {
              select: { employee_id: true, name: true, email: true },
            },
          },
          orderBy: { created_at: 'desc' },
        },
      },
    });

    if (!opportunity) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Opportunity with ID ${opportunityId} not found.`,
      });
    }

    return res.status(200).json({
      status: 'success',
      opportunity,
    });
  } catch (error) {
    return next(error);
  }
}

export default {
  createOpportunity,
  updateOpportunityStatus,
  getOpportunities,
  getOpportunityById,
};
