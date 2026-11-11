-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- TOAST & Capacity Planning (Classes 141-142)
-- Phase 17: Database Sizing & Capacity Planning
-- ============================================================

\c trigger_lab

-- ============================================================
-- 1. TOAST IN ACTION
-- ============================================================

CREATE TABLE toast_demo (
    id    SERIAL PRIMARY KEY,
    label TEXT,
    doc   TEXT
);

-- Small values (100 bytes each):
INSERT INTO toast_demo (label, doc)
SELECT 'small_' || g, repeat('x', 100)
FROM generate_series(1, 1000) g;

-- Large values (10KB each):
INSERT INTO toast_demo (label, doc)
SELECT 'large_' || g, repeat('A', 10240)
FROM generate_series(1, 1000) g;

-- Compare heap vs total (TOAST difference):
SELECT
    pg_size_pretty(pg_relation_size('toast_demo')) AS heap,
    pg_size_pretty(pg_table_size('toast_demo'))    AS table_with_toast;

-- ============================================================
-- 2. FINDING THE TOAST TABLE
-- ============================================================

-- Get TOAST table OID:
SELECT relname, reltoastrelid
FROM pg_class WHERE relname = 'toast_demo';

-- Measure TOAST table directly (replace OID):
-- SELECT pg_size_pretty(pg_relation_size(TOAST_OID)) AS toast_data,
--        pg_size_pretty(pg_total_relation_size(TOAST_OID)) AS toast_total;

-- ============================================================
-- 3. TOAST STORAGE STRATEGIES
-- ============================================================

-- Check current strategies:
SELECT attname, attstorage
FROM pg_attribute
WHERE attrelid = 'toast_demo'::regclass AND attnum > 0;
-- p=PLAIN, x=EXTENDED, e=EXTERNAL, m=MAIN

-- Change strategy:
ALTER TABLE toast_demo ALTER COLUMN doc SET STORAGE EXTERNAL;

-- Verify:
SELECT attname, attstorage
FROM pg_attribute
WHERE attrelid = 'toast_demo'::regclass AND attnum > 0;

-- ============================================================
-- 4. TOAST COMPRESSION (PG14+)
-- ============================================================

SHOW default_toast_compression;

-- Change default:
-- SET default_toast_compression = 'lz4';

-- Per-column compression:
-- ALTER TABLE toast_demo ALTER COLUMN doc SET COMPRESSION lz4;

-- ============================================================
-- 5. GROWTH TRACKING — SNAPSHOT TABLE
-- ============================================================

CREATE TABLE db_size_log (
    snapshot_date DATE PRIMARY KEY DEFAULT CURRENT_DATE,
    db_size_bytes BIGINT NOT NULL
);

-- Record a snapshot:
INSERT INTO db_size_log (db_size_bytes)
VALUES (pg_database_size(current_database()))
ON CONFLICT (snapshot_date) DO UPDATE
    SET db_size_bytes = EXCLUDED.db_size_bytes;

-- View snapshots:
SELECT snapshot_date,
       pg_size_pretty(db_size_bytes) AS size
FROM db_size_log
ORDER BY snapshot_date;

-- ============================================================
-- 6. GROWTH RATE AND PROJECTION
-- ============================================================

SELECT
    pg_size_pretty(max(db_size_bytes)) AS current_size,
    pg_size_pretty(
        (max(db_size_bytes) - min(db_size_bytes))
        / GREATEST(max(snapshot_date) - min(snapshot_date), 1)
    ) AS avg_daily_growth,
    pg_size_pretty(
        max(db_size_bytes) + (
            (max(db_size_bytes) - min(db_size_bytes))
            / GREATEST(max(snapshot_date) - min(snapshot_date), 1)
        ) * 90
    ) AS projected_90_days
FROM db_size_log;

-- ============================================================
-- 7. PER-TABLE GROWTH ESTIMATION
-- ============================================================

SELECT
    schemaname || '.' || relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS current_size,
    n_tup_ins AS total_inserts,
    CASE WHEN (now() - stats_reset) > '1 day'
         THEN round(n_tup_ins / EXTRACT(day FROM now() - stats_reset))
         ELSE n_tup_ins END AS inserts_per_day,
    stats_reset::date AS since
FROM pg_stat_user_tables
WHERE n_tup_ins > 0
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;

-- ============================================================
-- 8. CAPACITY PLANNING WORKSHEET
-- ============================================================

WITH disk_info AS (
    SELECT
        sum(pg_database_size(datname)) AS total_data,
        500::bigint * 1024 * 1024 * 1024 AS disk_capacity
    FROM pg_database
),
wal_info AS (
    SELECT sum(size) AS wal_size FROM pg_ls_waldir()
)
SELECT
    pg_size_pretty(d.total_data) AS data_size,
    pg_size_pretty(w.wal_size) AS wal_size,
    pg_size_pretty(d.total_data + w.wal_size) AS total_used,
    pg_size_pretty(d.disk_capacity) AS disk_total,
    round(100.0 * (d.total_data + w.wal_size) / d.disk_capacity, 1) AS pct_used
FROM disk_info d, wal_info w;

-- ============================================================
-- 9. HIDDEN DISK CONSUMERS
-- ============================================================

-- Replication slots (inactive slots prevent WAL cleanup!):
SELECT slot_name, active, pg_size_pretty(pg_wal_lsn_diff(
    pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots;

-- Drop an abandoned slot:
-- SELECT pg_drop_replication_slot('slot_name');

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create table with TEXT column, insert 100B, 5KB, 50KB rows
--    Compare pg_relation_size vs pg_table_size
-- 2. Check TOAST strategies: SELECT attname, attstorage FROM pg_attribute
-- 3. Create db_size_log and insert a snapshot
-- 4. Run per-table growth estimation query
-- 5. Calculate disk usage percentage

-- ============================================================
-- CLEANUP (optional)
-- ============================================================
-- DROP TABLE toast_demo;
-- DROP TABLE db_size_log;
