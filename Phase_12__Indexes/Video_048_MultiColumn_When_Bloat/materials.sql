-- =============================================
-- PostgreSQL Mastery: Multi-Column, When to Index & Bloat
-- Phase 12: Indexes | Classes 100-102
-- =============================================
-- Multi-column indexes, leftmost prefix rule,
-- indexing strategy, unused indexes, REINDEX.
-- =============================================

-- === SETUP ===

CREATE TABLE IF NOT EXISTS orders (
    id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT,
    order_date  DATE,
    amount      NUMERIC(10,2),
    status      VARCHAR(20)
);

INSERT INTO orders (customer_id, order_date, amount, status)
SELECT
  (RANDOM() * 1000 + 1)::INT,
  '2023-01-01'::DATE + (RANDOM() * 730)::INT,
  ROUND((RANDOM() * 990 + 10)::NUMERIC, 2),
  (ARRAY['pending','shipped','delivered','cancelled'])[
    FLOOR(RANDOM() * 4 + 1)::INT
  ]
FROM generate_series(1, 100000)
WHERE NOT EXISTS (SELECT 1 FROM orders);

ANALYZE orders;

-- === MULTI-COLUMN INDEX ===

-- Composite index on two columns
CREATE INDEX idx_orders_cust_status ON orders (customer_id, status);

-- ✓ Leftmost column present → uses index
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;

-- ✓ Both columns present → uses index efficiently
EXPLAIN SELECT * FROM orders
WHERE customer_id = 42 AND status = 'pending';

-- ✗ Only second column → CANNOT use this index
EXPLAIN SELECT * FROM orders WHERE status = 'pending';
-- Seq Scan! Leftmost column (customer_id) is missing

-- Three-column index
CREATE INDEX idx_orders_triple ON orders (customer_id, status, order_date);

-- ✓ Uses index: customer_id (first)
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;

-- ✓ Uses index: customer_id + status (first two)
EXPLAIN SELECT * FROM orders
WHERE customer_id = 42 AND status = 'pending';

-- ✓ Uses index: all three columns
EXPLAIN SELECT * FROM orders
WHERE customer_id = 42 AND status = 'pending'
AND order_date > '2024-01-01';

-- ✗ Cannot use: skips first column
EXPLAIN SELECT * FROM orders
WHERE status = 'pending' AND order_date > '2024-01-01';

-- === COLUMN ORDER MATTERS ===

-- Index (customer_id, status): sorted by customer first
-- Good for: WHERE customer_id = X
-- Good for: WHERE customer_id = X AND status = Y

-- Index (status, customer_id): sorted by status first
-- Good for: WHERE status = X
-- Good for: WHERE status = X AND customer_id = Y

-- Choose based on your most common queries!

-- Equality before range:
-- Good: (status, order_date) → WHERE status = 'pending' AND order_date > X
-- Bad:  (order_date, status) → order_date range can't narrow to status

-- Most selective first:
-- customer_id has 1000 distinct values → very selective
-- status has 4 distinct values → not selective
-- Put customer_id first if queried alone

-- === WHEN TO INDEX ===

