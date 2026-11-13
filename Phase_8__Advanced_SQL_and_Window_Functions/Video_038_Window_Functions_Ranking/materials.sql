-- =============================================
-- PostgreSQL Mastery: Window Functions Part 1
-- Phase 10: Advanced SQL | Classes 76-77
-- =============================================
-- ROW_NUMBER, RANK, DENSE_RANK, NTILE,
-- PARTITION BY, ORDER BY, top-N per group.
-- =============================================

-- === SETUP ===

CREATE TABLE IF NOT EXISTS employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    manager_id INT REFERENCES employees(id)
);

-- Only insert if empty
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

-- === BASIC WINDOW FUNCTION ===

-- AVG salary alongside each row (no GROUP BY collapse)
SELECT name, department, salary,
  ROUND(AVG(salary) OVER(), 2) AS overall_avg,
  salary - ROUND(AVG(salary) OVER(), 2) AS diff_from_avg
FROM employees
ORDER BY salary DESC;

-- AVG within each department
SELECT name, department, salary,
  ROUND(AVG(salary) OVER(PARTITION BY department), 2) AS dept_avg,
  salary - ROUND(AVG(salary) OVER(PARTITION BY department), 2) AS diff
FROM employees
ORDER BY department, salary DESC;

-- === ROW_NUMBER ===

-- Unique sequential number per row
SELECT name, department, salary,
  ROW_NUMBER() OVER(ORDER BY salary DESC) AS overall_rank
FROM employees;

-- ROW_NUMBER within each department
SELECT name, department, salary,
  ROW_NUMBER() OVER(
    PARTITION BY department ORDER BY salary DESC
  ) AS dept_rank
FROM employees;

-- === RANK vs DENSE_RANK ===

-- First, let's add some duplicate salaries to see the difference
-- (Using a separate demo table)
CREATE TABLE salary_demo (
    name    VARCHAR(50),
    dept    VARCHAR(50),
    salary  NUMERIC(10,2)
);

INSERT INTO salary_demo VALUES
('Alice', 'Sales', 90000),
('Bob',   'Sales', 85000),
('Carol', 'Sales', 85000),  -- tie with Bob
('Dave',  'Sales', 80000),
('Eve',   'Sales', 75000);

-- Compare all three ranking functions with ties
SELECT name, salary,
  ROW_NUMBER() OVER(ORDER BY salary DESC) AS row_num,
  RANK()       OVER(ORDER BY salary DESC) AS rank,
  DENSE_RANK() OVER(ORDER BY salary DESC) AS dense_rank
FROM salary_demo;

-- Result:
--  name  | salary | row_num | rank | dense_rank
-- -------+--------+---------+------+-----------
--  Alice | 90000  |       1 |    1 |          1
--  Bob   | 85000  |       2 |    2 |          2
--  Carol | 85000  |       3 |    2 |          2  ← tie
--  Dave  | 80000  |       4 |    4 |          3  ← RANK skips, DENSE doesn't
--  Eve   | 75000  |       5 |    5 |          4

-- ROW_NUMBER: always unique (1,2,3,4,5)
-- RANK: ties same, then skip (1,2,2,4,5)
-- DENSE_RANK: ties same, no skip (1,2,2,3,4)

-- === NTILE — Divide into Buckets ===

-- Quartiles (4 buckets)
SELECT name, salary,
  NTILE(4) OVER(ORDER BY salary DESC) AS quartile
FROM employees;

-- Terciles (3 buckets)
SELECT name, salary,
  NTILE(3) OVER(ORDER BY salary DESC) AS tercile
FROM employees;

-- Percentiles (100 buckets — need lots of rows)
-- NTILE(100) OVER(ORDER BY salary) AS percentile

-- Uneven distribution: earlier groups get extra rows
-- 9 rows / 4 buckets = groups of 3,2,2,2

-- === PARTITION BY ===

-- Rank within each department separately
SELECT name, department, salary,
  ROW_NUMBER() OVER(PARTITION BY department ORDER BY salary DESC) AS dept_rank,
  RANK() OVER(PARTITION BY department ORDER BY salary DESC) AS dept_rank_ties
FROM employees
ORDER BY department, dept_rank;

-- Multiple partitions in one query
SELECT name, department, salary,
  ROW_NUMBER() OVER(PARTITION BY department ORDER BY salary DESC) AS dept_rank,
  ROW_NUMBER() OVER(ORDER BY salary DESC) AS overall_rank
FROM employees
ORDER BY overall_rank;

-- === TOP N PER GROUP ===

-- Top 2 highest-paid employees per department
-- Must use subquery — can't filter window functions in WHERE
SELECT * FROM (
  SELECT name, department, salary,
    ROW_NUMBER() OVER(
      PARTITION BY department ORDER BY salary DESC
    ) AS rn
  FROM employees
) ranked
WHERE rn <= 2
ORDER BY department, rn;

-- Same with CTE
WITH ranked AS (
  SELECT name, department, salary,
    ROW_NUMBER() OVER(
      PARTITION BY department ORDER BY salary DESC
    ) AS rn
  FROM employees
)
SELECT name, department, salary
FROM ranked
WHERE rn <= 2
ORDER BY department, rn;

