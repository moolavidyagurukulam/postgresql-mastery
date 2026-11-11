-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Join Algorithms & Query Planner (Classes 166-167)
-- Phase 20: Query Optimization & Performance
-- ============================================================

-- ============================================================
-- SETUP: Create demo tables if not present
-- ============================================================

-- Customers table (1,000 rows):
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT
);

INSERT INTO customers (name, email)
SELECT 'Customer_' || g,
       'cust' || g || '@example.com'
FROM generate_series(1, 1000) g
ON CONFLICT DO NOTHING;

-- Orders table (50,000 rows):
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    amount NUMERIC(10,2),
    status TEXT,
    order_date DATE
);

INSERT INTO orders (customer_id, amount, status, order_date)
SELECT (random() * 999 + 1)::int,
       (random() * 500 + 1)::numeric(10,2),
       (ARRAY['pending','shipped','delivered','cancelled','returned'])[floor(random()*5+1)::int],
       '2025-01-01'::date + (random() * 365)::int
FROM generate_series(1, 50000) g
ON CONFLICT DO NOTHING;

-- Products table (200 rows):
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    price NUMERIC(10,2)
);

INSERT INTO products (name, price)
SELECT 'Product_' || g, (random() * 200 + 5)::numeric(10,2)
FROM generate_series(1, 200) g
ON CONFLICT DO NOTHING;

-- Refresh statistics:
ANALYZE customers;
ANALYZE orders;
ANALYZE products;

-- ============================================================
-- 1. NESTED LOOP JOIN
-- ============================================================

-- Nested Loop: small outer + indexed inner
EXPLAIN ANALYZE
SELECT o.id, o.amount, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.id < 10;

-- Watch for: loops=N on the inner scan (runs once per outer row)

-- ============================================================
-- 2. HASH JOIN
-- ============================================================

-- Hash Join: medium-to-large equi-join
EXPLAIN ANALYZE
SELECT o.id, o.amount, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.id;

-- Watch for: Buckets, Batches, Memory Usage
-- Batches = 1 → fits in memory (good)
-- Batches > 1 → spilled to disk (increase work_mem)

-- ============================================================
-- 3. MERGE JOIN
-- ============================================================

-- Force Merge Join for demonstration:
SET enable_hashjoin = off;
SET enable_nestloop = off;

EXPLAIN ANALYZE
SELECT o.id, o.amount, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.id;

-- Watch for: Sort Method — quicksort Memory vs external merge Disk

-- Reset planner defaults:
RESET enable_hashjoin;
RESET enable_nestloop;

-- ============================================================
-- 4. QUERY PLANNER STATISTICS (pg_stats)
-- ============================================================

-- What the planner knows about orders.status:
SELECT attname,
       n_distinct,
       most_common_vals,
       most_common_freqs,
       correlation
FROM pg_stats
WHERE tablename = 'orders' AND attname = 'status';

-- What the planner knows about orders.customer_id:
SELECT attname,
       n_distinct,
       null_frac,
       correlation
FROM pg_stats
WHERE tablename = 'orders' AND attname = 'customer_id';

-- Histogram bounds (used for range queries):
SELECT attname, histogram_bounds
FROM pg_stats
WHERE tablename = 'orders' AND attname = 'amount';

-- ============================================================
-- 5. JOIN REORDERING
-- ============================================================

-- Planner may reorder joins for efficiency:
EXPLAIN
SELECT *
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN products p ON p.id = (o.id % 200 + 1);

-- Read the plan bottom to top — deepest scan runs first

-- ============================================================
-- 6. PLANNER COST PARAMETERS
-- ============================================================

-- View current settings:
SHOW random_page_cost;      -- 4.0 (default, for spinning disk)
SHOW seq_page_cost;          -- 1.0 (base unit)
SHOW effective_cache_size;   -- how much OS+PG cache
SHOW work_mem;               -- per-operation sort/hash memory

-- For SSD storage (session-level change):
-- SET random_page_cost = 1.1;

-- Increase sort/hash memory for this session:
-- SET work_mem = '64MB';

-- ============================================================
-- 7. SPOTTING DISK SPILLS
-- ============================================================

-- Force a small work_mem to see disk spills:
SET work_mem = '64kB';

EXPLAIN ANALYZE
SELECT o.id, o.amount, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.id
ORDER BY o.amount;

-- Look for:
-- Sort Method: external merge  Disk: NNNNkB  ← spilling!
-- Batches: > 1                                ← hash spilling!

-- Fix:
SET work_mem = '64MB';

-- Re-run same query — should now say quicksort Memory:
EXPLAIN ANALYZE
SELECT o.id, o.amount, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.id
ORDER BY o.amount;

RESET work_mem;

-- ============================================================
-- 8. PLAN SEARCH STRATEGIES
-- ============================================================

-- Check GEQO threshold:
SHOW geqo_threshold;         -- default 12
SHOW join_collapse_limit;    -- default 8
SHOW from_collapse_limit;    -- default 8

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Run EXPLAIN ANALYZE on a two-table join.
--    Identify the join algorithm (Nested Loop, Hash, or Merge).
-- 2. Force a Merge Join by disabling hashjoin and nestloop.
--    Compare execution time to the original plan.
-- 3. Set work_mem = '64kB' and run a large join with ORDER BY.
--    Spot the disk spill. Then set work_mem = '64MB' and compare.
-- 4. Query pg_stats for a column with skewed data.
--    Check most_common_vals and most_common_freqs.
-- 5. Write a three-table join and check if the planner
--    reorders the tables. Read the plan bottom to top.
