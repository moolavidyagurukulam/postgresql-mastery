-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Users, Roles & Privileges (Classes 133-135)
-- Phase 16: Administration Basics
-- ============================================================

-- ============================================================
-- 1. ROLES vs USERS (They Are the Same)
-- ============================================================

-- These are identical:
CREATE USER alice WITH PASSWORD 'secure_pass_123';
CREATE ROLE bob WITH LOGIN PASSWORD 'secure_pass_456';

-- Group role (no login):
CREATE ROLE readonly NOLOGIN;

-- List roles:
\du

-- ============================================================
-- 2. CREATE ROLE OPTIONS
-- ============================================================

-- Full syntax example:
-- CREATE ROLE role_name WITH
--     LOGIN | NOLOGIN
--     PASSWORD 'secret'
--     SUPERUSER | NOSUPERUSER
--     CREATEDB | NOCREATEDB
--     CREATEROLE | NOCREATEROLE
--     INHERIT | NOINHERIT
--     CONNECTION LIMIT 5
--     VALID UNTIL '2027-01-01'
--     IN ROLE group_role;

-- Modify later:
ALTER ROLE alice WITH CREATEDB;
ALTER ROLE alice SET work_mem = '128MB';  -- per-role default
ALTER ROLE alice WITH PASSWORD 'new_pass';

-- ============================================================
-- 3. BUILDING A ROLE HIERARCHY
-- ============================================================

-- Step 1: Group roles (no login)
CREATE ROLE reader NOLOGIN;
CREATE ROLE writer NOLOGIN;
CREATE ROLE admin_role NOLOGIN;

-- Step 2: Login users
CREATE ROLE alice LOGIN PASSWORD 'pass_alice';
CREATE ROLE bob LOGIN PASSWORD 'pass_bob';
CREATE ROLE carol LOGIN PASSWORD 'pass_carol';

-- Step 3: Grant membership
GRANT writer TO alice;
GRANT admin_role TO bob;
GRANT reader TO carol;

-- ============================================================
-- 4. GRANTING PRIVILEGES
-- ============================================================

-- Schema access (REQUIRED):
GRANT USAGE ON SCHEMA public TO reader;
GRANT USAGE ON SCHEMA public TO writer;
GRANT USAGE, CREATE ON SCHEMA public TO admin_role;

-- Table privileges:
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reader;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO writer;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_role;

-- Sequences (for SERIAL/IDENTITY):
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO writer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO admin_role;

-- CRITICAL: Future tables:
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO writer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON TABLES TO admin_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE ON SEQUENCES TO writer;

-- ============================================================
-- 5. TESTING PERMISSIONS
-- ============================================================

SET ROLE carol;  -- reader
SELECT name, salary FROM employees LIMIT 2;  -- works
-- INSERT INTO employees ... → ERROR: permission denied
RESET ROLE;

SET ROLE alice;  -- writer
INSERT INTO employees (name, department, salary) VALUES ('Test', 'HR', 50000);  -- works
RESET ROLE;

-- ============================================================
-- 6. REVOKING PRIVILEGES
-- ============================================================

REVOKE DELETE ON ALL TABLES IN SCHEMA public FROM writer;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM reader;
REVOKE reader FROM carol;  -- remove role membership

-- Re-grant for continuity:
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reader;
GRANT reader TO carol;

-- ============================================================
-- 7. INHERIT vs NOINHERIT
-- ============================================================

CREATE ROLE deploy LOGIN PASSWORD 'deploy_pass' NOINHERIT;
GRANT writer TO deploy;
GRANT admin_role TO deploy;

-- As deploy (NOINHERIT): no privileges until SET ROLE
SET ROLE deploy;
-- SELECT * FROM employees; → ERROR (no inherited privileges)
SET ROLE writer;  -- now has writer privileges
-- SELECT * FROM employees; → works
RESET ROLE;

-- ============================================================
-- 8. INSPECTING PRIVILEGES
-- ============================================================

-- Table privileges:
\dp employees

-- Check specific privilege:
SELECT has_table_privilege('carol', 'employees', 'SELECT');  -- t
SELECT has_table_privilege('carol', 'employees', 'INSERT');  -- f

-- All grants:
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
ORDER BY grantee, table_name;

-- ============================================================
-- 9. DROPPING A ROLE (Three Steps)
-- ============================================================

-- This will fail if role owns objects:
-- DROP ROLE alice; → ERROR: depends on it

-- Step 1: Reassign objects
REASSIGN OWNED BY alice TO postgres;

-- Step 2: Drop remaining privileges
DROP OWNED BY alice;

-- Step 3: Drop the role
DROP ROLE alice;

-- ============================================================
-- 10. SECURING THE PUBLIC SCHEMA
-- ============================================================

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE trigger_lab FROM PUBLIC;
GRANT CONNECT ON DATABASE trigger_lab TO reader, writer, admin_role;
GRANT CREATE ON SCHEMA public TO admin_role;

-- ============================================================
-- PRODUCTION PRIVILEGE TEMPLATE
-- ============================================================

-- 1. Lock down public schema
-- REVOKE CREATE ON SCHEMA public FROM PUBLIC;
-- REVOKE ALL ON DATABASE myapp FROM PUBLIC;

-- 2. Create group roles
-- CREATE ROLE app_reader NOLOGIN;
-- CREATE ROLE app_writer NOLOGIN;
-- CREATE ROLE app_admin NOLOGIN;

-- 3. Grant access
-- GRANT CONNECT ON DATABASE myapp TO app_reader, app_writer, app_admin;
-- GRANT USAGE ON SCHEMA public TO app_reader, app_writer, app_admin;
-- GRANT CREATE ON SCHEMA public TO app_admin;

-- 4. Table privileges
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_reader;
-- GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO app_writer;

-- 5. Future tables
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_reader;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO app_writer;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Build 3 groups + 3 users, GRANT membership
-- 2. Grant table privileges, test with SET ROLE
-- 3. Create new table, test reader access, fix with ALTER DEFAULT PRIVILEGES
-- 4. Try DROP ROLE with dependencies, follow 3-step cleanup
-- 5. REVOKE CREATE ON SCHEMA public FROM PUBLIC
