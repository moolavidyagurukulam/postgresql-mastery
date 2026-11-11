-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Migrating Oracle to PostgreSQL — Ora2Pg (Classes 250-251)
-- Phase 28: Upgrade & Migration
-- ============================================================

-- ============================================================
-- 1. INSTALL ORA2PG (Linux)
-- ============================================================

-- Step 1: Install Oracle Instant Client
-- sudo apt install libaio1 alien
-- sudo alien -i oracle-instantclient-basic-21.12.0.0.0-1.x86_64.rpm
-- export ORACLE_HOME=/usr/lib/oracle/21/client64
-- export LD_LIBRARY_PATH=$ORACLE_HOME/lib

-- Step 2: Install Perl DBI + DBD::Oracle
-- sudo apt install libdbi-perl
-- sudo cpan DBD::Oracle

-- Step 3: Install Ora2Pg
-- wget https://github.com/darold/ora2pg/archive/refs/tags/v24.3.tar.gz
-- tar xzf v24.3.tar.gz && cd ora2pg-24.3
-- perl Makefile.PL && make && sudo make install

-- ============================================================
-- 2. ORA2PG CONFIGURATION — CONNECTION
-- ============================================================

-- Key settings in ora2pg.conf:
--
-- ORACLE_HOME  /usr/lib/oracle/21/client64
-- ORACLE_DSN   dbi:Oracle:host=oracle-server;sid=ORCL;port=1521
-- ORACLE_USER  system
-- ORACLE_PWD   oracle_password
-- SCHEMA       HR
--
-- PG_DSN       dbi:Pg:dbname=app_db;host=pg-server;port=5432
-- PG_USER      postgres
-- PG_PWD       pg_password

-- ============================================================
-- 3. ORA2PG CONFIGURATION — EXPORT SETTINGS
-- ============================================================

-- TYPE          TABLE   (or VIEW, SEQUENCE, FUNCTION, PROCEDURE,
--                        PACKAGE, INSERT, COPY, INDEX, CONSTRAINT)
-- OUTPUT        /migration/output/tables.sql
-- DATA_LIMIT    10000
-- DROP_FKEY     1
-- FKEY_DEFERRABLE  1
-- PG_NUMERIC_TYPE  1
-- DEFAULT_NUMERIC  bigint
-- NLS_LANG      AMERICAN_AMERICA.AL32UTF8

-- ============================================================
-- 4. MIGRATION ASSESSMENT
-- ============================================================

-- Run assessment report:
-- ora2pg -t SHOW_REPORT -c ora2pg.conf

-- Output shows complexity rating per object type:
-- A = trivial, B = moderate, C = complex (manual work needed)
-- Also shows estimated person-days

-- ============================================================
-- 5. EXPORT SCHEMA OBJECTS
-- ============================================================

-- Export tables:
-- ora2pg -t TABLE -o tables.sql -c ora2pg.conf

-- Export sequences:
-- ora2pg -t SEQUENCE -o sequences.sql -c ora2pg.conf

-- Export views:
-- ora2pg -t VIEW -o views.sql -c ora2pg.conf

-- Export indexes:
-- ora2pg -t INDEX -o indexes.sql -c ora2pg.conf

-- Export constraints:
-- ora2pg -t CONSTRAINT -o constraints.sql -c ora2pg.conf

-- Export functions:
-- ora2pg -t FUNCTION -o functions.sql -c ora2pg.conf

-- Export procedures:
-- ora2pg -t PROCEDURE -o procedures.sql -c ora2pg.conf

-- Export packages (converted to schemas + functions):
-- ora2pg -t PACKAGE -o packages.sql -c ora2pg.conf

-- ============================================================
-- 6. EXPORT DATA
-- ============================================================

-- COPY format (fastest):
-- ora2pg -t COPY -o data.sql -c ora2pg.conf -j 4

-- INSERT format (slower, but resumable):
-- ora2pg -t INSERT -o data_insert.sql -c ora2pg.conf

-- ============================================================
-- 7. LOAD INTO POSTGRESQL — CORRECT ORDER
-- ============================================================

-- 1. Tables (DDL, no foreign keys)
-- psql -U postgres -d app_db -f tables.sql

-- 2. Sequences
-- psql -U postgres -d app_db -f sequences.sql

-- 3. Data (bulk load)
-- psql -U postgres -d app_db -f data.sql

-- 4. Indexes
-- psql -U postgres -d app_db -f indexes.sql

-- 5. Constraints (foreign keys)
-- psql -U postgres -d app_db -f constraints.sql

-- 6. Views
-- psql -U postgres -d app_db -f views.sql

-- 7. Triggers
-- psql -U postgres -d app_db -f triggers.sql

