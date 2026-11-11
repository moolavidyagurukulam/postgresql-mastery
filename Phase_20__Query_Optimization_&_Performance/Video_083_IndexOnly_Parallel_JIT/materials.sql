-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Index Only Scans, Parallel Queries & JIT (Classes 170-172)
-- Phase 20: Query Optimization & Performance
-- ============================================================

-- ============================================================
-- 1. INDEX ONLY SCANS
-- ============================================================

-- Create a covering index:
CREATE INDEX idx_orders_cust_amount
  ON orders(customer_id) INCLUDE (amount);

-- Dirty the visibility map:
UPDATE orders SET amount = amount + 0.01 WHERE id < 1000;

-- BEFORE VACUUM — check Heap Fetches:
EXPLAIN ANALYZE
SELECT customer_id, amount FROM orders
WHERE customer_id BETWEEN 1 AND 50;

-- Run VACUUM to update visibility map:
VACUUM orders;

-- AFTER VACUUM — Heap Fetches should drop:
EXPLAIN ANALYZE
SELECT customer_id, amount FROM orders
WHERE customer_id BETWEEN 1 AND 50;

-- ============================================================
-- 2. COVERING INDEX METHODS
-- ============================================================

-- Method 1: Regular multi-column index
CREATE INDEX idx_orders_multi ON orders(customer_id, status);

-- Method 2: INCLUDE (non-key columns)
CREATE INDEX idx_orders_cust_incl
  ON orders(customer_id) INCLUDE (status, amount);

-- Method 3: Covering unique index
-- CREATE UNIQUE INDEX idx_unique_cover
--   ON orders(id) INCLUDE (customer_id, amount);

-- Check which enables Index Only Scan:
EXPLAIN ANALYZE
SELECT customer_id, status, amount
FROM orders WHERE customer_id = 42;

-- ============================================================
-- 3. VISIBILITY MAP MONITORING
-- ============================================================

-- Check visibility map coverage:
SELECT relname,
       n_live_tup,
       n_dead_tup,
       last_vacuum,
       last_autovacuum
FROM pg_stat_user_tables
WHERE relname = 'orders';

-- Heap Fetches across all indexes:
SELECT relname,
       indexrelname,
       idx_scan,
       idx_tup_read,
       idx_tup_fetch
FROM pg_stat_user_indexes
WHERE relname = 'orders'
ORDER BY idx_tup_fetch DESC;

-- ============================================================
-- 4. PARALLEL QUERY BASICS
-- ============================================================

-- Check parallel settings:
SHOW max_worker_processes;
SHOW max_parallel_workers;
SHOW max_parallel_workers_per_gather;
SHOW min_parallel_table_scan_size;

-- Parallel aggregation:
EXPLAIN ANALYZE
SELECT status, COUNT(*), AVG(amount)
FROM orders
GROUP BY status;

-- Look for: Gather, Workers Planned, Workers Launched
-- Look for: Parallel Seq Scan, Partial HashAggregate

-- ============================================================
-- 5. PER-TABLE PARALLEL WORKERS
-- ============================================================

-- Set higher parallelism for a specific table:
ALTER TABLE orders SET (parallel_workers = 4);

EXPLAIN ANALYZE
SELECT status, COUNT(*) FROM orders GROUP BY status;

-- Reset:
ALTER TABLE orders RESET (parallel_workers);

-- ============================================================
-- 6. DISABLING PARALLEL FOR TESTING
-- ============================================================

-- Compare parallel vs sequential:

-- With parallel (default):
EXPLAIN ANALYZE
SELECT COUNT(*) FROM orders WHERE amount > 100;

-- Without parallel:
SET max_parallel_workers_per_gather = 0;
EXPLAIN ANALYZE
SELECT COUNT(*) FROM orders WHERE amount > 100;

-- Re-enable:
RESET max_parallel_workers_per_gather;

-- ============================================================
-- 7. JIT COMPILATION
-- ============================================================

-- Check if JIT is available:
SHOW jit;
SELECT pg_jit_available();

-- Check JIT thresholds:
SHOW jit_above_cost;              -- 100000
SHOW jit_inline_above_cost;       -- 500000
SHOW jit_optimize_above_cost;     -- 500000

-- Force JIT for demonstration (lower threshold):
SET jit_above_cost = 10;

EXPLAIN ANALYZE
SELECT status, COUNT(*), AVG(amount)
FROM orders
WHERE amount > 100
GROUP BY status;

-- Look for the JIT section showing:
-- Functions, Generation, Inlining, Optimization, Emission times

RESET jit_above_cost;

-- ============================================================
-- 8. JIT TROUBLESHOOTING
-- ============================================================

-- If JIT is slowing small queries, raise the threshold:
-- SET jit_above_cost = 500000;

-- Or disable JIT for a specific session:
-- SET jit = off;

-- Check if JIT was used in last query:
-- (Look for JIT section in EXPLAIN ANALYZE output)

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a covering index with INCLUDE.
--    Run EXPLAIN ANALYZE and verify Index Only Scan with Heap Fetches: 0.
-- 2. UPDATE some rows, then check Heap Fetches again.
--    Run VACUUM and check if Heap Fetches drops.
-- 3. Run a GROUP BY query and identify if parallel workers are used.
--    Set max_parallel_workers_per_gather = 0 and compare.
-- 4. Set parallel_workers = 4 on a table. Verify with EXPLAIN ANALYZE.
-- 5. Lower jit_above_cost and run a query.
--    Find the JIT section in the plan output.
