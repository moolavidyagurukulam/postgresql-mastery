-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- VACUUM FULL & AUTOVACUUM (Classes 158-159)
-- Phase 19: Vacuum & Maintenance
-- ============================================================

-- ============================================================
-- 1. VACUUM FULL DEMO
-- ============================================================

-- Create and bloat a table:
CREATE TABLE full_test (
    id SERIAL PRIMARY KEY,
    data TEXT
);
INSERT INTO full_test (data)
SELECT 'Row ' || g FROM generate_series(1, 50000) AS g;

-- Create bloat (3 rounds of updates):
UPDATE full_test SET data = 'V2: ' || id;
UPDATE full_test SET data = 'V3: ' || id;
UPDATE full_test SET data = 'V4: ' || id;

-- Check size before:
SELECT pg_size_pretty(pg_relation_size('full_test')) AS before_size;

-- Regular VACUUM (does NOT shrink):
VACUUM full_test;
SELECT pg_size_pretty(pg_relation_size('full_test')) AS after_vacuum;

-- VACUUM FULL (DOES shrink, but LOCKS table):
VACUUM FULL full_test;
SELECT pg_size_pretty(pg_relation_size('full_test')) AS after_full;

-- ============================================================
-- 2. AUTOVACUUM CONFIGURATION
-- ============================================================

-- Check if autovacuum is enabled:
SHOW autovacuum;

-- View all autovacuum settings:
SHOW autovacuum_vacuum_threshold;
SHOW autovacuum_vacuum_scale_factor;
SHOW autovacuum_analyze_threshold;
SHOW autovacuum_analyze_scale_factor;
SHOW autovacuum_max_workers;
SHOW autovacuum_naptime;
SHOW autovacuum_vacuum_cost_delay;
SHOW autovacuum_vacuum_cost_limit;

-- ============================================================
-- 3. PER-TABLE AUTOVACUUM TUNING
-- ============================================================

-- Lower scale factor for large tables:
ALTER TABLE orders SET (
    autovacuum_vacuum_scale_factor = 0.02,
    autovacuum_vacuum_threshold = 1000
);

-- Fixed threshold for very large tables:
ALTER TABLE audit_log SET (
    autovacuum_vacuum_scale_factor = 0,
    autovacuum_vacuum_threshold = 10000
);

-- Tune ANALYZE for large tables:
ALTER TABLE orders SET (
    autovacuum_analyze_scale_factor = 0.01,
    autovacuum_analyze_threshold = 500
);

-- Check per-table settings:
SELECT relname, reloptions
FROM pg_class
WHERE reloptions IS NOT NULL
  AND relkind = 'r';

-- Remove per-table overrides:
ALTER TABLE orders RESET (
    autovacuum_vacuum_scale_factor,
    autovacuum_vacuum_threshold
);

-- ============================================================
-- 4. MONITORING AUTOVACUUM
-- ============================================================

-- Check last vacuum/autovacuum per table:
SELECT relname,
       n_dead_tup,
       last_vacuum,
       last_autovacuum,
       autovacuum_count,
       vacuum_count
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Check if autovacuum is currently running:
SELECT pid, datname, relid::regclass AS table_name,
       phase, heap_blks_scanned, heap_blks_total
FROM pg_stat_progress_vacuum;

-- Check last analyze times:
SELECT relname, last_analyze, last_autoanalyze,
       analyze_count, autoanalyze_count
FROM pg_stat_user_tables
ORDER BY last_autoanalyze DESC NULLS LAST;

-- ============================================================
-- 5. TRANSACTION ID WRAPAROUND MONITORING
-- ============================================================

-- Per-table xid age:
SELECT c.relname,
       age(c.relfrozenxid) AS xid_age,
       CASE
         WHEN age(c.relfrozenxid) > 150000000 THEN 'WARNING'
         WHEN age(c.relfrozenxid) > 1000000000 THEN 'CRITICAL'
         ELSE 'OK'
       END AS status
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY age(c.relfrozenxid) DESC;

-- Database-level check:
SELECT datname, age(datfrozenxid) AS db_xid_age
FROM pg_database
ORDER BY age(datfrozenxid) DESC;

-- ============================================================
-- 6. PRODUCTION AUTOVACUUM CONFIG (postgresql.conf)
-- ============================================================

-- autovacuum = on
-- autovacuum_max_workers = 5
-- autovacuum_naptime = 30s
-- autovacuum_vacuum_cost_delay = 2ms
-- autovacuum_vacuum_cost_limit = 800
-- maintenance_work_mem = 512MB

-- ============================================================
-- 7. CLEANUP
-- ============================================================

DROP TABLE IF EXISTS full_test;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a bloated table (50K rows, 3x UPDATE). Compare size
--    after VACUUM vs VACUUM FULL.
-- 2. Check AUTOVACUUM settings with SHOW commands.
-- 3. Set per-table autovacuum_vacuum_scale_factor = 0.01 on a table.
-- 4. Query pg_stat_user_tables to check last_autovacuum times.
-- 5. Check transaction ID age with age(relfrozenxid).
