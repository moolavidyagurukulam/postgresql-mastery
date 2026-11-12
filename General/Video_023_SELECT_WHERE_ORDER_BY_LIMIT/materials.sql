-- =============================================
-- PostgreSQL Mastery: SELECT, WHERE, ORDER BY & LIMIT
-- Phase 5: DML | Classes 35-38
-- =============================================
-- Querying, filtering, sorting, and paging data.
-- =============================================

-- === SETUP ===

CREATE TABLE employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(150) UNIQUE,
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    hire_date  DATE,
    is_active  BOOLEAN DEFAULT true
);

INSERT INTO employees (name, email, department, salary, hire_date, is_active) VALUES
('Ravi',   'ravi@co.com',   'Engineering', 95000,  '2022-03-15', true),
('Priya',  'priya@co.com',  'Engineering', 88000,  '2023-06-01', true),
('Arjun',  'arjun@co.com',  'Marketing',   72000,  '2021-11-20', true),
('Meera',  'meera@co.com',  'Engineering', 105000, '2020-01-10', true),
('Kiran',  'kiran@co.com',  'Sales',       68000,  '2024-02-14', true),
('Anita',  NULL,             'Marketing',   75000,  '2023-09-05', false),
('Deepak', 'deepak@co.com', 'Sales',       71000,  '2022-07-22', true),
('Sonia',  'sonia@co.com',  'HR',          82000,  '2021-04-30', true),
('Vikram', 'vikram@co.com', 'Engineering', 92000,  '2023-01-18', false),
('Neha',   'neha@co.com',   'HR',          78000,  '2024-08-01', true);

-- === SELECT — Column Selection ===

-- All columns
SELECT * FROM employees;

-- Specific columns
SELECT name, department, salary FROM employees;

-- Column aliases
SELECT name AS employee_name,
       salary AS annual_salary
FROM employees;

-- Expressions in SELECT
SELECT name,
       salary AS annual,
       ROUND(salary / 12, 2) AS monthly,
       salary * 1.10 AS after_10pct_raise
FROM employees;

-- String concatenation
SELECT name || ' (' || department || ')' AS employee_info
FROM employees;

-- === DISTINCT ===

SELECT DISTINCT department FROM employees ORDER BY department;
-- Engineering, HR, Marketing, Sales

SELECT DISTINCT department, is_active FROM employees;
-- Unique combinations

SELECT COUNT(DISTINCT department) AS dept_count FROM employees;
-- 4

-- === WHERE — Comparison Operators ===

-- Equal
SELECT name, salary FROM employees WHERE department = 'Engineering';

-- Not equal (<> is SQL standard, != also works)
SELECT name FROM employees WHERE department <> 'Sales';

-- Greater than / Less than
SELECT name, salary FROM employees WHERE salary > 90000;
SELECT name, salary FROM employees WHERE salary <= 75000;

-- Date comparison
SELECT name, hire_date FROM employees WHERE hire_date >= '2023-01-01';

-- === WHERE — BETWEEN ===

-- Inclusive on both ends!
SELECT name, salary FROM employees
WHERE salary BETWEEN 75000 AND 95000;

-- Date range
SELECT name, hire_date FROM employees
WHERE hire_date BETWEEN '2022-01-01' AND '2023-12-31';

-- NOT BETWEEN
SELECT name, salary FROM employees
WHERE salary NOT BETWEEN 70000 AND 90000;

-- === WHERE — IN / NOT IN ===

SELECT name, department FROM employees
WHERE department IN ('Engineering', 'HR');

SELECT name, department FROM employees
WHERE department NOT IN ('Sales', 'Marketing');

-- IN with subquery (preview)
-- SELECT name FROM employees
-- WHERE department IN (SELECT dept FROM high_priority_depts);

-- === WHERE — LIKE / ILIKE ===

-- % = any number of chars, _ = exactly one char

SELECT name FROM employees WHERE name LIKE 'R%';     -- Starts with R
SELECT name FROM employees WHERE name LIKE '%a';     -- Ends with a
SELECT name FROM employees WHERE name LIKE '%ir%';   -- Contains 'ir'
SELECT name FROM employees WHERE name LIKE '_e%';    -- 2nd char is 'e'
SELECT name FROM employees WHERE name LIKE '____';   -- Exactly 4 chars

