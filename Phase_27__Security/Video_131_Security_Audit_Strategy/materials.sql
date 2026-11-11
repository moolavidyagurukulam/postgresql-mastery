-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Security Audit Strategy (Classes 242-243)
-- Phase 27: Security
-- ============================================================

-- ============================================================
-- 1. INSTALL pgAudit
-- ============================================================

-- Debian/Ubuntu:
-- sudo apt install postgresql-16-pgaudit

-- Add to postgresql.conf:
-- shared_preload_libraries = 'pgaudit'
-- Requires restart:
-- sudo systemctl restart postgresql-16

-- Create extension:
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- ============================================================
-- 2. CONFIGURE pgAudit SESSION LOGGING
-- ============================================================

-- Log DDL and role changes (recommended baseline):
ALTER SYSTEM SET pgaudit.log = 'ddl, role';

-- Log parameter values in audit entries:
ALTER SYSTEM SET pgaudit.log_parameter = on;

-- Apply:
SELECT pg_reload_conf();

-- Verify:
SHOW pgaudit.log;

-- ============================================================
-- 3. pgAudit LOG CLASSES REFERENCE
-- ============================================================

-- READ     : SELECT, COPY TO
-- WRITE    : INSERT, UPDATE, DELETE, TRUNCATE, COPY FROM
-- FUNCTION : Function calls, DO blocks
-- DDL      : CREATE, ALTER, DROP (all object types)
-- ROLE     : GRANT, REVOKE, CREATE/ALTER/DROP ROLE
-- MISC     : DISCARD, FETCH, CHECKPOINT
-- ALL      : Everything (dev/staging only)

-- Common production settings:
-- pgaudit.log = 'ddl, role'           -- Minimum
-- pgaudit.log = 'ddl, role, write'    -- Track data changes too
-- pgaudit.log = 'all'                 -- Dev only (huge volume)

-- ============================================================
-- 4. OBJECT-LEVEL AUDITING
-- ============================================================

-- Create auditor role:
CREATE ROLE pgaudit_auditor NOLOGIN;

-- Grant on sensitive tables:
-- GRANT SELECT ON patients TO pgaudit_auditor;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON salary TO pgaudit_auditor;

-- Set in postgresql.conf:
ALTER SYSTEM SET pgaudit.role = 'pgaudit_auditor';
SELECT pg_reload_conf();

-- Now any matching operation on those tables is logged,
-- regardless of session-level pgaudit.log setting.

-- ============================================================
-- 5. AUDIT QUERY: SUPERUSER & ROLE CHECK
-- ============================================================

-- Find all superuser roles:
SELECT rolname, rolcanlogin, rolvaliduntil
FROM pg_roles
WHERE rolsuper = true
ORDER BY rolname;

-- Roles with no password expiry:
SELECT rolname, rolcanlogin,
  CASE WHEN rolvaliduntil IS NULL THEN 'NO EXPIRY'
       WHEN rolvaliduntil < now() THEN 'EXPIRED'
       ELSE rolvaliduntil::text
  END AS password_status
FROM pg_roles
WHERE rolcanlogin = true
ORDER BY rolvaliduntil NULLS FIRST;

-- Roles that bypass RLS:
SELECT rolname FROM pg_roles
WHERE rolbypassrls = true AND rolname != 'postgres';

-- Roles with no connection limit:
SELECT rolname, rolconnlimit
FROM pg_roles
WHERE rolcanlogin = true AND rolconnlimit = -1;

-- ============================================================
-- 6. AUDIT QUERY: CONFIGURATION SCORECARD
-- ============================================================

SELECT name AS setting,
  CASE
    WHEN name = 'password_encryption' AND setting = 'scram-sha-256' THEN 'PASS'
    WHEN name = 'ssl' AND setting = 'on' THEN 'PASS'
    WHEN name = 'log_connections' AND setting = 'on' THEN 'PASS'
    WHEN name = 'log_disconnections' AND setting = 'on' THEN 'PASS'
    WHEN name = 'log_statement' AND setting IN ('ddl','mod','all') THEN 'PASS'
    WHEN name = 'listen_addresses' AND setting != '*' THEN 'PASS'
    WHEN name = 'idle_session_timeout' AND setting != '0' THEN 'PASS'
    ELSE 'FAIL: ' || setting
  END AS status
FROM pg_settings
WHERE name IN (
  'password_encryption', 'ssl', 'log_connections',
  'log_disconnections', 'log_statement',
  'listen_addresses', 'idle_session_timeout'
)
ORDER BY status DESC, name;

-- ============================================================
-- 7. AUDIT QUERY: pg_hba.conf REVIEW
-- ============================================================

-- List all rules:
SELECT line_number, type, database, user_name, address, auth_method
FROM pg_hba_file_rules
ORDER BY line_number;

-- Find weak authentication methods:
SELECT line_number, type, auth_method, address
FROM pg_hba_file_rules
WHERE auth_method IN ('trust', 'md5', 'password');
-- Should return 0 rows in production

-- ============================================================
-- 8. AUDIT QUERY: EXTENSIONS & FUNCTIONS
-- ============================================================

-- Dangerous extensions check:
SELECT extname, extversion FROM pg_extension
WHERE extname IN ('dblink', 'file_fdw', 'postgres_fdw', 'adminpack', 'lo')
ORDER BY extname;

