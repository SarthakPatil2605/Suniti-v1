# Suniti Construction CRM Backend

Production-ready backend API service for **Suniti Construction CRM**, built with Node.js (ES Modules), Express.js, Prisma ORM, and Supabase PostgreSQL.

---

## 🏗️ Architecture & Tech Stack

- **Runtime:** Node.js (ES Modules `"type": "module"`)
- **Web Framework:** Express.js 4.x
- **Database:** Supabase PostgreSQL with Integer autoincrement primary keys
- **ORM:** Prisma Client & Prisma CLI
- **Authentication & Security:** bcrypt for hashing, jsonwebtoken for JWT issuance, CORS middleware

---

## 📁 Project Structure

```text
Suniti V-2/
├── .env.example                # Environment configuration template
├── .env                        # Local environment variables
├── .gitignore                  # Git ignore rules
├── package.json                # Project dependencies and npm scripts
├── prisma/
│   ├── schema.prisma           # Prisma data models and enums
│   └── seed.js                 # Database seeder script
└── src/
    ├── config/
    │   └── prisma.js           # Prisma client singleton with proxy aliases
    ├── routes/
    │   ├── auth.routes.js      # Auth route placeholders
    │   ├── customer.routes.js  # Customer CRUD route placeholders
    │   ├── employee.routes.js  # Employee management route placeholders
    │   ├── leadNote.routes.js  # Lead notes & tasks route placeholders
    │   └── opportunity.routes.js # Opportunities & pipeline route placeholders
    └── server.js               # Express app, middlewares, error handler & server entry
```

---

## 🗄️ Database Schema Summary

All models use **integer autoincrement primary keys** (`Int @id @default(autoincrement())`):

### 1. `employees`
- `employee_id` (PK, Int)
- `name` (String)
- `email` (String, Unique)
- `password_hash` (String)
- `role` (Enum: `ADMIN`, `MANAGER`, `SALES_REP`)
- `created_at` (DateTime, Default: `now()`)

### 2. `customers`
- `customer_id` (PK, Int)
- `name` (String)
- `customer_type` (Enum: `NEW`, `EXISTING`, Default: `NEW`)
- `tier` (Enum: `PREMIUM`, `LOYAL`, `INTERIOR_DESIGNER`)
- `phone` (String, Nullable)
- `billing_address` (Text, Nullable)
- `is_blocklisted` (Boolean, Default: `false`)
- `created_at` (DateTime, Default: `now()`)

### 3. `opportunities`
- `opportunity_id` (PK, Int)
- `customer_id` (FK to `customers.customer_id`)
- `employee_id` (FK to `employees.employee_id` - assigned sales rep)
- `project_title` (String)
- `location_name` (String, Nullable)
- `lead_temperature` (Enum: `HOT`, `WARM`, `COLD`, Default: `WARM`)
- `deal_status` (Enum: `PIPELINE`, `CLOSED_WON`, `CLOSED_LOST`, Default: `PIPELINE`)
- `project_phase` (Enum: `TALKING`, `PROCESSING`, `DEAL_CLOSED`, Default: `TALKING`)
- `is_completed` (Boolean, Default: `false`)
- `completed_at` (DateTime, Nullable)
- `completed_by` (FK to `employees.employee_id`, Nullable)
- `created_at` (DateTime, Default: `now()`)

### 4. `lead_notes` (Lead Notes / Tasks)
- `note_id` (PK, Int)
- `opportunity_id` (FK to `opportunities.opportunity_id`)
- `employee_id` (FK to `employees.employee_id` - author)
- `conclusion_notes` (Text, Nullable)
- `next_call_date` (DateTime, Nullable)
- `is_completed` (Boolean, Default: `false`)
- `completed_at` (DateTime, Nullable)
- `completed_by` (FK to `employees.employee_id`, Nullable)
- `created_at` (DateTime, Default: `now()`)

---

## ⚡ Quick Start & Setup

### 1. Configure Supabase Connection
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
Update `DATABASE_URL` (Port 6543 connection pooler) and `DIRECT_URL` (Port 5432 direct connection) with your Supabase credentials:
```env
DATABASE_URL="postgresql://postgres.[YOUR-PROJECT-REF]:[YOUR-PASSWORD]@aws-0-[YOUR-REGION].pooler.supabase.com:6543/postgres?pgbouncer=true"
DIRECT_URL="postgresql://postgres.[YOUR-PROJECT-REF]:[YOUR-PASSWORD]@aws-0-[YOUR-REGION].pooler.supabase.com:5432/postgres"
```

### 2. Apply Migrations to Supabase
```bash
# Push schema or run Prisma migration
npm run prisma:migrate
```

### 3. Generate Prisma Client
```bash
npm run prisma:generate
```

### 4. Seed Initial Data (Optional)
```bash
npm run prisma:seed
```

### 5. Start Server
```bash
# Development (with nodemon live reload)
npm run dev

# Production
npm start
```

---

## 🌐 API Endpoints Overview

### Authentication & Authorization
| Method | Endpoint | Roles | Description |
|---|---|---|---|
| `POST` | `/api/auth/login` | Public | Authenticate employee & obtain JWT |
| `GET` | `/api/auth/me` | Authenticated | Retrieve current employee profile |
| `POST` | `/api/auth/register` | `ADMIN` | Provision new employee account |

