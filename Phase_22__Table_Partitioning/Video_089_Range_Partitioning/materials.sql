-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Range Partitioning (Classes 182-183)
-- Phase 22: Table Partitioning
-- ============================================================

-- ============================================================
-- 1. SETUP — Create Partitioned Table
-- ============================================================

CREATE DATABASE partition_lab;
\c partition_lab

-- Parent table (holds no data):
CREATE TABLE orders (
    id          BIGSERIAL,
    customer_id INTEGER NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    status      TEXT NOT NULL DEFAULT 'pending',
    order_date  DATE NOT NULL,
    PRIMARY KEY (id, order_date)  -- partition key MUST be in PK
) PARTITION BY RANGE (order_date);

-- ============================================================
-- 2. CREATE MONTHLY PARTITIONS
-- ============================================================

CREATE TABLE orders_2025_01 PARTITION OF orders
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE orders_2025_02 PARTITION OF orders
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

CREATE TABLE orders_2025_03 PARTITION OF orders
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

-- Range is [FROM, TO) — FROM inclusive, TO exclusive

-- ============================================================
-- 3. INSERT DATA — Automatic Routing
-- ============================================================

INSERT INTO orders (customer_id, amount, status, order_date)
VALUES
  (1, 99.99, 'pending', '2025-01-15'),
  (2, 149.50, 'shipped', '2025-02-20'),
  (3, 75.00, 'delivered', '2025-03-10');

-- Check which partition each row landed in:
SELECT tableoid::regclass AS partition, *
FROM orders;

-- ============================================================
-- 4. MISSING PARTITION ERROR
-- ============================================================

-- This fails (no April partition):
-- INSERT INTO orders (customer_id, amount, status, order_date)
-- VALUES (4, 200.00, 'pending', '2025-04-05');
-- ERROR: no partition of relation "orders" found for row

-- Fix: create the missing partition:
CREATE TABLE orders_2025_04 PARTITION OF orders
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');

INSERT INTO orders (customer_id, amount, status, order_date)
VALUES (4, 200.00, 'pending', '2025-04-05');

-- ============================================================
-- 5. DEFAULT PARTITION (Safety Net)
-- ============================================================

CREATE TABLE orders_default PARTITION OF orders DEFAULT;

INSERT INTO orders (customer_id, amount, status, order_date)
VALUES (5, 50.00, 'pending', '2025-12-25');

SELECT tableoid::regclass AS partition, id, order_date
FROM orders WHERE order_date = '2025-12-25';

-- ============================================================
-- 6. INDEXES ON PARTITIONED TABLES
-- ============================================================

CREATE INDEX idx_orders_customer ON orders(customer_id);

-- Lists per-partition indexes:
\di orders*

-- ============================================================
-- 7. GENERATE FULL YEAR OF PARTITIONS
-- ============================================================

DO $$
DECLARE
    month_start DATE;
    month_end   DATE;
    part_name   TEXT;
BEGIN
    FOR m IN 1..12 LOOP
        month_start := make_date(2026, m, 1);
        month_end   := month_start + '1 month'::interval;
        part_name   := 'orders_' ||
                       to_char(month_start, 'YYYY_MM');

        EXECUTE format(
            'CREATE TABLE %I PARTITION OF orders
             FOR VALUES FROM (%L) TO (%L)',
            part_name, month_start, month_end
        );

        RAISE NOTICE 'Created partition: %', part_name;
    END LOOP;
END $$;

-- ============================================================
-- 8. PERFORMANCE DEMO
-- ============================================================

INSERT INTO orders (customer_id, amount, status, order_date)
SELECT
    (random() * 999 + 1)::int,
    (random() * 500 + 1)::numeric(10,2),
    (ARRAY['pending','shipped','delivered'])[floor(random()*3+1)::int],
    '2026-01-01'::date + (random() * 365)::int
FROM generate_series(1, 1000000);

-- Only scans one partition:
EXPLAIN ANALYZE
SELECT COUNT(*), SUM(amount)
FROM orders
WHERE order_date >= '2026-03-01'
  AND order_date < '2026-04-01';

-- ============================================================
-- 9. RANGE PARTITIONING BY INTEGER
-- ============================================================

CREATE TABLE users (
    id      BIGINT NOT NULL,
    name    TEXT NOT NULL,
    email   TEXT,
    PRIMARY KEY (id)
) PARTITION BY RANGE (id);

CREATE TABLE users_0_1m PARTITION OF users
    FOR VALUES FROM (0) TO (1000000);
CREATE TABLE users_1m_2m PARTITION OF users
    FOR VALUES FROM (1000000) TO (2000000);
CREATE TABLE users_2m_3m PARTITION OF users
    FOR VALUES FROM (2000000) TO (3000000);

INSERT INTO users (id, name, email)
VALUES (500000, 'Alice', 'alice@example.com');

SELECT tableoid::regclass, * FROM users WHERE id = 500000;

-- ============================================================
-- 10. MINVALUE & MAXVALUE
-- ============================================================

CREATE TABLE orders_archive PARTITION OF orders
    FOR VALUES FROM (MINVALUE) TO ('2025-01-01');

CREATE TABLE orders_future PARTITION OF orders
    FOR VALUES FROM ('2027-01-01') TO (MAXVALUE);

-- ============================================================
-- 11. INSPECT PARTITION STRUCTURE
-- ============================================================

SELECT
    parent.relname AS parent_table,
    child.relname  AS partition,
    pg_get_expr(c.relpartbound, c.oid) AS bounds
FROM pg_inherits i
JOIN pg_class parent ON i.inhparent = parent.oid
JOIN pg_class child  ON i.inhrelid  = child.oid
JOIN pg_class c      ON c.oid       = child.oid
WHERE parent.relname = 'orders'
ORDER BY child.relname;

-- Partition row counts:
SELECT tableoid::regclass AS partition,
       COUNT(*) AS row_count
FROM orders
GROUP BY tableoid
ORDER BY partition;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a sales table partitioned by RANGE on sale_date.
--    Add quarterly partitions for 2026.
-- 2. Insert rows into each quarter. Verify routing with tableoid.
-- 3. Try inserting a row for 2027 (no partition). See the error.
--    Add a DEFAULT partition and retry.
-- 4. Create an index on the parent. Verify per-partition indexes.
-- 5. Load 500K rows and run EXPLAIN ANALYZE for one quarter.
--    Confirm only that partition is scanned.
