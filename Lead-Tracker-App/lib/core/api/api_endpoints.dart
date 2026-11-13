// Complete endpoint mapping matching the Suniti V-2 Express API router

class ApiEndpoints {
  ApiEndpoints._();

  // Health
  static const String health = '/health';

  // 1. Authentication (/api/auth)
  static const String login = '/api/auth/login';
  static const String me = '/api/auth/me';
  static const String register = '/api/auth/register';

  // 2. Customers (/api/customers)
  static const String customersNew = '/api/customers/new';
  static const String customersExisting = '/api/customers/existing';
  static const String customersBlocklisted = '/api/customers/blocklisted';
  static const String customers = '/api/customers';
  static String customerById(int id) => '/api/customers/$id';
  static String customerOpportunities(int id) =>
      '/api/customers/$id/opportunities';
  static String customerBlocklist(int id) => '/api/customers/$id/blocklist';
  static String customerTier(int id) => '/api/customers/$id/tier';

  // 3. Admin Customer Blocklist Override (/api/admin)
  static String adminCustomerBlocklist(int id) =>
      '/api/admin/customers/$id/blocklist';

  // 4. Opportunities (/api/opportunities)
  static const String opportunities = '/api/opportunities';
  static String opportunityById(int id) => '/api/opportunities/$id';
  static String opportunityStatus(int id) => '/api/opportunities/$id/status';
  static String opportunityNotes(int id) => '/api/opportunities/$id/notes';

  // 5. Tasks & Lead Notes (/api/tasks & /api/lead-notes)
  static const String tasksToday = '/api/tasks/today';
  static String taskOpportunity(int oppId) => '/api/tasks/opportunity/$oppId';
  static String taskComplete(int noteId) => '/api/tasks/$noteId/complete';
  static String taskAssign(int noteId) => '/api/tasks/$noteId/assign';
  static const String tasks = '/api/tasks';
  static String taskById(int id) => '/api/tasks/$id';

  // 6. Manager Controls (/api/manager)
  static const String managerWorkload = '/api/manager/workload';
  static const String managerOverdueAlerts =
      '/api/manager/alerts/overdue-tasks';
  static String managerLeadAudit(int oppId) =>
      '/api/manager/audit/lead-history/$oppId';
  static const String managerAnalytics = '/api/manager/analytics';

  // 7. Employees (/api/employees)
  static const String employees = '/api/employees';
  static String employeeById(int id) => '/api/employees/$id';
}
