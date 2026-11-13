-- =============================================
-- PostgreSQL Mastery: Memory Architecture
-- Phase 9: Architecture | Class 69
-- =============================================
-- shared_buffers, work_mem, maintenance_work_mem,
-- buffer cache hit ratio, and memory tuning.
-- =============================================

-- === CHECK CURRENT MEMORY SETTINGS ===

SHOW shared_buffers;           -- default: 128MB (way too small!)
SHOW work_mem;                 -- default: 4MB per operation
SHOW maintenance_work_mem;     -- default: 64MB
SHOW temp_buffers;             -- default: 8MB per session
SHOW wal_buffers;              -- default: -1 (auto-tuned)
SHOW effective_cache_size;     -- hint to planner (not actual allocation)

-- === BUFFER CACHE HIT RATIO ===

-- How well is shared_buffers working?
-- Should be > 99% for OLTP workloads
SELECT
  datname,
  blks_hit,
  blks_read,
  ROUND(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2)
    AS cache_hit_pct
FROM pg_stat_database
WHERE datname = current_database();

-- All databases at once
SELECT
  datname,
  blks_hit,
  blks_read,
  ROUND(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2)
    AS cache_hit_pct
FROM pg_stat_database
WHERE datname IS NOT NULL
ORDER BY cache_hit_pct;

-- === SHARED_BUFFERS ===

-- shared_buffers = RAM cache for 8 KB data pages
-- Recommendation: ~25% of total RAM
-- Never more than ~40% (OS needs the rest for file cache)

-- Check actual size in pages and bytes
SELECT
  name,
  setting,
  unit,
  pg_size_pretty(setting::BIGINT * 8192) AS actual_size
FROM pg_settings
WHERE name = 'shared_buffers';

-- === WORK_MEM ===

-- work_mem = memory per SORT or HASH operation
-- A query with 3 sorts uses 3 × work_mem
-- 100 connections × 3 sorts × 4MB = 1.2 GB
-- Be careful when increasing!

-- Check current value
SHOW work_mem;

-- Temporarily increase for a big query
SET work_mem = '64MB';
SHOW work_mem;

-- Run your complex query here...

-- Reset back to default
RESET work_mem;
SHOW work_mem;

-- Set for just one transaction
BEGIN;
SET LOCAL work_mem = '128MB';
-- Your query here
COMMIT;
-- work_mem is back to default after COMMIT

-- === MAINTENANCE_WORK_MEM ===

-- Used by: VACUUM, CREATE INDEX, ALTER TABLE ADD FK
-- Runs one at a time usually → safe to set higher
-- Recommendation: 256MB - 2GB depending on server

SHOW maintenance_work_mem;

-- Temporarily increase for a big index build
SET maintenance_work_mem = '512MB';
CREATE INDEX CONCURRENTLY idx_test ON your_table (column);
RESET maintenance_work_mem;

-- === DETECTING MEMORY PRESSURE ===

-- Check if sorts are spilling to disk (temp files)
SELECT
  datname,
  temp_files,
  pg_size_pretty(temp_bytes) AS temp_size
FROM pg_stat_database
WHERE datname = current_database();
-- temp_files > 0 means sorts/hashes spilled to disk
-- Consider increasing work_mem

-- Enable temp file logging in postgresql.conf:
-- log_temp_files = 0   (log ALL temp files)
-- log_temp_files = 1024 (log temp files > 1MB)

-- === EXPLAIN WITH BUFFERS ===

-- See actual buffer usage for a query
CREATE TABLE test_memory (
    id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    val  INT,
    data TEXT
);

INSERT INTO test_memory (val, data)
SELECT g, repeat('x', 100)
FROM generate_series(1, 10000) AS g;

-- Check buffer hits vs reads
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM test_memory ORDER BY val;
-- Look for:
--   Sort Method: quicksort  (fits in work_mem)
--   Sort Method: external merge  (spilled to disk!)
--   Buffers: shared hit=X read=Y
--   hit = from shared_buffers (fast)
--   read = from disk (slow)

-- === MEMORY SIZING GUIDE ===

