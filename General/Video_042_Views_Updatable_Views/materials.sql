-- =============================================
-- PostgreSQL Mastery: Views & Updatable Views
-- Phase 11: Views | Classes 86-87
-- =============================================
-- Regular views, updatable views, WITH CHECK OPTION.
-- =============================================

-- === SETUP ===

CREATE TABLE IF NOT EXISTS employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    manager_id INT REFERENCES employees(id)
);

INSERT INTO employees (name, department, salary, manager_id)
SELECT name, department, salary, manager_id FROM (VALUES
  ('Meera',  'Executive',   120000, NULL),
  ('Ravi',   'Engineering',  95000, 1),
  ('Sonia',  'HR',           85000, 1),
  ('Priya',  'Engineering',  88000, 2),
  ('Arjun',  'Engineering',  92000, 2),
  ('Kiran',  'HR',           78000, 3),
  ('Deepak', 'Sales',        71000, 1),
  ('Anita',  'Marketing',    75000, 1),
  ('Vikram', 'Engineering',  82000, 5)
) AS t(name, department, salary, manager_id)
WHERE NOT EXISTS (SELECT 1 FROM employees);

-- === CREATE A VIEW ===

-- Simple view: engineering employees
CREATE VIEW v_engineering AS
SELECT id, name, salary
FROM employees
WHERE department = 'Engineering';

-- Query the view like a table
SELECT * FROM v_engineering ORDER BY salary DESC;

-- View with aggregation
CREATE VIEW v_dept_stats AS
SELECT department,
  COUNT(*) AS emp_count,
  ROUND(AVG(salary), 2) AS avg_salary,
  MAX(salary) AS max_salary
FROM employees
GROUP BY department;

SELECT * FROM v_dept_stats ORDER BY avg_salary DESC;

-- View with JOIN
CREATE VIEW v_emp_manager AS
SELECT e.id, e.name, e.department, e.salary,
       m.name AS manager_name
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;

SELECT * FROM v_emp_manager ORDER BY department;

-- === CREATE OR REPLACE ===

-- Update view query without dropping
CREATE OR REPLACE VIEW v_engineering AS
SELECT id, name, department, salary, manager_id
FROM employees
WHERE department = 'Engineering';

SELECT * FROM v_engineering;

-- === LIST AND INSPECT VIEWS ===

-- List all views in current schema
-- \dv

-- View definition
-- \d+ v_engineering

-- From information_schema
SELECT table_name, view_definition
FROM information_schema.views
WHERE table_schema = 'public';

-- pg_views catalog
SELECT viewname, definition
FROM pg_views
WHERE schemaname = 'public';

-- === UPDATABLE VIEWS ===

-- A view is automatically updatable when:
-- 1. FROM has exactly ONE table (no JOINs)
-- 2. No GROUP BY, HAVING, DISTINCT, LIMIT, OFFSET
-- 3. No aggregate functions
-- 4. No UNION, INTERSECT, EXCEPT
-- 5. All target columns are simple column references

-- v_engineering IS updatable (single table, simple WHERE)
-- v_emp_manager is NOT (has a JOIN)
-- v_dept_stats is NOT (has GROUP BY + aggregates)

-- Check if a view is updatable
SELECT table_name, is_updatable, is_insertable_into
FROM information_schema.views
WHERE table_schema = 'public';

-- === INSERT THROUGH UPDATABLE VIEW ===

-- This works: v_engineering is updatable
INSERT INTO v_engineering (name, department, salary, manager_id)
OVERRIDING SYSTEM VALUE
VALUES ('Neha', 'Engineering', 90000, 2);

SELECT * FROM v_engineering ORDER BY salary DESC;

-- UPDATE through the view
UPDATE v_engineering SET salary = 91000 WHERE name = 'Neha';

-- DELETE through the view
DELETE FROM v_engineering WHERE name = 'Neha';

-- === DISAPPEARING ROWS ===

-- Without CHECK OPTION, you can insert rows that
-- won't be visible through the view!

-- Insert a Sales employee through the engineering view
-- (department column is in the view now)
INSERT INTO v_engineering (name, department, salary, manager_id)
OVERRIDING SYSTEM VALUE
VALUES ('Ghost', 'Sales', 50000, 1);

-- The row is in the table but NOT visible through the view!
SELECT * FROM v_engineering WHERE name = 'Ghost';  -- empty!
SELECT * FROM employees WHERE name = 'Ghost';       -- found!

-- Clean up
DELETE FROM employees WHERE name = 'Ghost';

-- === WITH CHECK OPTION ===

-- Prevents disappearing rows
CREATE OR REPLACE VIEW v_engineering AS
SELECT id, name, department, salary, manager_id
FROM employees
WHERE department = 'Engineering'
WITH CHECK OPTION;

-- Now try the same trick — it's blocked!
-- INSERT INTO v_engineering (name, department, salary, manager_id)
-- OVERRIDING SYSTEM VALUE VALUES ('Ghost', 'Sales', 50000, 1);
-- ERROR: new row violates check option for view "v_engineering"

