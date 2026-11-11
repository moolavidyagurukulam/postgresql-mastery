-- =============================================
-- PostgreSQL Mastery: Query Flow & MVCC
-- Phase 9: Architecture | Classes 71-74 Part 1
-- =============================================
-- Query pipeline (Parse → Rewrite → Plan → Execute),
-- MVCC, xmin/xmax, tuple visibility, snapshots.
-- =============================================

-- === SETUP (if not already from previous classes) ===

CREATE TABLE IF NOT EXISTS employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    manager_id INT REFERENCES employees(id)
);

-- Only insert if table is empty
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

-- === STAGE 1: PARSER ===

-- Parser catches SYNTAX errors
-- Try these (they will fail):
-- SELCET * FROM employees;
-- SELECT * FORM employees;
-- SELECT * FROM employees WERE id = 1;

-- Analysis (after parser) catches unknown objects:
-- SELECT * FROM nonexistent_table;
-- SELECT fake_column FROM employees;

-- === STAGE 2: REWRITER ===

-- Create a view to see the rewriter in action
CREATE OR REPLACE VIEW eng_employees AS
SELECT id, name, salary FROM employees
WHERE department = 'Engineering';

-- This query goes through the rewriter:
-- It expands the view definition into the actual query
EXPLAIN SELECT * FROM eng_employees WHERE salary > 90000;
-- The plan shows: Filter on employees table, not the view

-- === STAGE 3: PLANNER / OPTIMIZER ===

-- EXPLAIN shows the execution plan WITHOUT running it
EXPLAIN SELECT * FROM employees WHERE department = 'Engineering';

-- EXPLAIN ANALYZE runs the query and shows actual times
EXPLAIN ANALYZE SELECT * FROM employees WHERE department = 'Engineering';

-- EXPLAIN with all options
EXPLAIN (ANALYZE, BUFFERS, COSTS, TIMING, FORMAT TEXT)
SELECT * FROM employees WHERE department = 'Engineering';

-- Compare plans: sequential scan vs index scan
CREATE INDEX idx_emp_dept ON employees(department);

EXPLAIN SELECT * FROM employees WHERE department = 'Engineering';
-- May switch to Index Scan if planner thinks it's cheaper

-- Force sequential scan to compare
SET enable_indexscan = off;
EXPLAIN SELECT * FROM employees WHERE department = 'Engineering';
SET enable_indexscan = on;

-- Planner statistics: what the planner knows about a table
SELECT relname, reltuples::BIGINT AS est_rows, relpages
FROM pg_class WHERE relname = 'employees';

-- Column statistics
SELECT
  attname,
  n_distinct,
  most_common_vals,
  most_common_freqs
FROM pg_stats
WHERE tablename = 'employees' AND attname = 'department';

-- Update statistics (if estimates seem off)
ANALYZE employees;

-- === STAGE 4: EXECUTOR ===

-- The executor runs the plan node by node
-- Different node types you'll see in EXPLAIN:

-- Seq Scan: reads every page of the table
EXPLAIN SELECT * FROM employees;

-- Index Scan: uses an index to find rows
EXPLAIN SELECT * FROM employees WHERE department = 'Engineering';

-- Nested Loop: for small inner tables
EXPLAIN SELECT e.name, m.name AS manager
FROM employees e JOIN employees m ON e.manager_id = m.id;

-- Hash Join: builds hash table on inner side
-- (need bigger tables to see this)

-- Sort: ORDER BY
EXPLAIN SELECT * FROM employees ORDER BY salary;

-- Aggregate: GROUP BY, COUNT, SUM
EXPLAIN SELECT department, COUNT(*) FROM employees GROUP BY department;

-- === MVCC: xmin and xmax ===

-- Every row has hidden system columns
SELECT xmin, xmax, id, name, salary FROM employees ORDER BY id;
-- xmin = transaction that CREATED this tuple version
-- xmax = transaction that DELETED it (0 = not deleted)

-- Current transaction ID
SELECT txid_current();

-- === MVCC IN ACTION: UPDATE ===

-- Before update: check xmin
SELECT xmin, xmax, id, name, salary FROM employees WHERE id = 1;

-- Update a row
UPDATE employees SET salary = salary + 5000 WHERE id = 1;

-- After update: xmin changed!
SELECT xmin, xmax, id, name, salary FROM employees WHERE id = 1;
-- The old tuple (with old xmin) is now a "dead tuple"
-- A NEW tuple was created with the new xmin

-- === MVCC IN ACTION: DELETE ===

