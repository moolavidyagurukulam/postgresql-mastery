-- =============================================
-- PostgreSQL Mastery: Materialized Views
-- Phase 11: Views | Classes 88-89
-- =============================================
-- Materialized views, REFRESH, REFRESH CONCURRENTLY,
-- indexes on matviews, WITH NO DATA, pg_matviews.
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
  ('2024-01-01'::DATE, 'Widget',  10000::NUMERIC),
  ('2024-02-01', 'Widget',  12000),
  ('2024-03-01', 'Widget',  11500),
  ('2024-04-01', 'Widget',  14000),
  ('2024-05-01', 'Widget',  13000),
  ('2024-06-01', 'Widget',  15500),
  ('2024-01-01', 'Gadget',   8000),
  ('2024-02-01', 'Gadget',   9500),
  ('2024-03-01', 'Gadget',   7800),
  ('2024-04-01', 'Gadget',  10200),
  ('2024-05-01', 'Gadget',  11000),
  ('2024-06-01', 'Gadget',  12500)
) AS t(month, product, revenue)
WHERE NOT EXISTS (SELECT 1 FROM monthly_sales);

-- === CREATE MATERIALIZED VIEW ===

-- A materialized view stores the query result on disk
-- Unlike a regular view, it does NOT re-run the query each time
CREATE MATERIALIZED VIEW mv_sales_summary AS
SELECT
  product,
  DATE_TRUNC('month', month) AS sale_month,
  SUM(revenue) AS total_revenue,
  COUNT(*) AS record_count
FROM monthly_sales
GROUP BY product, DATE_TRUNC('month', month)
ORDER BY product, sale_month;

-- Query it — reads stored data, no re-computation
SELECT * FROM mv_sales_summary;

-- Filter just like a table
SELECT * FROM mv_sales_summary WHERE product = 'Widget';

-- === INDEXES ON MATERIALIZED VIEWS ===

-- Regular index for fast lookups
CREATE INDEX idx_mv_sales_product
ON mv_sales_summary (product);

-- Composite index
CREATE INDEX idx_mv_sales_prod_month
ON mv_sales_summary (product, sale_month);

-- UNIQUE index — required for REFRESH CONCURRENTLY!
CREATE UNIQUE INDEX idx_mv_sales_unique
ON mv_sales_summary (product, sale_month);

-- Verify indexes
-- \di+ mv_sales*

-- === REFRESH MATERIALIZED VIEW ===

-- Normal refresh: re-runs query, replaces all data
-- WARNING: locks the matview — no reads during refresh!
REFRESH MATERIALIZED VIEW mv_sales_summary;

-- Concurrent refresh: builds new data alongside old
-- Readers can still query old data during refresh
-- REQUIRES a unique index on the matview!
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_sales_summary;

-- === ERROR: CONCURRENTLY without unique index ===

-- Create a matview WITHOUT a unique index
CREATE MATERIALIZED VIEW mv_no_unique AS
SELECT department, COUNT(*) AS cnt FROM employees
GROUP BY department;

-- This will fail:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_no_unique;
-- ERROR:  cannot refresh materialized view "public"."mv_no_unique" concurrently
-- HINT:  Create a unique index with no WHERE clause on one or more columns
--        of the materialized view.

-- Fix: add a unique index
CREATE UNIQUE INDEX idx_mv_no_unique_dept ON mv_no_unique (department);

-- Now concurrent refresh works
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_no_unique;

-- === pg_matviews — Matview Metadata ===

-- List all materialized views
SELECT schemaname, matviewname, matviewowner, ispopulated
FROM pg_matviews
WHERE schemaname = 'public';

-- ispopulated = t means data is loaded
-- ispopulated = f means WITH NO DATA (not yet refreshed)

-- === CREATE WITH NO DATA ===

-- Define the matview but do NOT run the query
CREATE MATERIALIZED VIEW mv_dept_summary AS
SELECT department, COUNT(*) AS emp_count,
       ROUND(AVG(salary), 2) AS avg_salary
