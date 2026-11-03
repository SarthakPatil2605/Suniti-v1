# Suniti Construction CRM — PostgreSQL Database Schema

This repository contains the production-ready PostgreSQL relational database schema for the **Suniti Construction CRM** application.

---

## 🏗️ Architecture & Entities

### 1. `employees`
Internal team members (Sales Representatives, Admins) who manage clients and record deal notes.
- **`employee_id`** (`UUID`, PK): Auto-generated using `gen_random_uuid()`.
- **`name`** (`VARCHAR(255)`, NOT NULL): Full name of the employee.
- **`email`** (`VARCHAR(255)`, UNIQUE, NOT NULL): Corporate email address used for CRM login.
- **`password_hash`** (`VARCHAR(255)`, NOT NULL): Secure hashed credential string (e.g., bcrypt/argon2).
- **`role`** (`ENUM: 'ADMIN', 'SALES_REP'`, NOT NULL, DEFAULT: `'SALES_REP'`).
- **`created_at`** (`TIMESTAMPTZ`, DEFAULT: `CURRENT_TIMESTAMP`).

---

### 2. `customers`
Leads, prospect accounts, and established clients.
- **`customer_id`** (`UUID`, PK): Auto-generated using `gen_random_uuid()`.
- **`name`** (`VARCHAR(255)`, NOT NULL): Client or business entity name.
- **`customer_type`** (`ENUM: 'NEW', 'EXISTING'`, NOT NULL, DEFAULT: `'NEW'`).
- **`tier`** (`ENUM: 'PREMIUM', 'LOYAL', 'INTERIOR_DESIGNER'`, Nullable for new customers).
- **`phone`** (`VARCHAR(20)`).
- **`billing_address`** (`TEXT`).
- **`is_blocklisted`** (`BOOLEAN`, NOT NULL, DEFAULT: `FALSE`).
- **`created_at`** (`TIMESTAMPTZ`, DEFAULT: `CURRENT_TIMESTAMP`).
- **Constraint**: `chk_customer_new_tier` enforces that `customer_type = 'EXISTING'` or `tier IS NULL`.

---

### 3. `opportunities`
Construction bids, renovation projects, and sales deals tracked under a customer.
- **`opportunity_id`** (`UUID`, PK): Auto-generated using `gen_random_uuid()`.
- **`customer_id`** (`UUID`, FK -> `customers.customer_id`, NOT NULL).
- **`project_title`** (`VARCHAR(255)`, NOT NULL): Title of the project (e.g., "3BHK Luxury Villa Renovation").
- **`location_name`** (`VARCHAR(100)`, NOT NULL): Site city or micro-market (e.g., "Pune", "Pimpri", "Mumbai").
- **`lead_temperature`** (`ENUM: 'HOT', 'WARM', 'COLD'`, NOT NULL, DEFAULT: `'WARM'`).
- **`deal_status`** (`ENUM: 'PIPELINE', 'CLOSED_WON', 'CLOSED_LOST'`, NOT NULL, DEFAULT: `'PIPELINE'`).
- **`created_at`** (`TIMESTAMPTZ`, DEFAULT: `CURRENT_TIMESTAMP`).

---

### 4. `lead_notes`
Chronological activity notes, client conversation summaries, and scheduled follow-up dates for each opportunity.
- **`note_id`** (`UUID`, PK): Auto-generated using `gen_random_uuid()`.
- **`opportunity_id`** (`UUID`, FK -> `opportunities.opportunity_id`, NOT NULL).
- **`employee_id`** (`UUID`, FK -> `employees.employee_id`, Nullable).
- **`conclusion_notes`** (`TEXT`, NOT NULL): Detailed meeting or call conclusion notes.
- **`next_call_date`** (`TIMESTAMPTZ`): Scheduled date and time for the next sales outreach.
- **`created_at`** (`TIMESTAMPTZ`, DEFAULT: `CURRENT_TIMESTAMP`).

---

## 🔗 Foreign Key Cascading Strategy

| Relationship | Foreign Key | Cascade Rule | Design Rationale |
| :--- | :--- | :--- | :--- |
| `opportunities` -> `customers` | `customer_id` | `ON DELETE CASCADE` | When a customer record is pruned, all corresponding sales deals and pipeline records are purged. |
| `lead_notes` -> `opportunities` | `opportunity_id` | `ON DELETE CASCADE` | Notes have no standalone context without their parent opportunity. |
| `lead_notes` -> `employees` | `employee_id` | `ON DELETE SET NULL` | Preserves valuable historical meeting logs even if an employee account is deleted/offboarded. |

---

## ⚡ Performance Indexes

PostgreSQL does not automatically index foreign key columns. The following indexes are created:

1. **Foreign Key Performance**:
   - `idx_opportunities_customer_id` on `opportunities(customer_id)`
   - `idx_lead_notes_opportunity_id` on `lead_notes(opportunity_id)`
   - `idx_lead_notes_employee_id` on `lead_notes(employee_id)`
2. **Sales Funnel & Search Queries**:
   - `idx_customers_phone` on `customers(phone)`
   - `idx_opportunities_deal_status` on `opportunities(deal_status)`
   - `idx_opportunities_temperature` on `opportunities(lead_temperature)`
   - `idx_opportunities_location` on `opportunities(location_name)`
   - `idx_lead_notes_next_call_date` on `lead_notes(next_call_date)` (for sales call reminders & follow-up queues)

