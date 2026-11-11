-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- RTO, RPO & Backup Overview (Classes 143-144)
-- Phase 18: Backup, Recovery & Disaster Recovery
-- ============================================================

-- ============================================================
-- 1. CHECK CURRENT BACKUP-RELATED SETTINGS
-- ============================================================

SHOW wal_level;          -- must be 'replica' or 'logical' for physical backup
SHOW archive_mode;       -- 'on' needed for WAL archiving
SHOW archive_command;    -- command to archive WAL files

-- ============================================================
-- 2. DATABASE SIZE (to estimate backup time/space)
-- ============================================================

SELECT datname,
       pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;

-- ============================================================
-- 3. WAL ARCHIVING STATUS
-- ============================================================

SELECT archived_count,
       failed_count,
       last_archived_wal,
       last_archived_time,
       last_failed_wal,
       last_failed_time
FROM pg_stat_archiver;

-- ============================================================
-- 4. BACKUP METHOD COMPARISON
-- ============================================================

-- pg_dump (Logical):
--   + Portable (cross-version, cross-platform)
--   + Selective (specific tables/schemas)
--   - Slow for large databases
--   - No PITR support
--
-- pg_basebackup (Physical):
--   + Fast — streams binary data
--   + Supports PITR with WAL archiving
--   - Same major version only
--   - All-or-nothing restore
--
-- Filesystem Snapshot:
--   + Near-instant
--   + Supports PITR with WAL archiving
--   - Requires consistent filesystem or WAL archiving

-- ============================================================
-- 5. RTO/RPO REFERENCE
-- ============================================================

-- RTO (Recovery Time Objective):
--   Maximum acceptable DOWNTIME
--   "How long can we be down?"
--
-- RPO (Recovery Point Objective):
--   Maximum acceptable DATA LOSS
--   "How much data can we lose?"
--
-- | Business     | RTO       | RPO       | Strategy              |
-- |--------------|-----------|-----------|------------------------|
-- | Blog         | 24 hours  | 24 hours  | Daily pg_dump          |
-- | E-commerce   | 1 hour    | 5 minutes | Replication + PITR     |
-- | Banking      | < 5 min   | 0         | Sync replication + PITR|

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. SHOW wal_level; SHOW archive_mode; SHOW archive_command;
-- 2. Define RTO/RPO for a project you know
-- 3. Check pg_stat_archiver for archive health
-- 4. List all databases with sizes to estimate backup needs
