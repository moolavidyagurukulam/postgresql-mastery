-- =============================================
-- PostgreSQL Mastery: COPY, CASE WHEN, COALESCE & NULLIF
-- Phase 5: DML | Classes 42-44
-- =============================================
-- CSV import/export, conditional logic, NULL handling.
-- =============================================

-- === SETUP ===

CREATE TABLE employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(150),
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    bonus      NUMERIC(10,2),
    hire_date  DATE,
    is_active  BOOLEAN DEFAULT true
);

INSERT INTO employees (name, email, department, salary, bonus, hire_date, is_active) VALUES
('Ravi',   'ravi@co.com',   'Engineering', 95000,  10000, '2022-03-15', true),
('Priya',  'priya@co.com',  'Engineering', 88000,  8000,  '2023-06-01', true),
('Arjun',  'arjun@co.com',  'Marketing',   72000,  NULL,  '2021-11-20', true),
('Meera',  'meera@co.com',  'Engineering', 105000, 15000, '2020-01-10', true),
('Kiran',  'kiran@co.com',  'Sales',       68000,  5000,  '2024-02-14', true),
('Anita',  NULL,             'Marketing',   75000,  NULL,  '2023-09-05', false),
('Deepak', 'deepak@co.com', 'Sales',       71000,  3000,  '2022-07-22', true),
('Sonia',  'sonia@co.com',  'HR',          82000,  6000,  '2021-04-30', true),
('Vikram', 'vikram@co.com', 'Engineering', 92000,  NULL,  '2023-01-18', false),
('Neha',   'neha@co.com',   'HR',          78000,  4000,  '2024-08-01', true);

-- === COPY TO — Export Data ===

-- Export full table to CSV (from psql, client-side)
-- \copy employees TO '/tmp/employees.csv' WITH (FORMAT CSV, HEADER);

-- Export specific columns
-- \copy (SELECT name, department, salary FROM employees)
--   TO '/tmp/salaries.csv' WITH (FORMAT CSV, HEADER);

-- Export filtered data
-- \copy (SELECT * FROM employees WHERE is_active)
--   TO '/tmp/active_employees.csv' WITH (FORMAT CSV, HEADER);

-- Tab-separated
-- \copy employees TO '/tmp/employees.tsv' WITH (FORMAT CSV, HEADER, DELIMITER E'\t');

-- Server-side COPY (needs server file permissions):
-- COPY employees TO '/var/data/employees.csv' WITH (FORMAT CSV, HEADER);

-- === COPY FROM — Import Data ===

-- Create staging table for import
CREATE TABLE employees_import (
    name       VARCHAR(100),
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    hire_date  DATE
);

-- Import from CSV (client-side, from psql):
-- \copy employees_import FROM '/tmp/new_hires.csv' WITH (FORMAT CSV, HEADER);

-- Import options:
-- FORMAT CSV       → CSV format
-- HEADER           → skip first row (column names)
-- DELIMITER ','    → field separator (comma default)
-- NULL 'NULL'      → treat string 'NULL' as SQL NULL
-- NULL ''          → treat empty string as NULL
-- QUOTE '"'        → quoting character
-- ENCODING 'UTF8'  → character encoding

-- Server-side COPY:
-- COPY employees_import FROM '/var/data/new_hires.csv'
--   WITH (FORMAT CSV, HEADER);

-- COPY is 10-100x faster than INSERT for bulk loading!

-- === COMMON COPY ERRORS ===

-- Error 1: Permission denied (server COPY)
-- COPY employees FROM '/home/user/data.csv' CSV HEADER;
-- ERROR: could not open file: Permission denied
-- Fix: use \copy (client-side) instead

-- Error 2: Column count mismatch
-- \copy employees FROM '/tmp/bad.csv' CSV HEADER;
-- ERROR: extra data after last expected column
-- Fix: specify columns: \copy employees (name, salary) FROM ...

-- Error 3: Data type mismatch
-- ERROR: invalid input syntax for type numeric: "abc"
-- Fix: clean CSV data before importing

-- === CASE WHEN — Searched Form ===

