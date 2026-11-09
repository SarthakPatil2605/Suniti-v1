import prisma from '../config/prisma.js';

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
 * Controller: Fetch Today's Task Queue for Sales Rep / Manager
 * Route: GET /api/tasks/today
 *
 * Query options:
 * - employee_id: Filter by specific employee (Managers/Admins only)
 * - include_overdue: 'true' (default: true) to include past due calls
 */
export async function getTodayTaskQueue(req, res, next) {
  try {
    const isManagerOrAdmin = ['ADMIN', 'MANAGER'].includes(req.user?.role);
    const requestedEmployeeId = req.query.employee_id
      ? parseIntegerId(req.query.employee_id)
      : null;

    // Determine target employee: Sales Reps can only view their own tasks
    let targetEmployeeId = req.user.employee_id;
    if (isManagerOrAdmin) {
      targetEmployeeId = requestedEmployeeId || (req.query.all === 'true' ? null : req.user.employee_id);
    }

    // Time boundaries for today
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
    const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);

    const where = {
      is_completed: false,
    };

    if (targetEmployeeId) {
      where.employee_id = targetEmployeeId;
    }

    const includeOverdue = req.query.include_overdue !== 'false';
    if (includeOverdue) {
      // Due up to the end of today (past overdue + today)
      where.next_call_date = {
        lte: endOfToday,
      };
    } else {
      // Strictly due today
      where.next_call_date = {
        gte: startOfToday,
        lte: endOfToday,
      };
    }

    const tasks = await prisma.leadNote.findMany({
      where,
      include: {
        opportunity: {
          select: {
            opportunity_id: true,
            project_title: true,
            location_name: true,
            deal_status: true,
            project_phase: true,
            lead_temperature: true,
            customer: {
              select: {
                customer_id: true,
                name: true,
                phone: true,
                tier: true,
                customer_type: true,
                is_blocklisted: true,
              },
            },
          },
        },
        author: {
          select: { employee_id: true, name: true, email: true },
        },
      },
      orderBy: {
        next_call_date: 'asc',
      },
    });

    // Partition tasks into overdue and due today
    let overdueCount = 0;
    let dueTodayCount = 0;

    const formattedTasks = tasks.map((task) => {
      const callDate = task.next_call_date ? new Date(task.next_call_date) : null;
      let urgency = 'DUE_TODAY';

      if (callDate && callDate < startOfToday) {
        urgency = 'OVERDUE';
        overdueCount++;
      } else {
        dueTodayCount++;
      }

      const diffMs = callDate ? now.getTime() - callDate.getTime() : 0;
      const daysOverdue = diffMs > 0 ? Math.floor(diffMs / (1000 * 60 * 60 * 24)) : 0;

      return {
        ...task,
        urgency,
        days_overdue: daysOverdue,
      };
    });

    return res.status(200).json({
      status: 'success',
      total_queue_count: formattedTasks.length,
      overdue_count: overdueCount,
      due_today_count: dueTodayCount,
      tasks: formattedTasks,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Log Conversation Conclusion Notes & Schedule Next Call
 * Route: POST /api/opportunities/:opportunity_id/notes
 * Also: POST /api/tasks/opportunity/:opportunity_id
 *
 * Core Automations:
 * 1. Automatically marks prior pending tasks for this opportunity as COMPLETED.
 * 2. Self-assigns the new follow-up task to the logged-in employee (req.user.employee_id).
 *    (Managers can override assignment via assigned_employee_id).
 * 3. If next_call_date is blank, automatically defaults to 30 days from creation.
 */
export async function logConclusionNoteAndScheduleCall(req, res, next) {
  try {
    const oppIdParam = req.params.opportunity_id || req.params.id;
    const opportunityId = parseIntegerId(oppIdParam, 'opportunity_id');

    const {
      conclusion_notes,
      next_call_date,
      assigned_employee_id,
      lead_temperature,
    } = req.body;

    if (!opportunityId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid opportunity ID. Must be a positive integer.',
      });
    }

    // 1. Verify opportunity exists
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

    // 2. Determine target assignee
    let targetEmployeeId = req.user.employee_id;
    if (
      assigned_employee_id &&
      ['ADMIN', 'MANAGER'].includes(req.user?.role)
    ) {
      const parsedAssigned = parseIntegerId(assigned_employee_id);
      if (parsedAssigned) {
        targetEmployeeId = parsedAssigned;
      }
    }

    // 3. Compute next call date (Default: 30 days from creation if blank)
    let callDate;
    if (next_call_date && !isNaN(new Date(next_call_date).getTime())) {
      callDate = new Date(next_call_date);
    } else {
      const thirtyDaysAhead = new Date();
      thirtyDaysAhead.setDate(thirtyDaysAhead.getDate() + 30);
      callDate = thirtyDaysAhead;
    }

    // 4. Atomic transaction
    const result = await prisma.$transaction(async (tx) => {
      // Step A: Mark prior pending tasks for this opportunity as COMPLETED
      const priorUpdated = await tx.leadNote.updateMany({
        where: {
          opportunity_id: opportunityId,
          is_completed: false,
        },
        data: {
          is_completed: true,
          completed_at: new Date(),
          completed_by: req.user.employee_id,
        },
      });

      // Step B: Update lead temperature if provided
      if (lead_temperature && ['HOT', 'WARM', 'COLD'].includes(lead_temperature.toUpperCase())) {
        await tx.opportunity.update({
          where: { opportunity_id: opportunityId },
          data: { lead_temperature: lead_temperature.toUpperCase() },
        });
      }

      // Step C: Create new lead note and scheduled follow-up
      const newNote = await tx.leadNote.create({
        data: {
          opportunity_id: opportunityId,
          employee_id: targetEmployeeId,
          conclusion_notes: conclusion_notes
            ? conclusion_notes.trim()
            : 'Call completed. Next follow-up call scheduled.',
          next_call_date: callDate,
          is_completed: false,
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
            },
          },
        },
      });

      return {
        new_note: newNote,
        prior_tasks_completed_count: priorUpdated.count,
      };
    });

    return res.status(201).json({
      status: 'success',
      message: `Conversation logged. ${result.prior_tasks_completed_count} prior task(s) completed. Next call scheduled for ${callDate.toISOString().split('T')[0]}.`,
      data: result,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Mark Task as Completed
 * Route: PATCH /api/tasks/:note_id/complete
 * Also: POST /api/tasks/:note_id/complete
 *
 * Records completed_by employee and completed_at timestamp.
 */
export async function completeTask(req, res, next) {
  try {
    const noteIdParam = req.params.note_id || req.params.id;
    const noteId = parseIntegerId(noteIdParam, 'note_id');
    const { conclusion_notes } = req.body;

    if (!noteId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid task/note ID. Must be a positive integer.',
      });
    }

    const task = await prisma.leadNote.findUnique({
      where: { note_id: noteId },
    });

    if (!task) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Task with ID ${noteId} not found.`,
      });
    }

    if (task.is_completed) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Task with ID ${noteId} has already been marked as completed.`,
        completed_at: task.completed_at,
        completed_by: task.completed_by,
      });
    }

    const updateData = {
      is_completed: true,
      completed_at: new Date(),
      completed_by: req.user.employee_id,
    };

    if (conclusion_notes && typeof conclusion_notes === 'string') {
      updateData.conclusion_notes = conclusion_notes.trim();
    }

    const updatedTask = await prisma.leadNote.update({
      where: { note_id: noteId },
      data: updateData,
      include: {
        author: {
          select: { employee_id: true, name: true, email: true },
        },
        completed_by_employee: {
          select: { employee_id: true, name: true, email: true },
        },
        opportunity: {
          select: {
            opportunity_id: true,
            project_title: true,
            customer: {
              select: { customer_id: true, name: true },
            },
          },
        },
      },
    });

    return res.status(200).json({
      status: 'success',
      message: `Task #${noteId} marked as completed successfully.`,
      task: updatedTask,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Manager Task Assignment
 * Route: PATCH /api/tasks/:note_id/assign
 * Permission: Manager or Admin only
 *
 * Allows managers to reassign or assign a task directly to any employee.
 */
export async function assignTask(req, res, next) {
  try {
    const noteIdParam = req.params.note_id || req.params.id;
    const noteId = parseIntegerId(noteIdParam, 'note_id');
    const { employee_id } = req.body;

    if (!noteId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid task ID. Must be a positive integer.',
      });
    }

    const targetEmployeeId = parseIntegerId(employee_id, 'employee_id');
    if (!targetEmployeeId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'A valid numeric "employee_id" is required for assignment.',
      });
    }

    // Verify target employee exists
    const targetEmployee = await prisma.employee.findUnique({
      where: { employee_id: targetEmployeeId },
      select: { employee_id: true, name: true, email: true, role: true },
    });

    if (!targetEmployee) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Target employee with ID ${targetEmployeeId} not found.`,
      });
    }

    const task = await prisma.leadNote.findUnique({
      where: { note_id: noteId },
    });

    if (!task) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Task with ID ${noteId} not found.`,
      });
    }

    const updatedTask = await prisma.leadNote.update({
      where: { note_id: noteId },
      data: { employee_id: targetEmployeeId },
      include: {
        author: {
          select: { employee_id: true, name: true, email: true, role: true },
        },
        opportunity: {
          select: { opportunity_id: true, project_title: true },
        },
      },
    });

    return res.status(200).json({
      status: 'success',
      message: `Task #${noteId} successfully assigned to ${targetEmployee.name} (${targetEmployee.email}).`,
      task: updatedTask,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: List all tasks / lead notes with filters
 * Route: GET /api/tasks
 */
export async function getTasks(req, res, next) {
  try {
    const {
      opportunity_id,
      employee_id,
      is_completed,
      overdue_only,
    } = req.query;

    const where = {};

    if (opportunity_id) {
      where.opportunity_id = parseInt(opportunity_id, 10);
    }

    if (employee_id) {
      where.employee_id = parseInt(employee_id, 10);
    } else if (req.user.role === 'SALES_REP') {
      where.employee_id = req.user.employee_id;
    }

    if (typeof is_completed !== 'undefined') {
      where.is_completed = is_completed === 'true';
    }

    if (overdue_only === 'true') {
      where.is_completed = false;
      where.next_call_date = { lt: new Date() };
    }

    const tasks = await prisma.leadNote.findMany({
      where,
      include: {
        author: {
          select: { employee_id: true, name: true, email: true },
        },
        completed_by_employee: {
          select: { employee_id: true, name: true, email: true },
        },
        opportunity: {
          select: {
            opportunity_id: true,
            project_title: true,
            customer: {
              select: { customer_id: true, name: true, phone: true },
            },
          },
        },
      },
      orderBy: { created_at: 'desc' },
    });

    return res.status(200).json({
      status: 'success',
      count: tasks.length,
      tasks,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Controller: Get Task by ID
 * Route: GET /api/tasks/:id
 */
export async function getTaskById(req, res, next) {
  try {
    const noteId = parseIntegerId(req.params.id);

    if (!noteId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid task ID. Must be a positive integer.',
      });
    }

    const task = await prisma.leadNote.findUnique({
      where: { note_id: noteId },
      include: {
        author: {
          select: { employee_id: true, name: true, email: true, role: true },
        },
        completed_by_employee: {
          select: { employee_id: true, name: true, email: true },
        },
        opportunity: {
          include: {
            customer: true,
          },
        },
      },
    });

    if (!task) {
      return res.status(404).json({
        error: 'Not Found',
        message: `Task with ID ${noteId} not found.`,
      });
    }

    return res.status(200).json({
      status: 'success',
      task,
    });
  } catch (error) {
    return next(error);
  }
}

export default {
  getTodayTaskQueue,
  logConclusionNoteAndScheduleCall,
  completeTask,
  assignTask,
  getTasks,
  getTaskById,
};
