-- ============================================================================
-- SUNITI CONSTRUCTION CRM - COMPLETE SUPABASE SQL SCHEMA
-- ============================================================================

-- 1. Drop existing types and tables if re-running (clean slate)
DROP TABLE IF EXISTS lead_notes CASCADE;
DROP TABLE IF EXISTS opportunities CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS employees CASCADE;

DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS customer_type CASCADE;
DROP TYPE IF EXISTS customer_tier CASCADE;
DROP TYPE IF EXISTS lead_temp CASCADE;
DROP TYPE IF EXISTS deal_state CASCADE;

-- ============================================================================
-- 2. CREATE ENUMS
-- ============================================================================
CREATE TYPE user_role AS ENUM ('ADMIN', 'SALES_REP');
CREATE TYPE customer_type AS ENUM ('NEW', 'EXISTING');
CREATE TYPE customer_tier AS ENUM ('PREMIUM', 'LOYAL', 'INTERIOR_DESIGNER');
CREATE TYPE lead_temp AS ENUM ('HOT', 'WARM', 'COLD');
CREATE TYPE deal_state AS ENUM ('PIPELINE', 'CLOSED_WON', 'CLOSED_LOST');

-- ============================================================================
-- 3. EMPLOYEES TABLE (Users & RBAC Roles)
-- ============================================================================
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'SALES_REP',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 4. CUSTOMERS TABLE (Existing Tiers & New Prospects)
-- ============================================================================
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    customer_type customer_type NOT NULL DEFAULT 'NEW',
    tier customer_tier, -- Nullable for new leads, required upon migration to existing
    phone VARCHAR(50),
    billing_address TEXT,
    is_blocklisted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 5. OPPORTUNITIES TABLE (Multi-Project Plants like Pune, Pimpri, Mumbai)
-- ============================================================================
CREATE TABLE opportunities (
    opportunity_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id) ON DELETE CASCADE,
    project_title VARCHAR(255) NOT NULL,
    location_name VARCHAR(100) NOT NULL,
    lead_temperature lead_temp DEFAULT 'WARM',
    deal_status deal_state DEFAULT 'PIPELINE',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 6. LEAD NOTES TABLE (Call Logs & Employee Attribution)
-- ============================================================================
CREATE TABLE lead_notes (
    note_id SERIAL PRIMARY KEY,
    opportunity_id INT REFERENCES opportunities(opportunity_id) ON DELETE CASCADE,
    employee_id INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    conclusion_notes TEXT NOT NULL,
    next_call_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 7. PERFORMANCE INDEXES
-- ============================================================================
CREATE INDEX idx_opportunities_customer_id ON opportunities(customer_id);
CREATE INDEX idx_lead_notes_opportunity_id ON lead_notes(opportunity_id);
CREATE INDEX idx_lead_notes_employee_id ON lead_notes(employee_id);
CREATE INDEX idx_customers_type_tier ON customers(customer_type, tier);

-- ============================================================================
-- 8. OPTIONAL: SEED INITIAL ADMIN & SALES REP
-- ============================================================================
-- Note: password_hash below is a placeholder for 'password123' hashed with bcrypt
INSERT INTO employees (name, email, password_hash, role) VALUES
('Sandeep Kumar', 'sandeep@suniti.com', '$2b$10$YourHashedPasswordPlaceholder1', 'SALES_REP'),
('Admin User', 'admin@suniti.com', '$2b$10$YourHashedPasswordPlaceholder2', 'ADMIN')
ON CONFLICT (email) DO NOTHING;