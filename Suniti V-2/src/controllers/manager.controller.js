import bcrypt from 'bcrypt';
import prisma from '../config/prisma.js';

const VALID_ROLES = ['ADMIN', 'MANAGER', 'SALES_REP'];

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

// ==========================================
// 1. EMPLOYEE CRUD OPERATIONS
// ==========================================

/**
 * Controller: List all employees with filters & activity counts
 * Route: GET /api/manager/employees (also /api/employees)
 */
export async function getEmployees(req, res, next) {
  try {
    const { role, search } = req.query;

    const where = {};
    if (role && VALID_ROLES.includes(role.toUpperCase())) {
      where.role = role.toUpperCase();
    }

    if (search && search.trim()) {
      where.OR = [
        { name: { contains: search.trim(), mode: 'insensitive' } },
        { email: { contains: search.trim(), mode: 'insensitive' } },
      ];
    }

    const employees = await prisma.employee.findMany({
      where,
      select: {
        employee_id: true,
        name: true,
        email: true,
        role: true,
        created_at: true,
        _count: {
          select: {
            assigned_opportunities: true,
            authored_notes: true,
          },
        },
      },
      orderBy: { created_at: 'desc' },
    });

    return res.status(200).json({
      status: 'success',
      count: employees.length,
      employees,
      data: employees,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Get Single Employee by ID with Detailed Activity Stats
 * Route: GET /api/manager/employees/:id (also /api/employees/:id)
 */
export async function getEmployeeById(req, res, next) {
  try {
    const employeeId = parseIntegerId(req.params.id);

    if (!employeeId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid employee ID. Must be a positive integer.',
      });
    }

    const employee = await prisma.employee.findUnique({
      where: { employee_id: employeeId },
      select: {
        employee_id: true,
        name: true,
        email: true,
        role: true,
        created_at: true,
        assigned_opportunities: {
          select: {
            opportunity_id: true,
            project_title: true,
            deal_status: true,
            project_phase: true,
            lead_temperature: true,
            customer: {
              select: { customer_id: true, name: true, tier: true },
            },
          },
          orderBy: { created_at: 'desc' },
          take: 10,
        },
        _count: {
          select: {
            assigned_opportunities: true,
            authored_notes: true,
            completed_notes: true,
            completed_opportunities: true,
          },
        },
      },
    });

    if (!employee) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Employee with ID ${employeeId} not found.`,
      });
    }

    return res.status(200).json({
      status: 'success',
      employee,
      data: employee,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Create New Employee
 * Route: POST /api/manager/employees (also /api/employees)
 */
export async function createEmployee(req, res, next) {
  try {
    const { name, email, password, role } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Fields "name", "email", and "password" are required.',
      });
    }

    const normalizedEmail = email.trim().toLowerCase();
    const assignedRole = role ? role.toUpperCase() : 'SALES_REP';

    if (!VALID_ROLES.includes(assignedRole)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Invalid role "${role}". Allowed roles: ${VALID_ROLES.join(', ')}`,
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Password must be at least 6 characters long.',
      });
    }

    const existing = await prisma.employee.findUnique({
      where: { email: normalizedEmail },
    });

    if (existing) {
      return res.status(409).json({
        error: 'Conflict',
        message: `An employee with email "${normalizedEmail}" is already registered.`,
      });
    }

    const password_hash = await bcrypt.hash(password, 10);

    const newEmployee = await prisma.employee.create({
      data: {
        name: name.trim(),
        email: normalizedEmail,
        password_hash,
        role: assignedRole,
      },
      select: {
        employee_id: true,
        name: true,
        email: true,
        role: true,
        created_at: true,
      },
    });

    return res.status(201).json({
      status: 'success',
      message: 'Employee created successfully.',
      employee: newEmployee,
      data: newEmployee,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Update Employee (Role, Name, Email, Password)
 * Route: PATCH /api/manager/employees/:id (also /api/employees/:id)
 */
export async function updateEmployee(req, res, next) {
  try {
    const employeeId = parseIntegerId(req.params.id);
    const { name, email, role, password } = req.body;

    if (!employeeId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid employee ID. Must be a positive integer.',
      });
    }

    const employee = await prisma.employee.findUnique({
      where: { employee_id: employeeId },
    });

    if (!employee) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Employee with ID ${employeeId} not found.`,
      });
    }

    const updateData = {};

    if (name && typeof name === 'string' && name.trim()) {
      updateData.name = name.trim();
    }

    if (email && typeof email === 'string' && email.trim()) {
      const normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail !== employee.email) {
        const emailTaken = await prisma.employee.findUnique({
          where: { email: normalizedEmail },
        });
        if (emailTaken) {
          return res.status(409).json({
            error: 'Conflict',
            message: `Email "${normalizedEmail}" is already in use by another staff member.`,
          });
        }
        updateData.email = normalizedEmail;
      }
    }

    if (role) {
      const upperRole = role.toUpperCase();
      if (!VALID_ROLES.includes(upperRole)) {
        return res.status(400).json({
          error: 'Bad Request',
          message: `Invalid role "${role}". Allowed roles: ${VALID_ROLES.join(', ')}`,
        });
      }
      updateData.role = upperRole;
    }

    if (password && typeof password === 'string' && password.length >= 6) {
      updateData.password_hash = await bcrypt.hash(password, 10);
    }

    const updated = await prisma.employee.update({
      where: { employee_id: employeeId },
      data: updateData,
      select: {
        employee_id: true,
        name: true,
        email: true,
        role: true,
        created_at: true,
      },
    });

    return res.status(200).json({
      status: 'success',
      message: `Employee #${employeeId} updated successfully.`,
      employee: updated,
      data: updated,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Delete Employee
 * Route: DELETE /api/manager/employees/:id (also /api/employees/:id)
 * Permission: Admin only
 */
export async function deleteEmployee(req, res, next) {
  try {
    const employeeId = parseIntegerId(req.params.id);

    if (!employeeId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid employee ID. Must be a positive integer.',
      });
    }

    // Protect against self-deletion
    if (req.user?.employee_id === employeeId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'You cannot delete your own account.',
      });
    }

    const employee = await prisma.employee.findUnique({
      where: { employee_id: employeeId },
      include: {
        _count: {
          select: {
            assigned_opportunities: true,
            authored_notes: true,
          },
        },
      },
    });

    if (!employee) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Employee with ID ${employeeId} not found.`,
      });
    }

    // Safety check for dependent relational data
    if (employee._count.assigned_opportunities > 0) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Cannot delete employee #${employeeId}: Employee has ${employee._count.assigned_opportunities} active/historical opportunities. Reassign opportunities first.`,
      });
    }

    await prisma.employee.delete({
      where: { employee_id: employeeId },
    });

    return res.status(200).json({
      status: 'success',
      message: `Employee "${employee.name}" (#${employeeId}) deleted successfully.`,
    });
  } catch (error) {
    return next(error);
  }
}

