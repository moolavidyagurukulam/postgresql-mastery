-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- pg_hba.conf & ALTER SYSTEM (Classes 131-132)
-- Phase 16: Administration Basics
-- ============================================================

-- ============================================================
-- 1. FINDING CONFIG FILES
-- ============================================================

SHOW hba_file;
SHOW ident_file;
SHOW config_file;

-- ============================================================
-- 2. READING pg_hba.conf FROM SQL
-- ============================================================

-- View all HBA rules:
SELECT line_number, type, database, user_name, address, auth_method
FROM pg_hba_file_rules
ORDER BY line_number;

-- Check for errors:
SELECT line_number, error
FROM pg_hba_file_rules
WHERE error IS NOT NULL;

-- ============================================================
-- 3. pg_hba.conf FORMAT REFERENCE
-- ============================================================

-- TYPE    DATABASE  USER      ADDRESS         METHOD
-- -------------------------------------------------------
-- local   all       all                       peer
-- host    all       all       127.0.0.1/32    scram-sha-256
-- host    all       all       ::1/128         scram-sha-256
-- host    all       all       0.0.0.0/0       reject

-- PRODUCTION EXAMPLE:
-- host    all       postgres    127.0.0.1/32     scram-sha-256
-- host    myapp_db  webapp      10.0.1.0/24      scram-sha-256
-- host    reporting analyst     192.168.10.0/24  scram-sha-256
-- host    replication replicator 10.0.2.10/32    scram-sha-256
-- host    all       all         0.0.0.0/0        reject
-- host    all       all         ::0/0            reject

-- ============================================================
-- 4. AUTHENTICATION METHODS
-- ============================================================

-- trust         = no password (NEVER in production)
-- scram-sha-256 = secure password hash (recommended)
-- md5           = older password hash (legacy)
-- peer          = OS username match (local only)
-- ident         = OS username via ident server (TCP)
-- cert          = SSL client certificate
-- reject        = explicitly deny
-- ldap          = LDAP/Active Directory

-- ============================================================
-- 5. READING pg_ident.conf FROM SQL (PostgreSQL 16)
-- ============================================================

SELECT line_number, map_name, sys_name, pg_username, error
FROM pg_ident_file_mappings
ORDER BY line_number;

-- ============================================================
-- 6. ALTER SYSTEM — SAFE PARAMETER CHANGES
-- ============================================================

-- Change a parameter (writes to postgresql.auto.conf):
ALTER SYSTEM SET work_mem = '64MB';
ALTER SYSTEM SET log_min_duration_statement = 1000;

-- Validation catches errors:
-- ALTER SYSTEM SET shared_buffers = 'banana';
-- ERROR: invalid value for parameter "shared_buffers": "banana"

-- Reload to apply (sighup parameters):
SELECT pg_reload_conf();

-- Verify:
SHOW work_mem;
SHOW log_min_duration_statement;

-- ============================================================
-- 7. ALTER SYSTEM RESET
-- ============================================================

-- Remove one override:
ALTER SYSTEM RESET work_mem;

-- Remove ALL overrides:
-- ALTER SYSTEM RESET ALL;

-- Reload after reset:
SELECT pg_reload_conf();

-- See what ALTER SYSTEM has written:
SELECT sourcefile, name, setting, applied
FROM pg_file_settings
WHERE sourcefile LIKE '%auto%'
ORDER BY name;

-- ============================================================
-- 8. RELOAD vs RESTART
-- ============================================================

-- RELOAD (sighup parameters — no downtime):
SELECT pg_reload_conf();
-- Or: pg_ctl reload -D "C:\Program Files\PostgreSQL\16\data"
-- Or: sudo systemctl reload postgresql

-- RESTART (postmaster parameters — brief downtime):
-- pg_ctl restart -D "C:\Program Files\PostgreSQL\16\data"
-- sudo systemctl restart postgresql

-- Check which parameters need restart:
SELECT name, setting, unit, pending_restart
FROM pg_settings
WHERE pending_restart = true;

-- Check parameter context:
SELECT name, context
FROM pg_settings
WHERE name IN ('shared_buffers', 'work_mem', 'log_min_duration_statement');

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Read your pg_hba.conf
-- SELECT * FROM pg_hba_file_rules ORDER BY line_number;

-- 2. ALTER SYSTEM SET and verify
-- ALTER SYSTEM SET log_min_duration_statement = 500;
-- SELECT pg_reload_conf();
-- SHOW log_min_duration_statement;

-- 3. ALTER SYSTEM RESET
-- ALTER SYSTEM RESET log_min_duration_statement;
-- SELECT pg_reload_conf();

-- 4. Find pending restarts
-- SELECT name, setting FROM pg_settings WHERE pending_restart = true;

-- 5. Write an HBA rule (in the file):
-- host  reporting_db  analyst  192.168.1.0/24  scram-sha-256