FROM employees
GROUP BY department
WITH NO DATA;

-- Query fails: not populated yet
-- SELECT * FROM mv_dept_summary;
-- ERROR:  materialized view "mv_dept_summary" has not been populated
-- HINT:  Use the REFRESH MATERIALIZED VIEW command.

-- Check ispopulated
SELECT matviewname, ispopulated FROM pg_matviews WHERE schemaname = 'public';
-- mv_dept_summary | f

-- Populate it
REFRESH MATERIALIZED VIEW mv_dept_summary;

-- Now it works
SELECT * FROM mv_dept_summary ORDER BY avg_salary DESC;

-- === WHEN TO USE MATERIALIZED VIEWS ===

-- GOOD: expensive aggregation queried often, stale data OK
-- Example: daily sales dashboard
CREATE MATERIALIZED VIEW mv_daily_dashboard AS
SELECT
  product,
  SUM(revenue) AS total_revenue,
  ROUND(AVG(revenue), 2) AS avg_monthly_revenue,
  COUNT(*) AS months_with_data
FROM monthly_sales
GROUP BY product;

SELECT * FROM mv_daily_dashboard;

-- Schedule refresh with pg_cron (if installed):
-- SELECT cron.schedule('refresh_dashboard', '0 */6 * * *',
--   'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_dashboard');
-- Refreshes every 6 hours

-- Or use crontab on the server:
-- 0 */6 * * * psql -d mydb -c "REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_dashboard;"

-- BAD: real-time data needed
-- Use a regular view or direct query instead

-- === DROP MATERIALIZED VIEW ===

DROP MATERIALIZED VIEW IF EXISTS mv_no_unique;
DROP MATERIALIZED VIEW IF EXISTS mv_dept_summary;
DROP MATERIALIZED VIEW IF EXISTS mv_daily_dashboard;

-- === PRACTICE EXERCISES ===

-- Exercise 1: Create a matview with GROUP BY
CREATE MATERIALIZED VIEW mv_dept_stats AS
SELECT department, COUNT(*) AS cnt, MAX(salary) AS max_sal
FROM employees GROUP BY department;

SELECT * FROM mv_dept_stats;

-- Exercise 2: Add a unique index
CREATE UNIQUE INDEX idx_mv_dept_stats ON mv_dept_stats (department);

-- Exercise 3: Refresh normally
REFRESH MATERIALIZED VIEW mv_dept_stats;

-- Exercise 4: Refresh concurrently (needs unique index)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dept_stats;

-- Exercise 5: Create with NO DATA
CREATE MATERIALIZED VIEW mv_practice AS
SELECT product, SUM(revenue) AS total FROM monthly_sales GROUP BY product
WITH NO DATA;

-- Check: not populated
SELECT matviewname, ispopulated FROM pg_matviews
WHERE matviewname = 'mv_practice';

-- Populate it
REFRESH MATERIALIZED VIEW mv_practice;
SELECT * FROM mv_practice;

-- Exercise 6: Check pg_matviews
SELECT matviewname, ispopulated FROM pg_matviews WHERE schemaname = 'public';

-- Exercise 7: Drop matviews
DROP MATERIALIZED VIEW IF EXISTS mv_dept_stats;
DROP MATERIALIZED VIEW IF EXISTS mv_practice;

-- === CLEANUP ===
DROP MATERIALIZED VIEW IF EXISTS mv_sales_summary;
-- DROP TABLE IF EXISTS monthly_sales, employees;

-- =============================================
-- Phase 11: Views — COMPLETE!
-- Video 042: Views & Updatable Views
-- Video 043: Materialized Views
--
-- Next Phase: Phase 12 — Indexes
-- B-Tree, Hash, GIN, GiST, BRIN, Partial,
-- Expression, Covering, Multi-Column
-- =============================================