### Customers & Tiers
| Method | Endpoint | Roles | Description |
|---|---|---|---|
| `POST` | `/api/customers/new` | All Employees | Create customer + initial opportunity (phase `'TALKING'`, auto 30-day next call date) |
| `GET` | `/api/customers/existing` | All Employees | Group existing customers by tier (`PREMIUM`, `LOYAL`, `INTERIOR_DESIGNER`) |
| `GET` | `/api/customers/:id/opportunities` | All Employees | Retrieve deals & distinct plant/site locations for company |
| `GET` | `/api/customers/blocklisted` | `ADMIN`, `MANAGER` | Retrieve all blocklisted customers |
| `PATCH` | `/api/admin/customers/:id/blocklist` | `ADMIN`, `MANAGER` | Toggle or set customer blocklist status |
| `PATCH` | `/api/customers/:id/tier` | `MANAGER`, `ADMIN` | Upgrade, modify, or switch customer tier |
| `GET` | `/api/customers` | All Employees | List customers with search & filter |
| `GET` | `/api/customers/:id` | All Employees | Retrieve single customer details |

### Opportunities & Pipeline Lifecycle
| Method | Endpoint | Roles | Description |
|---|---|---|---|
| `POST` | `/api/opportunities` | All Employees | Create new opportunity with employee attribution |
| `PATCH` | `/api/opportunities/:id/status` | Sales Rep, Manager | Update deal status (`CLOSED_WON`, `CLOSED_LOST`) & pipeline phase (`TALKING` -> `PROCESSING` -> `DEAL_CLOSED`). Triggers **Rule 2 Deal Closure Graduation**. |
| `GET` | `/api/opportunities` | All Employees | List opportunities with status & phase filters |
| `GET` | `/api/opportunities/:id` | All Employees | Retrieve opportunity with full lead notes history |
| `POST` | `/api/opportunities/:id/notes` | All Employees | Log call conclusions & auto-schedule next call (auto-completes prior pending tasks) |

### Tasks & Call Logging
| Method | Endpoint | Roles | Description |
|---|---|---|---|
| `GET` | `/api/tasks/today` | All Employees | Priority task queue (due today and overdue calls) |
| `PATCH` | `/api/tasks/:note_id/complete` | All Employees | Mark task complete with employee & timestamp attribution |
| `PATCH` | `/api/tasks/:note_id/assign` | `MANAGER`, `ADMIN` | Reassign follow-up task directly to any employee |
| `GET` | `/api/tasks` | All Employees | General task listing with status & date filters |
| `GET` | `/api/tasks/:id` | All Employees | Retrieve single task record |

### Manager Governance, Workload & Analytics
| Method | Endpoint | Roles | Description |
|---|---|---|---|
| `GET` | `/api/manager/workload` | `MANAGER`, `ADMIN` | Team workload capacity: active deals & pending tasks per rep |
| `GET` | `/api/manager/alerts/overdue-tasks` | `MANAGER`, `ADMIN` | Filter overdue tasks with days overdue & urgency levels |
| `GET` | `/api/manager/audit/lead-history/:id` | `MANAGER`, `ADMIN` | Full chronological audit trail: creators, updaters & completions |
| `GET` | `/api/manager/analytics` | `MANAGER`, `ADMIN` | Pipeline counts, conversion/win rates & team activity metrics |
| `GET` | `/api/manager/analytics/export?format=csv` | `MANAGER`, `ADMIN` | Download CSV/Excel ready pipeline & performance report |
| `GET` | `/api/manager/employees` | `MANAGER`, `ADMIN` | Staff directory with activity counts |
| `POST` | `/api/manager/employees` | `MANAGER`, `ADMIN` | Create new staff member |
| `PATCH` | `/api/manager/employees/:id` | `MANAGER`, `ADMIN` | Update staff profile / role |
| `DELETE` | `/api/manager/employees/:id` | `ADMIN` | Remove staff member |

---

## ⚡ Core Business Automation Rules

1. **New Customer & Initial Outreach Automation (`POST /api/customers/new`)**:
   - Customer starts in `customer_type = 'NEW'`.
   - Initial opportunity is automatically defaulted to `project_phase = 'TALKING'` and `deal_status = 'PIPELINE'`.
   - If `next_call_date` is blank or omitted, it is automatically scheduled exactly **30 days** from creation date.
   - Initial opportunity and follow-up task are committed atomically in a Prisma database transaction.

2. **Call Logging & Follow-Up Lifecycle (`POST /api/opportunities/:id/notes`)**:
   - **Auto-Completion of Prior Tasks:** Automatically marks all existing uncompleted tasks for that opportunity as `is_completed = true` (with `completed_at = now` and `completed_by = logged_in_employee`).
   - **Self-Assignment:** The new follow-up task is automatically attributed to `req.user.employee_id` (or overridden by a Manager via `assigned_employee_id`).
   - **Default 30-Day Scheduling:** If `next_call_date` is omitted, the next call is scheduled 30 days ahead.

3. **Rule 2: Deal Closure Graduation (`PATCH /api/opportunities/:id/status`)**:
   - When `deal_status` is updated to `'CLOSED_WON'`:
     * The parent customer's `customer_type` is automatically promoted from `'NEW'` to `'EXISTING'`.
     * A valid customer tier (`'PREMIUM'`, `'LOYAL'`, `'INTERIOR_DESIGNER'`) is assigned (from request body or fallback to `'LOYAL'`).
     * The opportunity's `project_phase` transitions to `'DEAL_CLOSED'`.
     * The opportunity is marked `is_completed = true`, stamped with `completed_at = now`, and attributed to `completed_by = employee_id`.
   - Both **Sales Reps** and **Managers/Admins** can advance lifecycle stages: `TALKING` -> `PROCESSING` -> `DEAL_CLOSED`.
