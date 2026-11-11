-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Scenario Questions & Certifications (Classes 288-289)
-- Phase 33: Interview & Career
-- ============================================================

-- ============================================================
-- SECTION 1: SCENARIO-BASED INTERVIEW QUESTIONS
-- ============================================================

-- ============================================================
-- SCENARIO 1: "The database is slow"
-- ============================================================

-- Step 1: What's running right now?
SELECT pid, now() - query_start AS duration,
    wait_event_type, wait_event,
    state, left(query, 80) AS query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC LIMIT 10;

-- Step 2: Top slow queries by mean time
SELECT left(query, 60) AS query, calls,
    round(mean_exec_time::numeric, 1) AS mean_ms,
    round(total_exec_time::numeric, 1) AS total_ms,
    rows
FROM pg_stat_statements
WHERE calls > 100
ORDER BY mean_exec_time DESC LIMIT 10;

-- Step 3: EXPLAIN the worst query
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT o.id, o.total, u.name
FROM orders o JOIN users u ON o.user_id = u.id
WHERE o.status = 'pending' AND o.created_at > now() - interval '7 days';
-- Look for: Seq Scan, high Rows Removed, Buffers read (disk I/O)

-- Step 4: Fix — add missing index (non-blocking)
CREATE INDEX CONCURRENTLY idx_orders_status_date
    ON orders(status, created_at DESC);

-- Step 5: Verify
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.id, o.total, u.name
FROM orders o JOIN users u ON o.user_id = u.id
WHERE o.status = 'pending' AND o.created_at > now() - interval '7 days';
-- Should show Index Scan instead of Seq Scan

-- Step 6: Prevent — monitor going forward
-- log_min_duration_statement = 1000 (log queries > 1s)
-- Review pg_stat_statements weekly

-- ============================================================
-- SCENARIO 2: "Disk is 95% full"
-- ============================================================

-- Step 1: Database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database ORDER BY pg_database_size(datname) DESC;

-- Step 2: Largest tables
SELECT schemaname || '.' || tablename AS table_name,
    pg_size_pretty(pg_total_relation_size(
        schemaname || '.' || tablename)) AS total
FROM pg_tables WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(
    schemaname || '.' || tablename) DESC LIMIT 10;

-- Step 3: Check WAL accumulation
-- du -sh /var/lib/postgresql/16/main/pg_wal
-- If large: check replication slots
SELECT slot_name, active,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots;

-- Step 4: Check table bloat
SELECT relname, n_dead_tup,
    pg_size_pretty(pg_relation_size(relid)) AS size
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 5;

-- Step 5: Immediate fixes
VACUUM VERBOSE large_table;           -- reclaim dead rows
DROP INDEX CONCURRENTLY idx_unused;   -- drop unused indexes
-- Archive old data:
-- \COPY (SELECT * FROM logs WHERE created_at < '2026-01-01') TO '/archive/old_logs.csv' CSV;
-- DELETE in batches: DELETE FROM logs WHERE ctid IN (SELECT ctid FROM logs WHERE ... LIMIT 10000);

-- ============================================================
-- SCENARIO 3: "Primary server is down at 3 AM"
-- ============================================================

-- Step 1: Verify primary is truly down
-- pg_isready -h primary -p 5432  (try 3 times, 5 seconds apart)
-- ssh primary "systemctl status postgresql"

-- Step 2: Check standby status
SELECT pg_is_in_recovery();  -- TRUE = still standby
SELECT pg_last_xact_replay_timestamp();
SELECT now() - pg_last_xact_replay_timestamp() AS lag;

-- Step 3: Promote standby
-- pg_ctl promote -D /var/lib/postgresql/16/main
-- OR: SELECT pg_promote(wait => true);

-- Step 4: Verify promotion
SELECT pg_is_in_recovery();  -- FALSE = now primary
-- Test write:
CREATE TABLE failover_test (id int);
DROP TABLE failover_test;

-- Step 5: Redirect traffic
-- Update DNS / HAProxy config / app connection string
-- Verify application works

-- Step 6: Build new standby IMMEDIATELY
-- pg_basebackup -h new_primary -U repl_user -D /data -R -P -X stream

-- ============================================================
-- SCENARIO 4: "Developer ran DELETE without WHERE"
-- ============================================================

-- If transaction still open:
-- ROLLBACK;

-- If committed — PITR recovery:
-- 1. Stop PostgreSQL
-- 2. Restore base backup
-- 3. Add to postgresql.conf:
--    restore_command = 'cp /archive/%f %p'
--    recovery_target_time = '2026-11-05 14:55:00'
--    recovery_target_action = 'promote'
-- 4. Create recovery.signal
-- 5. Start PostgreSQL — replays WAL to target time

