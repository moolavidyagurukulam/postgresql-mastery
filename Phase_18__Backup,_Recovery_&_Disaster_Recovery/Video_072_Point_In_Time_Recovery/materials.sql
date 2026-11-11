-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Point-in-Time Recovery (Class 148)
-- Phase 18: Backup, Recovery & Disaster Recovery
-- ============================================================

-- ============================================================
-- 1. ENABLE WAL ARCHIVING
-- ============================================================

-- Check current settings:
SHOW archive_mode;
SHOW archive_command;
SHOW wal_level;

-- Enable archiving (requires restart):
ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM SET wal_level = 'replica';

-- Linux archive command:
ALTER SYSTEM SET archive_command = 'cp %p /backups/wal_archive/%f';

-- Windows archive command:
-- ALTER SYSTEM SET archive_command = 'copy "%p" "C:/backups/wal/%f"';

-- Create archive directory (Linux):
-- sudo mkdir -p /backups/wal_archive
-- sudo chown postgres:postgres /backups/wal_archive

-- Restart PostgreSQL, then verify:
-- SHOW archive_mode;  -- should be 'on'

-- ============================================================
-- 2. TEST WAL ARCHIVING
-- ============================================================

-- Force a WAL switch:
SELECT pg_switch_wal();

-- Check archive directory has files:
-- ls /backups/wal_archive/

-- Monitor archiving:
SELECT archived_count, failed_count,
       last_archived_wal, last_archived_time
FROM pg_stat_archiver;

-- ============================================================
-- 3. TAKE BASE BACKUP
-- ============================================================

-- pg_basebackup -U replicator -D /backups/pitr_base -Ft -z -P --checkpoint=fast

-- ============================================================
-- 4. SIMULATE WORK + DISASTER
-- ============================================================

-- Insert important data:
CREATE TABLE critical_report (
    id SERIAL PRIMARY KEY,
    data TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO critical_report (data) VALUES
    ('Q3 financial summary'),
    ('Annual audit');

-- NOTE THE TIMESTAMP (this is your recovery target):
SELECT now();
-- Save this: e.g., 2026-11-04 10:30:00+05:30

-- Force WAL archive:
SELECT pg_switch_wal();

-- More data AFTER target (will be "lost"):
INSERT INTO critical_report (data) VALUES ('After target');

-- DISASTER:
DROP TABLE critical_report;

-- ============================================================
-- 5. PERFORM PITR
-- ============================================================

-- Step 1: Stop PostgreSQL
-- sudo systemctl stop postgresql

-- Step 2: Move data directory aside
-- sudo mv /var/lib/postgresql/16/main /var/lib/postgresql/16/main_damaged

-- Step 3: Restore base backup
-- sudo mkdir /var/lib/postgresql/16/main
-- sudo tar xzf /backups/pitr_base/base.tar.gz -C /var/lib/postgresql/16/main
-- sudo tar xzf /backups/pitr_base/pg_wal.tar.gz -C /var/lib/postgresql/16/main/pg_wal
-- sudo chown -R postgres:postgres /var/lib/postgresql/16/main

-- Step 4: Configure recovery (append to postgresql.auto.conf):
-- restore_command = 'cp /backups/wal_archive/%f %p'
-- recovery_target_time = '2026-11-04 10:30:00+05:30'
-- recovery_target_action = 'promote'

-- Step 5: Create recovery signal
-- touch /var/lib/postgresql/16/main/recovery.signal

-- Step 6: Start PostgreSQL
-- sudo systemctl start postgresql

-- Step 7: Verify
-- SELECT * FROM critical_report;
-- Should see rows 1-2 but NOT row 3

-- ============================================================
-- 6. RECOVERY TARGET TYPES
-- ============================================================

-- By time:
-- recovery_target_time = '2026-11-04 10:30:00+05:30'

-- By transaction ID:
-- recovery_target_xid = '12345'

-- By named restore point:
-- recovery_target_name = 'before_migration'

-- By WAL position:
-- recovery_target_lsn = '0/5012340'

-- Include/exclude target transaction:
-- recovery_target_inclusive = true  (default: include target)
-- recovery_target_inclusive = false (stop BEFORE target)

-- ============================================================
-- 7. NAMED RESTORE POINTS
-- ============================================================

-- Create before risky operations:
SELECT pg_create_restore_point('before_v2_migration');

-- Then if migration goes wrong:
-- recovery_target_name = 'before_v2_migration'

-- ============================================================
-- 8. RECOVERY TARGET ACTIONS
-- ============================================================

-- promote:  become normal primary (for DR)
-- pause:    stop in recovery, read-only (for inspection)
-- shutdown: stop PostgreSQL after reaching target

-- If paused, resume with:
-- SELECT pg_wal_replay_resume();

-- ============================================================
-- 9. MONITORING ARCHIVING
-- ============================================================

SELECT * FROM pg_stat_archiver;

-- Alert if archiving is stale:
SELECT CASE
    WHEN last_archived_time < now() - '10 min'::interval
    THEN 'ALERT: WAL archiving stale!'
    ELSE 'OK: archiving healthy'
END AS status
FROM pg_stat_archiver;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Enable WAL archiving, restart, verify with pg_switch_wal
-- 2. Take base backup with pg_basebackup
-- 3. INSERT data, note timestamp, INSERT more, DROP TABLE
-- 4. Perform complete PITR to your noted timestamp
-- 5. Verify: table exists, first data present, second data gone
