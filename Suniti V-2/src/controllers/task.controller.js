import prisma from '../config/prisma.js';

// Timezone offset for Asia/Kolkata (IST = UTC +05:30)
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

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
 * - date: YYYY-MM-DD (calendar day in Asia/Kolkata, defaults to current IST date)
 * - include_overdue: 'true' | 'false' (defaults to 'false')
 * - employee_id: Filter by specific employee (Managers/Admins only)
 */
export async function getTodayTaskQueue(req, res, next) {
  try {
    const isManagerOrAdmin = ['ADMIN', 'MANAGER'].includes(req.user?.role);
    const requestedEmployeeId = req.query.employee_id
      ? parseIntegerId(req.query.employee_id)
      : null;

    // Determine target employee: Sales Reps view only their own tasks
    let targetEmployeeId = req.user.employee_id;
    if (isManagerOrAdmin) {
      targetEmployeeId =
        requestedEmployeeId || (req.query.all === 'true' ? null : req.user.employee_id);
    }

    // 1. Calculate Asia/Kolkata (IST) Day Boundaries in UTC
    let dateStr = req.query.date;
    if (!dateStr || !/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
      const nowUtc = new Date();
      const nowIst = new Date(nowUtc.getTime() + IST_OFFSET_MS);
      dateStr = nowIst.toISOString().split('T')[0];
    }

    const [year, month, day] = dateStr.split('-').map(Number);
    // 00:00:00.000 IST in UTC
    const startOfDayUtc = new Date(Date.UTC(year, month - 1, day, 0, 0, 0, 0) - IST_OFFSET_MS);
    // 23:59:59.999 IST in UTC
    const endOfDayUtc = new Date(Date.UTC(year, month - 1, day, 23, 59, 59, 999) - IST_OFFSET_MS);

    const isIncludeOverdue = req.query.include_overdue === 'true';

    // 2. Build where filter
    const where = {};
    if (targetEmployeeId) {
      where.employee_id = targetEmployeeId;
    }

    if (isIncludeOverdue) {
      where.OR = [
        // Pending tasks due on or before today
        {
          next_call_date: { lte: endOfDayUtc },
          is_completed: false,
        },
        // Completed tasks due today
        {
          next_call_date: { gte: startOfDayUtc, lte: endOfDayUtc },
          is_completed: true,
        },
      ];
    } else {
      // Strictly due today
      where.next_call_date = {
        gte: startOfDayUtc,
        lte: endOfDayUtc,
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
            is_completed: true,
            customer: {
              select: {
                customer_id: true,
                name: true,
                phone: true,
                tier: true,
                customer_type: true,
                billing_address: true,
                is_blocklisted: true,
              },
            },
            lead_notes: {
              select: {
                note_id: true,
                conclusion_notes: true,
                next_call_date: true,
                is_completed: true,
                created_at: true,
                author: {
                  select: { name: true },
                },
              },
              orderBy: { created_at: 'desc' },
              take: 5,
            },
          },
        },
        author: {
          select: { employee_id: true, name: true, email: true, role: true },
        },
        completed_by_employee: {
          select: { employee_id: true, name: true, email: true },
        },
      },
      orderBy: [
        { is_completed: 'asc' },
        { next_call_date: 'asc' },
      ],
    });

    let pendingCount = 0;
    let completedCount = 0;

    const formattedTasks = tasks.map((task) => {
      if (task.is_completed) {
        completedCount++;
      } else {
        pendingCount++;
      }

      const opp = task.opportunity;
      const cust = opp?.customer;

      // Extract prior history excluding current task
      const priorHistory = (opp?.lead_notes || [])
        .filter((h) => h.note_id !== task.note_id)
        .map((h) => ({
          note_id: h.note_id,
          conclusion_notes: h.conclusion_notes,
          next_call_date: h.next_call_date,
          is_completed: h.is_completed,
          created_at: h.created_at,
          recorded_by: h.author?.name || 'System',
        }));

      return {
        // DailyTask flat schema expected by Flutter
        task_id: task.note_id,
        company_name: cust?.name || 'Unknown Company',
        location: opp?.location_name || cust?.billing_address || null,
        contact_details: cust
          ? {
              customer_id: cust.customer_id,
              phone: cust.phone,
              billing_address: cust.billing_address,
              customer_type: cust.customer_type,
              customer_tier: cust.tier,
            }
          : null,
        opportunity: opp
          ? {
              opportunity_id: opp.opportunity_id,
              project_title: opp.project_title,
              location_name: opp.location_name,
              lead_temperature: opp.lead_temperature,
              deal_status: opp.deal_status,
            }
          : null,
        scheduled_call_date: task.next_call_date,
        task_instruction: task.conclusion_notes,
        is_completed: task.is_completed,
        completed_at: task.completed_at,
        scheduled_by: task.author
          ? {
              employee_id: task.author.employee_id,
              name: task.author.name,
              email: task.author.email,
            }
          : null,
        completed_by: task.completed_by_employee
          ? {
              employee_id: task.completed_by_employee.employee_id,
              name: task.completed_by_employee.name,
            }
          : null,
        prior_history: priorHistory,

        // Backwards compatibility aliases
        note_id: task.note_id,
        conclusion_notes: task.conclusion_notes,
        next_call_date: task.next_call_date,
        author: task.author,
      };
    });

    return res.status(200).json({
      success: true,
      status: 'success',
      query_date: dateStr,
      total_tasks: formattedTasks.length,
      pending_tasks: pendingCount,
      completed_tasks: completedCount,
      tasks: formattedTasks,
      data: formattedTasks,
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
        assigned_employee: {
          select: { employee_id: true, name: true, email: true },
        },
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
      let updatedOpp = opportunity;
      if (lead_temperature && ['HOT', 'WARM', 'COLD'].includes(lead_temperature.toUpperCase())) {
        updatedOpp = await tx.opportunity.update({
          where: { opportunity_id: opportunityId },
          data: { lead_temperature: lead_temperature.toUpperCase() },
          include: {
            customer: true,
            assigned_employee: {
              select: { employee_id: true, name: true, email: true },
            },
          },
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
        },
      });

      return {
        new_note: newNote,
        opportunity: updatedOpp,
        prior_tasks_completed_count: priorUpdated.count,
      };
    });

    return res.status(201).json({
      status: 'success',
      message: `Conversation logged. ${result.prior_tasks_completed_count} prior task(s) completed. Next call scheduled for ${callDate.toISOString().split('T')[0]}.`,
      note: result.new_note,
      opportunity: result.opportunity,
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
 * Optionally updates linked opportunity temperature/status and schedules subsequent note.
 */
export async function completeTask(req, res, next) {
  try {
    const noteIdParam = req.params.note_id || req.params.id;
    const noteId = parseIntegerId(noteIdParam, 'note_id');
    const {
      conclusion_notes,
      lead_temperature,
      deal_status,
      next_call_date,
    } = req.body;

    if (!noteId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid task/note ID. Must be a positive integer.',
      });
    }

    const task = await prisma.leadNote.findUnique({
      where: { note_id: noteId },
      include: { opportunity: true },
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

    const result = await prisma.$transaction(async (tx) => {
      // 1. Mark task completed
      const updated = await tx.leadNote.update({
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

      // 2. Optional: update opportunity temperature or status
      const oppUpdate = {};
      if (lead_temperature && ['HOT', 'WARM', 'COLD'].includes(lead_temperature.toUpperCase())) {
        oppUpdate.lead_temperature = lead_temperature.toUpperCase();
      }
      if (deal_status && ['PIPELINE', 'CLOSED_WON', 'CLOSED_LOST', 'OTHER'].includes(deal_status.toUpperCase())) {
        oppUpdate.deal_status = deal_status.toUpperCase();
      }

      if (Object.keys(oppUpdate).length > 0) {
        await tx.opportunity.update({
          where: { opportunity_id: task.opportunity_id },
          data: oppUpdate,
        });
      }

      // 3. Optional: schedule subsequent follow-up note
      let followUpNote = null;
      if (next_call_date && !isNaN(new Date(next_call_date).getTime())) {
        followUpNote = await tx.leadNote.create({
          data: {
            opportunity_id: task.opportunity_id,
            employee_id: req.user.employee_id,
            conclusion_notes: conclusion_notes || 'Follow-up scheduled from completed task.',
            next_call_date: new Date(next_call_date),
            is_completed: false,
          },
        });
      }

      return { updated, followUpNote };
    });

    return res.status(200).json({
      status: 'success',
      message: `Task #${noteId} marked as completed successfully.`,
      task: result.updated,
      data: result.updated,
      follow_up_note: result.followUpNote,
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
      data: updatedTask,
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
      data: tasks,
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
      data: task,
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
