-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- postgres_fdw — Connect PG to PG (Class 218)
-- Phase 25: Advanced Features
-- ============================================================

-- ============================================================
-- 1. COMPLETE SETUP
-- ============================================================

-- Step 1: Enable extension:
CREATE EXTENSION postgres_fdw;

-- Step 2: Define remote server:
CREATE SERVER app_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (
        host '10.0.1.10',
        port '5432',
        dbname 'app_db'
    );

-- Step 3: Map local user → remote credentials:
CREATE USER MAPPING FOR analytics_user
    SERVER app_server
    OPTIONS (
        user 'fdw_reader',
        password 'SecurePass123!'
    );

-- Step 4a: Manual foreign table:
CREATE FOREIGN TABLE remote_users (
    id int,
    name text,
    email text,
    created_at timestamptz
)
SERVER app_server
OPTIONS (schema_name 'public', table_name 'users');

-- Step 4b: Auto-import schema:
CREATE SCHEMA IF NOT EXISTS app_data;

IMPORT FOREIGN SCHEMA public
    LIMIT TO (users, orders, products)
    FROM SERVER app_server
    INTO app_data;

-- ============================================================
-- 2. QUERYING REMOTE DATA
-- ============================================================

-- Simple query:
SELECT count(*) FROM app_data.users;

-- Join remote with local:
SELECT u.name, r.target_amount
FROM app_data.users u
JOIN revenue_targets r ON r.user_id = u.id;

-- Join two remote tables (pushed to remote):
SELECT u.name, count(o.id) AS order_count
FROM app_data.users u
JOIN app_data.orders o ON o.user_id = u.id
GROUP BY u.name;

-- ============================================================
-- 3. WRITING TO REMOTE TABLES
-- ============================================================

-- INSERT:
INSERT INTO app_data.users (name, email)
VALUES ('New User', 'new@example.com');

-- UPDATE:
UPDATE app_data.users
SET name = 'Updated Name'
WHERE id = 100;

-- DELETE:
DELETE FROM app_data.users WHERE id = 100;

-- Bulk insert from local to remote:
INSERT INTO app_data.users (name, email)
SELECT name, email FROM local_staging;

-- ============================================================
-- 4. CHECK PUSHDOWN
-- ============================================================

EXPLAIN VERBOSE
SELECT name, email
FROM app_data.users
WHERE created_at > '2024-01-01'
ORDER BY name LIMIT 10;

-- ============================================================
-- 5. TUNING fetch_size
-- ============================================================

-- Server-level:
ALTER SERVER app_server OPTIONS (SET fetch_size '1000');

-- Table-level (overrides server):
ALTER FOREIGN TABLE app_data.orders
    OPTIONS (SET fetch_size '5000');

-- ============================================================
-- 6. MATERIALIZED VIEW FOR REPORTING
-- ============================================================

CREATE MATERIALIZED VIEW daily_revenue AS
SELECT
    date_trunc('day', o.created_at) AS day,
    count(*) AS order_count,
    sum(o.total_amount) AS revenue
FROM app_data.orders o
WHERE o.created_at >= current_date - interval '90 days'
GROUP BY 1
ORDER BY 1;

-- Refresh daily:
REFRESH MATERIALIZED VIEW daily_revenue;

-- ============================================================
-- 7. SECURITY — REMOTE USER SETUP
-- ============================================================

-- On REMOTE server:
-- CREATE ROLE fdw_reader LOGIN PASSWORD 'SecurePass';
-- GRANT CONNECT ON DATABASE app_db TO fdw_reader;
-- GRANT USAGE ON SCHEMA public TO fdw_reader;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO fdw_reader;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public
--     GRANT SELECT ON TABLES TO fdw_reader;

-- On LOCAL server: restrict server access:
GRANT USAGE ON FOREIGN SERVER app_server TO analytics_user;

-- Use .pgpass instead of password in mapping:
-- ~/.pgpass: 10.0.1.10:5432:app_db:fdw_reader:SecurePass

-- ============================================================
-- 8. MONITORING CONNECTIONS
-- ============================================================

-- See cached connections:
SELECT server_name, valid, used_in_xact
FROM postgres_fdw_get_connections();

-- Disconnect one:
SELECT postgres_fdw_disconnect('app_server');

-- Disconnect all:
SELECT postgres_fdw_disconnect_all();

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. If you have two PostgreSQL instances (even on localhost
--    with different ports), set up postgres_fdw between them.

-- 2. Create a foreign table and query it.
--    Use EXPLAIN VERBOSE to see what gets pushed down.

-- 3. Try IMPORT FOREIGN SCHEMA to auto-create tables.

-- 4. Test writing: INSERT a row into a remote table.
--    Verify it appeared on the remote server.

-- 5. Create a materialized view that aggregates remote data.
--    Refresh it and query locally.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP MATERIALIZED VIEW IF EXISTS daily_revenue;
-- DROP FOREIGN TABLE IF EXISTS remote_users;
-- DROP SCHEMA IF EXISTS app_data CASCADE;
-- DROP USER MAPPING IF EXISTS FOR analytics_user SERVER app_server;
-- DROP SERVER IF EXISTS app_server;
-- DROP EXTENSION IF EXISTS postgres_fdw;
