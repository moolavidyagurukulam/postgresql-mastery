-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Database & Table Sizing (Classes 138-140)
-- Phase 17: Database Sizing & Capacity Planning
-- ============================================================

\c trigger_lab

-- ============================================================
-- 1. DATABASE SIZE FUNCTIONS
-- ============================================================

-- Single database:
SELECT pg_size_pretty(pg_database_size('trigger_lab')) AS db_size;

-- All databases sorted by size:
SELECT datname,
       pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;

-- ============================================================
-- 2. TABLE SIZE FUNCTIONS
-- ============================================================

-- Setup: large table for meaningful measurements
CREATE TABLE big_orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    product     TEXT NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    order_date  DATE NOT NULL,
    notes       TEXT
);

INSERT INTO big_orders (customer_id, product, amount, order_date, notes)
SELECT
    (random() * 10000)::int,
    (ARRAY['Widget','Gadget','Doohickey','Thingamajig','Gizmo'])[1 + (random()*4)::int],
    (random() * 999 + 1)::numeric(10,2),
    '2025-01-01'::date + (random() * 365)::int,
    'Order notes for item ' || g
FROM generate_series(1, 500000) AS g;

-- Measure from every angle:
SELECT
    pg_size_pretty(pg_total_relation_size('big_orders')) AS total,
    pg_size_pretty(pg_table_size('big_orders'))          AS table_only,
    pg_size_pretty(pg_indexes_size('big_orders'))        AS indexes,
    pg_size_pretty(pg_relation_size('big_orders'))       AS heap;

-- ============================================================
-- 3. TABLE SIZE REPORT (Essential Query)
-- ============================================================

SELECT
    schemaname || '.' || relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total,
    pg_size_pretty(pg_table_size(relid)) AS data,
    pg_size_pretty(pg_indexes_size(relid)) AS indexes,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    CASE WHEN n_live_tup > 0
         THEN round(100.0 * n_dead_tup / n_live_tup, 1)
         ELSE 0 END AS dead_pct
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;

-- ============================================================
-- 4. INDIVIDUAL INDEX SIZES
-- ============================================================

CREATE INDEX idx_big_orders_customer ON big_orders(customer_id);
CREATE INDEX idx_big_orders_date ON big_orders(order_date);
CREATE INDEX idx_big_orders_product ON big_orders(product);

SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size,
       idx_scan AS scans
FROM pg_stat_user_indexes
WHERE relname = 'big_orders'
ORDER BY pg_relation_size(indexrelid) DESC;

-- ============================================================
-- 5. FINDING UNUSED INDEXES
-- ============================================================

-- When were stats last reset?
SELECT stats_reset FROM pg_stat_database WHERE datname = current_database();

-- Unused indexes (0 scans since reset):
SELECT schemaname, relname, indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size,
       idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND indexrelname NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;

-- ============================================================
-- 6. TABLE BLOAT — CREATE AND MEASURE
-- ============================================================

SELECT pg_size_pretty(pg_table_size('big_orders')) AS before_size;

-- Create bloat: update 200k rows
UPDATE big_orders SET amount = amount * 1.1 WHERE id <= 200000;

SELECT pg_size_pretty(pg_table_size('big_orders')) AS after_size;

SELECT n_live_tup, n_dead_tup,
       round(100.0 * n_dead_tup / GREATEST(n_live_tup, 1), 1) AS dead_pct
FROM pg_stat_user_tables
WHERE relname = 'big_orders';

-- ============================================================
-- 7. VACUUM vs VACUUM FULL
-- ============================================================

-- Regular VACUUM: marks dead rows reusable, does NOT shrink file
VACUUM VERBOSE big_orders;
SELECT pg_size_pretty(pg_table_size('big_orders')) AS after_vacuum;

-- VACUUM FULL: shrinks file but LOCKS the table (dangerous in prod!)
-- VACUUM FULL big_orders;
-- SELECT pg_size_pretty(pg_table_size('big_orders')) AS after_full;

-- ============================================================
-- 8. COLUMN SIZES
-- ============================================================

SELECT
    avg(pg_column_size(id)) AS id_bytes,
    avg(pg_column_size(customer_id)) AS cust_bytes,
    avg(pg_column_size(product)) AS product_bytes,
    avg(pg_column_size(amount)) AS amount_bytes,
    avg(pg_column_size(order_date)) AS date_bytes,
    avg(pg_column_size(notes)) AS notes_bytes,
    avg(pg_column_size(big_orders.*)) AS row_total
FROM big_orders TABLESAMPLE SYSTEM(1);

-- ============================================================
-- 9. DISK MONITORING
-- ============================================================

-- Total size of all databases:
SELECT pg_size_pretty(sum(pg_database_size(datname))::bigint) AS total
FROM pg_database;

-- WAL directory:
SELECT count(*) AS wal_files,
       pg_size_pretty(sum(size)) AS wal_total
FROM pg_ls_waldir();

-- Temp file usage:
SELECT datname, temp_files, pg_size_pretty(temp_bytes) AS temp_size
FROM pg_stat_database WHERE temp_bytes > 0;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Run the table size report on your database
-- 2. Create a 100k row table, UPDATE 50k rows, check dead_pct
-- 3. VACUUM VERBOSE and confirm file size unchanged
-- 4. Find unused indexes with pg_stat_user_indexes
-- 5. Measure total database + WAL size

-- ============================================================
-- CLEANUP (optional)
-- ============================================================
-- DROP INDEX idx_big_orders_customer;
-- DROP INDEX idx_big_orders_date;
-- DROP INDEX idx_big_orders_product;
-- DROP TABLE big_orders;
