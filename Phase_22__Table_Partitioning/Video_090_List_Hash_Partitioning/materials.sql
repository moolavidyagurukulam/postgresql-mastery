-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- List & Hash Partitioning (Classes 184-185)
-- Phase 22: Table Partitioning
-- ============================================================

-- ============================================================
-- 1. LIST PARTITIONING — By Region
-- ============================================================

\c partition_lab

CREATE TABLE sales (
    id          BIGSERIAL,
    product     TEXT NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    region      TEXT NOT NULL,
    sale_date   DATE NOT NULL,
    PRIMARY KEY (id, region)
) PARTITION BY LIST (region);

CREATE TABLE sales_north PARTITION OF sales
    FOR VALUES IN ('north');
CREATE TABLE sales_south PARTITION OF sales
    FOR VALUES IN ('south');
CREATE TABLE sales_east PARTITION OF sales
    FOR VALUES IN ('east');
CREATE TABLE sales_west PARTITION OF sales
    FOR VALUES IN ('west');

-- One partition for multiple values:
CREATE TABLE sales_overseas PARTITION OF sales
    FOR VALUES IN ('europe', 'asia', 'africa');

-- Insert and check routing:
INSERT INTO sales (product, amount, region, sale_date)
VALUES
  ('Widget A', 100.00, 'north', '2026-01-15'),
  ('Widget B', 250.00, 'south', '2026-02-20'),
  ('Widget C', 175.00, 'europe', '2026-03-10'),
  ('Widget D', 300.00, 'east', '2026-04-05');

SELECT tableoid::regclass AS partition, id, product, region
FROM sales;

-- Partition pruning:
EXPLAIN (COSTS OFF)
SELECT * FROM sales WHERE region = 'north';

-- ============================================================
-- 2. LIST — Default Partition
-- ============================================================

CREATE TABLE sales_other PARTITION OF sales DEFAULT;

INSERT INTO sales (product, amount, region, sale_date)
VALUES ('Widget E', 50.00, 'australia', '2026-05-01');

SELECT tableoid::regclass AS partition, id, region
FROM sales WHERE region = 'australia';

-- ============================================================
-- 3. LIST — Multi-Tenant Pattern
-- ============================================================

CREATE TABLE events (
    id          BIGSERIAL,
    tenant_id   TEXT NOT NULL,
    event_type  TEXT NOT NULL,
    payload     JSONB,
    created_at  TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (id, tenant_id)
) PARTITION BY LIST (tenant_id);

CREATE TABLE events_acme PARTITION OF events
    FOR VALUES IN ('acme');
CREATE TABLE events_globex PARTITION OF events
    FOR VALUES IN ('globex');
CREATE TABLE events_initech PARTITION OF events
    FOR VALUES IN ('initech');
CREATE TABLE events_default PARTITION OF events DEFAULT;

-- ============================================================
-- 4. LIST — Hot/Cold Status Split
-- ============================================================

CREATE TABLE shop_orders (
    id          BIGSERIAL,
    customer_id INTEGER NOT NULL,
    amount      NUMERIC(10,2),
    status      TEXT NOT NULL,
    created_at  DATE NOT NULL,
    PRIMARY KEY (id, status)
) PARTITION BY LIST (status);

CREATE TABLE shop_orders_active PARTITION OF shop_orders
    FOR VALUES IN ('pending', 'processing', 'shipped');
CREATE TABLE shop_orders_done PARTITION OF shop_orders
    FOR VALUES IN ('delivered', 'completed');
CREATE TABLE shop_orders_cancelled PARTITION OF shop_orders
    FOR VALUES IN ('cancelled', 'refunded');

-- ============================================================
-- 5. HASH PARTITIONING — By user_id
-- ============================================================

CREATE TABLE sessions (
    id         BIGSERIAL,
    user_id    INTEGER NOT NULL,
    ip_addr    INET,
    started_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (id, user_id)
) PARTITION BY HASH (user_id);

CREATE TABLE sessions_p0 PARTITION OF sessions
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE sessions_p1 PARTITION OF sessions
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE sessions_p2 PARTITION OF sessions
    FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE sessions_p3 PARTITION OF sessions
    FOR VALUES WITH (MODULUS 4, REMAINDER 3);

-- Insert 100K rows:
INSERT INTO sessions (user_id, ip_addr)
SELECT
    (random() * 9999 + 1)::int,
    ('192.168.' || (random()*254+1)::int || '.' ||
     (random()*254+1)::int)::inet
FROM generate_series(1, 100000);

-- Check distribution:
SELECT tableoid::regclass AS partition, COUNT(*) AS rows
FROM sessions GROUP BY tableoid ORDER BY partition;

-- Hash pruning on exact match:
EXPLAIN (COSTS OFF)
SELECT * FROM sessions WHERE user_id = 42;

-- Hash NO pruning on range:
EXPLAIN (COSTS OFF)
SELECT * FROM sessions WHERE user_id BETWEEN 1 AND 100;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a products table partitioned by LIST on category.
--    Add partitions for 'electronics', 'clothing', 'food'.
--    Insert rows and verify routing with tableoid.
-- 2. Add a DEFAULT partition. Insert an unknown category.
-- 3. Create a logs table partitioned by HASH on session_id
--    with MODULUS 8 (8 partitions). Insert 500K rows.
--    Check distribution — are they roughly equal?
-- 4. Run EXPLAIN for an exact match vs a range query on the
--    hash-partitioned table. Compare partition pruning.
-- 5. Design a partitioning strategy for an IoT sensor table
--    with 1 billion readings. What would you partition by?
