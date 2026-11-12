-- =============================================
-- PostgreSQL Mastery: Tablespaces
-- Phase 2: Database Objects | Class 11
-- =============================================
-- Tablespaces = physical locations on disk for data storage.
-- =============================================

-- === WHAT IS A TABLESPACE? ===
-- A named directory on disk where PostgreSQL stores data files
-- Schema = logical organization (by name)
-- Tablespace = physical organization (by disk location)

-- Default tablespaces:
-- pg_default = stores regular user data (inside data directory)
-- pg_global  = cluster-wide shared system data

-- List tablespaces
-- \db

-- === CREATE TABLESPACE ===

-- Step 1: Create directory on OS (Linux)
-- sudo mkdir -p /mnt/fast_ssd/pg_data
-- sudo chown postgres:postgres /mnt/fast_ssd/pg_data

-- Step 2: Create tablespace in PostgreSQL
CREATE TABLESPACE fast_ssd LOCATION '/mnt/fast_ssd/pg_data';

-- Windows example:
-- First create D:\pg_data directory
-- CREATE TABLESPACE fast_ssd LOCATION 'D:\pg_data';

-- Create tablespace with owner
CREATE TABLESPACE archive_ts OWNER postgres LOCATION '/mnt/hdd/pg_archive';

-- === USING TABLESPACES ===

-- Create table on a specific tablespace
CREATE TABLE big_logs (
    id         SERIAL,
    message    TEXT,
    created_at TIMESTAMP DEFAULT now()
) TABLESPACE fast_ssd;

-- Create index on a specific tablespace
CREATE INDEX idx_logs_created ON big_logs (created_at) TABLESPACE fast_ssd;

-- Set default tablespace for a database
ALTER DATABASE practice SET default_tablespace = 'fast_ssd';

-- Set default tablespace for current session
SET default_tablespace = 'fast_ssd';

-- Move existing table to a different tablespace
-- WARNING: This LOCKS the table and REWRITES all data!
ALTER TABLE big_logs SET TABLESPACE pg_default;

-- Move an index to a different tablespace
ALTER INDEX idx_logs_created SET TABLESPACE fast_ssd;

-- === QUERYING TABLESPACE INFO ===

-- Which tablespace is each table on?
SELECT tablename, tablespace
FROM pg_tables
WHERE schemaname = 'public';
-- NULL/blank = pg_default

-- Tablespace sizes
SELECT spcname, pg_size_pretty(pg_tablespace_size(spcname)) AS size
FROM pg_tablespace;

-- Tablespace locations
SELECT spcname, pg_tablespace_location(oid)
FROM pg_tablespace;

-- === DROP TABLESPACE ===

-- Must be empty first! Move or drop all objects
DROP TABLESPACE fast_ssd;

-- Safe version
DROP TABLESPACE IF EXISTS fast_ssd;

-- === WHEN TO USE TABLESPACES ===

-- GOOD use cases:
-- 1. Indexes on fast SSD, data on HDD
-- 2. Primary disk full — spread to another disk
-- 3. Separate I/O for tables vs indexes
-- 4. Archive old data to cheap storage
-- 5. Large databases with mixed workloads

-- NOT needed for:
-- Small to medium databases
-- Single-disk servers
-- Cloud managed databases (RDS, Aurora, etc.)
-- Default pg_default is fine for most applications

-- === COMMON ERRORS ===

-- ERROR: directory "/path" does not exist
-- FIX: Create the directory on the OS first

-- ERROR: could not set permissions on directory
-- FIX: sudo chown postgres:postgres /path/to/dir

-- ERROR: tablespace "fast_ssd" is not empty
-- FIX: Move or drop all objects from the tablespace first

-- WARNING: ALTER TABLE SET TABLESPACE locks table + rewrites all data
-- Plan large moves during maintenance windows!

-- === PRACTICE EXERCISES ===

-- Exercise 1: List all tablespaces and check sizes
-- \db
SELECT spcname, pg_size_pretty(pg_tablespace_size(spcname)) AS size
FROM pg_tablespace;

-- Exercise 2: (if you have a second disk/directory)
-- Create a tablespace, create a table on it, query info
-- CREATE TABLESPACE my_ts LOCATION '/path/to/dir';
-- CREATE TABLE test_table (id INT) TABLESPACE my_ts;

-- Exercise 3: Check tablespace for existing tables
SELECT tablename, tablespace
FROM pg_tables
WHERE schemaname = 'public';

-- Exercise 4: Move a table between tablespaces
-- ALTER TABLE test_table SET TABLESPACE pg_default;
-- Then drop: DROP TABLESPACE my_ts;

-- Note: Cloud databases (RDS, Aurora, Azure) may not support
-- custom tablespaces — that's normal.

-- === CLEANUP ===
-- DROP TABLE IF EXISTS big_logs;
-- DROP TABLESPACE IF EXISTS fast_ssd;
-- DROP TABLESPACE IF EXISTS archive_ts;

-- =============================================
-- Next Class: Data Types — Numeric & Text
-- =============================================


-- === ANSWER KEY ===

-- Answer 1:
-- \db+
SELECT spcname, pg_size_pretty(pg_tablespace_size(spcname)) AS size
FROM pg_tablespace;

-- Answer 2:
-- (On Linux: sudo mkdir -p /mnt/fast_ssd/pg_data && sudo chown postgres:postgres /mnt/fast_ssd/pg_data)
-- CREATE TABLESPACE fast_ssd LOCATION '/mnt/fast_ssd/pg_data';
-- CREATE TABLE t1 (id INT) TABLESPACE fast_ssd;

-- Answer 3:
SELECT tablename, COALESCE(tablespace, 'pg_default') AS tablespace_name
FROM pg_tables
WHERE schemaname = 'public';

-- Answer 4:
-- ALTER TABLE t1 SET TABLESPACE pg_default;

-- Answer 5:
-- Managed cloud DBs (AWS RDS, Azure, Cloud SQL) restrict custom OS paths;
-- choose storage classes / provisioned IOPS tiers instead.
