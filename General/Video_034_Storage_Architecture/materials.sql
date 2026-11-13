-- =============================================
-- PostgreSQL Mastery: Storage Architecture
-- Phase 9: Architecture | Class 70
-- =============================================
-- Data directory, table files, OIDs, WAL, TOAST,
-- FSM, VM, and disk usage monitoring.
-- =============================================

-- === DATA DIRECTORY ===

SHOW data_directory;
-- Linux default: /var/lib/postgresql/16/main
-- Windows default: C:/Program Files/PostgreSQL/16/data

-- === DATABASE OIDs ===

-- Each database = a subdirectory in base/<oid>
SELECT oid, datname FROM pg_database ORDER BY oid;

-- Your current database OID
SELECT oid, datname FROM pg_database WHERE datname = current_database();

-- === TABLE FILE PATHS ===

-- Find the file path for any table
SELECT pg_relation_filepath('employees');
-- Returns: base/<db_oid>/<filenode>

-- Filenode can differ from OID after VACUUM FULL or REINDEX
SELECT oid, relfilenode, relname
FROM pg_class
WHERE relname = 'employees';

-- === TABLE SIZES ON DISK ===

-- Data fork only (main file)
SELECT pg_size_pretty(pg_relation_size('employees')) AS data_size;

-- Total (data + indexes + TOAST + FSM + VM)
SELECT pg_size_pretty(pg_total_relation_size('employees')) AS total_size;

-- Indexes only
SELECT pg_size_pretty(pg_indexes_size('employees')) AS indexes_size;

-- All tables sorted by total size
SELECT
  schemaname,
  relname AS table_name,
  pg_size_pretty(pg_relation_size(schemaname || '.' || relname)) AS data,
  pg_size_pretty(pg_indexes_size(schemaname || '.' || relname)) AS indexes,
  pg_size_pretty(pg_total_relation_size(schemaname || '.' || relname)) AS total
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname || '.' || relname) DESC;

-- Database total size
SELECT pg_size_pretty(pg_database_size(current_database())) AS db_size;

-- All databases
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database ORDER BY pg_database_size(datname) DESC;

-- === FILE FORKS: MAIN, FSM, VM ===

-- Each table has up to 4 file forks:
-- main  = actual data
-- fsm   = Free Space Map (where to insert)
-- vm    = Visibility Map (clean pages for VACUUM)
-- init  = only for unlogged tables

-- Check each fork's size
SELECT
  pg_size_pretty(pg_relation_size('employees', 'main')) AS main,
  pg_size_pretty(pg_relation_size('employees', 'fsm'))  AS fsm,
  pg_size_pretty(pg_relation_size('employees', 'vm'))   AS vm;

-- === 8 KB PAGES ===

-- Each file is divided into 8 KB pages
-- Each page holds multiple rows (tuples)
-- Page layout: header (24 bytes) + item pointers + tuples + special area

-- How many pages does a table have?
SELECT relpages, reltuples::BIGINT AS est_rows
FROM pg_class WHERE relname = 'employees';

-- === 1 GB SEGMENTS ===

-- When a table file exceeds 1 GB, PostgreSQL splits it:
-- base/16384/16400       (first 1 GB)
-- base/16384/16400.1     (next 1 GB)
-- base/16384/16400.2     (next 1 GB)
-- Each segment = exactly 131072 pages × 8 KB = 1 GB

-- === TOAST ===

-- TOAST = The Oversized-Attribute Storage Technique
-- Problem: a row must fit in one 8 KB page
-- Solution: compress and/or move large values

-- TOAST strategies per column:
-- EXTENDED (default for text/jsonb): compress first, then move
-- EXTERNAL: move without compressing (faster retrieval)
-- MAIN: try to compress, avoid moving
-- PLAIN: never TOAST (only for small fixed-size types)

-- Check TOAST strategy for each column
SELECT attname, atttypid::regtype AS type,
       CASE attstorage
         WHEN 'p' THEN 'PLAIN'
         WHEN 'e' THEN 'EXTERNAL'
         WHEN 'm' THEN 'MAIN'
         WHEN 'x' THEN 'EXTENDED'
       END AS toast_strategy
FROM pg_attribute
WHERE attrelid = 'employees'::regclass AND attnum > 0
ORDER BY attnum;

-- Find a table's TOAST table
SELECT reltoastrelid::regclass AS toast_table
FROM pg_class WHERE relname = 'employees';

