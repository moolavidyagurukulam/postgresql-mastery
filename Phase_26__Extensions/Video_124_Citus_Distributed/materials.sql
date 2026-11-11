-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Citus — Distributed PostgreSQL (Class 230)
-- Phase 26: Extensions
-- ============================================================

-- ============================================================
-- INSTALLATION (on ALL nodes: coordinator + workers)
-- ============================================================

-- 1. Install package:
--    Debian/Ubuntu: sudo apt install postgresql-16-citus-12.1
--    RHEL/Rocky:    sudo dnf install citus_16

-- 2. Edit postgresql.conf:
--    shared_preload_libraries = 'citus'

-- 3. Restart:
--    sudo systemctl restart postgresql-16

-- 4. Create extension:
CREATE EXTENSION citus;

-- ============================================================
-- 1. CLUSTER SETUP (on coordinator)
-- ============================================================

-- Set coordinator:
SELECT citus_set_coordinator_host('coord-node', 5432);

-- Add workers:
SELECT citus_add_node('worker-1', 5432);
SELECT citus_add_node('worker-2', 5432);
SELECT citus_add_node('worker-3', 5432);

-- Verify:
SELECT * FROM citus_get_active_worker_nodes();

-- Single-node mode (for dev/testing):
SELECT citus_set_coordinator_host('localhost', 5432);

-- ============================================================
-- 2. DISTRIBUTED TABLES
-- ============================================================

-- Create table (include dist column in PK):
CREATE TABLE orders (
    id bigserial,
    tenant_id int NOT NULL,
    product text NOT NULL,
    amount numeric(10,2),
    created_at timestamptz DEFAULT now(),
    PRIMARY KEY (tenant_id, id)
);

-- Distribute by tenant_id:
SELECT create_distributed_table('orders', 'tenant_id');

-- Insert (same as normal SQL):
INSERT INTO orders (tenant_id, product, amount)
VALUES (1, 'Widget', 29.99);

INSERT INTO orders (tenant_id, product, amount)
VALUES (2, 'Gadget', 49.99);

-- ============================================================
-- 3. REFERENCE TABLES
-- ============================================================

CREATE TABLE countries (
    id int PRIMARY KEY,
    name text NOT NULL,
    code char(2) UNIQUE
);

SELECT create_reference_table('countries');

INSERT INTO countries VALUES
(1, 'United States', 'US'),
(2, 'United Kingdom', 'GB'),
(3, 'Germany', 'DE');

-- ============================================================
-- 4. QUERIES
-- ============================================================

-- Single-shard (filter by dist column — fast):
SELECT * FROM orders WHERE tenant_id = 1;

-- Multi-shard (aggregation — parallel):
SELECT tenant_id, count(*), sum(amount)
FROM orders
GROUP BY tenant_id
ORDER BY sum(amount) DESC;

-- Join with reference table (local on each worker):
-- SELECT o.product, c.name FROM orders o
-- JOIN countries c ON o.country_id = c.id
-- WHERE o.tenant_id = 1;

-- ============================================================
-- 5. CO-LOCATED JOINS
-- ============================================================

CREATE TABLE order_items (
    id bigserial,
    tenant_id int NOT NULL,
    order_id bigint NOT NULL,
    product_name text,
    quantity int,
    PRIMARY KEY (tenant_id, id)
);

-- Same distribution column:
SELECT create_distributed_table('order_items', 'tenant_id');

-- Co-located join (fast — same worker):
SELECT o.id, o.amount, oi.product_name
FROM orders o
JOIN order_items oi
    ON o.tenant_id = oi.tenant_id
   AND o.id = oi.order_id
WHERE o.tenant_id = 1;

-- ============================================================
-- 6. SCHEMA CHANGES
-- ============================================================

-- Add column (propagated to all workers):
ALTER TABLE orders ADD COLUMN status text DEFAULT 'pending';

-- Create index (on all shards):
CREATE INDEX idx_orders_status ON orders (tenant_id, status);

-- Add constraint:
ALTER TABLE orders ADD CONSTRAINT positive_amount CHECK (amount > 0);

-- ============================================================
-- 7. VIEWING DISTRIBUTION INFO
-- ============================================================

-- View shards:
SELECT * FROM citus_shards
WHERE table_name = 'orders'::regclass
LIMIT 10;

-- View distributed tables:
SELECT * FROM citus_tables;

-- Explain distributed query:
EXPLAIN SELECT * FROM orders WHERE tenant_id = 1;
-- Task Count: 1 (single shard)

EXPLAIN SELECT count(*) FROM orders;
-- Task Count: 32 (all shards — parallel)

-- ============================================================
-- 8. SHARD MANAGEMENT
-- ============================================================

-- Change shard count for new tables:
SET citus.shard_count = 64;

-- Rebalance shards after adding a worker:
-- SELECT citus_rebalance_start();

-- Remove a worker (drain shards first):
-- SELECT citus_drain_node('worker-3', 5432);
-- SELECT citus_remove_node('worker-3', 5432);

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Set up single-node Citus and create a distributed table
--    with tenant_id as the distribution column.

-- 2. Insert 1000 rows for 10 tenants. Query per-tenant
--    aggregations and check EXPLAIN output.

-- 3. Create a reference table and join it with the
--    distributed table.

-- 4. Create a second distributed table with the same
--    distribution column and perform a co-located join.

-- 5. Try creating a PRIMARY KEY without the distribution
--    column. Observe the error. Fix it.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TABLE IF EXISTS order_items;
-- DROP TABLE IF EXISTS orders;
-- DROP TABLE IF EXISTS countries;
-- DROP EXTENSION IF EXISTS citus;
