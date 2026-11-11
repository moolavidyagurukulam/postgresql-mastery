-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Replication Overview (Class 199)
-- Phase 24: Replication & High Availability
-- ============================================================

-- ============================================================
-- 1. CHECK CURRENT WAL LEVEL
-- ============================================================

SHOW wal_level;
-- Default in PG 16: replica
-- For streaming replication: replica is sufficient
-- For logical replication: must be set to 'logical'

-- ============================================================
-- 2. CHECK REPLICATION-RELATED SETTINGS
-- ============================================================

SELECT name, setting, unit, context
FROM pg_settings
WHERE name IN (
    'wal_level',
    'max_wal_senders',
    'wal_keep_size',
    'max_replication_slots',
    'hot_standby',
    'synchronous_commit',
    'synchronous_standby_names',
    'max_slot_wal_keep_size'
)
ORDER BY name;

-- ============================================================
-- 3. CHECK IF THIS SERVER IS PRIMARY OR STANDBY
-- ============================================================

SELECT pg_is_in_recovery() AS is_standby;
-- false = this is a primary server
-- true  = this is a standby (replica)

-- ============================================================
-- 4. VIEW CONNECTED STANDBYS (run on PRIMARY)
-- ============================================================

SELECT
    pid,
    usename,
    client_addr,
    state,
    sync_state,
    sent_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;
-- Empty result = no standbys connected

-- ============================================================
-- 5. VIEW REPLICATION SLOTS
-- ============================================================

SELECT
    slot_name,
    slot_type,
    active,
    restart_lsn,
    pg_wal_lsn_diff(
        pg_current_wal_lsn(),
        restart_lsn
    ) AS retained_bytes
FROM pg_replication_slots;
-- Empty result = no slots created yet

-- ============================================================
-- 6. VIEW WAL RECEIVER STATUS (run on STANDBY)
-- ============================================================

SELECT
    status,
    sender_host,
    sender_port,
    slot_name,
    last_msg_send_time,
    last_msg_receipt_time
FROM pg_stat_wal_receiver;
-- Only returns rows on a standby server

-- ============================================================
-- 7. REPLICATION TERMINOLOGY QUICK REFERENCE
-- ============================================================

-- Primary:     Server that accepts writes
-- Standby:     Server that receives WAL and replays it
-- Hot Standby: Standby that accepts read-only queries
-- Warm Standby: Standby that only replays WAL (no queries)
-- Promotion:   Converting standby → new primary
-- Failover:    Emergency switch to standby (primary failed)
-- Switchover:  Planned swap of primary and standby roles
-- WAL Sender:  Process on primary streaming WAL to standby
-- WAL Receiver: Process on standby receiving WAL

-- ============================================================
-- 8. REPLICATION TYPES COMPARISON
-- ============================================================

-- Streaming (Physical) Replication:
--   - Copies WAL byte stream (binary)
--   - Exact copy of entire database cluster
--   - Standby is read-only
--   - Very fast, low overhead
--   - Use for: HA, failover, read replicas
--   - Cannot replicate between different PG versions

-- Logical Replication:
--   - Copies row-level changes (SQL-level)
--   - Selective: specific tables only
--   - Subscriber is read-write
--   - Slightly more overhead
--   - Use for: migrations, CDC, selective sync
--   - CAN replicate between PG versions

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Run SHOW wal_level; on your server.
--    Is it set to 'replica' or 'logical'?

-- 2. Query pg_settings for all replication-related parameters.
--    Note the default values.

-- 3. Check pg_is_in_recovery() — is your server a primary
--    or a standby?

-- 4. Query pg_stat_replication — do you have any standbys?
--    (Expected: empty if this is a standalone server)

-- 5. Query pg_replication_slots — any slots created?
--    (Expected: empty on a fresh install)
