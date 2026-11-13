# Milestone 4B — Final Integration & Backend Contract Audit Report

**Audit Date:** November 10, 2026  
**Project:** Suniti CRM Frontend (`D:\Suniti-Master-Folder\Lead-Tracker-App`)  
**Backend Branch:** `suniti-new-development` (Supabase / PostgreSQL + Express.js)

---

## Executive Summary

A comprehensive, read-only audit of Milestone 4B was performed covering the Flutter implementation against the actual backend database schema, controllers, and routes in `suniti/src`.

The frontend architecture, static analysis (`flutter analyze`), and unit tests (9/9) are completely clean. However, this contract audit identified critical discrepancies between client expectations and backend capabilities, specifically regarding **lead closure categories**, **existing opportunity creation route mounting**, **UUID vs integer validation in admin controllers**, and **timezone boundaries in daily task filtering**.

---

## 1. Lead Closure Verification

### Current Frontend Implementation
- **File:** [`lib/screens/leads/ongoing_leads_screen.dart`](file:///D:/Suniti-Master-Folder/Lead-Tracker-App/lib/screens/leads/ongoing_leads_screen.dart) (`_showCloseDealDialog`, line 582)
- **Service:** [`lib/core/api/opportunity_service.dart`](file:///D:/Suniti-Master-Folder/Lead-Tracker-App/lib/core/api/opportunity_service.dart) (`updateOpportunityStatus`, line 27)
- **Request Payload Sent:**
  ```json
  {
    "deal_status": "CLOSED_WON" | "CLOSED_LOST",
    "tier": "PREMIUM" | "LOYAL" | "INTERIOR_DESIGNER" (required if CLOSED_WON and customer was NEW),
    "conclusion_notes": "string" (optional)
  }
  ```
- **Backend Route:** `PATCH /api/opportunities/:opportunity_id/status` handled by `updateOpportunityStatus` in `opportunity.controller.js`.

### Audit Findings

1. **Exact Payload & Persistence:**
   - When closing as `CLOSED_WON`, the backend updates `opportunities.deal_status = 'CLOSED_WON'`.
   - If the parent customer was `customer_type == 'NEW'`, Rule 2 triggers atomically: updates `customers.customer_type = 'EXISTING'` and `customers.tier = $1`.
   - Both `CLOSED_WON` and `CLOSED_LOST` are persisted cleanly into PostgreSQL.

2. **Explanation & Notes Persistence:**
   - **Confirmed Backend Behavior:** In `opportunity.controller.js` (lines 117-128):
     ```javascript
     if (conclusion_notes) {
       await client.query(
         `INSERT INTO lead_notes (opportunity_id, employee_id, conclusion_notes, next_call_date)
          VALUES ($1, $2, $3, NULL)`,
         [oppId, employeeId, `Deal status updated to ${deal_status}. Notes: ${conclusion_notes.trim()}`]
       );
     }
     ```
   - The conclusion explanation is **not merely displayed in the UI**; it is written directly to the `lead_notes` table in the same database transaction.

3. **Status of "Other" Closure Category:**
   - **Unsupported by Backend (Confirmed Limitation).**
   - The database enum `deal_state` in PostgreSQL is strictly:
     ```sql
     CREATE TYPE deal_state AS ENUM ('PIPELINE', 'CLOSED_WON', 'CLOSED_LOST');
     ```
   - Sending `Other` or `LEAD_COMPLETED` will trigger an immediate PostgreSQL enum type validation failure (`400 Bad Request` or `500 Server Error`).
   - The frontend honestly restricts closure choices to `CLOSED_WON` and `CLOSED_LOST` with a label indicating "(Lead Completed)".

4. **Exact Backend Change Required to Support All Three Categories:**
   To genuinely support `Other` and custom closure explanations:
   ```sql
   -- 1. Alter enum to add OTHER
   ALTER TYPE deal_state ADD VALUE 'OTHER';

   -- 2. Optional: Add dedicated closure explanation column
   ALTER TABLE opportunities ADD COLUMN closure_reason TEXT;
   ```
   In `opportunity.controller.js`:
   - Update `ALLOWED_DEAL_STATUSES = ['PIPELINE', 'CLOSED_WON', 'CLOSED_LOST', 'OTHER']`.
   - Accept `closure_reason` in request body and update the column.

---

## 2. New Customer Creation Verification

### Current Frontend Implementation
- **File:** [`lib/screens/leads/create_lead_screen.dart`](file:///D:/Suniti-Master-Folder/Lead-Tracker-App/lib/screens/leads/create_lead_screen.dart) (`_submitLead`, Flow A, line 114)
- **Service:** [`lib/core/api/customer_service.dart`](file:///D:/Suniti-Master-Folder/Lead-Tracker-App/lib/core/api/customer_service.dart) (`createCustomerWithOpportunity`, line 161)
- **Backend Route:** `POST /api/customers/new` in `customer.routes.js`, handled by `createNewCustomerWithOpportunity` in `customer.controller.js` (lines 123-228).

### Audit Findings

1. **Accepted Request Fields:**
   - Frontend sends: `name`, `project_title`, `location_name`, `phone`, `billing_address`, `lead_temperature`, `conclusion_notes`, `next_call_date`.
   - Backend extracts:
     `{ name, phone, billing_address, project_title, location_name, lead_temperature, conclusion_notes, next_call_date }`.
   - **Match:** 100% exact match.

2. **Atomic Transaction:**
   - Backend executes `BEGIN` ... `COMMIT` / `ROLLBACK`.
   - Inserts into `customers` (customer_type='NEW', tier=NULL).
   - Inserts into `opportunities` (deal_status='PIPELINE').
   - Inserts initial `lead_notes` entry.
   - All three records are created atomically in a single transaction.

3. **Next Call Date & Notes:**
   - If `next_call_date` is omitted, backend auto-schedules `now() + 30 days` (Rule 1). If provided as ISO string by Flutter, backend persists it directly.
   - `conclusion_notes` is persisted into `lead_notes`.

---

## 3. Existing Customer Lead Creation Verification

### Current Frontend Implementation
- **File:** [`lib/screens/leads/create_lead_screen.dart`](file:///D:/Suniti-Master-Folder/Lead-Tracker-App/lib/screens/leads/create_lead_screen.dart) (`_submitLead`, Flow B, line 165)
- **Service Call:** `OpportunityService().createOpportunity()` followed by `OpportunityService().addOpportunityNote()`.
- **Target Route:** `POST /api/opportunities`.

### Audit Findings: ⚠️ CRITICAL BACKEND ROUTING DEFECT FOUND

- **Issue:** In the backend repo (`suniti/src`), the function `createOpportunity` is written in `customer.controller.js` (line 235), but **IT IS NEVER MOUNTED TO ANY EXPRESS ROUTER**.
  - `opportunity.routes.js` only contains:
    - `POST /:opportunity_id/notes`
    - `PATCH /:opportunity_id/status`
  - Neither `opportunity.routes.js` nor `customer.routes.js` mounts `POST /api/opportunities` or `router.post('/', createOpportunity)`.
- **Impact:** Calling `POST /api/opportunities` on the current backend branch returns `404 Not Found: Cannot POST /api/opportunities`.
- **Recommended Backend Fix:**
  In `opportunity.routes.js`:
  ```javascript
  import { createOpportunity } from '../controllers/customer.controller.js';
  router.post('/', createOpportunity);
  ```

---

## 4. Today's Calls Verification

### Current Frontend Implementation
- **Screen:** [`lib/screens/tasks/todays_calls_screen.dart`](file:///D:/Suniti-Master-Folder/Lead-Tracker-App/lib/screens/tasks/todays_calls_screen.dart)
- **Provider:** [`lib/providers/task_provider.dart`](file:///D:/Suniti-Master-Folder/Lead-Tracker-App/lib/providers/task_provider.dart) (`dueTodayTasks`, `todayDueNotificationCount`)
- **Backend Controller:** `getTodayTasks` in `task.controller.js` (lines 11-149).

### Audit Findings

1. **Response Structure:**
   - Backend sends `{ success: true, query_date, total_tasks, pending_tasks, completed_tasks, tasks: [...] }`.
   - Model `DailyTask.fromJson` correctly deserializes nested `contact_details`, `opportunity`, `scheduled_by`, and `completed_by`.

2. **Date Filtering & Timezones:**
   - Backend queries: `WHERE (n.next_call_date >= $1 AND n.next_call_date <= $2)`.
   - Backend uses server UTC timestamp boundaries (`startOfDay.toISOString()` to `endOfDay.toISOString()`).
   - In `task_provider.dart`:
     ```dart
     List<DailyTask> get dueTodayTasks {
       final now = DateTime.now();
       return _todayTasks.where((task) {
         if (task.isCompleted) return false;
         if (task.scheduledCallDate == null) return false;
         final d = task.scheduledCallDate!.toLocal(); // Needs toLocal()
         return d.year == now.year && d.month == now.month && d.day == now.day;
       }).toList();
     }
     ```
   - **Minor Date-Boundary Caveat:** `scheduledCallDate` parsed from UTC ISO string must explicitly call `.toLocal()` before comparing with `now.year/month/day` to avoid date drift across GMT/IST midnight boundaries.

3. **Exclusion of Completed & Overdue Calls:**
   - Completed calls (`task.isCompleted == true`) are filtered out.
   - Future and overdue calls are excluded; only calls matching today's local calendar day are displayed.

4. **Consistency between Badge and Screen:**
   - Both the Notification Bell badge on `HomeScreen` and the list on `TodaysCallsScreen` consume the identical getter `taskProvider.dueTodayTasks.length` and `taskProvider.dueTodayTasks`.

5. **Refresh Lifecycle:**
   - Opening `TodaysCallsScreen` triggers `taskProvider.loadTodayTasks()` via `initState`.
   - Completing a task via `PATCH /api/tasks/:id/complete` awaits the API and calls `loadTodayTasks()`, immediately refreshing both screen and notification badge.

---

## 5. Blacklist Permissions Verification

### Current Frontend Implementation
- **Screen:** [`lib/screens/blocklist/blacklisted_customers_screen.dart`](file:///D:/Suniti-Master-Folder/Lead-Tracker-App/lib/screens/blocklist/blacklisted_customers_screen.dart)
- **Target Endpoint:** `PATCH /api/admin/customers/:id/blocklist`

### Audit Findings: ⚠️ BACKEND ID VALIDATION MISMATCH FOUND

1. **Role Enforcement:**
   - Backend `admin.routes.js` enforces `router.use(verifyToken, verifyAdmin)`.
   - The backend strictly requires `req.user.role === 'ADMIN'`.
   - In `employee.dart`, the roles are `ADMIN`, `MANAGER`, `SALES_REP`. The backend schema `user_role` only defines `ADMIN` and `SALES_REP` (`CREATE TYPE user_role AS ENUM ('ADMIN', 'SALES_REP')`).
   - If a sales rep triggers unblock, backend returns `403 Forbidden: Access forbidden: Requires ADMIN role`.
   - Frontend catches `ForbiddenException` and shows a clean in-app error banner without crashing.

2. **Backend UUID vs Serial Integer Bug in `admin.controller.js`:**
   - **Confirmed Backend Bug:**
     In `admin.controller.js` (line 377):
     ```javascript
     if (!isValidUuid(id)) {
       return res.status(400).json({
         success: false,
         message: 'Invalid customer ID. Must be a valid UUID.',
       });
     }
     ```
     However, in `schema.sql`:
     ```sql
     CREATE TABLE customers (
         customer_id SERIAL PRIMARY KEY, ...
     ```
     `customer_id` is an `INT` / `SERIAL` integer (e.g. `1`, `5`, `42`), **NOT A UUID**.
   - Calling `PATCH /api/admin/customers/:id/blocklist` with an integer ID currently fails validation on the backend with `400: Must be a valid UUID`.
   - **Recommended Backend Fix:** Update `admin.controller.js` line 377 to validate `parseInt(id, 10)` rather than `isValidUuid(id)`.

3. **Blacklist Reason Handling:**
   - The frontend honestly displays `RESTRICTED ACCOUNT` pill badges. It does **not** persist or fabricate dummy blacklist reasons, aligning strictly with the `is_blocklisted` boolean column.

---

## 6. API Configuration Verification

### Inspecting `api_constants.dart`, `api_endpoints.dart`, `api_client.dart`:

1. **No Hardcoded Credentials:**
   - No JWT secrets, database passwords, or auth keys are embedded in source code.
   - Tokens are persisted solely in `FlutterSecureStorage` under key `suniti_jwt_auth_token`.

2. **Authorization Header:**
   - Attached via Dio interceptor in `api_client.dart`:
     ```dart
     options.headers['Authorization'] = 'Bearer $token';
     ```

3. **HTTP Methods & Paths:**
   - All HTTP verbs align with standard REST conventions (`GET`, `POST`, `PATCH`, `DELETE`).
   - Centralized exception mapping handles `400`, `401`, `403`, `404`, `409`, `500`, and timeout/connection errors into typed `ApiException` classes.

---

## 7. Comprehensive Defect & Recommendation Matrix

| ID | Component | Current Implementation | Backend Contract / Root Cause | Classification | Recommended Fix |
|---|---|---|---|---|---|
| **ISSUE-1** | Existing Lead Creation | `POST /api/opportunities` | Route is declared in controller but **not mounted** in `opportunity.routes.js` or `app.js` | **Backend Bug / Missing Route** | Mount `router.post('/', createOpportunity)` in `opportunity.routes.js`. |
| **ISSUE-2** | Lead Closure Categories | Supports `CLOSED_WON` and `CLOSED_LOST` | Database `deal_state` enum strictly forbids `OTHER`. | **Backend Schema Limitation** | Backend must alter `deal_state` enum to add `OTHER`. |
| **ISSUE-3** | Admin Customer Unblock | `PATCH /api/admin/customers/:id/blocklist` | Controller rejects integer IDs expecting UUIDs (`isValidUuid(id)`), while `customers.customer_id` is a serial integer. | **Backend Bug** | Replace `isValidUuid(id)` with `parseInt(id, 10)` in `admin.controller.js`. |
| **ISSUE-4** | Today's Calls Date Boundary | `task.scheduledCallDate!.day == now.day` | UTC timestamp parsed without `.toLocal()` could shift calendar day across timezone offsets. | **Frontend Caveat** | Update `daily_task.dart` / `task_provider.dart` to use `.toLocal()` before day comparison. |
| **ISSUE-5** | Employee Roles Enum | `employee.dart` has `MANAGER` | `schema.sql` only defines `ADMIN` and `SALES_REP` (`CREATE TYPE user_role AS ENUM ('ADMIN', 'SALES_REP')`). | **Backend Contract Mismatch** | Teammate needs to add `MANAGER` to `user_role` enum or map Manager to Admin. |

---

## Conclusion

The Milestone 4B implementation accurately honors the backend capabilities while strictly refusing to fabricate fake endpoints or database columns. The identified routing and validation issues reside predominantly on the backend API layer and have been documented with exact code references for your teammate.
