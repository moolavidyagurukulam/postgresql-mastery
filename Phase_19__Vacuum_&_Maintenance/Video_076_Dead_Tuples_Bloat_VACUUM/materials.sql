-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Dead Tuples, Bloat & VACUUM (Classes 156-157)
-- Phase 19: Vacuum & Maintenance
-- ============================================================

-- ============================================================
-- 1. DEMO SETUP — CREATE BLOAT
-- ============================================================

CREATE TABLE bloat_test (
    id SERIAL PRIMARY KEY,
    data TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO bloat_test (data)
SELECT 'Original row ' || g
FROM generate_series(1, 10000) AS g;

-- Check initial size:
SELECT pg_size_pretty(pg_relation_size('bloat_test')) AS table_size;

-- ============================================================
-- 2. GENERATE DEAD TUPLES
-- ============================================================

-- Every UPDATE creates dead tuples:
UPDATE bloat_test SET data = 'Updated row ' || id, updated_at = now();

-- Check dead tuples:
SELECT relname,
       n_live_tup,
       n_dead_tup,
       ROUND(n_dead_tup::numeric / NULLIF(n_live_tup, 0) * 100, 1)
         AS dead_pct
FROM pg_stat_user_tables
WHERE relname = 'bloat_test';

-- More rounds of updates = more bloat:
UPDATE bloat_test SET data = 'Round 2: ' || id;
UPDATE bloat_test SET data = 'Round 3: ' || id;

-- DELETE also creates dead tuples:
DELETE FROM bloat_test WHERE id <= 5000;

-- ============================================================
-- 3. VACUUM — CLEAN DEAD TUPLES
-- ============================================================

-- Basic VACUUM (entire database):
VACUUM;

-- VACUUM a specific table:
VACUUM bloat_test;

-- VACUUM with verbose output:
VACUUM (VERBOSE) bloat_test;

-- VACUUM + ANALYZE (clean + update statistics):
VACUUM ANALYZE bloat_test;

-- VACUUM specific columns:
VACUUM ANALYZE bloat_test (data, updated_at);

-- VACUUM with parallel workers (PG 13+):
VACUUM (PARALLEL 4) bloat_test;

-- VACUUM FREEZE (prevent transaction ID wraparound):
VACUUM (FREEZE) bloat_test;

-- ============================================================
-- 4. MONITORING DEAD TUPLES
-- ============================================================

-- Dead tuple report for all tables:
SELECT schemaname, relname,
       n_live_tup,
       n_dead_tup,
       ROUND(n_dead_tup::numeric / NULLIF(n_live_tup, 0) * 100, 1)
         AS dead_pct,
       last_vacuum,
       last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 0
ORDER BY n_dead_tup DESC;

-- Table size vs estimated live data:
SELECT relname,
       pg_size_pretty(pg_relation_size(relid)) AS table_size,
       n_live_tup,
       n_dead_tup
FROM pg_stat_user_tables
ORDER BY pg_relation_size(relid) DESC;

-- ============================================================
-- 5. FREE SPACE MAP & VISIBILITY MAP
-- ============================================================

-- Install extensions (run as superuser):
CREATE EXTENSION IF NOT EXISTS pg_freespace;
CREATE EXTENSION IF NOT EXISTS pg_visibility;

-- Check free space per page:
SELECT * FROM pg_freespace('bloat_test') LIMIT 20;

-- Check visibility map:
SELECT * FROM pg_visibility('bloat_test') LIMIT 20;

-- ============================================================
-- 6. CLEANUP
-- ============================================================

DROP TABLE IF EXISTS bloat_test;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a table with 50,000 rows. Check size with pg_relation_size.
-- 2. UPDATE all rows. Check n_dead_tup in pg_stat_user_tables.
-- 3. Run VACUUM (VERBOSE). Verify n_dead_tup = 0.
-- 4. Confirm table size did NOT shrink after VACUUM.
-- 5. INSERT new rows — verify they reuse space (table does not grow).
