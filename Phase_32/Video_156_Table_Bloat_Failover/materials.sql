-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Scenario: Table Bloat & Primary Server Failover (Classes 278-279)
-- Phase 32: Real-World Scenarios
-- ============================================================

-- ============================================================
-- SCENARIO 1: TABLE BLOAT
-- ============================================================

-- ============================================================
-- 1. DETECT — Measure bloat
-- ============================================================

-- Check dead tuple percentage per table:
SELECT relname,
  pg_size_pretty(pg_relation_size(oid)) AS table_size,
  n_live_tup, n_dead_tup,
  round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 1) AS dead_pct
FROM pg_stat_user_tables JOIN pg_class ON relname = pg_class.relname
WHERE schemaname = 'public'
ORDER BY pg_relation_size(pg_class.oid) DESC LIMIT 10;

-- Exact bloat measurement with pgstattuple extension:
CREATE EXTENSION IF NOT EXISTS pgstattuple;
SELECT * FROM pgstattuple('orders');
-- dead_tuple_percent > 20% = significant bloat

-- Check when autovacuum last ran:
SELECT relname, last_autovacuum, last_autoanalyze,
  autovacuum_count
FROM pg_stat_user_tables
WHERE relname IN ('orders', 'sessions')
ORDER BY relname;

-- ============================================================
-- 2. DIAGNOSE — Find root cause
-- ============================================================

-- Check for long-running transactions blocking VACUUM:
SELECT pid, xact_start, now() - xact_start AS age,
  state, left(query, 50) AS query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_start LIMIT 5;

-- Check oldest transaction ID (wraparound risk):
SELECT max(age(backend_xmin)) AS oldest_xmin_age
FROM pg_stat_activity
WHERE backend_xmin IS NOT NULL;
-- Alert if > 1,000,000 (approaching wraparound)

-- Check autovacuum workers currently running:
SELECT pid, datname, relid::regclass AS table_name,
  phase, heap_blks_total, heap_blks_scanned
FROM pg_stat_progress_vacuum;

-- ============================================================
-- 3. FIX — Reclaim bloated space
-- ============================================================

-- Step 1: Kill blocking transactions
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - xact_start > interval '1 hour';

-- Step 2: VACUUM (reclaims space, does NOT shrink file)
VACUUM VERBOSE orders;

-- Step 3: For severe bloat, use pg_repack (online rebuild)
-- Install: sudo apt install postgresql-16-repack
-- CREATE EXTENSION pg_repack;  -- on each database
-- From shell:
-- pg_repack -d myapp -t sessions
-- pg_repack -d myapp -t orders --no-order

-- VACUUM FULL — locks table, use only in maintenance window:
-- VACUUM FULL sessions;  -- DO NOT USE IN PRODUCTION

-- ============================================================
-- 4. PREVENT — Tune autovacuum per table
-- ============================================================

-- Aggressive autovacuum for large, busy tables:
ALTER TABLE orders SET (
  autovacuum_vacuum_scale_factor = 0.01,    -- trigger at 1% dead (default 20%)
  autovacuum_vacuum_cost_delay = 2,         -- less sleeping (default 2ms in PG16)
  autovacuum_vacuum_cost_limit = 1000       -- more work per cycle (default 200)
);

ALTER TABLE sessions SET (
  autovacuum_vacuum_scale_factor = 0.01,
  autovacuum_vacuum_threshold = 500
);

-- Auto-kill forgotten transactions:
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';
SELECT pg_reload_conf();

-- Verify per-table autovacuum settings:
SELECT relname, reloptions
FROM pg_class
WHERE relname IN ('orders', 'sessions');

-- Monitor bloat regularly:
-- Schedule weekly: pgstattuple check on large tables
-- Alert if dead_tuple_percent > 20%

-- ============================================================
-- SCENARIO 2: PRIMARY SERVER FAILOVER
-- ============================================================

-- ============================================================
-- 1. DETECT — Primary is down
-- ============================================================

-- From shell: check if primary responds
-- pg_isready -h 10.0.1.10 -p 5432
-- Expected: "no response" if primary is down

-- Check standby status:
-- On STANDBY:
SELECT pg_is_in_recovery();  -- TRUE = still standby
SELECT pg_last_xact_replay_timestamp();  -- how recent
SELECT now() - pg_last_xact_replay_timestamp() AS lag;

-- ============================================================
-- 2. MANUAL FAILOVER — Promote standby
-- ============================================================

-- Step 1: Confirm primary is truly down (try multiple times)
-- pg_isready -h 10.0.1.10 -p 5432  (try 3 times, 5 sec apart)
-- ssh primary_server "systemctl status postgresql"
-- NEVER promote if primary might be alive (split brain!)

-- Step 2: Promote the standby
-- pg_ctl promote -D /var/lib/postgresql/16/main
-- OR from SQL:
SELECT pg_promote(wait => true, wait_seconds => 60);

-- Step 3: Verify promotion
SELECT pg_is_in_recovery();  -- FALSE = now a primary
-- Test a write:
CREATE TABLE failover_test (id int);
DROP TABLE failover_test;

-- ============================================================
-- 3. REDIRECT APPLICATION TRAFFIC
-- ============================================================

