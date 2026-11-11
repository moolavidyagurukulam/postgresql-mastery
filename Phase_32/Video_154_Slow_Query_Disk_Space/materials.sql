-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Scenario: Slow Query & Disk Space (Classes 274-275)
-- Phase 32: Real-World Scenarios
-- ============================================================

-- ============================================================
-- SCENARIO 1: SLOW QUERY DIAGNOSIS & FIX
-- ============================================================

-- ============================================================
-- 1. DETECT — Find the slow query
-- ============================================================

-- Find active queries running > 2 seconds:
SELECT pid, now() - query_start AS duration,
  state, left(query, 80) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '2 seconds'
ORDER BY duration DESC;

-- ============================================================
-- 2. DIAGNOSE — EXPLAIN ANALYZE
-- ============================================================

-- Run EXPLAIN ANALYZE on the slow query:
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT o.id, o.total, u.name
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.user_id = 42 AND o.status = 'pending';

-- Key things to look for in EXPLAIN output:
-- Seq Scan      → missing index (should be Index Scan)
-- Rows Removed  → high number means scanning too many rows
-- Buffers read  → high disk reads (data not in cache)
-- Nested Loop   → check inner side for seq scans
-- Sort          → check if can be avoided with index

-- ============================================================
-- 3. FIX — Create index (CONCURRENTLY in production!)
-- ============================================================

-- Create composite index without locking writes:
CREATE INDEX CONCURRENTLY idx_orders_user_status
  ON orders (user_id, status);

-- Verify fix:
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.id, o.total, u.name
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.user_id = 42 AND o.status = 'pending';
-- Should show Index Scan, < 1 ms

-- ============================================================
-- 4. PREVENT — Monitoring for slow queries
-- ============================================================

-- Enable slow query logging (log queries > 1 second):
ALTER SYSTEM SET log_min_duration_statement = 1000;
SELECT pg_reload_conf();

-- Enable pg_stat_statements:
-- Add to shared_preload_libraries in postgresql.conf:
-- shared_preload_libraries = 'pg_stat_statements'
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Top queries by total execution time:
SELECT left(query, 60) AS query,
  calls,
  round(total_exec_time::numeric, 1) AS total_ms,
  round(mean_exec_time::numeric, 1) AS mean_ms,
  rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Top queries by mean execution time:
SELECT left(query, 60) AS query,
  calls,
  round(mean_exec_time::numeric, 1) AS mean_ms,
  rows
FROM pg_stat_statements
WHERE calls > 100
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Tables with high sequential scans (need indexes):
SELECT schemaname, relname,
  seq_scan, idx_scan,
  CASE WHEN seq_scan + idx_scan > 0
    THEN round(100.0 * idx_scan / (seq_scan + idx_scan), 1)
  END AS idx_usage_pct
FROM pg_stat_user_tables
WHERE seq_scan > 1000
ORDER BY seq_scan DESC
LIMIT 10;

-- Reset statistics after review:
-- SELECT pg_stat_statements_reset();

-- ============================================================
-- SCENARIO 2: DATABASE RUNNING OUT OF DISK SPACE
-- ============================================================

-- ============================================================
-- 1. DETECT — Check database size
-- ============================================================

-- Total database size:
SELECT pg_size_pretty(pg_database_size('myapp')) AS db_size;

-- All database sizes:
SELECT datname,
  pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;

-- ============================================================
-- 2. DIAGNOSE — Find where space is used
-- ============================================================

-- Largest tables (data + indexes + toast):
SELECT schemaname || '.' || tablename AS table_name,
  pg_size_pretty(pg_total_relation_size(
    schemaname || '.' || tablename)) AS total,
  pg_size_pretty(pg_relation_size(
    schemaname || '.' || tablename)) AS data,
  pg_size_pretty(pg_indexes_size(
    schemaname || '.' || tablename)) AS indexes
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(
  schemaname || '.' || tablename) DESC
LIMIT 10;

-- Check table bloat (dead tuples):
SELECT schemaname, relname,
  n_live_tup, n_dead_tup,
  CASE WHEN n_live_tup > 0
    THEN round(100.0 * n_dead_tup / (n_live_tup + n_dead_tup), 1)
  END AS dead_pct,
  last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 10;

