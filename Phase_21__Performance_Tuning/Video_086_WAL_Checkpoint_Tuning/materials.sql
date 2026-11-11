-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- WAL & Checkpoint Tuning (Classes 176-177)
-- Phase 21: Performance Tuning
-- ============================================================

-- ============================================================
-- 1. CHECKPOINT PARAMETERS
-- ============================================================

-- Current checkpoint settings:
SHOW max_wal_size;                    -- default 1GB
SHOW min_wal_size;                    -- default 80MB
SHOW checkpoint_timeout;              -- default 5min
SHOW checkpoint_completion_target;    -- default 0.9
SHOW checkpoint_warning;              -- default 30s

-- Checkpoint statistics:
SELECT checkpoints_timed,
       checkpoints_req,
       buffers_checkpoint,
       buffers_clean,
       buffers_backend,
       maxwritten_clean
FROM pg_stat_bgwriter;

-- Key indicators:
-- checkpoints_req >> checkpoints_timed → increase max_wal_size
-- buffers_backend high → increase shared_buffers or bgwriter
-- maxwritten_clean > 0 → increase bgwriter_lru_maxpages

-- ============================================================
-- 2. WAL PARAMETERS
-- ============================================================

-- Current WAL settings:
SHOW wal_buffers;           -- default -1 (auto)
SHOW wal_level;             -- default replica
SHOW wal_compression;       -- default off
SHOW full_page_writes;      -- default on (NEVER disable!)
SHOW synchronous_commit;    -- default on

-- WAL generation statistics (PG 16):
SELECT wal_records,
       wal_fpi,
       pg_size_pretty(wal_bytes) AS wal_generated,
       wal_buffers_full,
       wal_write,
       wal_sync
FROM pg_stat_wal;

-- WAL directory size:
SELECT count(*) AS wal_files,
       pg_size_pretty(sum(size)) AS total
FROM pg_ls_waldir();

-- ============================================================
-- 3. SYNCHRONOUS_COMMIT OPTIONS
-- ============================================================

-- Check current:
SHOW synchronous_commit;

-- Per-session (for non-critical writes):
SET synchronous_commit = off;
INSERT INTO access_log (action, ts) VALUES ('login', now());
RESET synchronous_commit;

-- Per-transaction:
BEGIN;
SET LOCAL synchronous_commit = off;
INSERT INTO metrics (name, value) VALUES ('cpu_usage', 85.5);
COMMIT;

-- ============================================================
-- 4. WAL COMPRESSION
-- ============================================================

-- Enable WAL compression (PG 16 options: pglz, lz4, zstd):
-- postgresql.conf: wal_compression = 'zstd'

-- Check after enabling:
SHOW wal_compression;

-- ============================================================
-- 5. BACKGROUND WRITER
-- ============================================================

-- Current settings:
SHOW bgwriter_delay;           -- default 200ms
SHOW bgwriter_lru_maxpages;    -- default 100
SHOW bgwriter_lru_multiplier;  -- default 2.0
SHOW bgwriter_flush_after;     -- default 512kB

-- ============================================================
-- 6. COMPLETE PRODUCTION CONFIG (32GB SERVER)
-- ============================================================

-- postgresql.conf WAL & checkpoint settings:
-- wal_buffers = -1                      # auto (restart)
-- max_wal_size = '8GB'                  # no restart
-- min_wal_size = '1GB'                  # no restart
-- checkpoint_timeout = '15min'          # no restart
-- checkpoint_completion_target = 0.9    # no restart
-- wal_compression = 'zstd'             # no restart
-- wal_level = 'replica'                # restart required
-- full_page_writes = on                # no restart
-- synchronous_commit = on              # no restart

-- ============================================================
-- 7. MONITORING QUERIES
-- ============================================================

-- Checkpoint frequency check:
SELECT checkpoints_timed AS by_timeout,
       checkpoints_req AS by_wal_size,
       ROUND(100.0 * checkpoints_req /
         NULLIF(checkpoints_timed + checkpoints_req, 0), 1)
         AS pct_forced
FROM pg_stat_bgwriter;

-- If pct_forced > 50%, increase max_wal_size

-- Backend writes (should be near zero):
SELECT buffers_backend,
       buffers_checkpoint + buffers_clean AS bgwriter_total,
       ROUND(100.0 * buffers_backend /
         NULLIF(buffers_backend + buffers_checkpoint + buffers_clean, 0), 1)
         AS pct_backend_writes
FROM pg_stat_bgwriter;

-- If pct_backend_writes > 10%, increase shared_buffers or bgwriter

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Check pg_stat_bgwriter. Are checkpoints_req > checkpoints_timed?
-- 2. Check pg_stat_wal. How much WAL has been generated?
-- 3. Set synchronous_commit = off for a session.
--    Run 1000 INSERTs. Compare speed to synchronous_commit = on.
-- 4. Calculate appropriate max_wal_size for your workload
--    based on WAL generation rate.
-- 5. Check if buffers_backend is high relative to buffers_checkpoint.
