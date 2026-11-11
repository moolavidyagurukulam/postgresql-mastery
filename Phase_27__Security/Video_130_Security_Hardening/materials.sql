-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Security Hardening (Classes 240-241)
-- Phase 27: Security
-- ============================================================

-- ============================================================
-- 1. SECURE THE SUPERUSER
-- ============================================================

-- Set strong SCRAM password for postgres:
ALTER ROLE postgres WITH PASSWORD 'Str0ng!P@ss#2026-Prod';

-- Verify encryption method:
SHOW password_encryption;

-- Create separate DBA admin role:
CREATE ROLE dba_admin WITH LOGIN PASSWORD 'DbaStr0ng!2026' SUPERUSER;

-- ============================================================
-- 2. RESTRICT NETWORK LISTENING
-- ============================================================

-- postgresql.conf:
-- listen_addresses = 'localhost'         -- local only
-- listen_addresses = '10.0.1.5'         -- specific internal IP
-- listen_addresses = 'localhost,10.0.1.5' -- both

-- After change:
-- sudo systemctl restart postgresql-16

SHOW listen_addresses;

-- ============================================================
-- 3. LOCK DOWN pg_hba.conf
-- ============================================================

-- Production pg_hba.conf:
-- # TYPE   DATABASE   USER         ADDRESS          METHOD
-- local    all        postgres                      peer
-- hostssl  all        dba_admin    10.0.2.0/24      scram-sha-256
-- hostssl  app_db     web_app      10.0.1.10/32     scram-sha-256
-- hostssl  replication repl_user   10.0.3.20/32     scram-sha-256
-- hostssl  all        all          0.0.0.0/0        reject
-- hostnossl all       all          0.0.0.0/0        reject

-- Reload after changes:
SELECT pg_reload_conf();

-- ============================================================
-- 4. REVOKE PUBLIC SCHEMA PERMISSIONS
-- ============================================================

-- Check current permissions:
SELECT nspname, nspacl FROM pg_namespace WHERE nspname = 'public';

-- Revoke CREATE from PUBLIC:
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Revoke CONNECT on restricted databases:
-- REVOKE CONNECT ON DATABASE app_db FROM PUBLIC;
-- GRANT CONNECT ON DATABASE app_db TO web_app;

-- Verify the change:
SELECT nspname, nspacl FROM pg_namespace WHERE nspname = 'public';

-- ============================================================
-- 5. SET CONNECTION LIMITS
-- ============================================================

-- Global max connections:
ALTER SYSTEM SET max_connections = 150;
-- Requires restart!

-- Per-role limits:
-- ALTER ROLE web_app CONNECTION LIMIT 50;
-- ALTER ROLE dba_admin CONNECTION LIMIT 5;

-- Idle session timeout (PG 14+):
ALTER SYSTEM SET idle_session_timeout = '10min';

-- Statement timeout per role:
-- ALTER ROLE web_app SET statement_timeout = '30s';

SELECT pg_reload_conf();

-- Verify:
SHOW idle_session_timeout;

-- ============================================================
-- 6. DISABLE DANGEROUS FEATURES
-- ============================================================

-- Revoke dangerous default roles from app users:
-- REVOKE pg_read_server_files FROM web_app;
-- REVOKE pg_write_server_files FROM web_app;
-- REVOKE pg_execute_server_program FROM web_app;

-- Test: COPY file should fail for non-superuser
-- SET ROLE web_app;
-- COPY users TO '/tmp/test.csv';
-- ERROR: must be superuser or have pg_write_server_files role
-- RESET ROLE;

-- Drop unneeded extensions:
-- DROP EXTENSION IF EXISTS dblink;
-- DROP EXTENSION IF EXISTS file_fdw;

-- ============================================================
-- 7. SECURE LOGGING
-- ============================================================

-- postgresql.conf settings:
ALTER SYSTEM SET logging_collector = on;
ALTER SYSTEM SET log_statement = 'ddl';
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_line_prefix = '%t [%p] %u@%d from %h ';
ALTER SYSTEM SET log_min_duration_statement = 1000;

SELECT pg_reload_conf();

-- Verify logging settings:
SELECT name, setting FROM pg_settings
WHERE name IN ('log_statement', 'log_connections', 'log_disconnections',
               'log_line_prefix', 'log_min_duration_statement');

