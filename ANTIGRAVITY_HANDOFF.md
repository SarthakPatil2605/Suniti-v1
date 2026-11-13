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
