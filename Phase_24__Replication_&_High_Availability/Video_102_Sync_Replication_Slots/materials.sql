-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Synchronous Replication & Replication Slots (Classes 201-202)
-- Phase 24: Replication & High Availability
-- ============================================================

-- ============================================================
-- 1. ENABLE SYNCHRONOUS REPLICATION
-- ============================================================

-- On PRIMARY — name the sync standby:
ALTER SYSTEM SET synchronous_standby_names = 'standby1';
SELECT pg_reload_conf();

-- On STANDBY — set application_name in primary_conninfo:
-- primary_conninfo = 'user=replicator host=10.0.1.1
--   application_name=standby1'
-- Restart standby after changing primary_conninfo

-- Verify sync state:
SELECT application_name, sync_state
FROM pg_stat_replication;
-- sync_state should show 'sync'

-- ============================================================
-- 2. SYNCHRONOUS_COMMIT LEVELS
-- ============================================================

-- Server-wide default:
ALTER SYSTEM SET synchronous_commit = 'on';
SELECT pg_reload_conf();

-- Per-transaction (within BEGIN/COMMIT):
BEGIN;
SET LOCAL synchronous_commit = 'remote_apply';
INSERT INTO payments (amount) VALUES (1000.00);
COMMIT;

-- Levels (weakest to strongest):
-- off           → no flush on primary (fastest, risky)
-- local         → flush on primary only (async behavior)
-- remote_write  → written to standby OS cache
-- on            → flushed to standby disk (default for sync)
-- remote_apply  → replayed on standby (read-your-writes)

-- ============================================================
-- 3. MULTIPLE SYNC STANDBYS
-- ============================================================

-- FIRST N: wait for first N in priority order
ALTER SYSTEM SET synchronous_standby_names = 'FIRST 1 (standby1, standby2)';
-- Waits for standby1; if down, falls back to standby2

-- ANY N: quorum commit — any N out of the list
ALTER SYSTEM SET synchronous_standby_names = 'ANY 2 (standby1, standby2, standby3)';
-- Waits for any 2 of 3 to confirm
-- Tolerates 1 standby failure

SELECT pg_reload_conf();

-- Check quorum status:
SELECT application_name, sync_state
FROM pg_stat_replication;

-- ============================================================
-- 4. EMERGENCY: SYNC STANDBY DOWN — WRITES BLOCKED
-- ============================================================

-- If all sync standbys are down, writes hang!
-- Emergency fix: switch to async
ALTER SYSTEM SET synchronous_standby_names = '';
SELECT pg_reload_conf();
-- Writes resume immediately

-- Or per-session:
SET synchronous_commit = 'local';
-- This session only uses local commit

-- ============================================================
-- 5. PHYSICAL REPLICATION SLOTS
-- ============================================================

-- Create a slot:
SELECT pg_create_physical_replication_slot('standby1_slot');

-- View all slots:
SELECT
    slot_name,
    slot_type,
    active,
    active_pid,
    restart_lsn,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS retained_wal
FROM pg_replication_slots;

-- Use on standby (in postgresql.conf):
-- primary_slot_name = 'standby1_slot'

-- ============================================================
-- 6. SLOT SAFETY: max_slot_wal_keep_size
-- ============================================================

-- ALWAYS set in production:
ALTER SYSTEM SET max_slot_wal_keep_size = '10GB';
SELECT pg_reload_conf();

-- Monitor inactive slots:
SELECT
    slot_name,
    active,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS retained_wal,
    CASE
        WHEN NOT active AND pg_wal_lsn_diff(
            pg_current_wal_lsn(), restart_lsn
        ) > 5368709120 THEN 'DANGER (> 5 GB)'
        WHEN NOT active THEN 'INACTIVE'
        ELSE 'OK'
    END AS status
FROM pg_replication_slots;

-- Drop an inactive slot:
SELECT pg_drop_replication_slot('standby1_slot');

-- ============================================================
-- 7. CREATE SLOT DURING pg_basebackup
-- ============================================================

-- pg_basebackup -h 10.0.1.1 -U replicator \
--     -D /var/lib/postgresql/16/main \
--     -Fp -Xs -P -R \
--     -C -S standby1_slot
--
-- -C = create slot on primary
-- -S = name the slot

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Enable synchronous replication:
--    Set synchronous_standby_names = 'standby1'
--    Verify sync_state = 'sync' in pg_stat_replication

-- 2. Test per-transaction sync commit:
--    BEGIN; SET LOCAL synchronous_commit = 'remote_apply';
--    INSERT INTO test ...; COMMIT;
--    Compare speed vs SET LOCAL synchronous_commit = 'local';

-- 3. Simulate sync standby failure:
--    Stop the standby. Try INSERT on primary.
--    Observe the hang. Fix with: SET synchronous_commit = 'local';

-- 4. Create a replication slot. Verify with pg_replication_slots.
--    Stop the standby. Watch retained_wal grow.
--    Drop the slot to release WAL.

-- 5. Set max_slot_wal_keep_size = '1GB' for testing.
--    Stop standby, generate WAL, observe slot invalidation.
