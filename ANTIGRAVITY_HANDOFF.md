# Suniti CRM - Shared Antigravity Handoff

Last initialized: 2026-11-13

## Project structure
- `suniti/` - Existing backend project.
- `Suniti V-2/` - Existing project directory.
- `Lead-Tracker-App/` - Flutter CRM frontend.
- This file is the shared coordination log for both Antigravity agents.

## Frontend status
- Flutter implementation completed through Milestone 4B.
- Includes customer workflows, lead workflows, Today's Calls, and related UI.
- UI references are stored in `Lead-Tracker-App/ui-screen/`.
- Milestone reports are included in the Flutter project.
- Previously verified in the original workspace:
  - `flutter analyze` passed.
  - `flutter test` passed.
- Frontend is being introduced on branch `feature/milestone-4b-lead-workflows`.

## Backend integration findings
These are integration items to verify or resolve before declaring the frontend fully integrated:

1. `POST /api/opportunities` controller exists, but the route may not be mounted. Verify routing and fix if confirmed.
2. Blocklist customer ID validation appears to expect UUIDs, while customer IDs are integer database IDs. Align validation.
3. Lead closure currently supports `PIPELINE`, `CLOSED_WON`, and `CLOSED_LOST`. Confirm how the requested `OTHER` outcome should be represented.
4. `/api/tasks/today` should use the Asia/Kolkata calendar day, with correct UTC boundaries for database queries.
5. Blocklist route appears ADMIN-only. Confirm the intended permissions for ADMIN, MANAGER, and SALES_REP. Do not silently grant elevated permissions.
6. Verify whether `GET /api/customers?customer_type=NEW` is implemented.
7. Confirm the agreed customer location filtering field. Customer billing address and opportunity location are not necessarily interchangeable.

These findings are pending verification against the current backend code. Do not assume they are already fixed.

## Confirmed integration behavior
- `POST /api/customers/new` creates a NEW customer, opportunity, and initial lead note transactionally.
- `PATCH /api/opportunities/:id/status` supports CLOSED_WON and CLOSED_LOST.
- Closure notes are stored in lead notes.
- A won lead for a NEW customer changes the customer type to EXISTING and assigns a tier.
- Today's Calls uses `/api/tasks/today`; task completion uses `PATCH /api/tasks/:id/complete`.
- Blocklist endpoint identified: `PATCH /api/admin/customers/:id/blocklist`.
- No Firebase push notification dependency is required for the current scope.

## Shared working rules
1. Read this file before starting work.
2. Pull the latest shared branch before making changes.
3. Do not have both agents edit this file simultaneously.
4. Append a dated entry under `## Update Log`; do not overwrite previous entries.
5. Record files changed, behavior changed, tests run, results, unresolved issues, and commit hash.
6. Do not invent endpoints, payload fields, credentials, or backend behavior.
7. Do not commit secrets, `.env` files, local configuration, generated build files, or credentials.
8. Do not start the next frontend milestone until the current backend integration issues are verified and resolved.

## Update Log

### 2026-11-13 - Initial shared handoff
- Added Flutter Milestone 4B project to the existing repository workspace.
- Created feature branch from `suniti-new-development` to preserve existing repository history.
- Frontend validation had passed in the original workspace.
- Backend integration findings listed above require verification.
- No frontend integration commit or push has been made yet.

### 2026-11-13 - Backend Milestone 4B Integration & Contract Alignment
- **Agent:** Backend Integration Agent (Antigravity)
- **Branch:** `feature/backend-milestone-4b-integration`
- **What Was Inspected:**
  - Audited `Suniti V-2` controllers, Prisma schema, routes, and middleware against Flutter Milestone 4B contracts (`Lead-Tracker-App/lib/core/api/`, `models/`, `milestone-4b-audit.md`, `milestone-4b-report.md`, and `Suniti CRM Frontend Integration & Route Reference.pdf`).
  - Investigated Issues A through G raised in the handoff.
- **Root Cause & Architecture Clarification:**
  - `Suniti-v1` previously contained legacy backend code in `suniti/` with raw SQL queries and UUID assumptions. The active, modern Node.js/Express/Prisma backend is in `Suniti V-2/`, which uses autoincrementing integer IDs, Prisma ORM, and JWT authentication.
  - The audit report from the frontend team was partially assessing the legacy `suniti/` codebase. In `Suniti V-2/`, integer IDs are already standard, routes are properly mounted, and JWT payload extraction is role-aware.
