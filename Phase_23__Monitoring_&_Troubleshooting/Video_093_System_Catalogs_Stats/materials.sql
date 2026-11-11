-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- System Catalogs & Statistics Views (Classes 190-191)
-- Phase 23: Monitoring & Troubleshooting
-- ============================================================

-- ============================================================
-- 1. SYSTEM CATALOGS — Structure
-- ============================================================

-- All user tables with size:
SELECT
    relname AS table_name,
    relkind AS type,
    relpages AS pages,
    reltuples::bigint AS est_rows,
    pg_size_pretty(pg_total_relation_size(oid)) AS total_size
FROM pg_class
WHERE relnamespace = 'public'::regnamespace
  AND relkind = 'r'
ORDER BY pg_total_relation_size(oid) DESC;

-- All schemas:
SELECT nspname AS schema_name,
       nspowner::regrole AS owner
FROM pg_namespace
WHERE nspname NOT LIKE 'pg_%'
  AND nspname != 'information_schema';

-- Columns of a table:
SELECT
    a.attname AS column_name,
    pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
    a.attnotnull AS not_null,
    pg_get_expr(d.adbin, d.adrelid) AS default_value
FROM pg_attribute a
LEFT JOIN pg_attrdef d
    ON a.attrelid = d.adrelid AND a.attnum = d.adnum
WHERE a.attrelid = 'orders'::regclass
  AND a.attnum > 0
  AND NOT a.attisdropped
ORDER BY a.attnum;

-- All indexes on a table:
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'orders';

-- Invalid indexes:
SELECT c.relname AS index_name, i.indisvalid
FROM pg_index i
JOIN pg_class c ON i.indexrelid = c.oid
WHERE NOT i.indisvalid;

-- ============================================================
-- 2. STATISTICS VIEWS — Performance
-- ============================================================

-- Table health dashboard:
SELECT
    relname AS table_name,
    seq_scan, idx_scan,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    ROUND(100.0 * n_dead_tup /
      NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
    last_vacuum, last_autovacuum, last_analyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Tables needing indexes (high seq_scan, no idx_scan):
SELECT
    relname AS table_name,
    seq_scan, seq_tup_read,
    idx_scan, idx_tup_fetch,
    pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_stat_user_tables
WHERE seq_scan > 100
  AND (idx_scan IS NULL OR idx_scan = 0)
  AND pg_total_relation_size(relid) > 1024 * 1024
ORDER BY seq_tup_read DESC;

-- Unused indexes:
SELECT
    s.relname AS table_name,
    s.indexrelname AS index_name,
    s.idx_scan AS times_used,
    pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size
FROM pg_stat_user_indexes s
JOIN pg_index i ON s.indexrelid = i.indexrelid
WHERE s.idx_scan = 0
  AND NOT i.indisunique
  AND NOT i.indisprimary
ORDER BY pg_relation_size(s.indexrelid) DESC;

-- ============================================================
-- 3. DATABASE-LEVEL STATS
-- ============================================================

SELECT
    datname AS database,
    numbackends AS connections,
    xact_commit AS commits,
    xact_rollback AS rollbacks,
    blks_read, blks_hit,
    ROUND(100.0 * blks_hit /
      NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
    temp_files,
    pg_size_pretty(temp_bytes) AS temp_size,
    deadlocks, conflicts
FROM pg_stat_database
WHERE datname = current_database();

-- ============================================================
-- 4. TABLE I/O STATISTICS
-- ============================================================

SELECT
    relname AS table_name,
    heap_blks_read AS disk_reads,
    heap_blks_hit AS cache_hits,
    ROUND(100.0 * heap_blks_hit /
      NULLIF(heap_blks_hit + heap_blks_read, 0), 2) AS cache_hit_pct
FROM pg_statio_user_tables
WHERE heap_blks_read + heap_blks_hit > 100
ORDER BY heap_blks_read DESC
LIMIT 10;

-- ============================================================
-- 5. BLOAT DETECTION
-- ============================================================

SELECT
    relname AS table_name,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    ROUND(100.0 * n_dead_tup /
      NULLIF(n_live_tup, 0), 1) AS bloat_pct,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- ============================================================
-- 6. BACKGROUND WRITER & CHECKPOINTS
-- ============================================================

SELECT
    checkpoints_timed, checkpoints_req,
    buffers_checkpoint, buffers_clean, buffers_backend,
    ROUND(100.0 * buffers_backend /
      NULLIF(buffers_checkpoint + buffers_clean + buffers_backend, 0), 1)
      AS backend_write_pct,
    maxwritten_clean
FROM pg_stat_bgwriter;

-- ============================================================
-- 7. RESETTING STATISTICS
-- ============================================================

-- Reset current database stats:
-- SELECT pg_stat_reset();

-- Reset single table:
-- SELECT pg_stat_reset_single_table_counters('orders'::regclass::oid);

-- Check when stats were last reset:
SELECT stats_reset
FROM pg_stat_database
WHERE datname = current_database();

-- Server uptime:
SELECT pg_postmaster_start_time() AS started,
       now() - pg_postmaster_start_time() AS uptime;

-- ============================================================
-- 8. QUICK HEALTH CHECK QUERY
-- ============================================================

SELECT 'Cache Hit Ratio' AS metric,
  ROUND(100.0 * sum(blks_hit) /
    NULLIF(sum(blks_hit) + sum(blks_read), 0), 2) || '%' AS value
FROM pg_stat_database WHERE datname = current_database()
UNION ALL
SELECT 'Active Connections', count(*)::text
FROM pg_stat_activity WHERE state = 'active'
UNION ALL
SELECT 'Database Size',
  pg_size_pretty(pg_database_size(current_database()))
UNION ALL
SELECT 'Temp Files', temp_files::text
FROM pg_stat_database WHERE datname = current_database();

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Query pg_class to list all tables in your database.
--    Which is the largest?
-- 2. Check pg_stat_user_tables for tables with high seq_scan.
--    Do they have indexes? If not, what columns would you index?
-- 3. Find unused indexes using pg_stat_user_indexes.
--    How much disk space could you recover?
-- 4. Check your database cache hit ratio. Is it above 99%?
-- 5. Run the quick health check query. Note any warnings.
