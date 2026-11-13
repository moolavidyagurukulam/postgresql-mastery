-- =============================================
-- PostgreSQL Mastery: LATERAL & GENERATE_SERIES
-- Phase 10: Advanced SQL | Classes 83-85
-- =============================================
-- LATERAL joins for correlated subqueries in FROM,
-- GENERATE_SERIES for sequences, test data, gap filling.
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

CREATE TABLE IF NOT EXISTS monthly_sales (
    month    DATE,
    product  VARCHAR(50),
    revenue  NUMERIC(10,2)
);

INSERT INTO monthly_sales
SELECT * FROM (VALUES
  ('2024-01-01'::DATE, 'Widget', 10000::NUMERIC),
  ('2024-02-01', 'Widget', 12000),
  ('2024-03-01', 'Widget', 11500),
  ('2024-04-01', 'Widget', 14000),
  ('2024-05-01', 'Widget', 13000),
  ('2024-06-01', 'Widget', 15500)
) AS t(month, product, revenue)
WHERE NOT EXISTS (SELECT 1 FROM monthly_sales);

-- === LATERAL — Basic Concept ===

-- Normal subquery in FROM: cannot reference outer tables
-- LATERAL subquery: CAN reference outer tables

-- Top 2 employees per department
SELECT d.department, e.name, e.salary
FROM (SELECT DISTINCT department FROM employees) d,
LATERAL (
  SELECT name, salary
  FROM employees
  WHERE department = d.department
  ORDER BY salary DESC
  LIMIT 2
) e;

-- Same with explicit CROSS JOIN LATERAL
SELECT d.department, e.name, e.salary
FROM (SELECT DISTINCT department FROM employees) d
CROSS JOIN LATERAL (
  SELECT name, salary
  FROM employees
  WHERE department = d.department
  ORDER BY salary DESC
  LIMIT 2
) e;

-- === LEFT JOIN LATERAL ===

-- Keep all departments even if subquery returns nothing
SELECT d.department, e.name, e.salary
FROM (SELECT DISTINCT department FROM employees) d
LEFT JOIN LATERAL (
  SELECT name, salary
  FROM employees
  WHERE department = d.department
    AND salary > 100000  -- only high earners
  ORDER BY salary DESC
  LIMIT 1
) e ON TRUE;
-- ON TRUE is required for LEFT JOIN LATERAL
-- Departments with no high earners show NULL

-- === Top 1 Per Group (Highest Earner) ===

SELECT d.department, e.name, e.salary
FROM (SELECT DISTINCT department FROM employees) d,
LATERAL (
  SELECT name, salary FROM employees
  WHERE department = d.department
  ORDER BY salary DESC LIMIT 1
) e
ORDER BY e.salary DESC;

-- === LATERAL vs ROW_NUMBER ===

-- ROW_NUMBER approach (from previous class):
SELECT * FROM (
  SELECT name, department, salary,
    ROW_NUMBER() OVER(PARTITION BY department ORDER BY salary DESC) AS rn
  FROM employees
) r WHERE rn <= 2;

-- LATERAL approach (often cleaner for small N):
SELECT d.department, e.name, e.salary
FROM (SELECT DISTINCT department FROM employees) d,
LATERAL (
  SELECT name, salary FROM employees
  WHERE department = d.department
  ORDER BY salary DESC LIMIT 2
) e;

-- LATERAL is better when:
-- - N is small (LIMIT 1 or 2)
-- - You want to use LIMIT/OFFSET
-- - Combined with functions like generate_series

-- ROW_NUMBER is better when:
-- - You need to combine with other window functions
-- - N is dynamic or large
-- - You want to see the rank number

-- === GENERATE_SERIES — Numbers ===

-- Basic sequence
SELECT * FROM generate_series(1, 5);

-- With step
SELECT * FROM generate_series(0, 100, 10);
-- 0, 10, 20, 30, ..., 100

-- Descending
SELECT * FROM generate_series(10, 1, -1);
-- 10, 9, 8, ..., 1

-- Alias the column
SELECT n FROM generate_series(1, 5) AS n;

-- === GENERATE_SERIES — Dates ===

-- All months in 2024
SELECT d::DATE AS month
FROM generate_series('2024-01-01'::DATE, '2024-12-01', '1 month') AS d;