-- Top 1 per department (highest earner)
WITH ranked AS (
  SELECT name, department, salary,
    ROW_NUMBER() OVER(
      PARTITION BY department ORDER BY salary DESC
    ) AS rn
  FROM employees
)
SELECT name, department, salary
FROM ranked WHERE rn = 1;

-- === BOTTOM N PER GROUP ===

-- Lowest-paid per department (flip ORDER BY)
WITH ranked AS (
  SELECT name, department, salary,
    ROW_NUMBER() OVER(
      PARTITION BY department ORDER BY salary ASC
    ) AS rn
  FROM employees
)
SELECT name, department, salary
FROM ranked WHERE rn = 1;

-- === NAMED WINDOWS ===

-- Avoid repeating OVER clause with WINDOW keyword
SELECT name, department, salary,
  ROW_NUMBER() OVER w AS row_num,
  RANK()       OVER w AS rank,
  DENSE_RANK() OVER w AS dense_rank
FROM employees
WINDOW w AS (PARTITION BY department ORDER BY salary DESC)
ORDER BY department, row_num;

-- === WINDOW FUNCTIONS IN EXPLAIN ===

EXPLAIN SELECT name, salary,
  ROW_NUMBER() OVER(ORDER BY salary DESC) AS rn
FROM employees;
-- Shows: WindowAgg node in the plan

-- === COMMON ERRORS ===

-- ERROR: window functions not allowed in WHERE
-- SELECT * FROM employees WHERE ROW_NUMBER() OVER(...) <= 2;
-- Fix: use subquery or CTE

-- ERROR: window functions not allowed in GROUP BY
-- Fix: window functions operate AFTER GROUP BY

-- ERROR: missing ORDER BY in OVER for ranking
-- ROW_NUMBER() OVER() — technically works but meaningless order

-- === PRACTICE EXERCISES ===

-- Exercise 1: Rank all employees by salary
SELECT name, salary,
  ROW_NUMBER() OVER(ORDER BY salary DESC) AS rank
FROM employees;

-- Exercise 2: Rank within department
SELECT name, department, salary,
  ROW_NUMBER() OVER(PARTITION BY department ORDER BY salary DESC) AS dept_rank
FROM employees;

-- Exercise 3: Compare ROW_NUMBER, RANK, DENSE_RANK with ties
SELECT name, salary,
  ROW_NUMBER() OVER(ORDER BY salary DESC) AS rn,
  RANK()       OVER(ORDER BY salary DESC) AS rnk,
  DENSE_RANK() OVER(ORDER BY salary DESC) AS drnk
FROM salary_demo;

-- Exercise 4: NTILE quartiles
SELECT name, salary,
  NTILE(4) OVER(ORDER BY salary) AS quartile
FROM employees;

-- Exercise 5: Top 2 per department
SELECT * FROM (
  SELECT name, department, salary,
    ROW_NUMBER() OVER(PARTITION BY department ORDER BY salary DESC) AS rn
  FROM employees
) r WHERE rn <= 2;

-- Exercise 6: Named window
SELECT name, salary,
  ROW_NUMBER() OVER w, RANK() OVER w, DENSE_RANK() OVER w
FROM employees
WINDOW w AS (ORDER BY salary DESC);

-- Exercise 7: EXPLAIN a window function query
EXPLAIN SELECT name, salary,
  ROW_NUMBER() OVER(ORDER BY salary DESC) AS rn
FROM employees;

-- === CLEANUP ===
DROP TABLE IF EXISTS salary_demo;
-- DROP TABLE IF EXISTS employees;

-- =============================================
-- Next Class: Window Functions Part 2
-- LAG, LEAD, Running Totals, Frame Clauses
-- =============================================


-- =============================================
-- VERIFIED ANSWER KEY — WINDOW FUNCTIONS RANKING
-- =============================================

-- 1. Global Ranking with ROW_NUMBER()
SELECT name, department, salary,
  ROW_NUMBER() OVER(ORDER BY salary DESC) AS rank
FROM employees;

-- 2. Partition by Department
SELECT name, department, salary,
  ROW_NUMBER() OVER(PARTITION BY department ORDER BY salary DESC) AS dept_rank
FROM employees;

-- 3. Compare ROW_NUMBER, RANK, DENSE_RANK with Ties
SELECT name, salary,
  ROW_NUMBER() OVER(ORDER BY salary DESC) AS rn,
  RANK()       OVER(ORDER BY salary DESC) AS rnk,
  DENSE_RANK() OVER(ORDER BY salary DESC) AS drnk
FROM salary_demo;

-- 4. Compensation Quartiles with NTILE(4)
SELECT name, salary,
  NTILE(4) OVER(ORDER BY salary ASC) AS quartile
FROM employees;

-- 5. Top 2 Highest Earners per Department (CTE Pattern)
WITH ranked AS (
  SELECT name, department, salary,
    ROW_NUMBER() OVER(PARTITION BY department ORDER BY salary DESC) AS rn
  FROM employees
)
SELECT department, name, salary, rn
FROM ranked
WHERE rn <= 2
ORDER BY department, rn;