-- 8. Functions and procedures
-- psql -U postgres -d app_db -f functions.sql
-- psql -U postgres -d app_db -f procedures.sql
-- psql -U postgres -d app_db -f packages.sql

-- 9. Rebuild statistics
-- vacuumdb -U postgres -d app_db --analyze-in-stages

-- ============================================================
-- 8. DATA TYPE MAPPING REFERENCE
-- ============================================================

-- Oracle Type           → PostgreSQL Type
-- NUMBER(p,0) p<=4      → smallint
-- NUMBER(p,0) p<=9      → integer
-- NUMBER(p,0) p<=18     → bigint
-- NUMBER(p,s)           → numeric(p,s)
-- NUMBER (no precision) → bigint (configurable)
-- VARCHAR2(n)           → varchar(n)
-- CHAR(n)               → char(n)
-- DATE                  → timestamp (NOT date!)
-- TIMESTAMP             → timestamp
-- CLOB                  → text
-- BLOB / RAW            → bytea
-- LONG                  → text

-- ============================================================
-- 9. PL/SQL → PL/PGSQL CONVERSION REFERENCE
-- ============================================================

-- NVL(a, b)              → COALESCE(a, b)
-- SYSDATE                → CURRENT_TIMESTAMP
-- DECODE(a,b,c,d)        → CASE WHEN a=b THEN c ELSE d END
-- ROWNUM <= 10           → LIMIT 10
-- DBMS_OUTPUT.PUT_LINE   → RAISE NOTICE
-- EXECUTE IMMEDIATE      → EXECUTE
-- PACKAGE pkg_name       → CREATE SCHEMA pkg_name (+ functions)
-- CONNECT BY             → WITH RECURSIVE

-- ============================================================
-- 10. PACKAGE CONVERSION EXAMPLE
-- ============================================================

-- Oracle Package:
-- CREATE OR REPLACE PACKAGE employee_pkg AS
--   FUNCTION get_salary(p_emp_id NUMBER) RETURN NUMBER;
-- END employee_pkg;
-- /
-- CREATE OR REPLACE PACKAGE BODY employee_pkg AS
--   FUNCTION get_salary(p_emp_id NUMBER) RETURN NUMBER IS
--     v_salary NUMBER;
--   BEGIN
--     SELECT salary INTO v_salary
--     FROM employees WHERE emp_id = p_emp_id;
--     RETURN v_salary;
--   END;
-- END employee_pkg;

-- PostgreSQL Equivalent:
CREATE SCHEMA IF NOT EXISTS employee_pkg;

CREATE OR REPLACE FUNCTION employee_pkg.get_salary(
  p_emp_id integer
) RETURNS numeric AS $$
DECLARE
  v_salary numeric;
BEGIN
  SELECT salary INTO v_salary
  FROM employees WHERE emp_id = p_emp_id;
  RETURN v_salary;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 11. POST-MIGRATION VALIDATION
-- ============================================================

-- Compare row counts:
SELECT schemaname, relname, n_live_tup
FROM pg_stat_user_tables ORDER BY relname;

-- Check constraints loaded:
SELECT conname, contype, conrelid::regclass
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace;

-- Check indexes loaded:
SELECT indexname, tablename
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename;

-- ============================================================
-- 12. ORACLE FEATURES → POSTGRESQL ALTERNATIVES
-- ============================================================

-- PUBLIC SYNONYM    → search_path or VIEW
-- DATABASE LINK     → postgres_fdw foreign server
-- MVIEW LOG         → Logical replication or trigger
-- CONNECT BY        → WITH RECURSIVE CTE
-- FLASHBACK QUERY   → No equivalent (use backups)
-- AUTONOMOUS TRANS  → dblink to self
-- GLOBAL TEMP TABLE → ON COMMIT DROP/DELETE ROWS
-- BITMAP INDEX      → GIN index
-- VIRTUAL COLUMN    → GENERATED ALWAYS AS (PG 16)

-- ============================================================
-- 13. ORGANIZED PROJECT SETUP
-- ============================================================

-- Create project structure:
-- ora2pg --init_project my_migration
-- cd my_migration
-- Edit config/ora2pg.conf
-- Run ./export_schema.sh

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install Ora2Pg. Run SHOW_REPORT against Oracle XE.
--    Read the migration complexity score.

-- 2. Export Oracle HR schema (tables + sequences + data).
--    Load into PG 16. Compare row counts between Oracle and PG.

-- 3. Write an Oracle PL/SQL function using NVL + DECODE.
--    Convert manually to PL/pgSQL. Compare with Ora2Pg output.

-- 4. Use ora2pg --init_project to create a migration structure.
--    Explore the directory layout. Run a full schema export.

-- 5. Convert an Oracle CONNECT BY hierarchical query to
--    PostgreSQL WITH RECURSIVE. Verify both return same results.