-- Server RAM | shared_buffers | work_mem   | maint_work_mem
-- -----------+----------------+------------+---------------
-- 4 GB       | 1 GB           | 4-8 MB     | 256 MB
-- 8 GB       | 2 GB           | 8-16 MB    | 512 MB
-- 16 GB      | 4 GB           | 16-32 MB   | 1 GB
-- 32 GB      | 8 GB           | 32-64 MB   | 1-2 GB
-- 64 GB      | 16 GB          | 64-128 MB  | 2 GB

-- Golden rules:
-- 1. shared_buffers = ~25% of RAM
-- 2. effective_cache_size = ~75% of RAM (planner hint only)
-- 3. work_mem: start small, increase if temp files appear
-- 4. maintenance_work_mem: 256MB+ for production
-- 5. Never give PG more than 40% of RAM as shared_buffers

-- === PER-TABLE BUFFER USAGE ===

-- Which tables are in the buffer cache?
SELECT
  c.relname AS table_name,
  pg_size_pretty(pg_relation_size(c.oid)) AS table_size,
  count(*) AS buffers_cached,
  pg_size_pretty(count(*) * 8192) AS cached_size
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = c.relfilenode
WHERE c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
GROUP BY c.relname, c.oid
ORDER BY buffers_cached DESC;
-- Requires: CREATE EXTENSION pg_buffercache;
-- Shows which tables are actually in the buffer cache

-- === RESET STATS TO MEASURE FRESH ===

-- Reset stats for current database
SELECT pg_stat_reset();

-- After some workload, check hit ratio again
SELECT
  blks_hit, blks_read,
  ROUND(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2)
    AS fresh_hit_pct
FROM pg_stat_database
WHERE datname = current_database();

-- === PRACTICE EXERCISES ===

-- Exercise 1: Check all memory settings
SHOW shared_buffers;
SHOW work_mem;
SHOW maintenance_work_mem;
SHOW temp_buffers;
SHOW wal_buffers;

-- Exercise 2: Calculate buffer cache hit ratio
SELECT
  ROUND(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2)
    AS cache_hit_pct
FROM pg_stat_database
WHERE datname = current_database();

-- Exercise 3: Temporarily increase work_mem
SET work_mem = '64MB';
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM test_memory ORDER BY val;
RESET work_mem;

-- Exercise 4: Check temp file usage
SELECT datname, temp_files, pg_size_pretty(temp_bytes) AS temp_size
FROM pg_stat_database WHERE datname = current_database();

-- Exercise 5: Check shared_buffers in bytes
SELECT pg_size_pretty(setting::BIGINT * 8192) AS shared_buffers_bytes
FROM pg_settings WHERE name = 'shared_buffers';

-- Exercise 6: Compare to effective_cache_size
SHOW effective_cache_size;
-- This is a HINT to the planner, not actual memory allocation
-- Set to ~75% of RAM so planner knows disk cache exists

-- Exercise 7: EXPLAIN BUFFERS on a query
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM test_memory WHERE val BETWEEN 1000 AND 2000;

-- === CLEANUP ===
-- DROP TABLE IF EXISTS test_memory;

-- =============================================
-- Next Class: Storage Architecture
-- =============================================


-- =============================================
-- ANSWER KEY — MEMORY ARCHITECTURE & TUNING
-- =============================================

-- 1. Inspect Key Memory Parameters
SHOW shared_buffers;
SHOW work_mem;
SHOW maintenance_work_mem;
SHOW max_connections;

-- 2. Buffer Cache Hit Ratio
SELECT datname,
       ROUND(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct
FROM pg_stat_database
WHERE datname = current_database();

-- 3. Session-Level Memory Tuning
SET work_mem = '64MB';
-- Run complex sort or hash query
RESET work_mem;

-- 4. Monitor Temp File Spill to Disk
SELECT datname,
       temp_files,
       pg_size_pretty(temp_bytes) AS total_temp_size
FROM pg_stat_database
WHERE temp_files > 0;

-- 5. Profile Buffer Cache Hits vs Reads
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM pg_class ORDER BY relname;