-- TOAST table size
SELECT pg_size_pretty(pg_total_relation_size(reltoastrelid))
  AS toast_size
FROM pg_class WHERE relname = 'employees';

-- Change TOAST strategy for a column
-- ALTER TABLE employees ALTER COLUMN bio SET STORAGE EXTERNAL;

-- === WAL (Write-Ahead Log) ===

-- Current WAL position
SELECT pg_current_wal_lsn();

-- WAL insert position (latest write)
SELECT pg_current_wal_insert_lsn();

-- WAL flush position (confirmed on disk)
SELECT pg_current_wal_flush_lsn();

-- Total WAL size on disk
SELECT pg_size_pretty(sum(size)) AS wal_size
FROM pg_ls_waldir();

-- List WAL files
SELECT name, pg_size_pretty(size) AS size,
       modification
FROM pg_ls_waldir()
ORDER BY modification DESC
LIMIT 10;

-- WAL settings
SHOW wal_level;           -- minimal, replica, logical
SHOW max_wal_size;        -- triggers checkpoint (default: 1GB)
SHOW min_wal_size;        -- keeps at least this much (default: 80MB)
SHOW wal_segment_size;    -- each file size (default: 16MB)

-- === pg_xact (CLOG) ===

-- Transaction commit status directory
-- Stores 2 bits per transaction:
--   00 = in progress
--   01 = committed
--   10 = aborted
--   11 = sub-committed

-- Current transaction ID
SELECT txid_current();

-- === TABLESPACES ===

-- Tablespaces let you put tables on different disks
-- Default tablespaces:
SELECT spcname, pg_size_pretty(pg_tablespace_size(spcname)) AS size
FROM pg_tablespace;

-- pg_default = where tables go by default
-- pg_global  = shared system catalogs

-- Create a tablespace (requires OS directory):
-- CREATE TABLESPACE fast_disk LOCATION '/mnt/ssd/pg_data';
-- CREATE TABLE hot_data (...) TABLESPACE fast_disk;

-- === MONITORING DISK USAGE ===

-- Total disk used by all databases
SELECT
  datname,
  pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE datname NOT LIKE 'template%'
ORDER BY pg_database_size(datname) DESC;

-- Biggest tables across all schemas
SELECT
  nspname || '.' || relname AS table_name,
  pg_size_pretty(pg_total_relation_size(c.oid)) AS total,
  pg_size_pretty(pg_relation_size(c.oid)) AS data,
  pg_size_pretty(pg_indexes_size(c.oid)) AS indexes
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE relkind = 'r' AND nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT 20;

-- === PRACTICE EXERCISES ===

-- Exercise 1: Find your data directory
SHOW data_directory;

-- Exercise 2: Database OIDs
SELECT oid, datname FROM pg_database;

-- Exercise 3: Table file path
SELECT pg_relation_filepath('employees');

-- Exercise 4: Compare data vs total size
SELECT
  pg_size_pretty(pg_relation_size('employees')) AS data,
  pg_size_pretty(pg_total_relation_size('employees')) AS total;

-- Exercise 5: Check all fork sizes
SELECT
  pg_size_pretty(pg_relation_size('employees', 'main')) AS main,
  pg_size_pretty(pg_relation_size('employees', 'fsm'))  AS fsm,
  pg_size_pretty(pg_relation_size('employees', 'vm'))   AS vm;

-- Exercise 6: WAL position and size
SELECT pg_current_wal_lsn();
SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir();

-- Exercise 7: Database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database ORDER BY pg_database_size(datname) DESC;

-- =============================================
-- Next Class: Query Flow & MVCC
-- =============================================


-- =============================================
-- ANSWER KEY — STORAGE ARCHITECTURE SOLUTIONS
-- =============================================

-- 1. Locate Data Directory
SHOW data_directory;

-- 2. Map Table to RelFileNode Path
SELECT pg_relation_filepath('employees');

-- 3. Compare Heap vs Total Relation Size
SELECT pg_size_pretty(pg_relation_size('employees')) AS heap_size,
       pg_size_pretty(pg_total_relation_size('employees')) AS total_size;

-- 4. Check Current WAL LSN and Total WAL Storage
SELECT pg_current_wal_lsn() AS current_lsn;
SELECT pg_size_pretty(sum(size)) AS total_wal_size FROM pg_ls_waldir();

-- 5. Calculate Total Database Footprint
SELECT datname,
       pg_size_pretty(pg_database_size(datname)) AS total_db_size
FROM pg_database
WHERE datname = current_database();
