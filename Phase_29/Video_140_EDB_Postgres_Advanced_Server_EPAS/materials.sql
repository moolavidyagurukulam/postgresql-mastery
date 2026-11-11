-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- EDB Postgres Advanced Server (EPAS) (Classes 260-261)
-- Phase 29: EDB & Distributions
-- ============================================================

-- ============================================================
-- 1. EPAS OVERVIEW
-- ============================================================

-- EPAS = Community PostgreSQL + Oracle Compatibility Layer
-- Two modes:
--   PostgreSQL mode: identical to community PG
--   Redwood mode: Oracle compatibility enabled

-- Redwood mode changes:
-- - Empty string = NULL (Oracle behavior)
-- - DATE includes time (Oracle behavior)
-- - Oracle PL/SQL syntax supported
-- - Oracle-compatible catalog views available

-- ============================================================
-- 2. ORACLE PL/SQL SUPPORT
-- ============================================================

-- Oracle packages run DIRECTLY on EPAS (Redwood mode):

-- CREATE OR REPLACE PACKAGE employee_pkg AS
--   FUNCTION get_salary(p_emp_id NUMBER) RETURN NUMBER;
--   PROCEDURE raise_salary(p_emp_id NUMBER, p_amount NUMBER);
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
--
--   PROCEDURE raise_salary(p_emp_id NUMBER, p_amount NUMBER) IS
--   BEGIN
--     UPDATE employees SET salary = salary + p_amount
--     WHERE emp_id = p_emp_id;
--     DBMS_OUTPUT.PUT_LINE('Salary updated');
--   END;
-- END employee_pkg;

-- ============================================================
-- 3. ORACLE BUILT-IN PACKAGES IN EPAS
-- ============================================================

-- DBMS_OUTPUT  — Full support (PUT_LINE, GET_LINE, ENABLE)
-- UTL_FILE     — Full support (file read/write from PL/SQL)
-- DBMS_SQL     — Full support (dynamic SQL)
-- DBMS_JOB     — Full support (legacy job scheduling)
-- DBMS_SCHEDULER — Partial support
-- DBMS_LOB     — Full support (large objects)
-- DBMS_CRYPTO  — Full support (encryption/hashing)
-- DBMS_PIPE    — Full support (inter-session communication)
-- DBMS_LOCK    — Full support (user-defined locks)
-- UTL_MAIL     — Full support (send email)
-- DBMS_PROFILER — Full support (PL/SQL profiling)
-- UTL_HTTP     — Partial support (HTTP from PL/SQL)

-- ============================================================
-- 4. ORACLE DATA TYPES IN EPAS
-- ============================================================

-- NUMBER          → numeric (native Oracle semantics)
-- NUMBER(p,s)     → numeric(p,s)
-- VARCHAR2(n)     → varchar(n)
-- NVARCHAR2(n)    → varchar(n)
-- CHAR(n)/NCHAR   → char(n)
-- DATE            → timestamp (includes time in Redwood mode!)
-- CLOB            → text
-- BLOB            → bytea
-- RAW(n)          → bytea
-- LONG            → text
-- BINARY_FLOAT    → real
-- BINARY_DOUBLE   → double precision

-- ============================================================
-- 5. SYNONYMS (EPAS Only)
-- ============================================================

-- Private synonym:
-- CREATE SYNONYM emp FOR hr.employees;
-- SELECT * FROM emp;

-- Public synonym:
-- CREATE PUBLIC SYNONYM departments FOR hr.departments;

-- Drop:
-- DROP SYNONYM emp;
-- DROP PUBLIC SYNONYM departments;

-- ============================================================
-- 6. DATABASE LINKS (EPAS Only)
-- ============================================================

-- Create database link:
-- CREATE DATABASE LINK remote_oracle
--   CONNECT TO remote_user
--   IDENTIFIED BY 'password'
--   USING 'remote-server:1521/ORCL';

-- Query through link:
-- SELECT * FROM employees@remote_oracle WHERE department_id = 10;

-- Drop:
-- DROP DATABASE LINK remote_oracle;

-- ============================================================
-- 7. PROFILES (EPAS Only)
-- ============================================================

-- Create password policy profile:
-- CREATE PROFILE secure_profile LIMIT
--   FAILED_LOGIN_ATTEMPTS 5
--   PASSWORD_LOCK_TIME 1/24
--   PASSWORD_LIFE_TIME 90
--   PASSWORD_REUSE_TIME 365
--   PASSWORD_REUSE_MAX 12
--   PASSWORD_GRACE_TIME 7;

-- Assign to user:
-- ALTER USER app_user PROFILE secure_profile;

-- View profiles:
-- SELECT * FROM dba_profiles WHERE profile = 'SECURE_PROFILE';

-- Drop:
-- DROP PROFILE secure_profile CASCADE;

-- ============================================================
-- 8. REDWOOD MODE BEHAVIOR
-- ============================================================

-- Test empty string = NULL:
-- SELECT CASE WHEN '' IS NULL THEN 'NULL' ELSE 'NOT NULL' END;
-- Redwood mode: returns 'NULL'
-- PG mode:      returns 'NOT NULL'

-- Test DATE includes time:
-- SELECT SYSDATE FROM dual;
-- Redwood mode: returns timestamp with time
-- PG mode:      SYSDATE not available (use CURRENT_TIMESTAMP)

-- ============================================================
-- 9. WHEN TO CHOOSE EPAS vs COMMUNITY PG
-- ============================================================

-- Choose EPAS if:
--   Migrating from Oracle with heavy PL/SQL code
--   Enterprise compliance requires vendor SLAs
--   DBA team is Oracle-trained

-- Choose Community PG if:
--   No Oracle migration needed
--   New project starting fresh
--   Team already knows PostgreSQL
--   Budget-sensitive (same core engine, zero cost)

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install EPAS trial. Create database in Redwood mode.
--    Test: SELECT '' IS NULL — should return TRUE.

-- 2. Run the Oracle employee_pkg package directly on EPAS.
--    Verify it works without conversion.

-- 3. Create a profile with FAILED_LOGIN_ATTEMPTS = 3.
--    Assign to a test user. Test lockout after 3 failures.

-- 4. Compare: same PL/SQL on EPAS vs converted PL/pgSQL
--    on community PG. Verify identical results.