-- Assign salary tiers
SELECT name, salary,
  CASE
    WHEN salary >= 100000 THEN 'Senior'
    WHEN salary >= 80000  THEN 'Mid-Level'
    WHEN salary >= 60000  THEN 'Junior'
    ELSE 'Intern'
  END AS level
FROM employees
ORDER BY salary DESC;

-- CASE evaluates top to bottom, returns first match

-- === CASE WHEN — Simple Form ===

SELECT name, department,
  CASE department
    WHEN 'Engineering' THEN 'Tech'
    WHEN 'Marketing'   THEN 'Business'
    WHEN 'Sales'       THEN 'Business'
    WHEN 'HR'          THEN 'Operations'
    ELSE 'Other'
  END AS division
FROM employees;

-- === CASE WHEN — In WHERE ===

SELECT name, department, salary FROM employees
WHERE CASE
    WHEN department = 'Engineering' THEN salary > 90000
    ELSE salary > 75000
  END;

-- === CASE WHEN — In ORDER BY ===

SELECT name, department FROM employees
ORDER BY CASE department
    WHEN 'Engineering' THEN 1
    WHEN 'HR'          THEN 2
    WHEN 'Marketing'   THEN 3
    ELSE 4
  END;

-- === CASE WHEN — In UPDATE ===

UPDATE employees
SET salary = CASE
    WHEN department = 'Engineering' THEN salary * 1.10
    WHEN department = 'Sales'       THEN salary * 1.05
    ELSE salary * 1.03
  END
RETURNING name, department, salary AS new_salary;

-- === CASE WHEN — Pivot-Style Aggregation ===

SELECT department,
  COUNT(*) AS total,
  SUM(CASE WHEN salary > 80000 THEN 1 ELSE 0 END) AS high_earners,
  SUM(CASE WHEN is_active THEN 1 ELSE 0 END) AS active_count,
  ROUND(AVG(salary), 2) AS avg_salary
FROM employees
GROUP BY department
ORDER BY avg_salary DESC;

-- === COALESCE — First Non-NULL Value ===

-- Returns the first non-NULL argument
SELECT COALESCE(NULL, NULL, 'hello', 'world');  -- 'hello'

-- Default value for NULL columns
SELECT name,
       COALESCE(email, 'no-email@company.com') AS email_display
FROM employees;

-- Multiple fallbacks
SELECT name,
       COALESCE(bonus, 0) AS effective_bonus,
       salary + COALESCE(bonus, 0) AS total_pay
FROM employees;
-- NULL bonus becomes 0

-- In concatenation
SELECT name || ' - ' || COALESCE(department, 'No Dept') AS display
FROM employees;

-- === NULLIF — Return NULL If Values Match ===

-- NULLIF(a, b): NULL if a = b, else a
SELECT NULLIF(10, 10);  -- NULL
SELECT NULLIF(10, 20);  -- 10

-- Prevent division by zero
CREATE TABLE sales_summary (
    product      VARCHAR(100),
    total_revenue NUMERIC(12,2),
    total_orders  INT
);
INSERT INTO sales_summary VALUES
('Laptop', 50000, 50),
('Widget', 0, 0),      -- zero orders!
('Mouse', 15000, 100);

-- Without NULLIF: ERROR division by zero
-- SELECT total_revenue / total_orders FROM sales_summary;

-- With NULLIF: returns NULL instead of error
SELECT product,
       total_revenue / NULLIF(total_orders, 0) AS avg_order
FROM sales_summary;

-- Clean empty strings
SELECT name,
       COALESCE(NULLIF(email, ''), 'no-email') AS email_clean
FROM employees;
-- '' → NULL → 'no-email'

-- === GREATEST & LEAST ===

-- GREATEST: largest value
SELECT GREATEST(10, 20, 5, 30);  -- 30

-- LEAST: smallest value
SELECT LEAST(10, 20, 5, 30);  -- 5

-- Enforce minimum salary display
SELECT name,
       GREATEST(salary, 50000) AS effective_salary
FROM employees;

-- Cap discount
SELECT name, salary,
       LEAST(salary * 0.20, 10000.00) AS max_discount
FROM employees;
-- 20% of salary, but max 10,000

-- Clamp to range (between 60000 and 120000)
SELECT name,
       GREATEST(LEAST(salary, 120000), 60000) AS clamped_salary
