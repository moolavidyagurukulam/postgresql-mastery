-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Optimization Techniques & pg_stat_statements (Classes 168-169)
-- Phase 20: Query Optimization & Performance
-- ============================================================

-- ============================================================
-- 1. ENABLE pg_stat_statements
-- ============================================================

-- Step 1: Add to postgresql.conf:
-- shared_preload_libraries = 'pg_stat_statements'
-- pg_stat_statements.max = 5000
-- pg_stat_statements.track = top
-- compute_query_id = on

-- Step 2: Restart PostgreSQL

-- Step 3: Create the extension:
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Step 4: Reset statistics (start fresh):
SELECT pg_stat_statements_reset();

-- ============================================================
-- 2. FINDING SLOW QUERIES
-- ============================================================

-- Top 10 by total execution time:
SELECT
  queryid,
  calls,
  ROUND(total_exec_time::numeric, 2) AS total_ms,
  ROUND(mean_exec_time::numeric, 2)  AS avg_ms,
  ROUND(min_exec_time::numeric, 2)   AS min_ms,
  ROUND(max_exec_time::numeric, 2)   AS max_ms,
  rows,
  LEFT(query, 60) AS query_preview
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Top 10 by number of calls:
SELECT queryid, calls, LEFT(query, 60) AS query_preview
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 10;

-- Top 10 by I/O (shared blocks read):
SELECT queryid, calls,
  shared_blks_read,
  shared_blks_hit,
  ROUND(100.0 * shared_blks_hit /
    NULLIF(shared_blks_hit + shared_blks_read, 0), 1) AS cache_hit_pct,
  LEFT(query, 60) AS query_preview
FROM pg_stat_statements
ORDER BY shared_blks_read DESC
LIMIT 10;

-- ============================================================
-- 3. ADDING THE RIGHT INDEX
-- ============================================================

-- Before index:
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 42;

-- Create index:
CREATE INDEX idx_orders_customer_id ON orders(customer_id);

-- After index:
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 42;

-- ============================================================
-- 4. COVERING INDEX (INCLUDE)
-- ============================================================

-- Create covering index:
CREATE INDEX idx_orders_cust_cover
  ON orders(customer_id) INCLUDE (amount);

-- Index Only Scan — zero heap fetches:
EXPLAIN ANALYZE
SELECT customer_id, amount
FROM orders WHERE customer_id = 42;

-- ============================================================
-- 5. EXPRESSION INDEX
-- ============================================================

-- Without expression index:
EXPLAIN ANALYZE
SELECT * FROM customers WHERE UPPER(name) = 'CUSTOMER_42';

-- Create expression index:
CREATE INDEX idx_customers_upper_name
  ON customers (UPPER(name));

-- Now uses the index:
EXPLAIN ANALYZE
SELECT * FROM customers WHERE UPPER(name) = 'CUSTOMER_42';

-- ============================================================
-- 6. PARTIAL INDEX
-- ============================================================

-- Full index (all rows):
CREATE INDEX idx_orders_status ON orders(status);

-- Partial index (only pending):
CREATE INDEX idx_orders_pending
  ON orders(status)
  WHERE status = 'pending';

-- Compare sizes:
SELECT indexname,
       pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_indexes
WHERE tablename = 'orders'
  AND indexname IN ('idx_orders_status', 'idx_orders_pending');

-- ============================================================
-- 7. KEYSET PAGINATION vs OFFSET
-- ============================================================

-- OFFSET approach (slow on later pages):
EXPLAIN ANALYZE
SELECT * FROM orders
ORDER BY id
OFFSET 49950 LIMIT 50;

-- Keyset approach (constant speed):
EXPLAIN ANALYZE
SELECT * FROM orders
WHERE id > 49950
ORDER BY id
LIMIT 50;

-- ============================================================
-- 8. EXISTS vs IN
-- ============================================================

-- IN subquery:
EXPLAIN ANALYZE
SELECT * FROM customers c
WHERE c.id IN (
  SELECT customer_id FROM orders WHERE amount > 400
);

-- EXISTS subquery:
EXPLAIN ANALYZE
SELECT * FROM customers c
WHERE EXISTS (
  SELECT 1 FROM orders o
  WHERE o.customer_id = c.id
    AND o.amount > 400
);

-- ============================================================
-- 9. work_mem TUNING
-- ============================================================

-- Check current:
SHOW work_mem;

-- Force disk spill with low work_mem:
SET work_mem = '64kB';
EXPLAIN ANALYZE
SELECT customer_id, SUM(amount) AS total
FROM orders GROUP BY customer_id ORDER BY total DESC;
-- Look for: Sort Method: external merge Disk

-- Fix with higher work_mem:
SET work_mem = '128MB';
EXPLAIN ANALYZE
SELECT customer_id, SUM(amount) AS total
FROM orders GROUP BY customer_id ORDER BY total DESC;
-- Should show: Sort Method: quicksort Memory

RESET work_mem;

-- ============================================================
-- 10. FINDING UNUSED INDEXES
-- ============================================================

SELECT s.indexrelname AS index_name,
       s.idx_scan AS times_used,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size,
       s.relname AS table_name
FROM pg_stat_user_indexes s
WHERE s.idx_scan = 0
  AND pg_relation_size(s.indexrelid) > 1024 * 1024
ORDER BY pg_relation_size(s.indexrelid) DESC;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Enable pg_stat_statements and run several queries.
--    Find the top 5 by total execution time.
-- 2. Pick a query with a Seq Scan. Add an index.
--    Compare EXPLAIN ANALYZE before and after.
-- 3. Create a covering index with INCLUDE. Verify
--    Heap Fetches = 0 in the plan.
-- 4. Create a partial index for a common WHERE condition.
--    Compare its size to a full index on the same column.
-- 5. Test OFFSET pagination at page 1000 vs keyset
--    pagination. Compare execution times.
