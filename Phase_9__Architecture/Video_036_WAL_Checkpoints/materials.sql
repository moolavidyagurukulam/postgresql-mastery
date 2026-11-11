-- =============================================
-- PostgreSQL Mastery: WAL & Checkpoints
-- Phase 9: Architecture | Classes 71-74 Part 2
-- =============================================
-- Write-Ahead Logging, crash recovery, checkpoint
-- process, WAL settings, and monitoring.
-- =============================================

-- === WAL SETTINGS ===

-- Core WAL parameters
SHOW wal_level;                      -- minimal, replica, logical
SHOW max_wal_size;                   -- checkpoint trigger (default: 1GB)
SHOW min_wal_size;                   -- minimum WAL kept (default: 80MB)
SHOW wal_segment_size;               -- per file (default: 16MB)
SHOW wal_buffers;                    -- WAL write buffer (-1 = auto)
SHOW synchronous_commit;             -- on = wait for disk flush

-- === WAL FILES ===

-- Current WAL write position
SELECT pg_current_wal_lsn();

-- Current WAL insert position (latest write to buffer)
SELECT pg_current_wal_insert_lsn();

-- Current WAL flush position (confirmed on disk)
SELECT pg_current_wal_flush_lsn();

-- List WAL files on disk
SELECT name, pg_size_pretty(size) AS size, modification
FROM pg_ls_waldir()
ORDER BY modification DESC;

-- Total WAL size
SELECT pg_size_pretty(sum(size)) AS total_wal_size
FROM pg_ls_waldir();

-- Count of WAL files
SELECT count(*) AS wal_file_count FROM pg_ls_waldir();

-- === CHECKPOINTS ===

-- Checkpoint settings
SHOW checkpoint_timeout;             -- default: 5min
SHOW checkpoint_completion_target;   -- default: 0.9 (spread I/O)
SHOW max_wal_size;                   -- triggers checkpoint when exceeded

-- Force a checkpoint now
CHECKPOINT;

-- === CHECKPOINT MONITORING ===

-- Checkpoint and background writer statistics
SELECT
  checkpoints_timed,      -- triggered by timeout (normal, expected)
  checkpoints_req,        -- triggered by WAL size (too many = bad!)
  checkpoint_write_time,  -- ms spent writing during checkpoints
  checkpoint_sync_time,   -- ms spent syncing during checkpoints
  buffers_checkpoint,     -- pages written by checkpointer
  buffers_clean,          -- pages written by background writer
  buffers_backend,        -- pages written by backends (should be low!)
  maxwritten_clean        -- bgwriter stopped due to bgwriter_lru_maxpages
FROM pg_stat_bgwriter;

-- Rule of thumb:
-- checkpoints_req should be much lower than checkpoints_timed
-- If checkpoints_req is high → increase max_wal_size
-- buffers_backend should be low → if high, increase shared_buffers

-- Checkpoint frequency (checkpoints per hour)
SELECT
  checkpoints_timed + checkpoints_req AS total_checkpoints,
  ROUND(
    (checkpoints_timed + checkpoints_req) * 3600.0 /
    EXTRACT(EPOCH FROM now() - stats_reset),
    1
  ) AS checkpoints_per_hour
FROM pg_stat_bgwriter;

-- === CRASH RECOVERY ===

-- After a crash, PostgreSQL:
-- 1. Reads pg_control to find last checkpoint
-- 2. Replays WAL from that checkpoint forward
-- 3. Committed txns → restored
-- 4. Uncommitted txns → rolled back
-- 5. Database is consistent again

-- Check the control file info from SQL
SELECT pg_control_checkpoint();
-- Shows: checkpoint_lsn, redo_lsn, timeline, etc.

-- Detailed control data
SELECT pg_control_system();
-- Shows: pg_control version, catalog version, etc.

-- Recovery target if you need point-in-time recovery:
-- restore_command, recovery_target_time, etc.
-- (covered in backup & recovery phase)

-- === SYNCHRONOUS_COMMIT ===

-- ON (default): COMMIT waits for WAL flush to disk
-- OFF: COMMIT returns immediately (can lose ~200ms on crash)

SHOW synchronous_commit;

-- Change per session (for non-critical writes):
-- SET synchronous_commit = off;
-- INSERT INTO analytics_log (...) VALUES (...);
-- RESET synchronous_commit;

-- Change globally in postgresql.conf:
-- synchronous_commit = on   (keep this for safety!)

