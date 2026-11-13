-- =============================================
-- PostgreSQL Mastery: What Is an Index? B-Tree
-- Phase 12: Indexes | Classes 90-91
-- =============================================
-- Index fundamentals, B-Tree, EXPLAIN, scan types,
-- index costs, CREATE INDEX CONCURRENTLY.
-- =============================================

-- === SETUP: Create Test Data ===

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

-- Verify
SELECT COUNT(*) FROM orders;

-- Update statistics
ANALYZE orders;

-- === EXPLAIN WITHOUT INDEX ===

-- Sequential Scan: reads every row
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
-- Seq Scan on orders  (cost=0.00..2137.00 rows=~100)
--   Filter: (customer_id = 42)

-- EXPLAIN ANALYZE: actually runs the query and shows real time
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;

-- === CREATE INDEX ===

-- B-Tree index (default type)
CREATE INDEX idx_orders_customer ON orders (customer_id);

-- === EXPLAIN WITH INDEX ===

-- Now it uses Index Scan
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
-- Index Scan using idx_orders_customer on orders
--   Index Cond: (customer_id = 42)

-- Compare actual execution time
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;

-- === RANGE QUERIES WITH B-TREE ===

-- B-Tree handles ranges efficiently
CREATE INDEX idx_orders_date ON orders (order_date);

EXPLAIN SELECT * FROM orders
WHERE order_date BETWEEN '2024-01-01' AND '2024-01-31';

-- B-Tree also helps with ORDER BY
EXPLAIN SELECT * FROM orders ORDER BY order_date LIMIT 10;
-- Index Scan → no sort step needed!

-- MIN/MAX: reads first/last leaf entry
EXPLAIN SELECT MIN(order_date), MAX(order_date) FROM orders;

-- === SCAN TYPES ===

-- 1. Seq Scan: no index or planner prefers full scan
EXPLAIN SELECT * FROM orders WHERE status = 'pending';
-- ~25% of rows → Seq Scan is faster

-- 2. Index Scan: index → table row
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;