-- ============================================================
-- 8. PASSWORD POLICIES
-- ============================================================

-- Enable passwordcheck in postgresql.conf:
-- shared_preload_libraries = 'passwordcheck'
-- Requires restart!

-- Set password expiry:
-- ALTER ROLE web_app VALID UNTIL '2027-06-01';

-- Check password expiry for all roles:
SELECT rolname, rolvaliduntil FROM pg_roles
WHERE rolcanlogin = true AND rolvaliduntil IS NOT NULL;

-- ============================================================
-- 9. RLS AND SECURITY DEFINER AUDIT
-- ============================================================

-- Force RLS for table owners:
-- ALTER TABLE sensitive_data FORCE ROW LEVEL SECURITY;

-- Find all SECURITY DEFINER functions:
SELECT n.nspname, p.proname, r.rolname AS owner, p.proconfig
FROM pg_proc p
JOIN pg_roles r ON p.proowner = r.oid
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.prosecdef = true
  AND n.nspname NOT IN ('pg_catalog', 'information_schema');

-- ============================================================
-- 10. EXTENSION AUDIT
-- ============================================================

-- List all installed extensions:
SELECT extname, extversion, extowner::regrole FROM pg_extension;

-- Revoke blanket EXECUTE from public:
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- Grant only specific functions to specific roles:
-- GRANT EXECUTE ON FUNCTION my_safe_func(text) TO web_app;

-- ============================================================
-- 11. OS-LEVEL HARDENING (run as root)
-- ============================================================

-- Data directory permissions:
-- chmod 700 /var/lib/postgresql/16/main
-- chown -R postgres:postgres /var/lib/postgresql/16/main

-- Firewall (UFW):
-- sudo ufw allow from 10.0.1.10 to any port 5432
-- sudo ufw allow from 10.0.2.0/24 to any port 5432
-- sudo ufw deny 5432

-- Disable core dumps:
-- echo '* hard core 0' >> /etc/security/limits.conf
-- echo 'fs.suid_dumpable = 0' >> /etc/sysctl.conf

-- ============================================================
-- HARDENING AUDIT QUERY
-- ============================================================

-- Run this to check your hardening status:
SELECT 'password_encryption' AS check,
       CASE WHEN setting = 'scram-sha-256' THEN 'PASS' ELSE 'FAIL: ' || setting END AS status
FROM pg_settings WHERE name = 'password_encryption'
UNION ALL
SELECT 'ssl',
       CASE WHEN setting = 'on' THEN 'PASS' ELSE 'FAIL: SSL off' END
FROM pg_settings WHERE name = 'ssl'
UNION ALL
SELECT 'log_connections',
       CASE WHEN setting = 'on' THEN 'PASS' ELSE 'FAIL: not logging connections' END
FROM pg_settings WHERE name = 'log_connections'
UNION ALL
SELECT 'log_statement',
       CASE WHEN setting IN ('ddl', 'mod', 'all') THEN 'PASS' ELSE 'FAIL: not logging DDL' END
FROM pg_settings WHERE name = 'log_statement';

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Audit your pg_hba.conf: find trust/md5 lines, replace with
--    scram-sha-256 + hostssl. Reload and test connections.

-- 2. REVOKE CREATE ON SCHEMA public FROM PUBLIC. Connect as
--    a non-superuser and try CREATE TABLE. It should fail.

-- 3. Set CONNECTION LIMIT 3 for a test role. Open 3 connections,
--    try a 4th — observe the error.

-- 4. Run the SECURITY DEFINER audit query above. Fix any
--    functions missing SET search_path.

-- 5. Write a complete hardening.sql script that applies all
--    steps from this class to a fresh PG 16 installation.

-- ============================================================
-- CLEANUP
-- ============================================================
-- ALTER SYSTEM RESET idle_session_timeout;
-- ALTER SYSTEM RESET log_statement;
-- ALTER SYSTEM RESET log_connections;
-- ALTER SYSTEM RESET log_disconnections;
-- ALTER SYSTEM RESET log_line_prefix;
-- ALTER SYSTEM RESET log_min_duration_statement;
-- DROP ROLE IF EXISTS dba_admin;
-- SELECT pg_reload_conf();