-- Options beyond on/off:
-- on             = wait for local WAL flush
-- remote_apply   = wait for standby to apply
-- remote_write   = wait for standby OS buffer
-- local          = same as on (flush local WAL)
-- off            = don't wait (fastest, risky)

-- === WAL ARCHIVING ===

-- WAL archiving copies completed WAL files to backup storage
-- This enables Point-In-Time Recovery (PITR)

SHOW archive_mode;           -- off by default
SHOW archive_command;        -- shell command to copy WAL files
SHOW archive_timeout;        -- force switch WAL file after timeout

-- To enable:
-- archive_mode = on               (requires restart)
-- archive_command = 'cp %p /backup/wal/%f'
-- archive_timeout = 300            (5 min max gap)

-- Check archive status
SELECT archived_count, failed_count,
       last_archived_wal, last_archived_time
FROM pg_stat_archiver;

-- === REPLICATION SLOTS AND WAL RETENTION ===

-- Replication slots prevent WAL from being recycled
-- until the replica has consumed it

-- List replication slots
SELECT slot_name, slot_type, active,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn))
         AS slot_lag
FROM pg_replication_slots;

-- WARNING: inactive slots hold WAL forever!
-- Monitor slot lag and drop unused slots:
-- SELECT pg_drop_replication_slot('old_slot');

-- Other WAL retention settings
SHOW wal_keep_size;     -- minimum WAL kept (default: 0 = only for checkpoints)
-- In older PG versions: wal_keep_segments (deprecated)

-- === WAL TUNING FOR PRODUCTION ===

-- Server Type     | max_wal_size | checkpoint_timeout | wal_buffers
-- ----------------+--------------+--------------------+------------
-- Light writes    | 1 GB         | 5 min              | -1 (auto)
-- Medium writes   | 2-4 GB       | 10 min             | 64 MB
-- Heavy writes    | 4-8 GB       | 15 min             | 64 MB
-- Bulk loading    | 8-16 GB      | 15 min             | 128 MB

-- For heavy writes, also consider:
-- full_page_writes = on  (keep on! crash safety)
-- wal_compression = on   (PG 15+, reduces WAL volume)

-- === BACKGROUND WRITER ===

-- The background writer gradually flushes dirty pages
-- This reduces the I/O spike during checkpoints

SHOW bgwriter_delay;            -- 200ms (check interval)
SHOW bgwriter_lru_maxpages;     -- 100 (pages per round)
SHOW bgwriter_lru_multiplier;   -- 2.0 (how aggressively)

-- If buffers_backend is high in pg_stat_bgwriter:
-- Increase bgwriter_lru_maxpages to 200-400
-- Increase bgwriter_lru_multiplier to 4.0

-- === PRACTICE EXERCISES ===

-- Exercise 1: Check all WAL settings
SHOW wal_level;
SHOW max_wal_size;
SHOW checkpoint_timeout;
SHOW synchronous_commit;

-- Exercise 2: Check WAL size and file count
SELECT pg_size_pretty(sum(size)) AS total, count(*) AS files
FROM pg_ls_waldir();

-- Exercise 3: Current WAL position
SELECT pg_current_wal_lsn();

-- Exercise 4: Checkpoint statistics
SELECT checkpoints_timed, checkpoints_req,
  buffers_checkpoint, buffers_backend
FROM pg_stat_bgwriter;

-- Exercise 5: Force a checkpoint
CHECKPOINT;

-- Exercise 6: Check for WAL-heavy behavior
-- High checkpoints_req = increase max_wal_size
-- High buffers_backend = increase shared_buffers
SELECT
  CASE WHEN checkpoints_req > checkpoints_timed
       THEN 'WARNING: too many WAL-triggered checkpoints!'
       ELSE 'OK: mostly time-triggered checkpoints'
  END AS checkpoint_health
FROM pg_stat_bgwriter;

-- Exercise 7: Check archive status (if archiving enabled)
SELECT archived_count, failed_count FROM pg_stat_archiver;

-- =============================================
-- Phase 9: Architecture — COMPLETE!
-- Videos 032-036 cover:
--   Process Architecture
--   Memory Architecture
--   Storage Architecture
--   Query Flow & MVCC
--   WAL & Checkpoints
--
-- Next Phase: Phase 10 — Advanced SQL
-- UNION/INTERSECT/EXCEPT, Window Functions,
-- String/Date/Math functions, LATERAL, GENERATE_SERIES
-- =============================================