-- ILIKE: case-insensitive (PostgreSQL extension)
SELECT name FROM employees WHERE name ILIKE 'r%';    -- Matches Ravi

-- NOT LIKE
SELECT name FROM employees WHERE name NOT LIKE '%a';

-- === WHERE — IS NULL / IS NOT NULL ===

-- WRONG: = NULL never works!
SELECT name FROM employees WHERE email = NULL;    -- (0 rows) WRONG!

-- RIGHT: IS NULL
SELECT name FROM employees WHERE email IS NULL;   -- Anita

-- IS NOT NULL
SELECT name FROM employees WHERE email IS NOT NULL;  -- 9 rows

-- NULL is not equal to anything, not even itself!
-- NULL = NULL  → NULL (not true)
-- NULL <> NULL → NULL (not true)

-- === AND, OR, NOT ===

-- AND: both must be true
SELECT name, department, salary FROM employees
WHERE department = 'Engineering' AND salary > 90000;

-- OR: either can be true
SELECT name, department FROM employees
WHERE department = 'HR' OR department = 'Sales';

-- NOT: negate
SELECT name FROM employees WHERE NOT is_active;  -- Anita, Vikram

-- PRECEDENCE TRAP: AND before OR!
-- This: department = 'Sales' OR department = 'HR' AND salary > 80000
-- Means: Sales OR (HR AND salary>80k)
-- NOT:   (Sales OR HR) AND salary>80k

-- FIX: always use parentheses!
SELECT name, department, salary FROM employees
WHERE (department = 'Sales' OR department = 'HR')
  AND salary > 75000;

-- Complex condition
SELECT name, department, salary FROM employees
WHERE is_active
  AND (department IN ('Engineering', 'HR'))
  AND salary BETWEEN 80000 AND 100000;

-- === ORDER BY ===

-- Ascending (default)
SELECT name, salary FROM employees ORDER BY salary;

-- Descending
SELECT name, salary FROM employees ORDER BY salary DESC;

-- Multiple columns
SELECT name, department, salary FROM employees
ORDER BY department ASC, salary DESC;

-- NULLS FIRST / NULLS LAST
SELECT name, email FROM employees ORDER BY email NULLS FIRST;
SELECT name, email FROM employees ORDER BY email DESC NULLS LAST;

-- Order by expression
SELECT name, salary FROM employees ORDER BY salary * 12 DESC;

-- Order by column number (not recommended, but works)
SELECT name, department, salary FROM employees ORDER BY 3 DESC;
-- 3 = third column = salary

-- Order by alias (works in ORDER BY but NOT in WHERE!)
SELECT name, salary / 12 AS monthly FROM employees ORDER BY monthly DESC;

-- === LIMIT & OFFSET ===

-- Top 3 earners
SELECT name, salary FROM employees ORDER BY salary DESC LIMIT 3;

-- Next 3 (page 2)
SELECT name, salary FROM employees ORDER BY salary DESC LIMIT 3 OFFSET 3;

-- Pagination formula: LIMIT page_size OFFSET (page - 1) * page_size
-- Page 1: LIMIT 3 OFFSET 0
-- Page 2: LIMIT 3 OFFSET 3
-- Page 3: LIMIT 3 OFFSET 6

-- SQL standard syntax (FETCH FIRST):
SELECT name, salary FROM employees
ORDER BY salary DESC
FETCH FIRST 3 ROWS ONLY;

-- WARNING: LIMIT without ORDER BY = undefined results!
-- SELECT name FROM employees LIMIT 3;  -- Which 3? Random!

-- === KEYSET PAGINATION (Fast Alternative) ===

-- SLOW on deep pages:
-- SELECT * FROM employees ORDER BY id LIMIT 10 OFFSET 100000;
-- (reads 100,010 rows, returns 10)

-- FAST: keyset pagination
-- Page 1:
SELECT id, name, salary FROM employees ORDER BY id LIMIT 3;
-- Returns id: 1, 2, 3. Remember last_id = 3.

-- Page 2:
SELECT id, name, salary FROM employees WHERE id > 3 ORDER BY id LIMIT 3;
-- Returns id: 4, 5, 6. Remember last_id = 6.

