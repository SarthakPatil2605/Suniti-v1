-- ============================================================================
-- Seed Data: Suniti Construction CRM
-- Sample data for testing relationships, enums, and constraints
-- ============================================================================

-- 1. Employees
INSERT INTO employees (employee_id, name, email, password_hash, role)
VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Rahul Sharma', 'rahul.admin@suniticonstruction.com', '$2a$10$HdLm71LmrAXVJ9QLr6PBh.llgQlM0OVKquUm.nG0AILwDTwa5Vlq2', 'ADMIN'),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Priya Patil', 'priya.patil@suniticonstruction.com', '$2a$10$cP/nID.DYIFvg4HBiZ0G.eu7r7C2MGK4NDSjEQRgNL8mLsxp6333O', 'SALES_REP'),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'Amit Deshmukh', 'amit.d@suniticonstruction.com', '$2a$10$cP/nID.DYIFvg4HBiZ0G.eu7r7C2MGK4NDSjEQRgNL8mLsxp6333O', 'SALES_REP')
ON CONFLICT (email) DO NOTHING;

-- 2. Customers
INSERT INTO customers (customer_id, name, customer_type, tier, phone, billing_address, is_blocklisted)
VALUES
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'Kavita Joshi', 'NEW', NULL, '+91-9822011111', 'Baner, Pune, MH 411045', FALSE),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', 'Vikas Oberoi Enterprises', 'EXISTING', 'PREMIUM', '+91-9822022222', 'BKC, Bandra East, Mumbai, MH 400051', FALSE),
    ('f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a66', 'Studio DesignWorks (Sneha Nair)', 'EXISTING', 'INTERIOR_DESIGNER', '+91-9822033333', 'Wakad, Pimpri-Chinchwad, MH 411057', FALSE),
    ('10eebc99-9c0b-4ef8-bb6d-6bb9bd380a77', 'Rajesh Kulkarni', 'EXISTING', 'LOYAL', '+91-9822044444', 'Kothrud, Pune, MH 411038', FALSE)
ON CONFLICT (customer_id) DO NOTHING;

-- 3. Opportunities
INSERT INTO opportunities (opportunity_id, customer_id, project_title, location_name, lead_temperature, deal_status)
VALUES
    ('20eebc99-9c0b-4ef8-bb6d-6bb9bd380a88', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', '3BHK Luxury Villa Renovation', 'Pune', 'HOT', 'PIPELINE'),
    ('30eebc99-9c0b-4ef8-bb6d-6bb9bd380a99', 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', 'Commercial Office Fitout Phase 2', 'Mumbai', 'WARM', 'PIPELINE'),
    ('40eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', 'f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a66', 'Penthouse Interior Turnkey Build', 'Pimpri', 'HOT', 'CLOSED_WON')
ON CONFLICT (opportunity_id) DO NOTHING;

-- 4. Lead Notes
INSERT INTO lead_notes (note_id, opportunity_id, employee_id, conclusion_notes, next_call_date)
VALUES
    ('50eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', '20eebc99-9c0b-4ef8-bb6d-6bb9bd380a88', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Initial requirement gathering completed. Customer requested architectural quote by Thursday.', CURRENT_TIMESTAMP + INTERVAL '3 days'),
    ('60eebc99-9c0b-4ef8-bb6d-6bb9bd380b33', '30eebc99-9c0b-4ef8-bb6d-6bb9bd380a99', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'Presented design draft to procurement head. Awaiting budget sign-off.', CURRENT_TIMESTAMP + INTERVAL '5 days'),
    ('70eebc99-9c0b-4ef8-bb6d-6bb9bd380b44', '40eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Final contract executed with 20% advance milestone received. Project kickoff scheduled.', NULL)
ON CONFLICT (note_id) DO NOTHING;
