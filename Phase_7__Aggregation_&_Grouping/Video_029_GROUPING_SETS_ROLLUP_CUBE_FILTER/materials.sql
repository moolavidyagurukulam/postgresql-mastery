-- =============================================
-- PostgreSQL Mastery: GROUPING SETS, ROLLUP, CUBE & FILTER
-- Phase 7: Aggregation & Grouping | Classes 58-59
-- =============================================
-- Advanced grouping for subtotals, cross-tabs,
-- and conditional aggregation.
-- =============================================

-- === SETUP ===

CREATE TABLE sales (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department VARCHAR(50),
    region     VARCHAR(50),
    quarter    VARCHAR(10),
    revenue    NUMERIC(12,2),
    is_online  BOOLEAN DEFAULT false
);

INSERT INTO sales (department, region, quarter, revenue, is_online) VALUES
('Electronics', 'North', 'Q1', 50000, true),
('Electronics', 'North', 'Q2', 65000, false),
('Electronics', 'South', 'Q1', 45000, true),
('Electronics', 'South', 'Q2', 55000, false),
('Clothing',    'North', 'Q1', 30000, false),
('Clothing',    'North', 'Q2', 40000, true),
('Clothing',    'South', 'Q1', 25000, false),
('Clothing',    'South', 'Q2', 35000, true);

-- === REGULAR GROUP BY — One Grouping Only ===

-- By department
SELECT department, SUM(revenue) AS total
FROM sales GROUP BY department ORDER BY total DESC;

-- By region
SELECT region, SUM(revenue) AS total
FROM sales GROUP BY region ORDER BY total DESC;

-- Grand total (no GROUP BY)
SELECT SUM(revenue) AS grand_total FROM sales;

-- To get all three, you'd need UNION ALL — messy!

-- === GROUPING SETS — Custom Groupings ===

-- Three groupings in ONE query
SELECT department, region, SUM(revenue) AS total
FROM sales
GROUP BY GROUPING SETS (
  (department),        -- group by department
  (region),            -- group by region
  ()                   -- grand total
)
ORDER BY department NULLS LAST, region NULLS LAST;
-- NULL means "all values" for that column

-- Four groupings: dept, region, dept+region, grand total
SELECT department, region, SUM(revenue) AS total
FROM sales
GROUP BY GROUPING SETS (
  (department, region),
  (department),
  (region),
  ()
)
ORDER BY department NULLS LAST, region NULLS LAST;

-- === ROLLUP — Hierarchical Subtotals ===

-- ROLLUP(A, B) = GROUPING SETS ((A,B), (A), ())
SELECT department, region, SUM(revenue) AS total
FROM sales
GROUP BY ROLLUP (department, region)
ORDER BY department NULLS LAST, region NULLS LAST;
-- Shows: dept+region detail, dept subtotals, grand total

-- Three-level ROLLUP
SELECT department, region, quarter, SUM(revenue) AS total
FROM sales
GROUP BY ROLLUP (department, region, quarter)
ORDER BY department NULLS LAST, region NULLS LAST, quarter NULLS LAST;
-- ROLLUP(A,B,C) = (A,B,C), (A,B), (A), ()

-- === CUBE — All Combinations ===

-- CUBE(A, B) = GROUPING SETS ((A,B), (A), (B), ())
SELECT department, region, SUM(revenue) AS total
FROM sales
GROUP BY CUBE (department, region)
ORDER BY department NULLS LAST, region NULLS LAST;
-- Shows every possible combination including region-only

-- === GROUPING() — Identify Subtotal Rows ===

-- GROUPING(col) returns 1 for subtotal NULLs, 0 for real data
SELECT
  CASE WHEN GROUPING(department) = 1 THEN '** ALL DEPTS **'
       ELSE department END AS department,
  CASE WHEN GROUPING(region) = 1 THEN '** ALL REGIONS **'
       ELSE region END AS region,
  SUM(revenue) AS total
FROM sales
GROUP BY ROLLUP (department, region)
ORDER BY GROUPING(department), department,
         GROUPING(region), region;

-- Distinguish real NULLs from subtotal NULLs
-- GROUPING(col) = 0: real data (or real NULL in data)
-- GROUPING(col) = 1: this NULL means "all values" (subtotal)

-- === FILTER — Conditional Aggregation ===

-- Modern syntax (PG 9.4+): cleaner than CASE WHEN
SELECT department,
  SUM(revenue) AS total,
  SUM(revenue) FILTER (WHERE is_online)     AS online_rev,
  SUM(revenue) FILTER (WHERE NOT is_online)  AS offline_rev,
  COUNT(*) FILTER (WHERE region = 'North')   AS north_count,
  COUNT(*) FILTER (WHERE region = 'South')   AS south_count
FROM sales
GROUP BY department;

