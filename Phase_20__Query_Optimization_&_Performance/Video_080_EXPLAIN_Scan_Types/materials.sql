-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- EXPLAIN, EXPLAIN ANALYZE & Scan Types (Classes 164-165)
-- Phase 20: Query Optimization & Performance
-- ============================================================

-- ============================================================
-- 1. EXPLAIN BASICS
-- ============================================================

-- Basic EXPLAIN (plan only):
EXPLAIN SELECT * FROM orders WHERE status = 'shipped';

-- EXPLAIN ANALYZE (executes the query):
EXPLAIN ANALYZE SELECT * FROM orders WHERE status = 'shipped';

-- With buffer statistics:
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE status = 'shipped';

-- JSON output (for visualization tools):
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) SELECT * FROM orders;

-- Hide costs:
EXPLAIN (COSTS OFF) SELECT * FROM orders WHERE status = 'shipped';

-- Safe EXPLAIN ANALYZE for writes:
BEGIN;
EXPLAIN ANALYZE DELETE FROM orders WHERE id < 10;
ROLLBACK;

-- ============================================================
-- 2. SCAN TYPES
-- ============================================================

-- Sequential Scan (large result set):
EXPLAIN ANALYZE SELECT * FROM orders WHERE amount > 50;

-- Index Scan (highly selective):
CREATE INDEX idx_orders_date ON orders(order_date);
EXPLAIN ANALYZE SELECT * FROM orders WHERE order_date = '2026-01-15';

-- Bitmap Index Scan (middle ground):
CREATE INDEX idx_orders_status ON orders(status);
EXPLAIN ANALYZE SELECT * FROM orders WHERE status = 'shipped';

-- ============================================================
-- 3. COMBINING INDEXES (BitmapAnd / BitmapOr)
-- ============================================================

-- BitmapAnd (AND condition with two indexes):
EXPLAIN ANALYZE SELECT * FROM orders
WHERE status = 'shipped' AND order_date > '2026-06-01';

-- BitmapOr (OR condition with two indexes):
EXPLAIN ANALYZE SELECT * FROM orders
WHERE status = 'shipped' OR order_date = '2026-01-15';

-- ============================================================
-- 4. MULTI-NODE PLANS
-- ============================================================

-- Scan → Aggregate → Sort:
EXPLAIN ANALYZE
SELECT status, COUNT(*), AVG(amount)
FROM orders
GROUP BY status
ORDER BY count DESC;

-- ============================================================
-- 5. SPOTTING BAD ESTIMATES
-- ============================================================

-- Before ANALYZE:
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;
-- Check: estimated rows vs actual rows

-- Fix stale statistics:
ANALYZE orders;

-- After ANALYZE — better estimates:
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;

-- ============================================================
-- 6. COST PARAMETERS
-- ============================================================

SHOW seq_page_cost;        -- 1.0 (base unit)
SHOW random_page_cost;     -- 4.0 (random I/O is 4x sequential)
SHOW cpu_tuple_cost;       -- 0.01
SHOW cpu_index_tuple_cost; -- 0.005
SHOW cpu_operator_cost;    -- 0.0025

-- For SSD storage, lower random_page_cost:
-- SET random_page_cost = 1.1;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Run EXPLAIN on a simple SELECT. Identify scan type and cost.
-- 2. Run EXPLAIN ANALYZE. Compare estimated vs actual rows.
-- 3. Add BUFFERS. Check shared hit vs shared read.
-- 4. Create an index. Compare EXPLAIN before and after.
-- 5. Find a query where PostgreSQL uses Seq Scan despite an index existing.
--    Explain why. (Hint: check selectivity)
