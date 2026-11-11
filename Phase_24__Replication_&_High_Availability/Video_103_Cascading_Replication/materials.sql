-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Cascading Replication (Class 203)
-- Phase 24: Replication & High Availability
-- ============================================================

-- ============================================================
-- ARCHITECTURE: Primary → Standby 1 → Standby 2
-- ============================================================

-- Primary:   10.0.1.1   (accepts writes)
-- Standby 1: 10.0.1.10  (hot standby + relay)
-- Standby 2: 10.0.1.11  (hot standby, cascaded)

-- ============================================================
-- 1. PRIMARY CONFIGURATION (already set up)
-- ============================================================

-- wal_level = replica
-- max_wal_senders = 10
-- wal_keep_size = 1GB
-- pg_hba.conf: host replication replicator 10.0.1.10/32 scram-sha-256
-- Replicator role already created

-- ============================================================
-- 2. STANDBY 1 CONFIGURATION (relay standby)
-- ============================================================

-- Standby 1 receives from Primary AND sends to Standby 2
-- Required settings (already defaults in PG 16):
-- wal_level = replica
-- max_wal_senders = 10

-- pg_hba.conf on Standby 1 — allow Standby 2:
-- host  replication  replicator  10.0.1.11/32  scram-sha-256

-- Reload after pg_hba.conf change:
SELECT pg_reload_conf();

-- Optional: create slot on Standby 1 for Standby 2:
SELECT pg_create_physical_replication_slot('standby2_slot');

-- ============================================================
-- 3. STANDBY 2 SETUP (cascading from Standby 1)
-- ============================================================

-- On Standby 2 machine:
-- sudo systemctl stop postgresql
-- sudo rm -rf /var/lib/postgresql/16/main/*

-- pg_basebackup from STANDBY 1 (not primary!):
-- sudo -u postgres pg_basebackup \
--     -h 10.0.1.10 \
--     -U replicator \
--     -D /var/lib/postgresql/16/main \
--     -Fp -Xs -P -R

-- -R writes: primary_conninfo = '...host=10.0.1.10...'
-- Note: host=10.0.1.10 is Standby 1, not the Primary

-- Optional: set slot name
-- Add to postgresql.auto.conf:
-- primary_slot_name = 'standby2_slot'

-- Start Standby 2:
-- sudo systemctl start postgresql

-- ============================================================
-- 4. VERIFY THE CASCADE CHAIN
-- ============================================================

-- ON PRIMARY — only Standby 1 connected:
SELECT client_addr, state, sync_state
FROM pg_stat_replication;

-- ON STANDBY 1 — Standby 2 connected:
SELECT client_addr, state, sync_state
FROM pg_stat_replication;

-- ON STANDBY 2 — receiving from Standby 1:
SELECT sender_host, status
FROM pg_stat_wal_receiver;

-- All three confirm they are standbys:
SELECT pg_is_in_recovery();

-- ============================================================
-- 5. TEST DATA FLOW THROUGH CHAIN
-- ============================================================

-- ON PRIMARY:
INSERT INTO repl_test (msg) VALUES ('Cascading test!');

-- ON STANDBY 1 (milliseconds later):
SELECT * FROM repl_test ORDER BY id DESC LIMIT 1;

-- ON STANDBY 2 (a few more milliseconds):
SELECT * FROM repl_test ORDER BY id DESC LIMIT 1;

-- ============================================================
-- 6. MEASURE LAG THROUGH THE CHAIN
-- ============================================================

-- ON PRIMARY — lag to Standby 1:
SELECT
    client_addr,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
    ) AS lag
FROM pg_stat_replication;

-- ON STANDBY 1 — lag to Standby 2:
SELECT
    client_addr,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_last_wal_replay_lsn(), replay_lsn)
    ) AS lag
FROM pg_stat_replication;

-- Total lag (Standby 2 from Primary):
-- = (Primary → Standby 1 lag) + (Standby 1 → Standby 2 lag)

-- ============================================================
-- 7. RECONFIGURE IF RELAY GOES DOWN
-- ============================================================

-- If Standby 1 goes down permanently:
-- On Standby 2, change primary_conninfo to point to Primary:
-- ALTER SYSTEM SET primary_conninfo =
--   'user=replicator host=10.0.1.1 port=5432';
-- Restart Standby 2

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Verify Standby 1 has wal_level=replica and max_wal_senders>0.
--    These allow it to relay WAL.

-- 2. Add a pg_hba.conf replication entry on Standby 1
--    for Standby 2's IP address.

-- 3. Run pg_basebackup from Standby 1 (not primary) to create
--    Standby 2. Verify standby.signal was created.

-- 4. Start Standby 2. Check pg_stat_wal_receiver shows
--    sender_host = Standby 1's IP.

-- 5. Insert data on primary. Verify it appears on both standbys.
--    Measure the lag at each hop.