// ==========================================
// 2. TEAM WORKLOAD OVERVIEW
// ==========================================

/**
 * Controller: Team Workload Overview
 * Route: GET /api/manager/workload
 *
 * Provides managers with visibility into active pipeline count, pending tasks,
 * overdue calls, and capacity status across all sales reps.
 */
export async function getTeamWorkload(req, res, next) {
  try {
    const now = new Date();

    const employees = await prisma.employee.findMany({
      where: {
        role: { in: ['SALES_REP', 'MANAGER'] },
      },
      select: {
        employee_id: true,
        name: true,
        email: true,
        role: true,
        assigned_opportunities: {
          select: {
            opportunity_id: true,
            deal_status: true,
            project_phase: true,
            lead_temperature: true,
          },
        },
        authored_notes: {
          where: { is_completed: false },
          select: {
            note_id: true,
            next_call_date: true,
          },
        },
      },
      orderBy: { name: 'asc' },
    });

    const workloadReport = employees.map((emp) => {
      // Pipeline metrics
      const activeOpps = emp.assigned_opportunities.filter((o) => o.deal_status === 'PIPELINE');
      const wonDeals = emp.assigned_opportunities.filter((o) => o.deal_status === 'CLOSED_WON');
      const lostDeals = emp.assigned_opportunities.filter((o) => o.deal_status === 'CLOSED_LOST');

      // Task metrics
      const pendingTasks = emp.authored_notes;
      const overdueTasks = pendingTasks.filter(
        (t) => t.next_call_date && new Date(t.next_call_date) < now
      );

      // Workload capacity indicator
      let capacityStatus = 'BALANCED';
      if (pendingTasks.length > 15 || overdueTasks.length > 5) {
        capacityStatus = 'OVERLOADED';
      } else if (pendingTasks.length < 5 && activeOpps.length < 5) {
        capacityStatus = 'AVAILABLE';
      }

      return {
        employee_id: emp.employee_id,
        name: emp.name,
        email: emp.email,
        role: emp.role,
        active_opportunities_count: activeOpps.length,
        won_deals_count: wonDeals.length,
        lost_deals_count: lostDeals.length,
        pending_tasks_count: pendingTasks.length,
        overdue_tasks_count: overdueTasks.length,
        capacity_status: capacityStatus,
      };
    });

    return res.status(200).json({
      status: 'success',
      timestamp: now.toISOString(),
      team_count: workloadReport.length,
      workload: workloadReport,
      data: workloadReport,
    });
  } catch (error) {
    return next(error);
  }
}

