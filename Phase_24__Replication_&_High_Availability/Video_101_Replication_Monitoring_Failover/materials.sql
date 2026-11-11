-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Replication Monitoring & Failover (Class 200 Part 3)
-- Phase 24: Replication & High Availability
-- ============================================================

-- ============================================================
-- 1. MONITORING ON PRIMARY — pg_stat_replication
-- ============================================================

-- All connected standbys with lag:
SELECT
    pid,
    usename,
    client_addr,
    state,
    sync_state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, write_lsn) AS send_lag,
    pg_wal_lsn_diff(write_lsn, flush_lsn) AS flush_lag,
    pg_wal_lsn_diff(flush_lsn, replay_lsn) AS replay_lag,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS total_lag_bytes,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
    ) AS total_lag
FROM pg_stat_replication;

-- ============================================================
-- 2. MONITORING ON STANDBY — pg_stat_wal_receiver
-- ============================================================

SELECT pg_is_in_recovery() AS is_standby;

SELECT
    status,
    sender_host,
    sender_port,
    slot_name,
    received_lsn,
    pg_last_wal_receive_lsn() AS last_received,
    pg_last_wal_replay_lsn() AS last_replayed,
    pg_last_xact_replay_timestamp() AS last_replayed_at,
    now() - pg_last_xact_replay_timestamp() AS time_lag
FROM pg_stat_wal_receiver;

-- ============================================================
-- 3. REPLICATION HEALTH CHECK WITH ALERTS
-- ============================================================

SELECT
    client_addr,
    state,
    sync_state,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
    ) AS lag,
    CASE
        WHEN pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
             > 1073741824 THEN 'CRITICAL (> 1 GB)'
        WHEN pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
             > 104857600 THEN 'WARNING (> 100 MB)'
        ELSE 'OK'
    END AS status
FROM pg_stat_replication;

-- ============================================================
-- 4. CHECK REPLICATION SLOTS
-- ============================================================

-- All slots:
SELECT
    slot_name,
    slot_type,
    active,
    restart_lsn,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS retained_wal
FROM pg_replication_slots;

-- DANGER: Inactive slots with large retained WAL:
SELECT slot_name, active,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS retained_wal
FROM pg_replication_slots
WHERE NOT active;

-- Drop an inactive slot (if standby is gone):
-- SELECT pg_drop_replication_slot('standby1_slot');

-- ============================================================
-- 5. FAILOVER — PROMOTE STANDBY
-- ============================================================

-- Method 1: SQL function (run on STANDBY)
SELECT pg_promote();

-- Method 2: command line (on STANDBY)
-- sudo -u postgres pg_ctl promote -D /var/lib/postgresql/16/main

-- Verify promotion:
SELECT pg_is_in_recovery();
-- false = now a primary

-- Test writes:
INSERT INTO repl_test (msg) VALUES ('First write after promotion!');

-- Check timeline:
SELECT timeline_id FROM pg_control_checkpoint();

-- ============================================================
-- 6. RECONFIGURE OLD PRIMARY AS STANDBY
-- ============================================================

-- Option A: pg_rewind (fast, requires wal_log_hints=on)
-- sudo systemctl stop postgresql
-- sudo -u postgres pg_rewind \
--     --target-pgdata=/var/lib/postgresql/16/main \
--     --source-server='host=NEW_PRIMARY_IP user=postgres dbname=postgres'
-- sudo -u postgres touch /var/lib/postgresql/16/main/standby.signal
-- Edit postgresql.auto.conf: primary_conninfo points to NEW primary
-- sudo systemctl start postgresql

-- Option B: Fresh pg_basebackup (always works)
-- sudo systemctl stop postgresql
-- sudo rm -rf /var/lib/postgresql/16/main/*
-- sudo -u postgres pg_basebackup -h NEW_PRIMARY_IP -U replicator \
--     -D /var/lib/postgresql/16/main -Fp -Xs -P -R
-- sudo systemctl start postgresql

-- ============================================================
-- 7. SWITCHOVER (PLANNED ROLE SWAP)
-- ============================================================

-- Step 1: Stop writes on current primary
-- ALTER SYSTEM SET default_transaction_read_only = on;
-- SELECT pg_reload_conf();

-- Step 2: Wait for standby to catch up (lag = 0)
-- SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
-- FROM pg_stat_replication;

-- Step 3: Stop primary
-- sudo systemctl stop postgresql

-- Step 4: Promote standby
-- SELECT pg_promote();

-- Step 5: Convert old primary to standby
-- (pg_rewind or pg_basebackup — see section 6)

-- Step 6: Update application to point to new primary

-- ============================================================
-- 8. RECOVERY CONFLICT SETTINGS (on STANDBY)
-- ============================================================

-- Prevent query cancellations:
-- ALTER SYSTEM SET hot_standby_feedback = on;

-- Increase delay before canceling (default 30s):
-- ALTER SYSTEM SET max_standby_streaming_delay = '60s';

-- Never cancel queries (WAL replay waits):
-- ALTER SYSTEM SET max_standby_streaming_delay = '-1';
-- WARNING: this can cause replication lag!

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Run the lag monitoring query on your primary.
--    What is the current lag in bytes?

-- 2. Check pg_stat_wal_receiver on your standby.
--    Is the status 'streaming'?

-- 3. Simulate a disconnect: stop the standby.
--    Watch pg_stat_replication on the primary.
--    Start the standby and watch it reconnect.

-- 4. Test failover (on a test setup):
--    Stop the primary.
--    Promote the standby with pg_promote().
--    Verify writes work on the new primary.

-- 5. Set up the health check query as a cron job:
--    Save it as /opt/pg_repl_check.sql
--    crontab: */5 * * * * psql -f /opt/pg_repl_check.sql