-- Also blocks updates that would make a row disappear
-- UPDATE v_engineering SET department = 'Sales' WHERE name = 'Ravi';
-- ERROR: new row violates check option for view "v_engineering"

-- === LOCAL vs CASCADED CHECK ===

-- View A: salary > 50000
CREATE VIEW v_high_salary AS
SELECT * FROM employees WHERE salary > 50000;

-- View B (built on A): Engineering only
CREATE VIEW v_high_eng AS
SELECT * FROM v_high_salary WHERE department = 'Engineering'
WITH LOCAL CHECK OPTION;

-- LOCAL: only checks department = 'Engineering'
-- Allows salary = 30000 (violates parent view!)

-- CASCADED (default): checks parent views too
CREATE OR REPLACE VIEW v_high_eng AS
SELECT * FROM v_high_salary WHERE department = 'Engineering'
WITH CASCADED CHECK OPTION;
-- Blocks salary = 30000 AND department != 'Engineering'

-- === NON-UPDATABLE VIEW WORKAROUND ===

-- For non-updatable views, use INSTEAD OF triggers
-- (covered in Triggers phase)

-- Or use rules (legacy, prefer triggers):
-- CREATE RULE ... AS ON INSERT TO v_emp_manager DO INSTEAD ...

-- === COMMON ERRORS ===

-- ERROR: cannot insert into view with JOINs
-- INSERT INTO v_emp_manager (name) VALUES ('Test');
-- Fix: insert into the base table directly

-- ERROR: cannot change column types with OR REPLACE
-- CREATE OR REPLACE VIEW v_engineering AS SELECT id::TEXT ...;
-- Fix: DROP VIEW first, then CREATE VIEW

-- ERROR: cannot drop table with dependent views
-- DROP TABLE employees;
-- Fix: DROP TABLE employees CASCADE; (drops views too!)
-- Or: DROP VIEW first, then DROP TABLE

-- === VIEW SECURITY ===

-- Grant SELECT only (users can read, not write)
-- GRANT SELECT ON v_engineering TO app_user;

-- Grant all operations on updatable view
-- GRANT SELECT, INSERT, UPDATE, DELETE ON v_engineering TO app_user;

-- Revoke direct table access
-- REVOKE ALL ON employees FROM app_user;

-- Now app_user can only see Engineering employees
-- through the view — other departments are hidden

-- === PRACTICE EXERCISES ===

-- Exercise 1: Create a simple view
CREATE OR REPLACE VIEW v_hr AS
SELECT id, name, salary FROM employees WHERE department = 'HR';
SELECT * FROM v_hr;

-- Exercise 2: View with JOIN
-- Already created: v_emp_manager
SELECT * FROM v_emp_manager;

-- Exercise 3: Check updatability
SELECT table_name, is_updatable FROM information_schema.views
WHERE table_schema = 'public';

-- Exercise 4: INSERT through updatable view
INSERT INTO v_hr (name, department, salary)
OVERRIDING SYSTEM VALUE VALUES ('Test HR', 'HR', 72000);
SELECT * FROM v_hr;
DELETE FROM employees WHERE name = 'Test HR';

-- Exercise 5: WITH CHECK OPTION
CREATE OR REPLACE VIEW v_hr AS
SELECT id, name, department, salary FROM employees
WHERE department = 'HR' WITH CHECK OPTION;
-- Try: INSERT INTO v_hr ... VALUES ('Test', 'Sales', 50000);
-- Should fail!

-- Exercise 6: List all views
SELECT viewname, definition FROM pg_views WHERE schemaname = 'public';

-- Exercise 7: Drop views
DROP VIEW IF EXISTS v_hr;
DROP VIEW IF EXISTS v_high_eng;
DROP VIEW IF EXISTS v_high_salary;

-- === CLEANUP ===
-- DROP VIEW IF EXISTS v_engineering, v_emp_manager, v_dept_stats;
-- DROP TABLE IF EXISTS employees;

-- =============================================
-- Next Class: Materialized Views
-- =============================================


-- =============================================
-- VERIFIED ANSWER KEY — VIEWS & UPDATABLE VIEWS
-- =============================================

-- 1. Create a Filtered Department View
CREATE OR REPLACE VIEW v_hr AS
SELECT id, name, department, salary
FROM employees
WHERE department = 'HR';

-- 2. Encapsulate Join Complexity
CREATE OR REPLACE VIEW v_emp_manager AS
SELECT e.id,
       e.name AS employee_name,
       e.department,
       m.name AS manager_name
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;

-- 3. Inspect Updatability Metadata
SELECT table_name, is_updatable
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;

-- 4. INSERT via Updatable View
INSERT INTO v_hr (name, department, salary)
VALUES ('Devi', 'HR', 75000);

-- 5. WITH CHECK OPTION Integrity Protection
CREATE OR REPLACE VIEW v_hr AS
SELECT id, name, department, salary
FROM employees
WHERE department = 'HR'
WITH CHECK OPTION;
