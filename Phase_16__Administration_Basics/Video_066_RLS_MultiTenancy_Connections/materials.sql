-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- RLS, Multi-Tenancy & Connections (Classes 136-137)
-- Phase 16: Administration Basics
-- ============================================================

\c trigger_lab

-- ============================================================
-- 1. ROW-LEVEL SECURITY (RLS)
-- ============================================================

-- Setup: shared orders table
CREATE TABLE orders (
    id         SERIAL PRIMARY KEY,
    tenant_id  INT NOT NULL,
    product    TEXT NOT NULL,
    amount     NUMERIC(10,2),
    created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO orders (tenant_id, product, amount) VALUES
  (1, 'Widget', 99.99), (1, 'Gadget', 249.99),
  (2, 'Widget', 99.99), (2, 'Doohickey', 49.99),
  (3, 'Gadget', 249.99);

-- Enable RLS:
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Create tenant isolation policy:
CREATE POLICY tenant_isolation ON orders
    FOR ALL TO PUBLIC
    USING (tenant_id = current_setting('app.tenant_id')::int)
    WITH CHECK (tenant_id = current_setting('app.tenant_id')::int);

-- Grant access to test user:
GRANT SELECT, INSERT ON orders TO carol;
GRANT USAGE ON SEQUENCE orders_id_seq TO carol;

-- ============================================================
-- 2. TESTING RLS
-- ============================================================

SET ROLE carol;

-- As tenant 1:
SET app.tenant_id = '1';
SELECT * FROM orders;  -- sees only tenant 1 rows

-- As tenant 2:
SET app.tenant_id = '2';
SELECT * FROM orders;  -- sees only tenant 2 rows

-- WITH CHECK prevents wrong writes:
SET app.tenant_id = '1';
-- INSERT INTO orders (tenant_id, product, amount) VALUES (2, 'Hack', 0.01);
-- ERROR: new row violates row-level security policy

-- Correct write:
INSERT INTO orders (tenant_id, product, amount) VALUES (1, 'Thingamajig', 19.99);

RESET ROLE;

-- ============================================================
-- 3. FORCE RLS ON TABLE OWNER
-- ============================================================

-- By default, table owner bypasses RLS:
SELECT count(*) FROM orders;  -- sees ALL rows as postgres

-- Force owner to follow policies too:
ALTER TABLE orders FORCE ROW LEVEL SECURITY;
-- Now owner must also pass the policy
-- (Superusers ALWAYS bypass — no workaround)

-- Undo:
ALTER TABLE orders NO FORCE ROW LEVEL SECURITY;

-- ============================================================
-- 4. PERMISSIVE vs RESTRICTIVE POLICIES
-- ============================================================

-- PERMISSIVE (default): multiple policies combine with OR
-- RESTRICTIVE: combines with AND (additional filter)

-- Example: must be correct tenant AND account must be active
-- CREATE POLICY active_only ON orders AS RESTRICTIVE
--     FOR ALL TO PUBLIC
--     USING (is_active = true);

-- ============================================================
-- 5. MANAGING POLICIES
-- ============================================================

-- List policies:
SELECT policyname, permissive, roles, cmd, qual
FROM pg_policies WHERE tablename = 'orders';

-- Drop a policy:
DROP POLICY tenant_isolation ON orders;

-- Disable RLS:
ALTER TABLE orders DISABLE ROW LEVEL SECURITY;

-- Re-enable for schema isolation demo:
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON orders
    FOR ALL TO PUBLIC
    USING (tenant_id = current_setting('app.tenant_id')::int)
    WITH CHECK (tenant_id = current_setting('app.tenant_id')::int);

-- ============================================================
-- 6. SCHEMA-BASED MULTI-TENANCY
-- ============================================================

CREATE SCHEMA tenant_acme;
CREATE SCHEMA tenant_globex;

-- Same table in each schema:
CREATE TABLE tenant_acme.orders (
    id SERIAL PRIMARY KEY, product TEXT, amount NUMERIC
);
CREATE TABLE tenant_globex.orders (
    id SERIAL PRIMARY KEY, product TEXT, amount NUMERIC
);

-- Insert data per tenant:
INSERT INTO tenant_acme.orders (product, amount) VALUES ('Widget', 99.99);
INSERT INTO tenant_globex.orders (product, amount) VALUES ('Gadget', 249.99);

-- App sets search_path per connection:
SET search_path TO tenant_acme, public;
SELECT * FROM orders;  -- sees tenant_acme.orders

SET search_path TO tenant_globex, public;
SELECT * FROM orders;  -- sees tenant_globex.orders

-- Reset:
SET search_path TO public;

-- ============================================================
-- 7. CONNECTION MANAGEMENT
-- ============================================================

-- Current connections:
SHOW max_connections;

SELECT count(*) AS total,
  count(*) FILTER (WHERE state = 'active') AS active,
  count(*) FILTER (WHERE state = 'idle') AS idle,
  count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_tx
FROM pg_stat_activity
WHERE backend_type = 'client backend';

-- Detailed connection info:
SELECT pid, usename, datname, state,
       query_start, state_change,
       left(query, 60) AS query
FROM pg_stat_activity
WHERE backend_type = 'client backend'
ORDER BY state_change DESC;

-- Auto-kill idle-in-transaction connections:
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';
SELECT pg_reload_conf();

-- Per-role connection limit:
-- ALTER ROLE webapp CONNECTION LIMIT 20;

-- Reserved for superuser:
SHOW superuser_reserved_connections;

-- Terminate a specific connection:
-- SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE ...;

-- ============================================================
-- 8. PGBOUNCER OVERVIEW (pgbouncer.ini)
-- ============================================================

-- [databases]
-- myapp = host=127.0.0.1 port=5432 dbname=myapp
--
-- [pgbouncer]
-- listen_addr = 0.0.0.0
-- listen_port = 6432
-- pool_mode = transaction
-- default_pool_size = 50
-- max_client_conn = 1000
-- auth_type = scram-sha-256

-- App connects to port 6432 instead of 5432
-- PgBouncer pools 50 real connections for 1000 clients

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create tasks table with RLS: user_id, enable RLS,
--    policy USING (user_id = current_user)
-- 2. Test by SET ROLE to different users
-- 3. Create 2 tenant schemas with identical tables
-- 4. Monitor: SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
-- 5. ALTER SYSTEM SET idle_in_transaction_session_timeout = '2min';

-- ============================================================
-- CLEANUP (optional)
-- ============================================================
-- DROP POLICY tenant_isolation ON orders;
-- ALTER TABLE orders DISABLE ROW LEVEL SECURITY;
-- DROP TABLE orders;
-- DROP SCHEMA tenant_acme CASCADE;
-- DROP SCHEMA tenant_globex CASCADE;