-- Page 3:
SELECT id, name, salary FROM employees WHERE id > 6 ORDER BY id LIMIT 3;
-- Always fast — uses the primary key index!

-- === SQL EXECUTION ORDER ===

-- 1. FROM     → which table
-- 2. WHERE    → filter rows (aliases NOT available)
-- 3. GROUP BY → group rows
-- 4. HAVING   → filter groups
-- 5. SELECT   → choose columns, create aliases
-- 6. DISTINCT → remove duplicates
-- 7. ORDER BY → sort (aliases ARE available)
-- 8. LIMIT    → return subset

-- This is why:
-- WHERE alias = x    → ERROR (alias doesn't exist yet)
-- ORDER BY alias     → OK (alias exists by now)

-- === COMMON ERRORS ===

-- Error 1: Alias in WHERE
-- SELECT name, salary * 12 AS annual FROM employees WHERE annual > 1000000;
-- ERROR: column "annual" does not exist
-- Fix: WHERE salary * 12 > 1000000

-- Error 2: NULL comparison
-- SELECT name FROM employees WHERE email = NULL;
-- Returns 0 rows (silently wrong!)
-- Fix: WHERE email IS NULL

-- Error 3: AND/OR precedence
-- WHERE a = 1 OR b = 2 AND c = 3
-- Means: a=1 OR (b=2 AND c=3)
-- Fix: WHERE (a = 1 OR b = 2) AND c = 3

-- === PRACTICE EXERCISES ===

-- Exercise 1: Engineering employees earning > 90k
SELECT name, salary FROM employees
WHERE department = 'Engineering' AND salary > 90000;

-- Exercise 2: Names starting with M or ending with a
SELECT name FROM employees
WHERE name LIKE 'M%' OR name LIKE '%a';

-- Exercise 3: NULL email
SELECT name FROM employees WHERE email IS NULL;

-- Exercise 4: Distinct departments, sorted
SELECT DISTINCT department FROM employees ORDER BY department;

-- Exercise 5: Top 5 highest-paid
SELECT name, salary FROM employees ORDER BY salary DESC LIMIT 5;

-- Exercise 6: Page 2, 3 per page, sorted by hire_date
SELECT name, hire_date FROM employees
ORDER BY hire_date
LIMIT 3 OFFSET 3;

-- Exercise 7: Complex WHERE
SELECT name, department, salary FROM employees
WHERE is_active
  AND (department = 'Engineering' OR department = 'HR')
  AND salary BETWEEN 80000 AND 100000
ORDER BY salary DESC;

-- Exercise 8: Keyset pagination
SELECT id, name FROM employees ORDER BY id LIMIT 4;
-- Remember last_id, then:
-- SELECT id, name FROM employees WHERE id > <last_id> ORDER BY id LIMIT 4;


-- =============================================
-- ANSWER KEY — SELECT, WHERE, ORDER BY & LIMIT SOLUTIONS
-- =============================================
-- 1. Find Engineering employees earning over $90,000
-- Note: AND requires both conditions to evaluate to true.
SELECT id, name, department, salary
FROM employees
WHERE department = 'Engineering' AND salary > 90000
ORDER BY salary DESC;

-- 2. Pattern matching with LIKE / ILIKE
-- Note: ILIKE is PostgreSQL-specific case-insensitive matching.
SELECT id, name, email
FROM customers
WHERE name ILIKE 'john%'
ORDER BY name ASC;

-- 3. BETWEEN and IN filters
-- Note: BETWEEN is inclusive of both boundary endpoints.
SELECT id, title, price
FROM products
WHERE price BETWEEN 20.00 AND 100.00
  AND category IN ('Electronics', 'Accessories')
ORDER BY price ASC;

-- 4. Handling NULL values cleanly
-- Note: Always use IS NOT NULL (never != NULL).
SELECT id, name, phone
FROM clients
WHERE phone IS NOT NULL;

-- 5. Pagination with LIMIT and OFFSET
-- Note: Fetches page 3 of 10 items per page.
SELECT id, name, created_at
FROM audit_logs
ORDER BY created_at DESC
LIMIT 10 OFFSET 20;


-- === CLEANUP ===
-- DROP TABLE IF EXISTS employees;

-- =============================================
-- Next Class: UPDATE, DELETE & UPSERT
-- =============================================
