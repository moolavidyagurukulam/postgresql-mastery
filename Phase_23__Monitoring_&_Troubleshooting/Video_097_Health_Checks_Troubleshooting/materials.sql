-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Health Checks & Troubleshooting Scenarios (Class 198)
-- Phase 23: Monitoring & Troubleshooting
-- ============================================================

-- ============================================================
-- COMPLETE HEALTH CHECK SCRIPT
-- Save as: pg_health_check.sql
-- Run with: psql -U postgres -d mydb -f pg_health_check.sql
-- ============================================================

\echo '============================================'
\echo '  POSTGRESQL HEALTH CHECK'
\echo '============================================'

\echo ''
\echo '=== 1. SERVER INFO ==='
SELECT
    version() AS pg_version,
    pg_postmaster_start_time() AS started_at,
    now() - pg_postmaster_start_time() AS uptime,
    pg_is_in_recovery() AS is_standby,
    current_database() AS database;

\echo ''
\echo '=== 2. CONNECTION HEALTH ==='
SELECT
    (SELECT setting::int FROM pg_settings
     WHERE name = 'max_connections') AS max_conn,
    count(*) AS total_conn,
    count(*) FILTER (WHERE state = 'active') AS active,
    count(*) FILTER (WHERE state = 'idle') AS idle,
    count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_txn,
    ROUND(100.0 * count(*) / (
      SELECT setting::int FROM pg_settings
      WHERE name = 'max_connections'
    ), 1) AS usage_pct
FROM pg_stat_activity
WHERE backend_type = 'client backend';

\echo ''
\echo '=== 3. CACHE HIT RATIO ==='
SELECT
    ROUND(100.0 * blks_hit /
      NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
    temp_files,
    pg_size_pretty(temp_bytes) AS temp_size,
    deadlocks
FROM pg_stat_database
WHERE datname = current_database();

\echo ''
\echo '=== 4. BLOATED TABLES (dead rows > 10K) ==='
SELECT
    relname AS table_name,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup, 0), 1) AS bloat_pct,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC
LIMIT 5;

\echo ''
\echo '=== 5. LONG RUNNING QUERIES (> 5 min) ==='
SELECT
    pid, usename,
    now() - query_start AS duration,
    state,
    LEFT(query, 60) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '5 minutes'
  AND backend_type = 'client backend'
ORDER BY query_start;

\echo ''
\echo '=== 6. BLOCKED SESSIONS ==='
SELECT
    pid, usename,
    pg_blocking_pids(pid) AS blocked_by,
    now() - query_start AS wait_time,
    LEFT(query, 60) AS query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;

\echo ''
\echo '=== 7. IDLE IN TRANSACTION (> 5 min) ==='
SELECT
    pid, usename,
    now() - xact_start AS txn_age,
    LEFT(query, 60) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - state_change > interval '5 minutes'
ORDER BY xact_start;

\echo ''
\echo '=== 8. UNUSED INDEXES ==='
SELECT
    s.relname AS table_name,
    s.indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(s.indexrelid)) AS size
FROM pg_stat_user_indexes s
JOIN pg_index i ON s.indexrelid = i.indexrelid
WHERE s.idx_scan = 0
  AND NOT i.indisunique
  AND NOT i.indisprimary
ORDER BY pg_relation_size(s.indexrelid) DESC
LIMIT 5;

\echo ''
\echo '=== 9. DATABASE SIZE ==='
SELECT
    pg_size_pretty(pg_database_size(current_database())) AS db_size;

\echo ''
\echo '=== 10. TOP 5 LARGEST TABLES ==='
SELECT
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(oid)) AS total_size
FROM pg_class
WHERE relkind = 'r'
  AND relnamespace = 'public'::regnamespace
ORDER BY pg_total_relation_size(oid) DESC
LIMIT 5;

\echo ''
\echo '=== 11. XID AGE (Wraparound Check) ==='
SELECT
    relname,
    age(relfrozenxid) AS xid_age,
    CASE
      WHEN age(relfrozenxid) > 1000000000 THEN 'CRITICAL'
      WHEN age(relfrozenxid) > 200000000 THEN 'WARNING'
      ELSE 'OK'
    END AS status
FROM pg_class
WHERE relkind = 'r'
ORDER BY age(relfrozenxid) DESC
LIMIT 5;

\echo ''
\echo '============================================'
\echo '  HEALTH CHECK COMPLETE'
\echo '============================================'

-- ============================================================
-- TROUBLESHOOTING QUICK REFERENCE
-- ============================================================

-- SCENARIO 1: Application Timeouts
-- 1. Check pg_stat_activity for blocked sessions
-- 2. Find blocker with pg_blocking_pids
-- 3. Terminate blocker: pg_terminate_backend(pid)
-- 4. Set idle_in_transaction_session_timeout = '5min'

-- SCENARIO 2: Disk Full
-- 1. Check: du -sh pg_wal/ (WAL files)
-- 2. Check: pg_replication_slots for inactive slots
-- 3. Drop inactive: pg_drop_replication_slot('name')
-- 4. Delete old logs: find log/ -mtime +7 -delete
-- 5. Set max_slot_wal_keep_size

-- SCENARIO 3: Sudden Slowness
-- 1. ANALYZE affected tables (refresh statistics)
-- 2. Check n_dead_tup (VACUUM if high)
-- 3. EXPLAIN ANALYZE the slow queries
-- 4. Check pg_indexes (was an index dropped?)

-- SCENARIO 4: Connection Limit
-- 1. Check per-user connection count
-- 2. Terminate old idle connections
-- 3. Fix connection leak in application
-- 4. Deploy pgBouncer for pooling

-- SCENARIO 5: Autovacuum Behind
-- 1. Check n_dead_tup and last_autovacuum
-- 2. Tune per-table: autovacuum_vacuum_scale_factor = 0.01
-- 3. Manual: VACUUM (VERBOSE) table;
-- 4. Check age(relfrozenxid) for wraparound

-- SCENARIO 6: Replication Lag
-- 1. Check pg_stat_replication on primary
-- 2. Check pg_replication_slots (inactive slots)
-- 3. Check standby I/O and network
-- 4. Drop inactive slots if WAL retention is huge

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Run the complete health check script on your server.
--    Note any warnings or issues.
-- 2. Open two sessions. Create a lock conflict scenario.
--    Use the troubleshooting workflow to diagnose and resolve.
-- 3. Check your XID age. Is any table above 200,000,000?
-- 4. Find your largest table. Is it a candidate for partitioning?
-- 5. Set up a cron job to run the health check daily and
--    email the results.
