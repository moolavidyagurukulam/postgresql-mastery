-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Scenario: Replication Lag & Connection Limits (Classes 276-277)
-- Phase 32: Real-World Scenarios
-- ============================================================

-- ============================================================
-- SCENARIO 1: REPLICATION LAG IS INCREASING
-- ============================================================

-- ============================================================
-- 1. DETECT — Check replication lag
-- ============================================================

-- On PRIMARY: check lag in bytes
SELECT client_addr, state, sent_lsn, replay_lsn,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
  pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_pretty
FROM pg_stat_replication;

-- On STANDBY: check lag in time
SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;

-- Check if standby is receiving and replaying WAL
SELECT pg_is_in_recovery();          -- TRUE = standby
SELECT pg_last_wal_receive_lsn();    -- last received
SELECT pg_last_wal_replay_lsn();     -- last replayed
SELECT pg_last_xact_replay_timestamp(); -- time of last replayed tx

-- ============================================================
-- 2. DIAGNOSE — Find root cause
-- ============================================================

-- Check for long-running queries on STANDBY blocking replay:
SELECT pid, now() - query_start AS duration,
  state, left(query, 80) AS query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC;

-- Check WAL generation rate on PRIMARY:
SELECT pg_size_pretty(
  pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')
) AS total_wal_generated;

-- Check if replay is paused on STANDBY:
SELECT pg_is_wal_replay_paused();  -- TRUE = someone called pg_wal_replay_pause()

-- Check max_wal_senders usage on PRIMARY:
SELECT count(*) AS active_senders,
  (SELECT setting::int FROM pg_settings WHERE name = 'max_wal_senders') AS max_senders
FROM pg_stat_replication;

-- Check network throughput (from shell):
-- iftop -i eth0  (watch bandwidth between primary and standby)

-- ============================================================
-- 3. FIX — Resolve the lag
-- ============================================================

-- Cancel the blocking query on standby:
SELECT pg_cancel_backend(8821);  -- graceful cancel
-- If cancel doesn't work:
SELECT pg_terminate_backend(8821);  -- forceful terminate

-- If replay was paused, resume it:
SELECT pg_wal_replay_resume();

-- If primary is doing bulk import, throttle it:
-- Insert in batches with pauses:
-- INSERT INTO target SELECT * FROM source LIMIT 50000;
-- SELECT pg_sleep(0.5);
-- Repeat...

-- ============================================================
-- 4. PREVENT — Stop future lag spikes
-- ============================================================

-- On STANDBY: auto-cancel queries blocking replay > 30 seconds
-- In postgresql.conf:
-- max_standby_streaming_delay = 30s

-- Keep enough WAL on primary for standby to catch up:
-- wal_keep_size = 2048  (2 GB of WAL)

-- Or use replication slots (guaranteed WAL retention):
-- On PRIMARY:
SELECT pg_create_physical_replication_slot('standby_slot');
-- WARNING: if standby goes offline, WAL accumulates on primary!

-- Set hot_standby_feedback carefully:
-- hot_standby_feedback = on   → prevents conflicts but can cause bloat
-- hot_standby_feedback = off  → allows conflicts but no bloat on primary

-- Monitor lag with alerts:
-- Alert at lag > 10 seconds (warning)
-- Alert at lag > 30 seconds (critical)

-- ============================================================
-- SCENARIO 2: CONNECTION LIMIT REACHED
-- ============================================================

-- ============================================================
-- 1. DETECT — Check connection count
-- ============================================================

-- Current vs maximum connections:
SELECT count(*) AS current_connections,
  (SELECT setting::int FROM pg_settings
   WHERE name = 'max_connections') AS max_connections
FROM pg_stat_activity;

-- Connections by state:
SELECT state, count(*)
FROM pg_stat_activity
GROUP BY state
ORDER BY count DESC;

-- Connections by user:
SELECT usename, count(*)
FROM pg_stat_activity
GROUP BY usename
ORDER BY count DESC;