-- Option A: Update DNS (if using DNS for DB host)
-- Update db.myapp.com A record → 10.0.1.20
-- Set low TTL (30 seconds) BEFORE you expect failover

-- Option B: Update application connection string
-- PGHOST=10.0.1.20 (was 10.0.1.10)
-- Restart application instances

-- Option C: HAProxy (automatic — checks pg_is_in_recovery)
-- /etc/haproxy/haproxy.cfg:
-- backend pg_primary
--   option httpchk GET /primary
--   http-check expect status 200
--   server pg1 10.0.1.10:5432 check port 8008
--   server pg2 10.0.1.20:5432 check port 8008

-- ============================================================
-- 4. POST-FAILOVER — Build new standby
-- ============================================================

-- On new standby (the recovered old primary, or a fresh server):

-- Step 1: Stop PostgreSQL
-- sudo systemctl stop postgresql

-- Step 2: Clear data directory
-- sudo rm -rf /var/lib/postgresql/16/main/*

-- Step 3: Base backup from new primary
-- pg_basebackup -h 10.0.1.20 -U repl_user \
--   -D /var/lib/postgresql/16/main -R -P -X stream
-- -R creates standby.signal and sets primary_conninfo

-- Step 4: Start as standby
-- sudo systemctl start postgresql
SELECT pg_is_in_recovery();  -- TRUE = running as standby

-- Verify replication is working (on new primary):
SELECT client_addr, state, sent_lsn, replay_lsn,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- ============================================================
-- 5. PATRONI — Automatic Failover
-- ============================================================

-- Patroni handles: health checks, promotion, DCS update, traffic routing
-- Components: Patroni agent on each node + etcd (DCS) + HAProxy

-- /etc/patroni/patroni.yml (primary node):
-- scope: pg-cluster
-- name: node1
-- restapi:
--   listen: 0.0.0.0:8008
-- etcd3:
--   hosts: 10.0.1.30:2379
-- bootstrap:
--   dcs:
--     ttl: 30
--     loop_wait: 10
--     retry_timeout: 10
--     maximum_lag_on_failover: 1048576
-- postgresql:
--   listen: 0.0.0.0:5432
--   data_dir: /var/lib/postgresql/16/main
--   authentication:
--     replication:
--       username: repl_user
--       password: repl_pass
--     superuser:
--       username: postgres
--       password: pg_pass

-- Check Patroni cluster status:
-- patronictl -c /etc/patroni/patroni.yml list
-- + Cluster: pg-cluster ----+---------+---------+
-- | Member | Host       | Role    | State   | Lag |
-- +--------+------------+---------+---------+-----+
-- | node1  | 10.0.1.10  | Leader  | running |     |
-- | node2  | 10.0.1.20  | Replica | running |   0 |
-- +--------+------------+---------+---------+-----+

-- Manual switchover with Patroni (planned, zero downtime):
-- patronictl -c /etc/patroni/patroni.yml switchover
-- Patroni demotes old primary, promotes standby, updates DCS

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create bloat and measure it:
CREATE TABLE bloat_test (
    id SERIAL PRIMARY KEY,
    data TEXT DEFAULT repeat('x', 100)
);
INSERT INTO bloat_test (data)
SELECT repeat('x', 100) FROM generate_series(1, 100000);

-- Create bloat by updating all rows 5 times:
UPDATE bloat_test SET data = repeat('a', 100);
UPDATE bloat_test SET data = repeat('b', 100);
UPDATE bloat_test SET data = repeat('c', 100);
UPDATE bloat_test SET data = repeat('d', 100);
UPDATE bloat_test SET data = repeat('e', 100);

-- Check bloat:
SELECT relname, n_live_tup, n_dead_tup,
  pg_size_pretty(pg_relation_size('bloat_test')) AS size
FROM pg_stat_user_tables WHERE relname = 'bloat_test';

-- VACUUM and check again:
VACUUM VERBOSE bloat_test;
SELECT pg_size_pretty(pg_relation_size('bloat_test')) AS size_after_vacuum;
-- Note: size does NOT shrink! Space is just marked reusable.

-- 2. Test idle_in_transaction_session_timeout:
ALTER SYSTEM SET idle_in_transaction_session_timeout = '1min';
SELECT pg_reload_conf();
-- Open another psql, run BEGIN, wait 2 minutes
-- Connection should be terminated automatically

-- 3. Set up streaming replication:
-- Primary: create replication user
CREATE ROLE repl_user WITH REPLICATION LOGIN PASSWORD 'repl_pass';
-- Edit pg_hba.conf: host replication repl_user 10.0.1.0/24 scram-sha-256
-- On standby: pg_basebackup -h primary -U repl_user -D /data -R -P

-- 4. Practice manual promotion:
-- On standby: pg_ctl promote -D /var/lib/postgresql/16/main
-- Verify: SELECT pg_is_in_recovery(); -- should be FALSE

-- 5. After promotion, build new standby:
-- pg_basebackup from new primary, start as standby
-- Verify with pg_stat_replication on new primary

-- Cleanup:
-- DROP TABLE bloat_test;
-- ALTER SYSTEM RESET idle_in_transaction_session_timeout;
-- SELECT pg_reload_conf();
