-- =============================================
-- PostgreSQL Mastery: Aggregates, GROUP BY & HAVING
-- Phase 7: Aggregation & Grouping | Classes 55-57
-- =============================================
-- COUNT, SUM, AVG, MIN, MAX, GROUP BY, HAVING.
-- =============================================

-- === SETUP ===

CREATE TABLE employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    email      VARCHAR(100),
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

-- === AGGREGATE FUNCTIONS — Whole Table ===

-- All five core aggregates on the entire table
SELECT
  COUNT(*)             AS total_employees,
  SUM(salary)          AS total_salary,
  ROUND(AVG(salary),2) AS avg_salary,
  MIN(salary)          AS lowest_salary,
  MAX(salary)          AS highest_salary
FROM employees;

-- === COUNT(*) vs COUNT(column) vs COUNT(DISTINCT) ===

SELECT
  COUNT(*)                    AS all_rows,       -- 10 (includes NULLs)
  COUNT(email)                AS has_email,      -- 9  (Anita's email is NULL)
  COUNT(bonus)                AS has_bonus,      -- 7  (3 NULL bonuses)
  COUNT(DISTINCT department)  AS dept_count      -- 4  unique departments
FROM employees;

-- === NULL Handling in Aggregates ===

-- Aggregates SKIP NULLs — they don't treat NULL as zero!
SELECT
  SUM(bonus)                   AS total_bonus,         -- 51000 (7 values)
  AVG(bonus)                   AS avg_bonus_skipping,  -- 51000/7 = 7285.71
  AVG(COALESCE(bonus, 0))      AS avg_bonus_with_null  -- 51000/10 = 5100
FROM employees;

-- Use COALESCE to include NULLs as zero in calculations
SELECT name, salary, COALESCE(bonus, 0) AS effective_bonus,
       salary + COALESCE(bonus, 0) AS total_compensation
FROM employees ORDER BY total_compensation DESC;

-- === GROUP BY — Single Column ===

-- One summary row per department
SELECT department,
  COUNT(*)             AS employees,
  ROUND(AVG(salary),2) AS avg_salary,
  MIN(salary)          AS min_salary,
  MAX(salary)          AS max_salary
FROM employees
GROUP BY department
ORDER BY avg_salary DESC;

-- === GROUP BY — Multiple Columns ===

-- Group by department AND active status
SELECT department, is_active,
  COUNT(*) AS employees,
  ROUND(AVG(salary),2) AS avg_salary
FROM employees
GROUP BY department, is_active
ORDER BY department, is_active;

-- Group by hire year
SELECT EXTRACT(YEAR FROM hire_date) AS hire_year,
       COUNT(*) AS hired
FROM employees
GROUP BY EXTRACT(YEAR FROM hire_date)
ORDER BY hire_year;

-- === THE GROUP BY RULE ===

-- EVERY column in SELECT must be in GROUP BY or in an aggregate
-- This ERRORS:
-- SELECT department, name, COUNT(*) FROM employees GROUP BY department;
-- ERROR: column "name" must appear in GROUP BY or be used in aggregate

-- Fix 1: add name to GROUP BY
SELECT department, name, COUNT(*) FROM employees GROUP BY department, name;

-- Fix 2: aggregate the name column
SELECT department,
       STRING_AGG(name, ', ' ORDER BY name) AS members,
       COUNT(*)
FROM employees GROUP BY department;

-- === HAVING — Filter Groups ===

-- Departments with average salary > 80000
SELECT department,
  COUNT(*) AS employees,
  ROUND(AVG(salary),2) AS avg_salary
FROM employees
GROUP BY department
HAVING AVG(salary) > 80000;

-- Departments with 2+ employees who have bonuses
SELECT department, COUNT(bonus) AS bonus_count
FROM employees
GROUP BY department
HAVING COUNT(bonus) >= 2;

-- === WHERE + GROUP BY + HAVING ===

-- WHERE filters rows, GROUP BY groups, HAVING filters groups
SELECT department,
  COUNT(*) AS active_employees,
  ROUND(AVG(salary),2) AS avg_salary,
  SUM(salary) AS total_salary
FROM employees
WHERE is_active = true           -- filter rows first
GROUP BY department
HAVING COUNT(*) >= 2             -- then filter groups
ORDER BY total_salary DESC;

-- === Department Bonus Report ===

SELECT department,
  COUNT(*) AS total,
  COUNT(bonus) AS with_bonus,
  COUNT(*) - COUNT(bonus) AS no_bonus,
  SUM(COALESCE(bonus, 0)) AS total_bonus,
  ROUND(AVG(salary), 0) AS avg_salary
FROM employees
GROUP BY department
ORDER BY total_bonus DESC;

-- === SQL EXECUTION ORDER ===

-- 1. FROM     → pick table(s)
-- 2. WHERE    → filter rows (NO aggregates, NO aliases)
-- 3. GROUP BY → create groups
-- 4. HAVING   → filter groups (aggregates OK, NO aliases)
-- 5. SELECT   → compute columns, CREATE aliases
-- 6. DISTINCT → remove duplicates
-- 7. ORDER BY → sort (aliases OK here!)
-- 8. LIMIT    → return subset

-- This is WHY:
-- WHERE alias = x    → ERROR (alias doesn't exist yet)
-- HAVING alias = x   → ERROR (alias doesn't exist yet)
-- ORDER BY alias     → OK (alias created by SELECT)

-- === COMMON ERRORS ===

-- Error 1: Column not in GROUP BY
-- SELECT department, name, COUNT(*) FROM employees GROUP BY department;
-- ERROR: column "name" must appear in GROUP BY clause
-- Fix: add name to GROUP BY, or aggregate it

-- Error 2: Alias in HAVING
-- SELECT department, AVG(salary) AS avg_sal
-- FROM employees GROUP BY department HAVING avg_sal > 80000;
-- ERROR: column "avg_sal" does not exist
-- Fix: HAVING AVG(salary) > 80000

-- Error 3: Aggregate in WHERE
-- SELECT department FROM employees WHERE COUNT(*) > 2 GROUP BY department;
-- ERROR: aggregate functions not allowed in WHERE
-- Fix: use HAVING COUNT(*) > 2

-- Error 4: Missing GROUP BY with aggregate
-- SELECT department, COUNT(*) FROM employees;
-- ERROR: column "department" must appear in GROUP BY clause
-- Fix: add GROUP BY department

-- === PRACTICE EXERCISES ===

-- Exercise 1: Count per department
SELECT department, COUNT(*) AS employees
FROM employees GROUP BY department ORDER BY employees DESC;

-- Exercise 2: Total and average salary per department
SELECT department,
       SUM(salary) AS total_salary,
       ROUND(AVG(salary), 2) AS avg_salary
FROM employees GROUP BY department ORDER BY total_salary DESC;

-- Exercise 3: HAVING — departments with 3+ employees
SELECT department, COUNT(*) AS employees
FROM employees GROUP BY department HAVING COUNT(*) >= 3;

-- Exercise 4: COUNT comparisons
SELECT
  COUNT(*) AS all_rows,
  COUNT(email) AS has_email,
  COUNT(bonus) AS has_bonus
FROM employees;

-- Exercise 5: WHERE + HAVING combined
SELECT department, ROUND(AVG(salary),2) AS avg_salary
FROM employees
WHERE is_active = true
GROUP BY department
HAVING AVG(salary) > 75000
ORDER BY avg_salary DESC;

-- Exercise 6: Oldest and newest hire per department
SELECT department,
       MIN(hire_date) AS first_hire,
       MAX(hire_date) AS latest_hire
FROM employees GROUP BY department ORDER BY first_hire;

-- Exercise 7: Department bonus percentage
SELECT department,
       COUNT(*) AS total,
       COUNT(bonus) AS with_bonus,
       ROUND(COUNT(bonus)::NUMERIC / COUNT(*) * 100, 1) AS bonus_pct
FROM employees GROUP BY department ORDER BY bonus_pct DESC;

-- === CLEANUP ===
-- DROP TABLE IF EXISTS employees;

-- =============================================
-- Next Class: GROUPING SETS, ROLLUP, CUBE & FILTER
-- =============================================


-- =============================================
-- ANSWER KEY — AGGREGATES, GROUP BY & HAVING SOLUTIONS
-- =============================================

-- 1. Count Employees per Department
SELECT department, COUNT(*) AS employees
FROM employees
GROUP BY department
ORDER BY employees DESC;

-- 2. Total and Average Salary per Department
SELECT department,
       SUM(salary) AS total_payroll,
       ROUND(AVG(salary), 2) AS avg_salary
FROM employees
GROUP BY department
ORDER BY total_payroll DESC;

-- 3. Filter Groups with HAVING (3+ Employees)
SELECT department, COUNT(*) AS employees
FROM employees
GROUP BY department
HAVING COUNT(*) >= 3;

-- 4. NULL Handling in COUNT Functions
SELECT
  COUNT(*) AS all_rows,
  COUNT(email) AS has_email,
  COUNT(bonus) AS has_bonus
FROM employees;

-- 5. Full Pipeline: WHERE + GROUP BY + HAVING
SELECT department, ROUND(AVG(salary), 2) AS avg_salary
FROM employees
WHERE is_active = true
GROUP BY department
HAVING AVG(salary) > 75000
ORDER BY avg_salary DESC;
