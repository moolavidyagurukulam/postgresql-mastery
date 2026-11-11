-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- ANALYZE, REINDEX & pg_repack (Classes 160-162)
-- Phase 19: Vacuum & Maintenance
-- ============================================================

-- ============================================================
-- 1. ANALYZE — UPDATE PLANNER STATISTICS
-- ============================================================

-- Analyze entire database:
ANALYZE;

-- Analyze a specific table:
ANALYZE stats_test;

-- Analyze specific columns:
ANALYZE stats_test (category, amount);

-- Verbose output:
ANALYZE (VERBOSE) stats_test;

-- ============================================================
-- 2. DEMO: STALE STATISTICS → BAD QUERY PLANS
-- ============================================================

CREATE TABLE stats_test (
    id SERIAL PRIMARY KEY,
    category TEXT,
    amount NUMERIC
);

INSERT INTO stats_test (category, amount)
SELECT
    CASE (random() * 3)::int
      WHEN 0 THEN 'electronics'
      WHEN 1 THEN 'clothing'
      WHEN 2 THEN 'food'
      ELSE 'other'
    END,
    (random() * 1000)::numeric(10,2)
FROM generate_series(1, 100000);

CREATE INDEX idx_stats_category ON stats_test(category);

-- Before ANALYZE — planner has no stats:
EXPLAIN SELECT * FROM stats_test WHERE category = 'electronics';
-- Shows: Seq Scan, rows=1 (wrong!)

-- After ANALYZE — planner has accurate stats:
ANALYZE stats_test;
EXPLAIN SELECT * FROM stats_test WHERE category = 'electronics';
-- Shows: Bitmap Index Scan, rows=~25000 (correct!)

-- ============================================================
-- 3. STATISTICS TARGET
-- ============================================================

-- Increase statistics target for a column:
ALTER TABLE stats_test
  ALTER COLUMN category SET STATISTICS 500;
-- Default: 100, Max: 10000
-- Higher = more accurate stats for columns with many distinct values

-- Re-analyze after changing target:
ANALYZE stats_test;

-- Check current stats target:
SELECT attname, attstattarget
FROM pg_attribute
WHERE attrelid = 'stats_test'::regclass
  AND attnum > 0;

-- View collected statistics:
SELECT attname, n_distinct, most_common_vals, most_common_freqs
FROM pg_stats
WHERE tablename = 'stats_test' AND attname = 'category';

-- ============================================================
-- 4. REINDEX — REBUILD INDEXES
-- ============================================================

-- Rebuild a single index:
REINDEX INDEX idx_stats_category;

-- Rebuild ALL indexes on a table:
REINDEX TABLE stats_test;

-- Rebuild all indexes in a schema:
REINDEX SCHEMA public;

-- Rebuild all indexes in the database:
REINDEX DATABASE trigger_lab;

-- CONCURRENTLY — no write lock (production safe):
REINDEX INDEX CONCURRENTLY idx_stats_category;
REINDEX TABLE CONCURRENTLY stats_test;

-- Verbose output:
REINDEX (VERBOSE) TABLE stats_test;

-- ============================================================
-- 5. DETECTING INDEX BLOAT
-- ============================================================

-- Index sizes and usage:
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
       idx_scan,
       idx_tup_read
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Detailed bloat analysis with pgstattuple:
CREATE EXTENSION IF NOT EXISTS pgstattuple;
SELECT * FROM pgstatindex('idx_stats_category');

-- ============================================================
-- 6. pg_repack — ONLINE TABLE REORGANIZATION
-- ============================================================

-- Install (OS level):
-- Ubuntu/Debian: sudo apt install postgresql-16-repack
-- RHEL/CentOS:   sudo dnf install pg_repack_16

-- Create extension:
CREATE EXTENSION pg_repack;

-- Repack a single table:
-- pg_repack -U postgres -d trigger_lab -t bloat_test

-- Repack ALL tables:
-- pg_repack -U postgres -d trigger_lab

-- Repack only indexes:
-- pg_repack -U postgres -d trigger_lab -t bloat_test --only-indexes

-- Repack a specific index:
-- pg_repack -U postgres -d trigger_lab -i idx_stats_category

-- Dry run:
-- pg_repack -U postgres -d trigger_lab -t bloat_test --dry-run

-- Parallel workers:
-- pg_repack -U postgres -d trigger_lab -t bloat_test -j 4

-- ============================================================
-- 7. BLOAT DETECTION QUERIES
-- ============================================================

-- Table bloat report:
SELECT schemaname, relname,
       n_live_tup,
       n_dead_tup,
       ROUND(n_dead_tup::numeric /
         NULLIF(n_live_tup + n_dead_tup, 0) * 100, 1)
         AS bloat_pct,
       pg_size_pretty(pg_total_relation_size(relid))
         AS total_size,
       last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- Unused indexes (consider dropping):
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size,
       idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;

-- ============================================================
-- 8. CLEANUP
-- ============================================================

DROP TABLE IF EXISTS stats_test;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create table with 100K rows, add index. EXPLAIN before/after ANALYZE.
-- 2. ALTER COLUMN SET STATISTICS 500, re-ANALYZE, compare pg_stats.
-- 3. REINDEX TABLE CONCURRENTLY on a table. Compare index size before/after.
-- 4. Install pg_repack, CREATE EXTENSION, repack a bloated table.
-- 5. Run the bloat detection query — identify tables needing maintenance.