-- Compare: FILTER vs CASE WHEN (same result)
SELECT department,
  -- FILTER way (clean)
  SUM(revenue) FILTER (WHERE is_online) AS filter_online,
  -- CASE WHEN way (verbose)
  SUM(CASE WHEN is_online THEN revenue ELSE 0 END) AS case_online
FROM sales
GROUP BY department;

-- FILTER with COUNT, AVG, MIN, MAX
CREATE TABLE staff (
    name       VARCHAR(50),
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    is_active  BOOLEAN
);

INSERT INTO staff VALUES
('Ravi',   'Engineering', 95000, true),
('Priya',  'Engineering', 88000, true),
('Vikram', 'Engineering', 92000, false),
('Sonia',  'HR',          82000, true),
('Anita',  'Marketing',   75000, false),
('Arjun',  'Marketing',   72000, true);

SELECT
  COUNT(*) FILTER (WHERE is_active) AS active_count,
  COUNT(*) FILTER (WHERE NOT is_active) AS inactive_count,
  ROUND(AVG(salary) FILTER (WHERE is_active), 2) AS active_avg,
  MIN(salary) FILTER (WHERE is_active) AS active_min,
  MAX(salary) FILTER (WHERE is_active) AS active_max
FROM staff;

-- FILTER per department
SELECT department,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE is_active) AS active,
  COUNT(*) FILTER (WHERE NOT is_active) AS inactive,
  ROUND(AVG(salary) FILTER (WHERE is_active), 2) AS active_avg_salary
FROM staff
GROUP BY department
ORDER BY department;

-- === ROLLUP vs CUBE — Number of Groupings ===

-- ROLLUP(A,B)     → 3 groupings: (A,B), (A), ()
-- CUBE(A,B)       → 4 groupings: (A,B), (A), (B), ()
-- ROLLUP(A,B,C)   → 4 groupings: (A,B,C), (A,B), (A), ()
-- CUBE(A,B,C)     → 8 groupings: all 2^3 combinations
-- CUBE(A,B,C,D)   → 16 groupings: all 2^4 combinations
-- WARNING: CUBE on many columns creates exponential groupings!

-- === COMMON ERRORS ===

-- Error 1: Confusing subtotal NULLs with data NULLs
-- Fix: use GROUPING(col) to distinguish them

-- Error 2: CUBE on too many columns
-- CUBE(a,b,c,d,e) = 32 groupings → huge result!
-- Fix: use GROUPING SETS to pick only what you need

-- Error 3: FILTER without parentheses around WHERE
-- SUM(revenue) FILTER WHERE is_online  -- ERROR!
-- SUM(revenue) FILTER (WHERE is_online)  -- correct!

-- === PRACTICE EXERCISES ===

-- Exercise 1: GROUPING SETS — by department, by quarter, grand total
SELECT department, quarter, SUM(revenue) AS total
FROM sales
GROUP BY GROUPING SETS ((department), (quarter), ())
ORDER BY department NULLS LAST, quarter NULLS LAST;

-- Exercise 2: ROLLUP(department, region)
SELECT department, region, SUM(revenue) AS total
FROM sales
GROUP BY ROLLUP (department, region)
ORDER BY department NULLS LAST, region NULLS LAST;

-- Exercise 3: CUBE(department, region)
SELECT department, region, SUM(revenue) AS total
FROM sales
GROUP BY CUBE (department, region)
ORDER BY department NULLS LAST, region NULLS LAST;

-- Exercise 4: GROUPING() labels
SELECT
  CASE WHEN GROUPING(department) = 1 THEN 'ALL' ELSE department END AS dept,
  CASE WHEN GROUPING(region) = 1 THEN 'ALL' ELSE region END AS region,
  SUM(revenue) AS total
FROM sales
GROUP BY CUBE (department, region)
ORDER BY GROUPING(department), department, GROUPING(region), region;

-- Exercise 5: FILTER — online vs offline per department
SELECT department,
  SUM(revenue) FILTER (WHERE is_online) AS online,
  SUM(revenue) FILTER (WHERE NOT is_online) AS offline
FROM sales GROUP BY department;

-- Exercise 6: FILTER — active vs inactive per department
SELECT department,
  COUNT(*) FILTER (WHERE is_active) AS active,
  COUNT(*) FILTER (WHERE NOT is_active) AS inactive
FROM staff GROUP BY department;

-- Exercise 7: Three-level ROLLUP
SELECT department, region, quarter, SUM(revenue) AS total
FROM sales
GROUP BY ROLLUP (department, region, quarter)
ORDER BY department NULLS LAST, region NULLS LAST, quarter NULLS LAST;

-- === CLEANUP ===
-- DROP TABLE IF EXISTS staff, sales;

-- =============================================
-- Phase 7: Aggregation & Grouping — COMPLETE!
-- Next Phase: Phase 8 — Subqueries & CTEs
-- Next Class: Subqueries (WHERE, FROM, SELECT, EXISTS)
-- =============================================
