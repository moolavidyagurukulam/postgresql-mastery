-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- postgresql.conf Deep Dive (Classes 130-131)
-- Phase 16: Administration Basics
-- ============================================================

-- ============================================================
-- 1. FINDING CONFIGURATION FILES
-- ============================================================

SHOW config_file;
SHOW data_directory;
SHOW hba_file;
SHOW ident_file;

-- ============================================================
-- 2. QUERYING CURRENT SETTINGS
-- ============================================================

-- Single parameter:
SHOW shared_buffers;
SHOW work_mem;
SHOW max_connections;

-- Detailed info from pg_settings:
SELECT name, setting, unit, context, source, pending_restart
FROM pg_settings
WHERE name = 'shared_buffers';

-- All non-default parameters:
SELECT name, setting, unit, boot_val, source
FROM pg_settings
WHERE source <> 'default' AND source <> 'override'
ORDER BY name;

-- Parameters that need restart:
SELECT name, setting, unit, pending_restart
FROM pg_settings
WHERE pending_restart = true;

-- Parameters by context (when they take effect):
SELECT context, count(*)
FROM pg_settings
GROUP BY context ORDER BY count DESC;

-- Check config file for errors:
SELECT sourcefile, name, setting, applied, error
FROM pg_file_settings
WHERE error IS NOT NULL;

-- ============================================================
-- 3. MEMORY PARAMETERS
-- ============================================================

-- Key memory settings:
SELECT name, setting, unit,
       CASE WHEN unit = '8kB' THEN (setting::bigint * 8 / 1024) || ' MB'
            WHEN unit = 'kB' THEN (setting::bigint / 1024) || ' MB'
            ELSE setting || ' ' || COALESCE(unit, '')
       END AS human_readable
FROM pg_settings
WHERE name IN (
    'shared_buffers',
    'work_mem',
    'maintenance_work_mem',
    'autovacuum_work_mem',
    'effective_cache_size',
    'temp_buffers',
    'wal_buffers'
)
ORDER BY name;

-- ============================================================
-- RECOMMENDED VALUES BY SERVER SIZE
-- ============================================================
--
-- | Parameter              | 4GB   | 16GB  | 64GB  |
-- |------------------------|-------|-------|-------|
-- | shared_buffers         | 1GB   | 4GB   | 16GB  |
-- | effective_cache_size   | 3GB   | 12GB  | 48GB  |
-- | work_mem               | 8MB   | 32MB  | 128MB |
-- | maintenance_work_mem   | 256MB | 1GB   | 2GB   |
-- | max_connections         | 50    | 100   | 200   |
-- | max_wal_size           | 1GB   | 4GB   | 8GB   |
-- | random_page_cost       | 1.1   | 1.1   | 1.1   |
-- | effective_io_concurrency| 200   | 200   | 200   |

-- ============================================================
-- 4. WAL & CHECKPOINT PARAMETERS
-- ============================================================

SELECT name, setting, unit
FROM pg_settings
WHERE name IN (
    'wal_level', 'wal_buffers', 'max_wal_size', 'min_wal_size',
    'checkpoint_completion_target', 'checkpoint_timeout'
)
ORDER BY name;

-- ============================================================
-- 5. LOGGING PARAMETERS
-- ============================================================

SELECT name, setting
FROM pg_settings
WHERE name LIKE 'log%'
ORDER BY name;

-- ============================================================
-- 6. PLANNER PARAMETERS
-- ============================================================

SELECT name, setting, unit
FROM pg_settings
WHERE name IN (
    'random_page_cost', 'seq_page_cost',
    'effective_io_concurrency', 'default_statistics_target',
    'jit', 'max_parallel_workers_per_gather'
)
ORDER BY name;

-- ============================================================
-- 7. AUTOVACUUM PARAMETERS
-- ============================================================

SELECT name, setting, unit
FROM pg_settings
WHERE name LIKE 'autovacuum%'
ORDER BY name;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Find your postgresql.conf location
-- SHOW config_file;

-- 2. List all restart-only parameters
-- SELECT name FROM pg_settings WHERE context = 'postmaster' ORDER BY name;

-- 3. Check your current memory settings
-- SELECT name, setting, unit FROM pg_settings
-- WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size');

-- 4. Check for config errors
-- SELECT * FROM pg_file_settings WHERE error IS NOT NULL;

-- 5. Find non-default parameters
-- SELECT name, setting, boot_val FROM pg_settings WHERE source <> 'default';