-- SECURITY DEFINER functions without pinned search_path:
SELECT n.nspname, p.proname, r.rolname AS owner
FROM pg_proc p
JOIN pg_roles r ON p.proowner = r.oid
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.prosecdef = true
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND (p.proconfig IS NULL
    OR NOT EXISTS (
      SELECT 1 FROM unnest(p.proconfig) c
      WHERE c LIKE 'search_path=%'));

-- ============================================================
-- 9. COMPLETE SECURITY AUDIT REPORT
-- ============================================================

-- Run with: \o /path/to/audit_YYYY-MM-DD.txt

SELECT 'AUTH: password_encryption' AS check,
  CASE WHEN setting = 'scram-sha-256' THEN 'PASS'
       ELSE 'FAIL: ' || setting END AS result
FROM pg_settings WHERE name = 'password_encryption'
UNION ALL
SELECT 'AUTH: superuser count',
  CASE WHEN count(*) <= 2 THEN 'PASS: ' || count(*)
       ELSE 'FAIL: ' || count(*) || ' superusers' END
FROM pg_roles WHERE rolsuper = true
UNION ALL
SELECT 'AUTH: expired passwords',
  CASE WHEN count(*) = 0 THEN 'PASS: none expired'
       ELSE 'WARN: ' || count(*) || ' expired' END
FROM pg_roles WHERE rolvaliduntil < now() AND rolcanlogin = true
UNION ALL
SELECT 'SSL: enabled',
  CASE WHEN setting = 'on' THEN 'PASS'
       ELSE 'FAIL: SSL off' END
FROM pg_settings WHERE name = 'ssl'
UNION ALL
SELECT 'LOG: connections tracked',
  CASE WHEN setting = 'on' THEN 'PASS'
       ELSE 'FAIL' END
FROM pg_settings WHERE name = 'log_connections'
UNION ALL
SELECT 'LOG: statement level',
  CASE WHEN setting IN ('ddl', 'mod', 'all') THEN 'PASS: ' || setting
       ELSE 'FAIL: ' || setting END
FROM pg_settings WHERE name = 'log_statement'
UNION ALL
SELECT 'NET: listen_addresses',
  CASE WHEN setting = '*' THEN 'FAIL: listening on all interfaces'
       ELSE 'PASS: ' || setting END
FROM pg_settings WHERE name = 'listen_addresses'
UNION ALL
SELECT 'HBA: weak auth methods',
  CASE WHEN count(*) = 0 THEN 'PASS: none found'
       ELSE 'FAIL: ' || count(*) || ' rules use trust/md5/password' END
FROM pg_hba_file_rules
WHERE auth_method IN ('trust', 'md5', 'password')
UNION ALL
SELECT 'EXT: dangerous extensions',
  CASE WHEN count(*) = 0 THEN 'PASS: none found'
       ELSE 'WARN: ' || string_agg(extname, ', ') END
FROM pg_extension
WHERE extname IN ('dblink', 'file_fdw', 'adminpack')
UNION ALL
SELECT 'FUNC: unprotected SECURITY DEFINER',
  CASE WHEN count(*) = 0 THEN 'PASS: all pinned'
       ELSE 'FAIL: ' || count(*) || ' without search_path' END
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.prosecdef = true
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND (p.proconfig IS NULL
    OR NOT EXISTS (
      SELECT 1 FROM unnest(p.proconfig) c
      WHERE c LIKE 'search_path=%'));

-- ============================================================
-- 10. SHELL SCRIPT FOR AUTOMATED AUDITING
-- ============================================================

-- Save as: /usr/local/bin/pg_security_audit.sh
--
-- #!/bin/bash
-- DATE=$(date +%Y-%m-%d)
-- AUDIT_DIR="/var/log/pg_audit"
-- mkdir -p "$AUDIT_DIR"
--
-- psql -U postgres -d postgres -f /opt/pg_audit/audit_report.sql \
--   -o "$AUDIT_DIR/audit_${DATE}.txt"
--
-- echo "Audit saved to: $AUDIT_DIR/audit_${DATE}.txt"
--
-- # Check for FAIL results:
-- if grep -q "FAIL" "$AUDIT_DIR/audit_${DATE}.txt"; then
--   echo "WARNING: Security audit found failures!"
--   grep "FAIL" "$AUDIT_DIR/audit_${DATE}.txt"
-- else
--   echo "All checks passed."
-- fi

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install pgAudit. Set pgaudit.log = 'ddl, role'.
--    CREATE a table, GRANT permissions, check the log file.

-- 2. Set up object-level audit on a test table.
--    Run SELECT on it and verify the audit entry appears.

-- 3. Run the complete security scorecard on your server.
--    Fix any FAIL results. Re-run to verify PASS.

-- 4. Write a shell script that runs the audit report
--    and saves it with today's date in the filename.

-- 5. Run the audit today, make a change (add a role),
--    run it again tomorrow, and diff the two reports.

-- ============================================================
-- CLEANUP
-- ============================================================
-- ALTER SYSTEM RESET pgaudit.log;
-- ALTER SYSTEM RESET pgaudit.role;
-- ALTER SYSTEM RESET pgaudit.log_parameter;
-- DROP ROLE IF EXISTS pgaudit_auditor;
-- DROP EXTENSION IF EXISTS pgaudit;
-- SELECT pg_reload_conf();