-- All days in January 2024
SELECT d::DATE AS day
FROM generate_series('2024-01-01'::DATE, '2024-01-31', '1 day') AS d;

-- Every hour for a day
SELECT d AS hour
FROM generate_series(
  '2024-01-15 00:00'::TIMESTAMP,
  '2024-01-15 23:00',
  '1 hour'
) AS d;

-- Every 15 minutes
SELECT d AS slot
FROM generate_series(
  '2024-01-15 09:00'::TIMESTAMP,
  '2024-01-15 17:00',
  '15 minutes'
) AS d;

-- All Mondays in 2024
SELECT d::DATE AS monday
FROM generate_series('2024-01-01'::DATE, '2024-12-31', '7 days') AS d
WHERE EXTRACT(DOW FROM d) = 1;

-- === FILL GAPS IN TIME SERIES ===

-- Problem: GROUP BY skips months with no data
-- Solution: generate all months, LEFT JOIN data

SELECT
  months.month,
  COALESCE(SUM(s.revenue), 0) AS revenue
FROM generate_series(
  '2024-01-01'::DATE, '2024-06-01', '1 month'
) AS months(month)
LEFT JOIN monthly_sales s
  ON DATE_TRUNC('month', s.month) = months.month
  AND s.product = 'Widget'
GROUP BY months.month
ORDER BY months.month;

-- With multiple products (CROSS JOIN products × months)
SELECT
  p.product,
  months.month,
  COALESCE(SUM(s.revenue), 0) AS revenue
FROM (SELECT DISTINCT product FROM monthly_sales) p
CROSS JOIN generate_series(
  '2024-01-01'::DATE, '2024-06-01', '1 month'
) AS months(month)
LEFT JOIN monthly_sales s
  ON s.product = p.product
  AND DATE_TRUNC('month', s.month) = months.month
GROUP BY p.product, months.month
ORDER BY p.product, months.month;

-- === GENERATE TEST DATA ===

-- Create 10,000 test rows
CREATE TABLE test_orders (
  id          INT,
  customer_id INT,
  order_date  DATE,
  amount      NUMERIC(10,2),
  status      VARCHAR(20)
);

INSERT INTO test_orders
SELECT
  g AS id,
  (RANDOM() * 100 + 1)::INT AS customer_id,
  '2024-01-01'::DATE + (RANDOM() * 365)::INT AS order_date,
  ROUND((RANDOM() * 990 + 10)::NUMERIC, 2) AS amount,
  (ARRAY['pending','shipped','delivered','cancelled'])[
    FLOOR(RANDOM() * 4 + 1)::INT
  ] AS status
FROM generate_series(1, 10000) AS g;

-- Verify
SELECT status, COUNT(*), ROUND(AVG(amount), 2) AS avg_amount
FROM test_orders GROUP BY status ORDER BY count DESC;

-- === LATERAL + GENERATE_SERIES ===

-- Expand date ranges into individual days
SELECT b.guest, d.day::DATE
FROM (VALUES
  ('Alice', '2024-01-10'::DATE, '2024-01-13'::DATE),
  ('Bob',   '2024-01-12'::DATE, '2024-01-14'::DATE)
) AS b(guest, check_in, check_out),
LATERAL generate_series(b.check_in, b.check_out, '1 day') AS d(day);

-- Count occupied rooms per day
SELECT d.day::DATE, COUNT(DISTINCT b.guest) AS occupied
FROM (VALUES
  ('Alice', '2024-01-10'::DATE, '2024-01-13'::DATE),
  ('Bob',   '2024-01-12'::DATE, '2024-01-14'::DATE),
  ('Carol', '2024-01-11'::DATE, '2024-01-12'::DATE)
) AS b(guest, check_in, check_out),
LATERAL generate_series(b.check_in, b.check_out, '1 day') AS d(day)
GROUP BY d.day ORDER BY d.day;

-- === GENERATE_SERIES AS JOIN MULTIPLIER ===

-- Generate row numbers alongside data
SELECT ROW_NUMBER() OVER() AS row_num, e.*
FROM employees e;

-- Cross join with series for matrix generation
SELECT r.row, c.col
FROM generate_series(1, 3) AS r(row),
     generate_series(1, 3) AS c(col);
-- Creates a 3×3 grid

-- === COMMON ERRORS ===

-- LATERAL must come AFTER the table it references
-- Wrong: FROM LATERAL (...) x, employees e
-- Right: FROM employees e, LATERAL (...) x