---

## 🚀 Quickstart with Docker

Spin up a PostgreSQL 16 container with `schema.sql` and `seed.sql` pre-applied:

```bash
docker compose up -d
```

Connect via `psql`:

```bash
docker exec -it suniti_crm_db psql -U suniti_admin -d suniti_crm
```

---

## 🔐 Authentication & RBAC Backend Module

### API Endpoints

| Method | Endpoint | Access Level | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/auth/login` | Public | Authenticate with email & password, returns JWT token. |
| `GET` | `/api/auth/me` | Authenticated (`verifyToken`) | Returns the currently logged in employee profile. |
| `POST` | `/api/auth/register` | Admin (`verifyAdmin`) | Register a new employee with hashed credentials. |
| `GET` | `/api/operational/pipeline` | Employee (`verifyEmployee`) | Accessible to `ADMIN` and `SALES_REP`. |
| `GET` | `/api/admin/security-audit` | Admin (`verifyAdmin`) | Exclusively restricted to `ADMIN`. |

### Middlewares

- **`verifyToken`**: Validates the Bearer JWT token from `Authorization` header, decodes `{ employee_id, name, role, email }`, and attaches it to `req.user`.
- **`verifyAdmin`**: Guarantees that `req.user.role === 'ADMIN'`. Returns `403 Forbidden` otherwise.
- **`verifyEmployee`**: Ensures the user belongs to `['ADMIN', 'SALES_REP']`. Returns `403 Forbidden` otherwise.

### Running Backend & Tests

```bash
# Install dependencies
npm install

# Run automated unit & integration tests (47 tests)
npm test

# Seed employees with bcrypt credentials into PostgreSQL
npm run seed

# Start API server
npm start
```

---

## 🏢 Customer & Opportunity Hierarchy API Module

### Endpoints

| Method | Endpoint | Access Level | Description & Rules |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/customers/existing` | Employee (`verifyEmployee`) | Returns existing customers grouped by tier (`PREMIUM`, `LOYAL`, `INTERIOR_DESIGNER`) and company name. |
| `GET` | `/api/customers/:companyId/opportunities` | Employee (`verifyEmployee`) | Fetches all plant locations / opportunities (e.g. Pune, Pimpri, Mumbai) for a specific customer company. |
| `POST` | `/api/customers/new` | Employee (`verifyEmployee`) | Creates a new customer, initial opportunity, and lead note. **Rule 1 (Auto-schedule)**: If `next_call_date` is empty or null, automatically sets it to `CURRENT_TIMESTAMP + 30 days`. |
| `PATCH` | `/api/opportunities/:id/status` | Employee (`verifyEmployee`) | Updates deal status (`PIPELINE`, `CLOSED_WON`, `CLOSED_LOST`). **Rule 2 (Deal Closure Migration)**: If updated to `CLOSED_WON`, automatically graduates customer from `NEW` to `EXISTING` and assigns tier (`PREMIUM`, `LOYAL`, or `INTERIOR_DESIGNER`). |

---

## 📞 Daily Tasks & Call Logging API Module

### Endpoints

| Method | Endpoint | Access Level | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/tasks/today` | Employee (`verifyEmployee`) | Fetches all leads where `next_call_date` falls on the current date (or query `?date=YYYY-MM-DD`), returning company name, location, contact info, opportunity details, and prior conversation history. |
| `POST` | `/api/opportunities/:id/notes` | Employee (`verifyEmployee`) | Adds a conversation conclusion note. Extracts `employee_id` from the auth token to record **WHO** made the call/took the lead, and accepts `next_call_date` to schedule the subsequent follow-up. |
| `PATCH` | `/api/tasks/:id/complete` | Employee (`verifyEmployee`) | Marks a daily task as completed (`is_completed = true`), records completion timestamp and employee attribution, updates opportunity tracking statuses (`lead_temperature`, `deal_status`), and optionally schedules the next follow-up. |

---

## 🛡️ Admin Management API Module (Restricted to `ADMIN` Role)

All routes in `/api/admin` are guarded by `verifyToken` and `verifyAdmin`.

### 1. Employees CRUD

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/admin/employees` | List all staff members (password hashes securely omitted). |
| `POST` | `/api/admin/employees` | Create a new employee/sales rep with bcrypt hashed password. |
| `PUT` | `/api/admin/employees/:id` | Update employee role (`ADMIN` or `SALES_REP`), name, email, or reset password. |
| `DELETE` | `/api/admin/employees/:id` | Delete/deactivate employee (prevents admin self-deletion; cascades `SET NULL` on historical notes). |

### 2. Customer & Record Override CRUD

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `PUT` | `/api/admin/customers/:id` | Full administrative edit of customer details, company name, address, contact, and tier override (`PREMIUM`, `LOYAL`, `INTERIOR_DESIGNER`). |
| `DELETE` | `/api/admin/opportunities/:id` | Purge invalid or erroneous opportunities (automatically cascades to delete related lead notes). |

### 3. Blocklist Management

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `PATCH` | `/api/admin/customers/:id/blocklist` | Toggle or set `is_blocklisted` flag (`true`/`false`) for restricted or bad-payment accounts. |