// ==========================================
// 3. OVERDUE TASK ALERTS
// ==========================================

/**
 * Controller: Overdue Task Alerts
 * Route: GET /api/manager/alerts/overdue-tasks
 *
 * Filters pending tasks where next_call_date has passed current timestamp,
 * calculating overdue duration and urgency.
 */
export async function getOverdueTaskAlerts(req, res, next) {
  try {
    const now = new Date();

    const overdueTasks = await prisma.leadNote.findMany({
      where: {
        is_completed: false,
        next_call_date: {
          lt: now,
        },
      },
      include: {
        author: {
          select: { employee_id: true, name: true, email: true, role: true },
        },
        opportunity: {
          select: {
            opportunity_id: true,
            project_title: true,
            deal_status: true,
            project_phase: true,
            lead_temperature: true,
            location_name: true,
            customer: {
              select: {
                customer_id: true,
                name: true,
                phone: true,
                tier: true,
                is_blocklisted: true,
              },
            },
          },
        },
      },
      orderBy: {
        next_call_date: 'asc', // Most overdue first
      },
    });

    let criticalCount = 0; // Overdue > 7 days

    const alerts = overdueTasks.map((task) => {
      const callDate = new Date(task.next_call_date);
      const diffMs = now.getTime() - callDate.getTime();
      const hoursOverdue = Math.floor(diffMs / (1000 * 60 * 60));
      const daysOverdue = Math.floor(hoursOverdue / 24);

      if (daysOverdue >= 7) {
        criticalCount++;
      }

      return {
        note_id: task.note_id,
        opportunity_id: task.opportunity_id,
        project_title: task.opportunity.project_title,
        customer_name: task.opportunity.customer.name,
        customer_phone: task.opportunity.customer.phone,
        lead_temperature: task.opportunity.lead_temperature,
        assigned_employee: task.author,
        scheduled_call_date: task.next_call_date,
        conclusion_notes: task.conclusion_notes,
        hours_overdue: hoursOverdue,
        days_overdue: daysOverdue,
        alert_level: daysOverdue >= 7 ? 'CRITICAL' : daysOverdue >= 3 ? 'HIGH' : 'WARNING',
      };
    });

    return res.status(200).json({
      status: 'success',
      total_overdue: alerts.length,
      critical_overdue_count: criticalCount,
      alerts,
      data: alerts,
    });
  } catch (error) {
    return next(error);
  }
}

// ==========================================
// 4. FULL AUDIT ATTRIBUTION
// ==========================================

/**
 * Controller: Full Lead History Audit
 * Route: GET /api/manager/audit/lead-history/:opportunity_id
 *
 * Returns complete audit trail with creator name, updater name,
 * and completion attribution across the opportunity and note lifecycle.
 */
