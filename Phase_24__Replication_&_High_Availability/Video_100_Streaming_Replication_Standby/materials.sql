-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Streaming Replication — Standby Server Setup (Class 200 Part 2)
-- Phase 24: Replication & High Availability
-- ============================================================

-- ============================================================
-- 1. pg_basebackup COMMAND (run on STANDBY)
-- ============================================================

-- Full command with all flags:
-- sudo -u postgres pg_basebackup \
--     -h 10.0.1.1 \
--     -U replicator \
--     -D /var/lib/postgresql/16/main \
--     -Fp \
--     -Xs \
--     -P \
--     -R

-- Flags:
-- -h  = primary server hostname/IP
-- -U  = replication username
-- -D  = destination directory (must be empty)
-- -Fp = plain format (files, not tar)
-- -Xs = stream WAL during backup
-- -P  = show progress
-- -R  = create standby.signal + write primary_conninfo

-- With replication slot creation:
-- sudo -u postgres pg_basebackup \
--     -h 10.0.1.1 \
--     -U replicator \
--     -D /var/lib/postgresql/16/main \
--     -Fp -Xs -P -R \
--     -C -S standby1_slot

-- ============================================================
-- 2. VERIFY standby.signal EXISTS
-- ============================================================

-- After pg_basebackup with -R:
-- ls -la /var/lib/postgresql/16/main/standby.signal
-- Should show an empty file (0 bytes)

-- If you need to create it manually:
-- sudo -u postgres touch /var/lib/postgresql/16/main/standby.signal

-- ============================================================
-- 3. STANDBY postgresql.conf SETTINGS
-- ============================================================

-- primary_conninfo (set by -R, or manually):
-- primary_conninfo = 'user=replicator host=10.0.1.1 port=5432'

-- Enable read-only queries:
-- hot_standby = on

-- Use a replication slot (optional but recommended):
-- primary_slot_name = 'standby1_slot'

-- Prevent query cancellations (recommended):
-- hot_standby_feedback = on

-- ============================================================
-- 4. PRODUCTION: USE .pgpass FOR PASSWORD
-- ============================================================

-- Create .pgpass file (on standby, as postgres user):
-- echo '10.0.1.1:5432:replication:replicator:SecurePass123!' \
--   > ~/.pgpass
-- chmod 600 ~/.pgpass

-- Then primary_conninfo does NOT need password=
-- primary_conninfo = 'user=replicator host=10.0.1.1 port=5432'

-- ============================================================
-- 5. VERIFY ON PRIMARY — pg_stat_replication
-- ============================================================

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
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- state = 'streaming' means replication is active
-- lag_bytes = 0 means standby is fully caught up

-- ============================================================
-- 6. VERIFY ON STANDBY
-- ============================================================

-- Am I a standby?
SELECT pg_is_in_recovery();
-- true = yes, this is a standby

-- WAL receiver status:
SELECT
    status,
    sender_host,
    sender_port,
    slot_name,
    received_lsn,
    last_msg_send_time,
    last_msg_receipt_time
FROM pg_stat_wal_receiver;

-- ============================================================
-- 7. TEST DATA REPLICATION
-- ============================================================

-- ON PRIMARY:
CREATE TABLE repl_test (
    id serial PRIMARY KEY,
    msg text,
    ts timestamptz DEFAULT now()
);

INSERT INTO repl_test (msg) VALUES ('Hello from primary!');
INSERT INTO repl_test (msg) VALUES ('Second row from primary');

-- ON STANDBY (should appear within milliseconds):
SELECT * FROM repl_test;

-- ============================================================
-- 8. MEASURE REPLICATION LAG
-- ============================================================

-- ON PRIMARY — lag in bytes per standby:
SELECT
    client_addr,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
    ) AS lag_pretty
FROM pg_stat_replication;

-- ON STANDBY — lag in time:
SELECT
    now() - pg_last_xact_replay_timestamp() AS replay_lag,
    pg_last_wal_receive_lsn() AS received_lsn,
    pg_last_wal_replay_lsn() AS replayed_lsn;

-- WARNING: If no writes are happening on primary,
-- replay_lag grows even though standby IS caught up.
-- Always compare LSN positions for accuracy.

-- ============================================================
-- 9. STANDBY IS READ-ONLY
-- ============================================================

-- These will fail on the standby:
-- INSERT INTO repl_test (msg) VALUES ('test');
-- ERROR: cannot execute INSERT in a read-only transaction

-- CREATE TABLE test (id int);
-- ERROR: cannot execute CREATE TABLE in a read-only transaction

-- Only SELECT, SHOW, EXPLAIN, and other read-only
-- commands work on a hot standby.

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Take a pg_basebackup from your primary to a test directory:
--    pg_basebackup -h 127.0.0.1 -U replicator -D /tmp/standby_test -Fp -Xs -P -R
--    (Use localhost if testing on same machine)

-- 2. Check that standby.signal was created.
--    Check postgresql.auto.conf for primary_conninfo.

-- 3. Start a second PostgreSQL instance on a different port:
--    pg_ctl -D /tmp/standby_test -o '-p 5433' start

-- 4. Connect to standby and verify:
--    psql -p 5433 -U postgres -c "SELECT pg_is_in_recovery();"

-- 5. INSERT a row on the primary and verify it appears
--    on the standby within seconds.
