-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- pgAudit — Compliance Audit Logging (Class 231)
-- Phase 26: Extensions
-- ============================================================

-- ============================================================
-- INSTALLATION
-- ============================================================

-- 1. Install package:
--    Debian/Ubuntu: sudo apt install postgresql-16-pgaudit
--    RHEL/Rocky:    sudo dnf install pgaudit_16

-- 2. Edit postgresql.conf:
--    shared_preload_libraries = 'pgaudit'

-- 3. Restart PostgreSQL:
--    sudo systemctl restart postgresql-16

-- 4. Create extension:
CREATE EXTENSION pgaudit;

-- Verify:
SHOW shared_preload_libraries;
-- \dx pgaudit

-- ============================================================
-- 1. SESSION AUDIT LOGGING
-- ============================================================

-- Audit DDL and write operations:
ALTER SYSTEM SET pgaudit.log = 'ddl, write';
SELECT pg_reload_conf();

-- Test: schema change is logged:
CREATE TABLE customers (
    id serial PRIMARY KEY,
    name text,
    email text
);
-- LOG: AUDIT: SESSION,1,1,DDL,CREATE TABLE,...

-- Test: insert is logged:
INSERT INTO customers (name, email)
VALUES ('Alice', 'alice@example.com');
-- LOG: AUDIT: SESSION,2,1,WRITE,INSERT,...

-- ============================================================
-- STATEMENT CLASSES
-- ============================================================

-- READ     : SELECT, COPY TO
-- WRITE    : INSERT, UPDATE, DELETE, COPY FROM, TRUNCATE
-- FUNCTION : Function calls, DO blocks
-- ROLE     : GRANT, REVOKE, CREATE/ALTER/DROP ROLE
-- DDL      : CREATE, ALTER, DROP (non-role)
-- MISC     : DISCARD, FETCH, CHECKPOINT, VACUUM
-- MISC_SET : SET, RESET
-- ALL      : Everything
-- NONE     : Disable

-- Examples:
-- ALTER SYSTEM SET pgaudit.log = 'ddl, role';
-- ALTER SYSTEM SET pgaudit.log = 'read, write, ddl';
-- ALTER SYSTEM SET pgaudit.log = 'all';
-- ALTER SYSTEM SET pgaudit.log = 'none';

-- ============================================================
-- 2. OBJECT AUDIT LOGGING
-- ============================================================

-- Create an audit role:
CREATE ROLE auditor NOLOGIN;

-- Set pgaudit.role:
ALTER SYSTEM SET pgaudit.role = 'auditor';
SELECT pg_reload_conf();

-- Grant audit permissions on sensitive tables:
GRANT SELECT, INSERT, UPDATE, DELETE ON customers TO auditor;

-- Now ALL operations on 'customers' are logged:
SELECT * FROM customers;
-- LOG: AUDIT: OBJECT,1,1,READ,SELECT,TABLE,public.customers,...

INSERT INTO customers (name, email)
VALUES ('Bob', 'bob@example.com');
-- LOG: AUDIT: OBJECT,2,1,WRITE,INSERT,TABLE,public.customers,...

-- Audit only SELECT on another table:
-- GRANT SELECT ON financial_records TO auditor;

-- ============================================================
-- 3. PER-USER SETTINGS
-- ============================================================

-- Audit everything for admin users:
ALTER ROLE admin_user SET pgaudit.log = 'all';

-- Only DDL for app users:
ALTER ROLE app_user SET pgaudit.log = 'ddl';

-- Read + write for analysts:
ALTER ROLE analyst SET pgaudit.log = 'read, write';

-- No session audit for monitoring:
ALTER ROLE monitoring SET pgaudit.log = 'none';

-- ============================================================
-- 4. CONFIGURATION OPTIONS
-- ============================================================

-- Reduce noise — skip catalog queries:
ALTER SYSTEM SET pgaudit.log_catalog = off;

-- Log parameter values (careful — may contain PII):
ALTER SYSTEM SET pgaudit.log_parameter = on;

-- Log SQL only on first line (reduce duplication):
ALTER SYSTEM SET pgaudit.log_statement_once = on;

-- Show audit in client messages too:
-- ALTER SYSTEM SET pgaudit.log_client = on;

-- Apply changes:
SELECT pg_reload_conf();

-- ============================================================
-- 5. PRODUCTION CONFIGURATION
-- ============================================================

-- Global: audit schema and role changes:
ALTER SYSTEM SET pgaudit.log = 'ddl, role';

-- Object audit for sensitive tables:
ALTER SYSTEM SET pgaudit.role = 'auditor';

-- Reduce noise:
ALTER SYSTEM SET pgaudit.log_catalog = off;
ALTER SYSTEM SET pgaudit.log_statement_once = on;

-- Apply:
SELECT pg_reload_conf();

-- Grant auditor on sensitive tables:
-- GRANT ALL ON customers TO auditor;
-- GRANT ALL ON financial_records TO auditor;
-- GRANT SELECT ON medical_records TO auditor;

-- ============================================================
-- 6. VIEWING AUDIT LOGS
-- ============================================================

-- Audit entries go to the PostgreSQL log:
-- Default: /var/log/postgresql/postgresql-16-main.log
-- Or: $PGDATA/log/

-- Search for audit entries:
-- grep 'AUDIT' /var/log/postgresql/postgresql-16-main.log

-- For structured parsing, use csvlog format:
-- ALTER SYSTEM SET log_destination = 'csvlog';
-- ALTER SYSTEM SET logging_collector = on;

-- ============================================================
-- 7. LOG SHIPPING
-- ============================================================

-- Ship to centralized logging:
-- Filebeat → Elasticsearch → Kibana
-- Fluentd → Elasticsearch
-- rsyslog → Splunk
-- Vector → any destination

-- For long-term compliance retention:
-- Store in immutable storage (S3 Glacier, etc.)
-- Set retention per compliance requirements

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install pgAudit and set pgaudit.log = 'ddl, write'.
--    Create a table and insert rows. Check the PostgreSQL log
--    for AUDIT entries.

-- 2. Create an auditor role and set pgaudit.role.
--    Grant SELECT on a table to the auditor.
--    Run a SELECT and verify it appears in the log.

-- 3. Set different pgaudit.log values for two roles.
--    Connect as each role and verify different logging levels.

-- 4. Disable pgaudit.log_catalog and compare the log volume
--    before and after.

-- 5. Design an audit configuration for a hypothetical
--    healthcare application (HIPAA compliance).

-- ============================================================
-- CLEANUP
-- ============================================================
-- ALTER SYSTEM RESET pgaudit.log;
-- ALTER SYSTEM RESET pgaudit.role;
-- ALTER SYSTEM RESET pgaudit.log_catalog;
-- ALTER SYSTEM RESET pgaudit.log_parameter;
-- ALTER SYSTEM RESET pgaudit.log_statement_once;
-- SELECT pg_reload_conf();
-- DROP TABLE IF EXISTS customers;
-- REVOKE ALL ON ALL TABLES IN SCHEMA public FROM auditor;
-- DROP ROLE IF EXISTS auditor;
-- DROP EXTENSION IF EXISTS pgaudit;