-- If delayed standby available:
-- pg_dump -h delayed_standby -t orders myapp > /tmp/orders_recovery.sql
-- psql -d myapp -f /tmp/orders_recovery.sql

-- Prevention:
-- REVOKE DELETE ON critical_tables FROM app_user;
-- GRANT DELETE ON orders TO admin_user;  -- only admins can delete
-- SET statement_timeout = '60s';  -- limit query duration

-- ============================================================
-- SCENARIO 5: "Replication lag is growing"
-- ============================================================

-- On PRIMARY:
SELECT client_addr, state, sent_lsn, replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag
FROM pg_stat_replication;

-- On STANDBY: check for blocking queries
SELECT pid, now() - query_start AS duration,
    left(query, 60) AS query
FROM pg_stat_activity
WHERE state = 'active' ORDER BY duration DESC;

-- Fix: cancel blocking query
SELECT pg_cancel_backend(<pid>);

-- If replay is paused:
SELECT pg_is_wal_replay_paused();
SELECT pg_wal_replay_resume();

-- Prevention:
-- max_standby_streaming_delay = 30s  (auto-cancel after 30s)
-- wal_keep_size = 2048  (retain WAL for catch-up)

-- ============================================================
-- SCENARIO 6: "Connection limit reached"
-- ============================================================

-- Immediate: find and kill leaked connections
SELECT pid, state, now() - state_change AS idle_time
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY idle_time DESC;

SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
    AND now() - state_change > interval '5 minutes';

-- Diagnose: who is using all connections?
SELECT usename, application_name, state, count(*)
FROM pg_stat_activity
GROUP BY usename, application_name, state
ORDER BY count DESC;

-- Long-term: deploy PgBouncer
-- pool_mode = transaction
-- max_client_conn = 1000
-- default_pool_size = 25

-- Prevention:
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';
ALTER ROLE app_user CONNECTION LIMIT 100;
SELECT pg_reload_conf();

-- ============================================================
-- SECTION 2: CERTIFICATIONS & RESOURCES
-- ============================================================

-- Certifications:
-- 1. EDB PostgreSQL Associate — entry level
--    Topics: SQL, basic admin, backup, monitoring
--    https://www.enterprisedb.com/training
--
-- 2. EDB PostgreSQL Professional — advanced
--    Topics: replication, HA, performance, security
--
-- 3. AWS Database Specialty
--    Topics: RDS, Aurora, migration, multi-AZ
--
-- 4. Google Cloud Professional Data Engineer
--    Topics: Cloud SQL, AlloyDB, data pipelines

-- Learning Resources:
-- 1. Official docs: postgresql.org/docs/16/
-- 2. pgexercises.com — interactive SQL practice
-- 3. Books:
--    - PostgreSQL Up and Running (Obe & Hsu)
--    - The Art of PostgreSQL (Dimitri Fontaine)
--    - Mastering PostgreSQL (Hans-Jürgen Schönig)
-- 4. Community:
--    - pgsql-general mailing list
--    - PostgreSQL Slack (postgresteam.slack.com)
--    - Stack Overflow [postgresql] tag
-- 5. Conferences:
--    - PGConf.dev, PGConf EU, PGConf India
--    - PGDay events worldwide

-- Career Paths:
-- DBA: $90K-$180K (experience dependent)
-- Database Developer: $80K-$160K
-- Data Engineer: $100K-$200K
-- Cloud DB Engineer: $110K-$190K
-- SRE with DB focus: $120K-$200K

-- ============================================================
-- PORTFOLIO CHECKLIST
-- ============================================================

-- GitHub Portfolio:
-- [ ] Library Management System (schema + functions + queries)
-- [ ] E-Commerce Database (schema + triggers + reports)
-- [ ] Multi-Tenant SaaS (RLS + partitioning)
-- [ ] HA Cluster Setup (Patroni + etcd + HAProxy)
-- [ ] DBA Monitoring Scripts (daily health check)
-- [ ] Blog posts (EXPLAIN ANALYZE, replication, bloat)

-- Interview Prep Checklist:
-- [ ] Explain MVCC in 30 seconds
-- [ ] Write a blocking query diagnostic from memory
-- [ ] Explain EXPLAIN ANALYZE output
-- [ ] Walk through a failover scenario step by step
-- [ ] Describe PgBouncer architecture and configuration
-- [ ] Explain RLS for multi-tenancy
-- [ ] Compare physical vs logical replication
-- [ ] Describe your backup and recovery strategy

-- ============================================================
-- CONGRATULATIONS!
-- ============================================================

-- You have completed PostgreSQL Mastery — 289 classes!
-- From SELECT * to production HA clusters.
-- You are ready for:
--   - DBA interviews
--   - Production PostgreSQL management
--   - Building data-driven applications
--   - Contributing to the PostgreSQL community
--
-- Thank you for learning with us.
-- Good luck on your PostgreSQL journey!