-- Insert a test row
INSERT INTO employees (name, department, salary, manager_id)
VALUES ('Test', 'QA', 50000, 1);

SELECT xmin, xmax, id, name FROM employees WHERE name = 'Test';
-- xmax = 0

DELETE FROM employees WHERE name = 'Test';
-- The tuple now has xmax set (but we can't see it anymore)

-- === DEAD TUPLES AND VACUUM ===

-- Check dead tuples
SELECT relname,
  n_live_tup,
  n_dead_tup,
  last_vacuum,
  last_autovacuum
FROM pg_stat_user_tables
WHERE relname = 'employees';

-- Manual vacuum
VACUUM employees;

-- Check again: dead tuples should decrease
SELECT relname, n_live_tup, n_dead_tup
FROM pg_stat_user_tables WHERE relname = 'employees';

-- VACUUM VERBOSE shows details
VACUUM VERBOSE employees;

-- VACUUM FULL: rewrites entire table (locks it!)
-- Only use when you need to shrink the file on disk
-- VACUUM FULL employees;  -- CAREFUL: exclusive lock!

-- === TRANSACTION SNAPSHOTS ===

-- Your snapshot: what you can and cannot see
SELECT txid_current_snapshot();
-- Format: xmin:xmax:xip_list
-- xmin  = oldest active txid (everything below is committed)
-- xmax  = first unassigned txid
-- xip   = list of in-progress txids between xmin and xmax

-- Demonstrate with two sessions:
-- Session 1:
--   BEGIN;
--   SELECT txid_current();  -- e.g., 100800
--   -- Don't commit yet
--
-- Session 2:
--   SELECT txid_current_snapshot();
--   -- Shows: 100800:100801:100800
--   -- Meaning: txid 100800 is in progress → invisible to session 2

-- === TRANSACTION ISOLATION LEVELS ===

-- PostgreSQL supports 3 levels:
-- READ COMMITTED (default): sees only committed data at query start
-- REPEATABLE READ: sees snapshot from transaction start
-- SERIALIZABLE: strictest — detects serialization anomalies

SHOW transaction_isolation;

-- Change for one transaction:
-- BEGIN ISOLATION LEVEL REPEATABLE READ;
-- ... your queries see a frozen snapshot ...
-- COMMIT;

-- === COMMON MVCC ISSUES ===

-- Issue 1: Table bloat (too many dead tuples)
SELECT relname, n_dead_tup,
  ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 1)
    AS dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 0
ORDER BY n_dead_tup DESC;

-- Issue 2: Long-running transactions block VACUUM
SELECT pid, state,
  age(backend_xmin) AS xmin_age,
  now() - xact_start AS duration,
  LEFT(query, 50) AS query
FROM pg_stat_activity
WHERE backend_xmin IS NOT NULL
ORDER BY age(backend_xmin) DESC;

-- Issue 3: Transaction ID wraparound (emergency!)
SELECT datname,
  age(datfrozenxid) AS txid_age,
  ROUND(age(datfrozenxid) * 100.0 / 2000000000, 1) AS pct_to_wraparound
FROM pg_database
ORDER BY age(datfrozenxid) DESC;
-- If pct_to_wraparound approaches 50%, you need aggressive vacuuming

-- === PRACTICE EXERCISES ===

-- Exercise 1: See the query plan
EXPLAIN SELECT * FROM employees WHERE salary > 90000;

-- Exercise 2: See actual execution
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM employees WHERE department = 'Engineering';

-- Exercise 3: Check xmin and xmax
SELECT xmin, xmax, id, name, salary FROM employees;

-- Exercise 4: Update and watch xmin change
UPDATE employees SET salary = salary + 1000 WHERE id = 2;
SELECT xmin, xmax, id, name, salary FROM employees WHERE id = 2;

-- Exercise 5: Check dead tuples
SELECT relname, n_live_tup, n_dead_tup FROM pg_stat_user_tables;

-- Exercise 6: VACUUM and check again
VACUUM employees;
SELECT relname, n_live_tup, n_dead_tup FROM pg_stat_user_tables
WHERE relname = 'employees';

-- Exercise 7: Transaction snapshot
SELECT txid_current();
SELECT txid_current_snapshot();

-- === CLEANUP ===
DROP INDEX IF EXISTS idx_emp_dept;
DROP VIEW IF EXISTS eng_employees;
-- DROP TABLE IF EXISTS employees;

-- =============================================
-- Next Class: WAL & Checkpoints
-- =============================================
