-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Routine Maintenance Checklist & Schedule (Class 163)
-- Phase 19: Vacuum & Maintenance
-- ============================================================

-- ============================================================
-- DAILY MONITORING QUERIES
-- ============================================================

-- 1. Dead tuple report (tables needing attention):
SELECT relname,
       n_live_tup,
       n_dead_tup,
       ROUND(n_dead_tup::numeric /
         NULLIF(n_live_tup, 0) * 100, 1) AS dead_pct,
       last_autovacuum,
       last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- 2. Database sizes:
SELECT datname,
       pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;

-- 3. Top 10 largest tables:
SELECT relname,
       pg_size_pretty(pg_total_relation_size(relid)) AS total,
       pg_size_pretty(pg_relation_size(relid)) AS table_only,
       pg_size_pretty(pg_indexes_size(relid)) AS indexes
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;

-- 4. WAL directory size:
SELECT count(*) AS wal_files,
       pg_size_pretty(sum(size)) AS wal_total
FROM pg_ls_waldir();

-- 5. Transaction ID age (wraparound risk):
SELECT c.relname,
       age(c.relfrozenxid) AS xid_age,
       CASE
         WHEN age(c.relfrozenxid) > 150000000
           THEN 'WARNING'
         WHEN age(c.relfrozenxid) > 1000000000
           THEN 'CRITICAL'
         ELSE 'OK'
       END AS status
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY age(c.relfrozenxid) DESC
LIMIT 10;

-- 6. Long-running queries (> 5 minutes):
SELECT pid, now() - query_start AS duration,
       state, left(query, 80) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < now() - '5 min'::interval
ORDER BY duration DESC;

-- 7. Idle in transaction (blocks autovacuum!):
SELECT pid, now() - state_change AS idle_time,
       left(query, 80) AS query_preview
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND state_change < now() - '10 min'::interval;

-- ============================================================
-- WEEKLY HEALTH CHECK QUERIES
-- ============================================================

-- Unused indexes (wasting disk and slowing writes):
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size,
       idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND pg_relation_size(indexrelid) > 1024 * 1024
ORDER BY pg_relation_size(indexrelid) DESC;

-- Inactive replication slots (WAL leak!):
SELECT slot_name, active,
       pg_size_pretty(
         pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
       ) AS retained_wal
FROM pg_replication_slots
WHERE NOT active;

-- Tables autovacuum has not touched in 7 days:
SELECT relname, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
WHERE last_autovacuum < now() - '7 days'::interval
   OR last_autovacuum IS NULL
ORDER BY n_dead_tup DESC;

-- Temp file usage (may need higher work_mem):
SELECT datname, temp_files,
       pg_size_pretty(temp_bytes) AS temp_size
FROM pg_stat_database
WHERE temp_bytes > 0;

-- ============================================================
-- MONTHLY MAINTENANCE COMMANDS
-- ============================================================

-- Full database ANALYZE:
ANALYZE (VERBOSE);

-- REINDEX bloat-prone tables (use CONCURRENTLY in production):
REINDEX TABLE CONCURRENTLY orders;

-- pg_repack heavy tables:
-- pg_repack -U postgres -d prod -t orders -t audit_log

-- ============================================================
-- PRODUCTION CRON SCHEDULE
-- ============================================================

-- # Daily health check (6 AM)
-- 0 6 * * * psql -U postgres -d prod -f /scripts/health_check.sql \
--   | mail -s 'PG Daily Health' dba@company.com
--
-- # Daily VACUUM ANALYZE (2 AM)
-- 0 2 * * * psql -U postgres -d prod -c 'VACUUM ANALYZE;'
--
-- # Weekly REINDEX (Sunday 3 AM)
-- 0 3 * * 0 psql -U postgres -d prod -c \
--   "REINDEX TABLE CONCURRENTLY orders;"
--
-- # Monthly pg_repack (1st of month, 4 AM)
-- 0 4 1 * * pg_repack -U postgres -d prod -t orders -t audit_log
--
-- # Monthly full ANALYZE (1st of month, 6 AM)
-- 0 6 1 * * psql -U postgres -d prod -c 'ANALYZE (VERBOSE);'
--
-- # Weekly backup verify (Sunday 1 AM)
-- 0 1 * * 0 pgbackrest --stanza=prod verify

-- ============================================================
-- COMPLETE DAILY HEALTH CHECK SCRIPT
-- ============================================================

-- Save this as /scripts/health_check.sql

-- 1. Bloat check
SELECT '1. BLOAT' AS check_type, relname,
       n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC LIMIT 5;

-- 2. Database sizes
SELECT '2. SIZES' AS check_type, datname,
       pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database WHERE datistemplate = false;

-- 3. XID age
SELECT '3. XID_AGE' AS check_type, c.relname,
       age(c.relfrozenxid) AS xid_age
FROM pg_class c JOIN pg_namespace n
  ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname = 'public'
ORDER BY age(c.relfrozenxid) DESC LIMIT 5;

-- 4. Long-running queries
SELECT '4. LONG_QUERY' AS check_type, pid,
       now() - query_start AS duration
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < now() - '5 min'::interval;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Run the daily health check script on your database.
-- 2. Identify tables where autovacuum has not run in 7 days.
-- 3. Find unused indexes larger than 1 MB.
-- 4. Check transaction ID age for all user tables.
-- 5. Create a cron job to run VACUUM ANALYZE daily at 2 AM.