-- ON TRUE required for LEFT JOIN LATERAL
-- Wrong: LEFT JOIN LATERAL (...) ON department = ...
-- Right: LEFT JOIN LATERAL (...) e ON TRUE
-- (the WHERE is inside the LATERAL subquery)

-- generate_series type must match
-- Wrong: generate_series('2024-01-01', '2024-12-01', '1 month')
-- Right: generate_series('2024-01-01'::DATE, '2024-12-01', '1 month')

-- === PRACTICE EXERCISES ===

-- Exercise 1: Top 1 employee per department with LATERAL
SELECT d.department, e.name, e.salary
FROM (SELECT DISTINCT department FROM employees) d,
LATERAL (
  SELECT name, salary FROM employees
  WHERE department = d.department
  ORDER BY salary DESC LIMIT 1
) e;

-- Exercise 2: Number series 1 to 20
SELECT * FROM generate_series(1, 20);

-- Exercise 3: All months in 2024
SELECT d::DATE FROM generate_series(
  '2024-01-01'::DATE, '2024-12-01', '1 month'
) d;

-- Exercise 4: Fill gaps in monthly data
SELECT months.month, COALESCE(SUM(s.revenue), 0)
FROM generate_series('2024-01-01'::DATE, '2024-06-01', '1 month') months(month)
LEFT JOIN monthly_sales s ON DATE_TRUNC('month', s.month) = months.month
  AND s.product = 'Widget'
GROUP BY months.month ORDER BY months.month;

-- Exercise 5: Generate 100 test rows
SELECT g, ROUND((RANDOM()*100)::NUMERIC, 2) AS value
FROM generate_series(1, 100) g;

-- Exercise 6: LEFT JOIN LATERAL
SELECT d.department, e.name
FROM (SELECT DISTINCT department FROM employees) d
LEFT JOIN LATERAL (
  SELECT name FROM employees
  WHERE department = d.department AND salary > 100000
  LIMIT 1
) e ON TRUE;

-- Exercise 7: Hourly slots for a workday
SELECT d::TIME AS slot
FROM generate_series(
  '2024-01-15 09:00'::TIMESTAMP,
  '2024-01-15 17:00',
  '30 minutes'
) d;

-- === CLEANUP ===
DROP TABLE IF EXISTS test_orders;
-- DROP TABLE IF EXISTS monthly_sales, employees;

-- =============================================
-- Phase 10: Advanced SQL — COMPLETE!
-- Videos 037-041 cover:
--   UNION, INTERSECT, EXCEPT
--   Window Functions Part 1 (Ranking)
--   Window Functions Part 2 (LAG, LEAD, Frames)
--   String, Date & Math Functions
--   LATERAL & GENERATE_SERIES
--
-- Next Phase: Phase 11 — Views
-- Regular Views, Updatable Views, Materialized Views
-- =============================================


-- =============================================
-- VERIFIED ANSWER KEY — LATERAL & GENERATE_SERIES
-- =============================================

-- 1. Top Earner per Department with LATERAL
SELECT d.department, e.name, e.salary
FROM (SELECT DISTINCT department FROM employees) d,
LATERAL (
  SELECT name, salary FROM employees
  WHERE department = d.department
  ORDER BY salary DESC LIMIT 1
) e;

-- 2. Number Series 1 to 20
SELECT * FROM generate_series(1, 20);

-- 3. Monthly Calendar Sequence
SELECT d::DATE AS calendar_month
FROM generate_series(
  '2024-01-01'::DATE, '2024-12-01', '1 month'
) d;

-- 4. Fill Zero-Revenue Gaps in Time Series
SELECT months.month, COALESCE(SUM(s.revenue), 0) AS total_revenue
FROM generate_series('2024-01-01'::DATE, '2024-06-01', '1 month') months(month)
LEFT JOIN monthly_sales s ON DATE_TRUNC('month', s.month) = months.month
  AND s.product = 'Widget'
GROUP BY months.month
ORDER BY months.month;

-- 5. Preserve Outer Rows with LEFT JOIN LATERAL ... ON TRUE
SELECT d.department, e.name
FROM (SELECT DISTINCT department FROM employees) d
LEFT JOIN LATERAL (
  SELECT name FROM employees
  WHERE department = d.department AND salary > 100000
  LIMIT 1
) e ON TRUE;
