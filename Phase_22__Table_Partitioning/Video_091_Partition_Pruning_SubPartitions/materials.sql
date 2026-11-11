-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Partition Pruning & Sub-Partitioning (Classes 186-187)
-- Phase 22: Table Partitioning
-- ============================================================

-- ============================================================
-- 1. PARTITION PRUNING — Plan-Time
-- ============================================================

\c partition_lab

-- Query for one month (literal values → plan-time pruning):
EXPLAIN (COSTS OFF)
SELECT * FROM orders
WHERE order_date >= '2026-03-01'
  AND order_date < '2026-04-01';
-- Only orders_2026_03 appears in the plan

-- Query spanning 3 months:
EXPLAIN (COSTS OFF)
SELECT * FROM orders
WHERE order_date >= '2026-03-01'
  AND order_date < '2026-06-01';
-- Three partitions appear

-- ============================================================
-- 2. PARTITION PRUNING — Execution-Time
-- ============================================================

PREPARE get_month_orders(date, date) AS
SELECT * FROM orders
WHERE order_date >= $1 AND order_date < $2;

EXPLAIN ANALYZE EXECUTE get_month_orders(
    '2026-06-01', '2026-07-01'
);
-- All partitions listed but only orders_2026_06 executed
-- Others show "(never executed)"

DEALLOCATE get_month_orders;

-- ============================================================
-- 3. FUNCTIONS DESTROY PRUNING
-- ============================================================

-- BAD — no pruning (scans all partitions):
EXPLAIN ANALYZE
SELECT COUNT(*) FROM orders
WHERE EXTRACT(month FROM order_date) = 3
  AND EXTRACT(year FROM order_date) = 2026;

-- GOOD — pruning works:
EXPLAIN ANALYZE
SELECT COUNT(*) FROM orders
WHERE order_date >= '2026-03-01'
  AND order_date < '2026-04-01';

-- Compare execution times!

-- ============================================================
-- 4. PRUNING WITH JOINS
-- ============================================================

CREATE TABLE promotions (
    id         SERIAL PRIMARY KEY,
    promo_name TEXT,
    start_date DATE,
    end_date   DATE
);

INSERT INTO promotions VALUES
    (1, 'Spring Sale', '2026-03-01', '2026-04-01');

EXPLAIN (COSTS OFF)
SELECT o.id, o.amount, p.promo_name
FROM orders o
JOIN promotions p ON TRUE
WHERE o.order_date >= p.start_date
  AND o.order_date < p.end_date
  AND p.id = 1;

-- ============================================================
-- 5. SUB-PARTITIONING
-- ============================================================

-- Level 1: Range by year
CREATE TABLE global_orders (
    id          BIGSERIAL,
    customer_id INTEGER NOT NULL,
    amount      NUMERIC(10,2),
    region      TEXT NOT NULL,
    order_date  DATE NOT NULL,
    PRIMARY KEY (id, order_date, region)
) PARTITION BY RANGE (order_date);

-- Level 2: List by region (within each year)
CREATE TABLE global_orders_2025
    PARTITION OF global_orders
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01')
    PARTITION BY LIST (region);

CREATE TABLE global_orders_2026
    PARTITION OF global_orders
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01')
    PARTITION BY LIST (region);

-- Level 3: Leaf partitions
CREATE TABLE global_orders_2025_north
    PARTITION OF global_orders_2025
    FOR VALUES IN ('north');
CREATE TABLE global_orders_2025_south
    PARTITION OF global_orders_2025
    FOR VALUES IN ('south');
CREATE TABLE global_orders_2025_east
    PARTITION OF global_orders_2025
    FOR VALUES IN ('east');

CREATE TABLE global_orders_2026_north
    PARTITION OF global_orders_2026
    FOR VALUES IN ('north');
CREATE TABLE global_orders_2026_south
    PARTITION OF global_orders_2026
    FOR VALUES IN ('south');
CREATE TABLE global_orders_2026_east
    PARTITION OF global_orders_2026
    FOR VALUES IN ('east');

-- Default at each level:
CREATE TABLE global_orders_2025_other
    PARTITION OF global_orders_2025 DEFAULT;
CREATE TABLE global_orders_2026_other
    PARTITION OF global_orders_2026 DEFAULT;

-- ============================================================
-- 6. MULTI-DIMENSIONAL PRUNING
-- ============================================================

INSERT INTO global_orders
  (customer_id, amount, region, order_date)
VALUES
  (1, 100.00, 'north', '2025-06-15'),
  (2, 200.00, 'south', '2026-03-20'),
  (3, 150.00, 'north', '2026-08-10');

-- Both dimensions pruned:
EXPLAIN (COSTS OFF)
SELECT * FROM global_orders
WHERE order_date >= '2026-01-01'
  AND order_date < '2027-01-01'
  AND region = 'north';
-- Only global_orders_2026_north scanned

-- ============================================================
-- 7. CHECKING PARTITION STRUCTURE
-- ============================================================

-- All leaf partitions of global_orders:
SELECT
    parent.relname AS parent,
    child.relname  AS partition,
    pg_get_expr(c.relpartbound, c.oid) AS bounds
FROM pg_inherits i
JOIN pg_class parent ON i.inhparent = parent.oid
JOIN pg_class child  ON i.inhrelid  = child.oid
JOIN pg_class c      ON c.oid       = child.oid
WHERE parent.relname LIKE 'global_orders%'
ORDER BY parent.relname, child.relname;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Run EXPLAIN ANALYZE on orders for one month.
--    Confirm only that partition appears in the plan.
-- 2. Create a prepared statement with date parameters.
--    Run EXPLAIN ANALYZE EXECUTE and find "(never executed)".
-- 3. Compare performance: EXTRACT(month ...) vs direct range.
--    How much faster is the pruned version?
-- 4. Create a 2-level sub-partitioned table:
--    Level 1: RANGE by quarter, Level 2: LIST by status.
--    Insert data and verify multi-dimensional pruning.
-- 5. Count your total leaf partitions across all tables.
--    Is the count under 200?