-- 1. Primary keys: automatic (don't create manually)
-- 2. Unique constraints: automatic
-- 3. Foreign keys: ALWAYS create an index!

-- Example: FK without index (common mistake!)
CREATE TABLE order_items (
    id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    product  VARCHAR(100),
    qty      INT
);

-- Without an index on order_id:
-- - JOINs between orders and order_items → Seq Scan
-- - DELETE FROM orders WHERE id = X → Seq Scan on order_items
-- - CASCADE DELETE → extremely slow on large tables

-- Fix: always index FK columns
CREATE INDEX idx_orderitems_order ON order_items (order_id);

-- 4. Frequent WHERE columns
-- Check your application's most common queries
-- Index columns used in WHERE with high selectivity

-- 5. JOIN columns
-- Index both sides of frequent JOINs

-- === FINDING UNUSED INDEXES ===

-- Indexes that have never been scanned
SELECT
  schemaname,
  relname AS table_name,
  indexrelname AS index_name,
  idx_scan AS times_used,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE '%_pkey'  -- skip primary keys
ORDER BY pg_relation_size(indexrelid) DESC;

-- Check when statistics were last reset
SELECT stats_reset FROM pg_stat_bgwriter;

-- If stats have been accumulating for weeks/months
-- and idx_scan = 0, the index is likely unused

-- === FINDING DUPLICATE INDEXES ===

-- Exact duplicates (same definition)
SELECT indexdef, COUNT(*)
FROM pg_indexes
WHERE schemaname = 'public'
GROUP BY indexdef
HAVING COUNT(*) > 1;

-- Indexes that are prefixes of other indexes
-- (A) is redundant if (A, B) exists
-- But (B) is NOT redundant even if (A, B) exists

-- === INDEX BLOAT ===

-- WHY: UPDATE/DELETE leaves dead entries in the index
-- VACUUM cleans table tuples but index cleanup can lag
-- Result: index grows larger than necessary

-- Simulate bloat: heavy updates
UPDATE orders SET amount = amount + 1 WHERE customer_id < 100;
UPDATE orders SET amount = amount - 1 WHERE customer_id < 100;

-- Check index size (may have grown)
SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes
WHERE relname = 'orders'
ORDER BY pg_relation_size(indexrelid) DESC;

-- === REINDEX ===

-- Rebuild a single index
REINDEX INDEX idx_orders_cust_status;

-- Rebuild all indexes on a table
REINDEX TABLE orders;

-- Rebuild all indexes in the database (maintenance window!)
-- REINDEX DATABASE practice;

-- Production: CONCURRENTLY (no lock, PostgreSQL 12+)
REINDEX INDEX CONCURRENTLY idx_orders_cust_status;

-- REINDEX TABLE CONCURRENTLY: rebuilds all indexes on table
REINDEX TABLE CONCURRENTLY orders;

-- Note: CONCURRENTLY takes longer but doesn't block reads/writes
-- Cannot run inside a transaction block

-- === INDEX MAINTENANCE CHECKLIST ===

-- Weekly/Monthly:
-- 1. Check for unused indexes (idx_scan = 0)
-- 2. Check for duplicate indexes
-- 3. Check index sizes vs table size
-- 4. REINDEX bloated indexes (>50% bloat)

-- After bulk operations:
-- 1. ANALYZE (update statistics)
-- 2. VACUUM (clean dead tuples)
-- 3. REINDEX if heavy UPDATE/DELETE occurred

-- === COMPLETE INDEX TYPE REFERENCE ===

-- B-Tree (default): =, <, >, <=, >=, BETWEEN, IN, ORDER BY
-- Hash:             = only
-- GIN:              @> (contains), ? (exists), @@ (text match)
-- GiST:             && (overlap), @> (contains), <-> (distance)
-- BRIN:             =, <, > on physically sorted data
-- SP-GiST:          << (network containment), prefix match

-- Advanced techniques:
-- Partial:    CREATE INDEX ... WHERE condition;
-- Expression: CREATE INDEX ... (LOWER(col));
-- Covering:   CREATE INDEX ... (key) INCLUDE (extra);
-- Multi-col:  CREATE INDEX ... (a, b, c); → leftmost prefix rule

-- === PRACTICE EXERCISES ===

-- Exercise 1: Multi-column index
CREATE INDEX idx_practice_multi ON orders (status, order_date);
EXPLAIN SELECT * FROM orders WHERE status = 'pending';
EXPLAIN SELECT * FROM orders WHERE order_date > '2024-01-01';
-- Which query uses the index? Why?

-- Exercise 2: Find unused indexes
SELECT indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE relname = 'orders' AND idx_scan = 0;

-- Exercise 3: Check total index overhead
SELECT
  pg_size_pretty(pg_table_size('orders')) AS table_size,
  pg_size_pretty(pg_indexes_size('orders')) AS indexes_size,
  ROUND(100.0 * pg_indexes_size('orders') / pg_table_size('orders'), 1)
    AS index_pct;

-- Exercise 4: REINDEX
REINDEX TABLE orders;

-- Exercise 5: FK indexing
-- Check: does every FK column have an index?
-- (order_items.order_id should be indexed)

-- Exercise 6: Index strategy review
-- For your application's top 5 queries:
-- 1. Run EXPLAIN ANALYZE
-- 2. Check for Seq Scans on large tables
-- 3. Create targeted indexes
-- 4. Re-run EXPLAIN ANALYZE to verify

-- === CLEANUP ===
DROP INDEX IF EXISTS idx_orders_cust_status, idx_orders_triple;
DROP INDEX IF EXISTS idx_practice_multi;
DROP TABLE IF EXISTS order_items;
-- DROP TABLE IF EXISTS orders;

-- =============================================
-- Phase 12: Indexes — COMPLETE!
-- Videos 044-048 cover:
--   B-Tree fundamentals, EXPLAIN, scan types
--   Hash & GIN indexes
--   GiST, BRIN & SP-GiST indexes
--   Partial, Expression & Covering indexes
--   Multi-column, When to Index & Bloat
--
-- Next Phase: Phase 13 — Transactions & Concurrency
-- BEGIN/COMMIT/ROLLBACK, ACID, SAVEPOINT,
-- Isolation levels, row-level locking
-- =============================================
