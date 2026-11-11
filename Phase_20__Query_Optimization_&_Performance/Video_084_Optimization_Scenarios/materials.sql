-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Real-World Optimization Scenarios (Class 173)
-- Phase 20: Query Optimization & Performance
-- ============================================================

-- ============================================================
-- SCENARIO 1: SLOW DASHBOARD QUERY
-- ============================================================

-- The slow query:
EXPLAIN ANALYZE
SELECT o.id, o.amount, o.status, o.order_date,
       c.name AS customer_name
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.status = 'pending'
ORDER BY o.order_date DESC
LIMIT 20;

-- Fix: composite index on (status, order_date DESC)
CREATE INDEX idx_orders_status_date
  ON orders(status, order_date DESC);

-- Re-run to verify improvement:
EXPLAIN ANALYZE
SELECT o.id, o.amount, o.status, o.order_date,
       c.name AS customer_name
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.status = 'pending'
ORDER BY o.order_date DESC
LIMIT 20;

-- ============================================================
-- SCENARIO 2: SLOW MONTHLY REPORT
-- ============================================================

-- The slow query:
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.name,
       COUNT(*) AS order_count,
       SUM(o.amount) AS total_amount,
       AVG(o.amount) AS avg_amount
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.order_date >= '2025-07-01'
  AND o.order_date < '2025-08-01'
GROUP BY c.name
ORDER BY total_amount DESC;

-- Fix 1: index on order_date
CREATE INDEX idx_orders_date ON orders(order_date);

-- Fix 2: increase work_mem for this session
SET work_mem = '64MB';

-- Re-run to verify:
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.name,
       COUNT(*) AS order_count,
       SUM(o.amount) AS total_amount,
       AVG(o.amount) AS avg_amount
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.order_date >= '2025-07-01'
  AND o.order_date < '2025-08-01'
GROUP BY c.name
ORDER BY total_amount DESC;

RESET work_mem;

-- ============================================================
-- SCENARIO 3: N+1 QUERY PROBLEM
-- ============================================================

-- Bad: N+1 approach (do NOT do this in production)
-- SELECT * FROM customers;
-- For each customer:
--   SELECT COUNT(*) FROM orders WHERE customer_id = ?;

-- Good: single JOIN query
EXPLAIN ANALYZE
SELECT c.name,
       COUNT(o.id) AS order_count,
       COALESCE(SUM(o.amount), 0) AS total_amount
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.name
ORDER BY total_amount DESC;

-- Better: materialized view for repeated access
CREATE MATERIALIZED VIEW customer_order_summary AS
SELECT c.id AS customer_id,
       c.name,
       COUNT(o.id) AS order_count,
       COALESCE(SUM(o.amount), 0) AS total_amount
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.name;

CREATE INDEX idx_cos_total
  ON customer_order_summary(total_amount DESC);

-- Query the materialized view:
SELECT * FROM customer_order_summary ORDER BY total_amount DESC LIMIT 10;

-- Refresh when data changes:
REFRESH MATERIALIZED VIEW CONCURRENTLY customer_order_summary;

-- ============================================================
-- SCENARIO 4: SLOW TEXT SEARCH
-- ============================================================

-- Problem: LIKE with leading wildcard
EXPLAIN ANALYZE
SELECT * FROM customers WHERE name ILIKE '%customer_42%';

-- Fix: pg_trgm extension + GIN index
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX idx_customers_name_trgm
  ON customers USING gin (name gin_trgm_ops);

-- Re-run:
EXPLAIN ANALYZE
SELECT * FROM customers WHERE name ILIKE '%customer_42%';

-- ============================================================
-- SCENARIO 5: CONNECTION MONITORING
-- ============================================================

-- Check active connections:
SELECT count(*) AS total_connections,
       count(*) FILTER (WHERE state = 'active') AS active,
       count(*) FILTER (WHERE state = 'idle') AS idle,
       count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_txn
FROM pg_stat_activity
WHERE backend_type = 'client backend';

-- Find idle in transaction (blocks autovacuum):
SELECT pid, now() - state_change AS idle_time,
       left(query, 60) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND state_change < now() - '5 min'::interval;

-- ============================================================
-- SCENARIO 6: STALE STATISTICS
-- ============================================================

-- After bulk loading, ANALYZE before querying:
ANALYZE orders;

-- Check when statistics were last updated:
SELECT relname, last_analyze, last_autoanalyze,
       n_live_tup, n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'orders';

-- Compare estimated vs actual rows:
EXPLAIN ANALYZE
SELECT * FROM orders WHERE status = 'pending';
-- If estimated rows ≠ actual rows → run ANALYZE

-- ============================================================
-- OPTIMIZATION WORKFLOW CHECKLIST
-- ============================================================

-- Step 1: Find slow queries
SELECT queryid, calls,
       ROUND(total_exec_time::numeric, 2) AS total_ms,
       ROUND(mean_exec_time::numeric, 2) AS avg_ms,
       LEFT(query, 60)
FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 10;

-- Step 2: Diagnose each one
-- EXPLAIN (ANALYZE, BUFFERS) <the slow query>;

-- Step 3: Check for stale stats (estimated ≠ actual rows)
-- ANALYZE <table>;

-- Step 4: Check for missing indexes (Seq Scan on WHERE columns)
-- CREATE INDEX ...;

-- Step 5: Check for disk spills (external merge / Batches > 1)
-- SET work_mem = '64MB';

-- Step 6: Verify improvement
-- EXPLAIN (ANALYZE, BUFFERS) <the slow query>;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a slow dashboard query (WHERE + ORDER BY + LIMIT).
--    Diagnose with EXPLAIN ANALYZE. Fix with a composite index.
-- 2. Write an N+1 pattern, then rewrite as a single JOIN.
--    Compare total execution time.
-- 3. Create a text search using LIKE '%term%'.
--    Add pg_trgm GIN index. Compare before and after.
-- 4. Bulk-load 100,000 rows. Query without ANALYZE, then with.
--    Note the difference in estimated vs actual rows.
-- 5. Follow the complete optimization workflow on a query
--    you write: Measure → Diagnose → Fix → Verify.