-- 3. Index Only Scan: reads only the index
-- (all needed columns must be in the index)
EXPLAIN SELECT customer_id FROM orders WHERE customer_id = 42;
-- Index Only Scan (doesn't visit the table!)

-- 4. Bitmap Index Scan: many matching rows
EXPLAIN SELECT * FROM orders WHERE customer_id < 50;
-- Bitmap Index Scan → Bitmap Heap Scan
-- Builds bitmap of matching pages, reads in order

-- === WHEN PLANNER IGNORES INDEX ===

-- High selectivity query → uses index
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;

-- Low selectivity → prefers Seq Scan
-- ~25% of table matches 'pending'
EXPLAIN SELECT * FROM orders WHERE status = 'pending';

-- The planner is almost always right!
-- Do NOT force index usage in production

-- For testing, you CAN disable seq scan:
-- SET enable_seqscan = off;
-- EXPLAIN SELECT * FROM orders WHERE status = 'pending';
-- SET enable_seqscan = on;  -- always turn back on!

-- === INDEX SIZE ===

-- Check index size
SELECT pg_size_pretty(pg_relation_size('idx_orders_customer')) AS index_size;

-- Compare table size vs index sizes
SELECT
  pg_size_pretty(pg_table_size('orders')) AS table_size,
  pg_size_pretty(pg_indexes_size('orders')) AS all_indexes_size,
  pg_size_pretty(pg_total_relation_size('orders')) AS total_size;

-- === LIST AND INSPECT INDEXES ===

-- List indexes in psql
-- \di

-- Detailed info
-- \di+ idx_orders_customer

-- Query pg_indexes catalog
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'orders';

-- Index usage statistics
SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE relname = 'orders';
-- idx_scan = 0 means the index is NEVER used!

-- === CREATE INDEX CONCURRENTLY ===

-- Normal CREATE INDEX locks the table for writes
-- CONCURRENTLY builds without locking (slower, but safe)

CREATE INDEX CONCURRENTLY idx_orders_amount
ON orders (amount);

-- Note: CONCURRENTLY cannot run inside a transaction block
-- BEGIN; CREATE INDEX CONCURRENTLY ...; → ERROR!

-- === IF NOT EXISTS ===

-- Avoid "already exists" error
CREATE INDEX IF NOT EXISTS idx_orders_customer
ON orders (customer_id);
-- NOTICE: relation already exists, skipping

-- === PRIMARY KEY = AUTOMATIC INDEX ===

-- The primary key already has an index — don't duplicate it!
-- DO NOT: CREATE INDEX ON orders (id); ← wastes space

-- Unique constraints also auto-create an index
ALTER TABLE orders ADD CONSTRAINT uq_placeholder UNIQUE (id, customer_id);
-- Creates index automatically
ALTER TABLE orders DROP CONSTRAINT uq_placeholder;

-- === ANALYZE — Update Statistics ===

-- After bulk data changes, update statistics
ANALYZE orders;

-- Planner uses statistics to estimate row counts
-- Bad statistics → bad query plans → slow queries!

-- === COMMON ERRORS ===

-- ERROR: index already exists
-- CREATE INDEX idx_orders_customer ON orders (customer_id);
-- Fix: CREATE INDEX IF NOT EXISTS ...

-- ERROR: cannot create index on non-existent column
-- CREATE INDEX idx_bad ON orders (nonexistent_col);
-- Fix: check column name with \d orders

-- ERROR: CONCURRENTLY cannot run in transaction block
-- BEGIN; CREATE INDEX CONCURRENTLY ...; → ERROR
-- Fix: run CONCURRENTLY outside of BEGIN/COMMIT

-- === PRACTICE EXERCISES ===

-- Exercise 1: EXPLAIN without index
EXPLAIN SELECT * FROM orders WHERE amount > 500;

-- Exercise 2: Create index on amount
-- (already created above with CONCURRENTLY)

-- Exercise 3: EXPLAIN with index
EXPLAIN SELECT * FROM orders WHERE amount > 900;
-- Few rows → Index Scan
EXPLAIN SELECT * FROM orders WHERE amount > 100;
-- Many rows → probably Seq Scan

-- Exercise 4: Index Only Scan
EXPLAIN SELECT order_date FROM orders WHERE order_date = '2024-06-15';

-- Exercise 5: Check index sizes
SELECT indexname, pg_size_pretty(pg_relation_size(indexname::regclass))
FROM pg_indexes WHERE tablename = 'orders';

-- Exercise 6: Check index usage
SELECT indexrelname, idx_scan
FROM pg_stat_user_indexes WHERE relname = 'orders';

-- Exercise 7: EXPLAIN ANALYZE (actual execution)
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;

-- === CLEANUP ===
-- DROP INDEX IF EXISTS idx_orders_customer, idx_orders_date, idx_orders_amount;
-- DROP TABLE IF EXISTS orders;

-- =============================================
-- Next Class: Hash & GIN Indexes
-- =============================================


-- =============================================
-- VERIFIED ANSWER KEY — B-TREE INDEXES & EXPLAIN
-- =============================================

-- 1. Inspect Execution Plan Without Index
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE amount > 950;

-- 2. Create Concurrent B-Tree Index (Online)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_amount
ON orders(amount);

-- 3. Selectivity Threshold Comparison
-- High selectivity (few rows matched): Index Scan
EXPLAIN SELECT * FROM orders WHERE amount > 990;

-- Low selectivity (many rows matched): Sequential Scan
EXPLAIN SELECT * FROM orders WHERE amount > 10;

-- 4. Index Only Scan Verification
EXPLAIN SELECT order_date
FROM orders
WHERE order_date = '2024-06-15';

-- 5. Monitor Physical Size & Usage Statistics
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
       idx_scan AS number_of_scans
FROM pg_stat_user_indexes
WHERE relname = 'orders'
ORDER BY idx_scan DESC;
