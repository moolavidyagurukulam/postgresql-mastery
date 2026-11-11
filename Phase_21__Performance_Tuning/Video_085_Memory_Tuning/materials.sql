-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Memory Tuning (Classes 174-175)
-- Phase 21: Performance Tuning
-- ============================================================

-- ============================================================
-- 1. SHARED_BUFFERS
-- ============================================================

-- Check current setting:
SHOW shared_buffers;

-- Cache hit ratio (should be > 99%):
SELECT
  datname,
  blks_hit,
  blks_read,
  ROUND(
    100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2
  ) AS hit_ratio_pct
FROM pg_stat_database
WHERE datname = current_database();

-- Per-table cache hit ratio:
SELECT relname,
       heap_blks_hit,
       heap_blks_read,
       ROUND(
         100.0 * heap_blks_hit /
         NULLIF(heap_blks_hit + heap_blks_read, 0), 2
       ) AS hit_ratio_pct
FROM pg_statio_user_tables
WHERE heap_blks_hit + heap_blks_read > 100
ORDER BY hit_ratio_pct ASC
LIMIT 10;

-- Recommended setting:
-- shared_buffers = 25% of total RAM
-- 32GB server → shared_buffers = '8GB'
-- REQUIRES PostgreSQL restart!

-- ============================================================
-- 2. WORK_MEM
-- ============================================================

-- Check current setting:
SHOW work_mem;

-- Check for disk spills (temp file usage):
SELECT datname,
       temp_files,
       pg_size_pretty(temp_bytes) AS temp_size
FROM pg_stat_database
WHERE temp_bytes > 0;

-- Enable temp file logging:
-- postgresql.conf: log_temp_files = 0 (log ALL)
-- or: log_temp_files = 10240 (log only > 10MB)

-- Set globally (conservative):
-- work_mem = '32MB'  (no restart needed — reload is enough)

-- Set per-session for a heavy report:
SET work_mem = '256MB';

-- Check if sort fits in memory:
EXPLAIN ANALYZE
SELECT customer_id, SUM(amount) AS total
FROM orders
GROUP BY customer_id
ORDER BY total DESC;
-- Look for: Sort Method: quicksort Memory (good)
-- vs: Sort Method: external merge Disk (bad)

RESET work_mem;

-- Set for a single transaction only:
BEGIN;
SET LOCAL work_mem = '256MB';
-- heavy query here...
COMMIT;
-- work_mem automatically resets

-- ============================================================
-- 3. MAINTENANCE_WORK_MEM
-- ============================================================

-- Check current setting:
SHOW maintenance_work_mem;

-- Increase per-session for manual maintenance:
SET maintenance_work_mem = '2GB';

-- CREATE INDEX (benefits from more memory):
CREATE INDEX idx_test ON orders(amount);
DROP INDEX idx_test;

-- VACUUM (processes more dead tuples per pass):
VACUUM (VERBOSE) orders;

RESET maintenance_work_mem;

-- Recommended: 1-2GB in postgresql.conf
-- maintenance_work_mem = '2GB' (no restart needed)

-- ============================================================
-- 4. AUTOVACUUM_WORK_MEM
-- ============================================================

-- Check current setting:
SHOW autovacuum_work_mem;
-- -1 = use maintenance_work_mem

-- Set separately to limit autovacuum memory:
-- autovacuum_work_mem = '512MB' (no restart needed)

-- Total autovacuum memory:
-- autovacuum_max_workers × autovacuum_work_mem
-- 3 × 512MB = 1.5GB

-- ============================================================
-- 5. EFFECTIVE_CACHE_SIZE
-- ============================================================

-- Check current setting:
SHOW effective_cache_size;

-- This is NOT allocated memory — it's a planner hint!
-- Set to 50-75% of total RAM:
-- 32GB server → effective_cache_size = '24GB'

-- Impact on planner:
SET effective_cache_size = '128MB';
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
-- May choose Seq Scan (thinks cache is small)

SET effective_cache_size = '24GB';
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
-- May choose Index Scan (thinks cache is large)

RESET effective_cache_size;

-- ============================================================
-- 6. ADDITIONAL MEMORY PARAMETERS
-- ============================================================

-- Temp buffers (per-session temp table cache):
SHOW temp_buffers;
-- Default: 8MB. Set to 32MB for temp table-heavy workloads.

-- Huge pages:
SHOW huge_pages;
-- Default: try. Use 'on' if OS is configured for huge pages.

-- ============================================================
-- 7. COMPLETE CONFIGURATION (32GB SERVER)
-- ============================================================

-- postgresql.conf:
-- shared_buffers = '8GB'           # 25% of RAM (restart)
-- effective_cache_size = '24GB'    # 75% of RAM (reload)
-- work_mem = '32MB'                # conservative global (reload)
-- maintenance_work_mem = '2GB'     # fast maintenance (reload)
-- autovacuum_work_mem = '512MB'    # per autovacuum worker (reload)
-- temp_buffers = '32MB'            # temp table cache (reload)
-- huge_pages = 'try'               # OS huge pages (restart)

-- ============================================================
-- MONITORING QUERIES
-- ============================================================

-- Overall cache hit ratio:
SELECT
  ROUND(100.0 * sum(blks_hit) /
    NULLIF(sum(blks_hit) + sum(blks_read), 0), 2) AS overall_hit_pct
FROM pg_stat_database;

-- Temp file trend (reset stats to start fresh):
-- SELECT pg_stat_reset();
-- Then check temp_files and temp_bytes periodically.

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Check your cache hit ratio. Is it above 99%?
-- 2. Set work_mem to 64kB and run a sort-heavy query.
--    Confirm disk spill in EXPLAIN ANALYZE.
--    Then set work_mem to 128MB and compare.
-- 3. Check temp file usage in pg_stat_database.
-- 4. Set effective_cache_size very low (128MB) and very high (24GB).
--    Compare EXPLAIN plans for the same query.
-- 5. Calculate the memory configuration for your server
--    using the 25%/75% rules.