export async function getLeadHistoryAudit(req, res, next) {
  try {
    const oppIdParam = req.params.opportunity_id || req.params.id;
    const opportunityId = parseIntegerId(oppIdParam, 'opportunity_id');

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
          select: { employee_id: true, name: true, email: true, role: true },
        },
        lead_notes: {
          include: {
            author: {
              select: { employee_id: true, name: true, email: true, role: true },
            },
            completed_by_employee: {
              select: { employee_id: true, name: true, email: true, role: true },
            },
          },
          orderBy: { created_at: 'asc' },
        },
      },
    });

    if (!opportunity) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Opportunity with ID ${opportunityId} not found.`,
      });
    }

    // Build chronological audit entries
    const timeline = [];

    // 1. Initial creation entry
    timeline.push({
      event: 'OPPORTUNITY_CREATED',
      timestamp: opportunity.created_at,
      actor: opportunity.assigned_employee,
      details: {
        project_title: opportunity.project_title,
        location_name: opportunity.location_name,
        initial_phase: opportunity.project_phase,
        initial_temperature: opportunity.lead_temperature,
      },
    });

    // 2. Note and task history entries
    opportunity.lead_notes.forEach((note) => {
      timeline.push({
        event: 'NOTE_AND_CALL_LOGGED',
        note_id: note.note_id,
        timestamp: note.created_at,
        actor: note.author,
        details: {
          conclusion_notes: note.conclusion_notes,
          scheduled_next_call: note.next_call_date,
        },
      });

      if (note.is_completed && note.completed_at) {
        timeline.push({
          event: 'TASK_COMPLETED',
          note_id: note.note_id,
          timestamp: note.completed_at,
          actor: note.completed_by_employee || { name: 'System / Automated' },
          details: {
            completion_date: note.completed_at,
          },
        });
      }
    });

    // 3. Opportunity completion entry
    if (opportunity.is_completed && opportunity.completed_at) {
      timeline.push({
        event: 'OPPORTUNITY_CLOSED',
        timestamp: opportunity.completed_at,
        actor: opportunity.completed_by_employee || { name: 'System / Automated' },
        details: {
          deal_status: opportunity.deal_status,
          final_phase: opportunity.project_phase,
        },
      });
    }

    // Sort timeline chronologically
    timeline.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    return res.status(200).json({
      status: 'success',
      opportunity_id: opportunity.opportunity_id,
      project_title: opportunity.project_title,
      customer: {
        customer_id: opportunity.customer.customer_id,
        name: opportunity.customer.name,
        customer_type: opportunity.customer.customer_type,
        tier: opportunity.customer.tier,
      },
      attribution_summary: {
        created_by: opportunity.assigned_employee,
        is_completed: opportunity.is_completed,
        completed_by: opportunity.completed_by_employee,
        completed_at: opportunity.completed_at,
      },
      audit_timeline_count: timeline.length,
      audit_timeline: timeline,
      data: timeline,
    });
  } catch (error) {
    return next(error);
  }
}

// ==========================================
// 5. ANALYTICS & EXPORT REPORTING
// ==========================================

/**
 * Controller: Analytics & Metrics Reporting
 * Route: GET /api/manager/analytics
 * Also: GET /api/manager/analytics/export (supports ?format=csv)
 */
export async function getAnalyticsReport(req, res, next) {
  try {
    const { format } = req.query;

    // A. Aggregated Pipeline Phase Counts
    const phaseCounts = await prisma.opportunity.groupBy({
      by: ['project_phase'],
      _count: { opportunity_id: true },
    });

    // B. Aggregated Deal Status Counts
    const statusCounts = await prisma.opportunity.groupBy({
      by: ['deal_status'],
      _count: { opportunity_id: true },
    });

    // C. Aggregated Lead Temperature Counts
    const tempCounts = await prisma.opportunity.groupBy({
      by: ['lead_temperature'],
      _count: { opportunity_id: true },
    });

    // Format metrics maps
    const phaseMap = { TALKING: 0, PROCESSING: 0, DEAL_CLOSED: 0 };
    phaseCounts.forEach((p) => {
      phaseMap[p.project_phase] = p._count.opportunity_id;
    });

    const statusMap = { PIPELINE: 0, CLOSED_WON: 0, CLOSED_LOST: 0 };
    statusCounts.forEach((s) => {
      statusMap[s.deal_status] = s._count.opportunity_id;
    });

    const tempMap = { HOT: 0, WARM: 0, COLD: 0 };
    tempCounts.forEach((t) => {
      tempMap[t.lead_temperature] = t._count.opportunity_id;
    });

    // D. Conversion Rates
    const totalOpportunities = statusMap.PIPELINE + statusMap.CLOSED_WON + statusMap.CLOSED_LOST;
    const closedDecidedDeals = statusMap.CLOSED_WON + statusMap.CLOSED_LOST;
    const winRate =
      closedDecidedDeals > 0
        ? parseFloat(((statusMap.CLOSED_WON / closedDecidedDeals) * 100).toFixed(2))
        : 0;

    const pipelineWinRatio =
      totalOpportunities > 0
        ? parseFloat(((statusMap.CLOSED_WON / totalOpportunities) * 100).toFixed(2))
        : 0;

    // E. Team Activity Metrics
    const teamActivity = await prisma.employee.findMany({
      where: {
        role: { in: ['SALES_REP', 'MANAGER'] },
      },
      select: {
        employee_id: true,
        name: true,
        email: true,
        role: true,
        _count: {
          select: {
            assigned_opportunities: true,
            authored_notes: true,
            completed_notes: true,
            completed_opportunities: true,
          },
        },
      },
    });

    // Calculate won deals per employee
    const wonDealsByRep = await prisma.opportunity.groupBy({
      by: ['employee_id'],
      where: { deal_status: 'CLOSED_WON' },
      _count: { opportunity_id: true },
    });

    const wonMap = {};
    wonDealsByRep.forEach((w) => {
      wonMap[w.employee_id] = w._count.opportunity_id;
    });

    const activityMetrics = teamActivity.map((member) => ({
      employee_id: member.employee_id,
      name: member.name,
      email: member.email,
      role: member.role,
      total_deals_managed: member._count.assigned_opportunities,
      deals_won: wonMap[member.employee_id] || 0,
      notes_logged: member._count.authored_notes,
      tasks_completed: member._count.completed_notes,
    }));

    const reportData = {
      timestamp: new Date().toISOString(),
      summary: {
        total_opportunities: totalOpportunities,
        active_pipeline: statusMap.PIPELINE,
        closed_won: statusMap.CLOSED_WON,
        closed_lost: statusMap.CLOSED_LOST,
        win_rate_percentage: winRate,
        pipeline_win_ratio_percentage: pipelineWinRatio,
      },
      pipeline_by_phase: phaseMap,
      pipeline_by_status: statusMap,
      leads_by_temperature: tempMap,
      team_activity: activityMetrics,
    };

    // If CSV export requested
    if (format === 'csv') {
      let csvContent = 'SUNITI CONSTRUCTION CRM - PIPELINE & WORKLOAD REPORT\n';
      csvContent += `Generated At,${reportData.timestamp}\n\n`;

      csvContent += 'EXECUTIVE SUMMARY\n';
      csvContent += `Total Opportunities,${reportData.summary.total_opportunities}\n`;
      csvContent += `Active in Pipeline,${reportData.summary.active_pipeline}\n`;
      csvContent += `Closed Won,${reportData.summary.closed_won}\n`;
      csvContent += `Closed Lost,${reportData.summary.closed_lost}\n`;
      csvContent += `Win Rate %,${reportData.summary.win_rate_percentage}%\n\n`;

      csvContent += 'PIPELINE BY LIFECYCLE PHASE\n';
      csvContent += `Phase,Count\n`;
      csvContent += `TALKING,${phaseMap.TALKING}\n`;
      csvContent += `PROCESSING,${phaseMap.PROCESSING}\n`;
      csvContent += `DEAL_CLOSED,${phaseMap.DEAL_CLOSED}\n\n`;

      csvContent += 'TEAM ACTIVITY & PERFORMANCE\n';
      csvContent += 'Employee ID,Name,Email,Role,Total Deals,Deals Won,Calls/Notes Logged,Tasks Completed\n';
      activityMetrics.forEach((m) => {
        csvContent += `${m.employee_id},"${m.name}","${m.email}",${m.role},${m.total_deals_managed},${m.deals_won},${m.notes_logged},${m.tasks_completed}\n`;
      });

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename="suniti_crm_analytics.csv"');
      return res.status(200).send(csvContent);
    }

    return res.status(200).json({
      status: 'success',
      report: reportData,
      data: reportData,
    });
  } catch (error) {
    return next(error);
  }
}

export default {
  getEmployees,
  getEmployeeById,
  createEmployee,
  updateEmployee,
  deleteEmployee,
  getTeamWorkload,
  getOverdueTaskAlerts,
  getLeadHistoryAudit,
  getAnalyticsReport,
};