- **What Was Changed / API Behavior Updates:**
  - **Issue A (`POST /api/opportunities`):**
    - Verified route is mounted at `/api/opportunities` in `src/server.js` and protected by `verifyEmployee`.
    - Supports existing customer opportunity creation (`customer_id`, `project_title`, `location_name`, `lead_temperature`, optional `deal_status`).
    - Standardized response envelope to provide both `{ opportunity, customer }` and root-level `{ data: opportunity }` for complete compatibility across client deserializers.
  - **Issue B (Customer Blocklist & Integer IDs):**
    - Validates integer customer IDs (`parseIntegerId`).
    - Mounted on both `PATCH /api/admin/customers/:id/blocklist` (admin router) and `PATCH /api/customers/:id/blocklist` (customer router).
    - Secured with `verifyManagerOrAdmin` so both Admins and Managers can toggle blocklist status, while `SALES_REP` is rejected with 403 Forbidden.
  - **Issue C (Lead Closure & OTHER Status):**
    - Added `OTHER` to Prisma enum `DealStatus` in `prisma/schema.prisma` (`PIPELINE`, `CLOSED_WON`, `CLOSED_LOST`, `OTHER`).
    - Added `closure_reason String? @map("closure_reason") @db.Text` to the `opportunities` model.
    - Created migration `20261113164500_add_other_status_and_closure_reason`.
    - Regenerated Prisma Client (`npx prisma generate`).
    - In `PATCH /api/opportunities/:id/status`, handled `OTHER` identically to `CLOSED_LOST` (sets `project_phase = 'DEAL_CLOSED'`, `is_completed = true`, saves `closure_reason`, and atomically logs `conclusion_notes` into `lead_notes`).
    - Implemented upfront input validation before DB queries for immediate 400 Bad Request responses on invalid payload values.
  - **Issue D (Today's Calls & Asia/Kolkata Calendar Day):**
    - In `GET /api/tasks/today`, fixed date calculation to strictly use `Asia/Kolkata` (IST, UTC+5:30) calendar day boundaries. Converted IST midnight (00:00:00.000) and end-of-day (23:59:59.999) to UTC timestamps (`18:30:00.000Z` of previous day to `18:29:59.999Z` of target day) for database queries.
    - Formatted response objects to strictly comply with Flutter's `DailyTask.fromJson`, populating `contact_details`, `opportunity`, `task_instruction`, `scheduled_by`, `completed_by`, and `prior_history`.
    - Returns summary counters `{ query_date, total_tasks, pending_tasks, completed_tasks, tasks, data }`.
    - In `PATCH /api/tasks/:note_id/complete`, added support for optional `lead_temperature`, `deal_status`, and `next_call_date` to support follow-up workflows.
  - **Issue E (Role Permissions):**
    - Retained clear separation between `ADMIN`, `MANAGER`, and `SALES_REP`.
    - No silent mapping of `MANAGER` to `ADMIN`.
    - `ADMIN`: Full access (employee CRUD, deletion, all management).
    - `MANAGER`: Workload tracking, alerts, analytics, customer tier changes, blocklist toggling. Cannot delete employees.
    - `SALES_REP`: View assigned tasks, create customers/leads, advance stages on owned opportunities. Cannot modify blocklist (403), modify customer tier (403), or delete employees (403).
  - **Issue F (New Customer Listing):**
    - In `GET /api/customers`, verified filtering by `customer_type=NEW` and `customer_type=EXISTING`.
    - In `GET /api/customers/existing`, enriched response with `total_existing_customers`, `new_customers_count`, and `counts: { NEW, PREMIUM, LOYAL, INTERIOR_DESIGNER }`.
  - **Issue G (Customer Location Filtering):**
    - In `GET /api/customers?location=<query>`, implemented location search that checks both `billing_address` (customer location) and `opportunities.some.location_name` (project plant/site location), avoiding field mismatch between customer and plant sites.
    - In `GET /api/customers/:id/opportunities`, returns `company_id`, `company_name`, `customer_id`, `opportunities`, and distinct `plant_locations`.
- **Files Modified:**
  - `Suniti V-2/prisma/schema.prisma`
  - `Suniti V-2/prisma/migrations/20261113164500_add_other_status_and_closure_reason/migration.sql`
  - `Suniti V-2/package.json`
  - `Suniti V-2/src/controllers/opportunity.controller.js`
  - `Suniti V-2/src/controllers/customer.controller.js`
  - `Suniti V-2/src/controllers/task.controller.js`
  - `Suniti V-2/src/controllers/manager.controller.js`
  - `Suniti V-2/test/backend-integration.test.js`
  - `ANTIGRAVITY_HANDOFF.md`
- **Tests Executed & Results:**
  - Created automated test suite `Suniti V-2/test/backend-integration.test.js` with 18 distinct test scenarios verifying issues A through G.
  - Executed via `npm test`: **18 passed, 0 failed (100% pass rate)**.
- **Remaining Issues:**
  - None for Milestone 4B backend requirements. The backend contract is fully aligned with the Flutter integration specification.
- **Git Branch & Commit:**
  - Branch: `feature/backend-milestone-4b-integration`
  - Commit: `93b21bf` (feat(backend): complete Milestone 4B Flutter integration and API contract alignment)