FROM employees;

-- === NULL-HANDLING CHEAT SHEET ===

-- COALESCE(a, b, c)    → first non-NULL (defaults, fallbacks)
-- NULLIF(a, b)          → NULL if a=b (prevent /0)
-- GREATEST(a, b, c)     → largest (enforce minimum)
-- LEAST(a, b, c)        → smallest (cap maximum)
-- CASE WHEN x IS NULL   → complex custom logic

-- === PRACTICE EXERCISES ===

-- Exercise 1: CASE WHEN tiers
SELECT name, salary,
  CASE
    WHEN salary >= 100000 THEN 'Senior'
    WHEN salary >= 80000  THEN 'Mid'
    WHEN salary >= 60000  THEN 'Junior'
    ELSE 'Entry'
  END AS tier
FROM employees ORDER BY salary DESC;

-- Exercise 2: CASE in UPDATE
UPDATE employees
SET bonus = CASE
    WHEN department = 'Engineering' THEN salary * 0.15
    WHEN department = 'Sales' THEN salary * 0.10
    ELSE salary * 0.05
  END
WHERE bonus IS NULL
RETURNING name, department, bonus;

-- Exercise 3: COALESCE for NULL handling
SELECT name,
       COALESCE(email, 'no-email@co.com') AS email,
       salary + COALESCE(bonus, 0) AS total_comp
FROM employees;

-- Exercise 4: NULLIF for safe division
SELECT product,
       ROUND(total_revenue / NULLIF(total_orders, 0), 2) AS avg_value
FROM sales_summary;

-- Exercise 5: GREATEST/LEAST to clamp
SELECT name,
       GREATEST(LEAST(salary, 100000), 70000) AS adjusted
FROM employees;

-- Exercise 6: Pivot with CASE
SELECT department,
       COUNT(*) AS total,
       SUM(CASE WHEN salary > 90000 THEN 1 ELSE 0 END) AS above_90k,
       SUM(CASE WHEN bonus IS NOT NULL THEN 1 ELSE 0 END) AS has_bonus
FROM employees
GROUP BY department;

-- Exercise 7: Export and reimport
-- \copy employees TO '/tmp/emp_backup.csv' WITH (FORMAT CSV, HEADER);
-- TRUNCATE employees RESTART IDENTITY;
-- \copy employees FROM '/tmp/emp_backup.csv' WITH (FORMAT CSV, HEADER);


-- =============================================
-- ANSWER KEY — COPY, CASE & COALESCE SOLUTIONS
-- =============================================
-- 1. Export query results to CSV with \copy
-- Note: \copy runs on client-side with user permissions.
\copy (SELECT id, name, salary FROM employees WHERE salary > 80000) TO 'high_earners.csv' WITH (FORMAT CSV, HEADER);

-- 2. Import CSV into staging table
-- Note: Staging tables avoid locking production tables during ETL.
\copy staging_users FROM 'users.csv' WITH (FORMAT CSV, HEADER);

-- 3. Conditional salary tiers with CASE WHEN
-- Note: CASE WHEN evaluates top-to-bottom and stops on first match.
SELECT id, name, salary,
  CASE
    WHEN salary >= 100000 THEN 'Senior'
    WHEN salary >= 70000  THEN 'Mid-Level'
    ELSE 'Junior'
  END AS salary_tier
FROM employees;

-- 4. Replace NULL values with COALESCE
-- Note: COALESCE returns the first non-null argument in the list.
SELECT id, name, COALESCE(phone, mobile, 'No Phone') AS contact_phone
FROM contacts;

-- 5. Prevent division by zero with NULLIF
-- Note: NULLIF(units, 0) returns NULL if units is 0, avoiding runtime crash.
SELECT id, revenue, units,
  revenue / NULLIF(units, 0) AS revenue_per_unit
FROM sales_batches;


-- === CLEANUP ===
-- DROP TABLE IF EXISTS employees_import, sales_summary, employees;

-- =============================================
-- Phase 5: DML — COMPLETE!
-- Next Phase: Phase 6 — JOINs
-- Next Class: INNER, LEFT, RIGHT, FULL & CROSS JOIN
-- =============================================