-- Connections by application:
SELECT application_name, count(*)
FROM pg_stat_activity
GROUP BY application_name
ORDER BY count DESC;

-- ============================================================
-- 2. DIAGNOSE — Find connection leaks
-- ============================================================

-- Find idle-in-transaction connections (leaked transactions):
SELECT pid, usename, state,
  now() - state_change AS idle_duration,
  left(query, 60) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY idle_duration DESC;

-- Find old idle connections (potential leaks):
SELECT pid, usename, state,
  now() - state_change AS idle_duration,
  client_addr
FROM pg_stat_activity
WHERE state = 'idle'
  AND now() - state_change > interval '30 minutes'
ORDER BY idle_duration DESC;

-- ============================================================
-- 3. FIX — Free connections immediately
-- ============================================================

-- Kill idle-in-transaction connections older than 5 minutes:
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - state_change > interval '5 minutes';

-- Kill idle connections older than 1 hour (if emergency):
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
  AND now() - state_change > interval '1 hour'
  AND usename != 'postgres';

-- Set timeout to auto-kill leaked transactions:
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';
SELECT pg_reload_conf();

-- ============================================================
-- 4. REAL FIX — Deploy PgBouncer
-- ============================================================

-- Install PgBouncer:
-- sudo apt install pgbouncer

-- /etc/pgbouncer/pgbouncer.ini:
-- [databases]
-- myapp = host=127.0.0.1 port=5432 dbname=myapp
--
-- [pgbouncer]
-- listen_addr = 0.0.0.0
-- listen_port = 6432
-- auth_type = scram-sha-256
-- auth_file = /etc/pgbouncer/userlist.txt
-- pool_mode = transaction
-- max_client_conn = 1000
-- default_pool_size = 25
-- min_pool_size = 5
-- reserve_pool_size = 5
-- reserve_pool_timeout = 3
-- server_idle_timeout = 600
-- log_connections = 1
-- log_disconnections = 1

-- /etc/pgbouncer/userlist.txt:
-- "app_user" "scram-sha-256$4096:salt$stored:server"
-- (or use auth_query for dynamic lookups)

-- Start PgBouncer:
-- sudo systemctl start pgbouncer
-- sudo systemctl enable pgbouncer

-- Application connects to port 6432 now:
-- psql -h 127.0.0.1 -p 6432 -U app_user -d myapp

-- ============================================================
-- 5. MONITOR PGBOUNCER
-- ============================================================

-- Connect to PgBouncer admin:
-- psql -h 127.0.0.1 -p 6432 -U pgbouncer pgbouncer

-- Show pool status:
-- SHOW POOLS;
-- cl_active:  client connections doing queries
-- cl_waiting: client connections waiting for server
-- sv_active:  server connections running queries
-- sv_idle:    server connections available

-- Show stats:
-- SHOW STATS;

-- Show config:
-- SHOW CONFIG;

-- ============================================================
-- 6. PREVENT — Connection management
-- ============================================================

-- Auto-kill leaked transactions:
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';

-- Close idle sessions (PG 14+):
ALTER SYSTEM SET idle_session_timeout = '30min';

-- Limit connections per role:
ALTER ROLE app_user CONNECTION LIMIT 100;
ALTER ROLE report_user CONNECTION LIMIT 20;

-- Reserve connections for superuser (default = 3):
-- superuser_reserved_connections = 3

-- Reload config:
SELECT pg_reload_conf();

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Set up streaming replication. Monitor with pg_stat_replication.
--    Bulk INSERT on primary. Observe lag. Watch recovery.

-- 2. On standby: start long query. Observe replay lag increase.
--    pg_cancel_backend(). Watch lag recover.

-- 3. Check your connections by state:
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
--    Identify idle and idle-in-transaction counts.

-- 4. Install PgBouncer. Configure transaction mode.
--    Connect application through port 6432.
--    Run SHOW POOLS from admin console.

-- 5. Set idle_in_transaction_session_timeout = '1min'.
--    Open psql, run BEGIN, wait 2 minutes.
--    Verify connection was terminated automatically.