-- Find unused indexes (wasting space):
SELECT schemaname, relname, indexrelname,
  idx_scan,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND pg_relation_size(indexrelid) > 1048576  -- > 1 MB
ORDER BY pg_relation_size(indexrelid) DESC;

-- Check WAL directory size (from shell):
-- du -sh $PGDATA/pg_wal

-- ============================================================
-- 3. FIX — Reclaim space
-- ============================================================

-- Step 1: VACUUM tables with high dead tuples
-- (Does NOT lock the table, safe for production)
VACUUM VERBOSE orders;

-- Step 2: Archive old data to file
\COPY (SELECT * FROM audit_log
  WHERE created_at < now() - interval '90 days')
  TO '/tmp/audit_archive.csv' CSV HEADER;

-- Step 3: Batched delete (10K at a time, NOT millions at once!)
DELETE FROM audit_log
WHERE ctid IN (
  SELECT ctid FROM audit_log
  WHERE created_at < now() - interval '90 days'
  LIMIT 10000
);
-- Repeat until 0 rows deleted

-- Step 4: VACUUM after deletes to reclaim space
VACUUM VERBOSE audit_log;

-- Step 5: Drop unused indexes
DROP INDEX CONCURRENTLY idx_orders_old_status;

-- Step 6: For extreme cases, pg_repack (online VACUUM FULL):
-- pg_repack -d myapp -t orders

-- ============================================================
-- 4. PREVENT — Tune autovacuum per table
-- ============================================================

-- Set aggressive autovacuum for large, frequently updated tables:
ALTER TABLE orders SET (
  autovacuum_vacuum_scale_factor = 0.01,
  autovacuum_vacuum_threshold = 1000,
  autovacuum_analyze_scale_factor = 0.005
);

-- Verify per-table settings:
SELECT relname, reloptions
FROM pg_class
WHERE relname = 'orders';

-- Check autovacuum is running:
SELECT schemaname, relname,
  last_autovacuum, last_autoanalyze,
  autovacuum_count, autoanalyze_count
FROM pg_stat_user_tables
ORDER BY last_autovacuum DESC NULLS LAST
LIMIT 10;

-- ============================================================
-- 5. VERIFY — Confirm space reclaimed
-- ============================================================

SELECT pg_size_pretty(pg_database_size('myapp')) AS db_size;
-- Should be significantly smaller

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create table with 1M rows. Query without index.
--    EXPLAIN ANALYZE. Add index. EXPLAIN ANALYZE again. Compare.

CREATE TABLE test_orders (
    id SERIAL PRIMARY KEY,
    user_id INT,
    status TEXT,
    total NUMERIC(10,2),
    created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO test_orders (user_id, status, total)
SELECT
    (random() * 10000)::int,
    (ARRAY['pending','shipped','delivered'])[1 + (random()*2)::int],
    (random() * 1000)::numeric(10,2)
FROM generate_series(1, 1000000);

-- Query without index (expect Seq Scan):
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM test_orders
WHERE user_id = 42 AND status = 'pending';

-- Add index:
CREATE INDEX idx_test_orders_user_status
  ON test_orders (user_id, status);

-- Query with index (expect Index Scan):
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM test_orders
WHERE user_id = 42 AND status = 'pending';

-- 2. Create bloat, then VACUUM:
UPDATE test_orders SET total = total + 1 WHERE id <= 500000;
-- Check dead tuples:
SELECT relname, n_live_tup, n_dead_tup FROM pg_stat_user_tables
WHERE relname = 'test_orders';
-- VACUUM:
VACUUM VERBOSE test_orders;

-- 3. Find 5 largest tables:
SELECT schemaname || '.' || tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 5;

-- 4. Find unused indexes:
SELECT indexrelname, idx_scan,
  pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- 5. Set autovacuum on test table:
ALTER TABLE test_orders SET (
  autovacuum_vacuum_scale_factor = 0.01
);

-- Cleanup:
-- DROP TABLE test_orders;
