-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Scenario: Data Corruption & Blocking Queries (Classes 280-281)
-- Phase 32: Real-World Scenarios
-- ============================================================

-- ============================================================
-- SCENARIO 1: DATA CORRUPTION RECOVERY
-- ============================================================

-- ============================================================
-- 1. DETECT — Identify corruption
-- ============================================================

-- Check if data checksums are enabled:
SHOW data_checksums;
-- If 'off', corruption is silent — you won't get errors until data is wrong

-- Check PostgreSQL logs for:
-- WARNING: page verification failed, calculated checksum does not match
-- ERROR: invalid page in block XXXX of relation base/OID/FILENODE

-- Identify table from file number:
SELECT relname, relnamespace::regnamespace AS schema
FROM pg_class WHERE relfilenode = 24680;

-- Check for corruption with pg_stat_database:
SELECT datname, checksum_failures, checksum_last_failure
FROM pg_stat_database WHERE datname = current_database();

-- ============================================================
-- 2. DIAGNOSE — Assess damage extent
-- ============================================================

-- Enable zero_damaged_pages temporarily to read past corruption:
SET zero_damaged_pages = on;  -- SESSION ONLY, never globally!
SELECT count(*) FROM orders;
-- Warnings show which blocks are corrupted
-- Compare count with expected rows to estimate loss
SET zero_damaged_pages = off;  -- Turn off immediately after!

-- Check index integrity with amcheck:
CREATE EXTENSION IF NOT EXISTS amcheck;

-- Verify all B-tree indexes:
SELECT bt_index_check(c.oid), c.relname
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
WHERE c.relam = (SELECT oid FROM pg_am WHERE amname = 'btree');

-- More thorough check (slower, checks against heap):
-- SELECT bt_index_parent_check(c.oid, true), c.relname
-- FROM pg_index i
-- JOIN pg_class c ON c.oid = i.indexrelid
-- WHERE c.relam = (SELECT oid FROM pg_am WHERE amname = 'btree');

-- ============================================================
-- 3. FIX — Recovery options
-- ============================================================

-- Option 1: Restore table from standby (best if available)
-- On STANDBY:
-- pg_dump -h standby_host -t orders myapp > /tmp/orders_from_standby.sql
-- On PRIMARY:
-- ALTER TABLE orders RENAME TO orders_corrupted;
-- psql -d myapp -f /tmp/orders_from_standby.sql
-- Verify:
-- SELECT count(*) FROM orders;
-- DROP TABLE orders_corrupted;

-- Option 2: Restore table from backup
-- Rename corrupted table first:
ALTER TABLE orders RENAME TO orders_corrupted;
-- Restore just this table:
-- pg_restore -d myapp -t orders /backups/myapp_nightly.dump
-- Verify and rebuild:
REINDEX TABLE orders;
ANALYZE orders;
-- DROP TABLE orders_corrupted;

-- Option 3: Point-in-time recovery (entire database)
-- Requires continuous WAL archiving set up beforehand!
-- Stop PostgreSQL
-- Restore base backup
-- Create recovery.signal
-- Set restore_command and recovery_target_time in postgresql.conf
-- Start PostgreSQL — it replays WAL to the target time

-- Option 4: Emergency read with zero_damaged_pages
-- Creates a clean copy minus corrupted rows:
SET zero_damaged_pages = on;
CREATE TABLE orders_recovered AS SELECT * FROM orders;
SET zero_damaged_pages = off;
-- Then replace:
-- DROP TABLE orders;
-- ALTER TABLE orders_recovered RENAME TO orders;
-- Rebuild indexes manually

-- ============================================================
-- 4. PREVENT — Stop future corruption
-- ============================================================

-- Enable checksums (must be done at initdb):
-- initdb --data-checksums -D /var/lib/postgresql/16/main

-- Check current setting:
SHOW data_checksums;

-- Critical postgresql.conf settings:
-- fsync = on                 (NEVER set to off in production!)
-- full_page_writes = on      (prevents torn page after crash)
-- wal_sync_method = fdatasync (or open_datasync, platform-dependent)

-- Monitor checksum failures:
SELECT datname, checksum_failures, checksum_last_failure
FROM pg_stat_database;
-- Alert if checksum_failures > 0

-- Hardware monitoring (from shell):
-- smartctl -a /dev/sda           (disk SMART data)
-- smartctl -t long /dev/sda      (run long self-test)
-- memtest86                      (RAM test — run from boot)

-- ============================================================
-- SCENARIO 2: BLOCKING QUERIES
-- ============================================================

-- ============================================================
-- 1. DETECT — Find blocked sessions
-- ============================================================

-- Count sessions by wait event:
SELECT count(*), wait_event_type, wait_event
FROM pg_stat_activity
WHERE wait_event IS NOT NULL
GROUP BY wait_event_type, wait_event
ORDER BY count DESC;

-- Find sessions waiting for locks:
SELECT pid, state, wait_event_type, wait_event,
  now() - query_start AS duration,
  left(query, 60) AS query
FROM pg_stat_activity
WHERE wait_event_type = 'Lock'
ORDER BY duration DESC;

-- ============================================================
-- 2. DIAGNOSE — Find the blocker
-- ============================================================

-- The essential blocking query:
SELECT blocked.pid AS blocked_pid,
  blocked.query AS blocked_query,
  blocking.pid AS blocking_pid,
  blocking.query AS blocking_query,
  now() - blocking.query_start AS blocking_duration
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
  ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
ORDER BY blocking_duration DESC;

-- More detailed: see lock modes
SELECT l.pid, l.locktype, l.mode, l.granted,
  l.relation::regclass AS table_name,
  a.state, left(a.query, 50) AS query
FROM pg_locks l
JOIN pg_stat_activity a ON a.pid = l.pid
WHERE l.relation IS NOT NULL
ORDER BY l.relation, l.granted;

-- ============================================================
-- 3. FIX — Unblock the system
-- ============================================================

-- Graceful cancel (sends SIGINT):
SELECT pg_cancel_backend(5678);
-- Waits for current statement to reach a cancel point

-- Forceful terminate (sends SIGTERM):
SELECT pg_terminate_backend(5678);
-- Kills the entire backend connection

-- Kill all idle-in-transaction blocking sessions:
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - state_change > interval '10 minutes';

-- ============================================================
-- 4. PREVENT — Safe DDL and lock management
-- ============================================================

-- Always set lock_timeout before DDL:
SET lock_timeout = '5s';
ALTER TABLE orders ADD COLUMN notes TEXT DEFAULT '';
-- If lock can't be acquired in 5 seconds: gives up instead of blocking

-- Use CONCURRENTLY for indexes (no write lock):
CREATE INDEX CONCURRENTLY idx_orders_notes ON orders(notes);
-- Takes longer but does not block DML

-- Global prevention settings:
ALTER SYSTEM SET log_lock_waits = on;           -- log when waiting > deadlock_timeout
ALTER SYSTEM SET lock_timeout = '30s';          -- DDL gives up after 30 seconds
ALTER SYSTEM SET statement_timeout = '300s';    -- no query runs > 5 minutes
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';
SELECT pg_reload_conf();

-- Per-role timeout (tighter for app, looser for admin):
ALTER ROLE app_user SET statement_timeout = '60s';
ALTER ROLE admin_user SET statement_timeout = '600s';

-- ============================================================
-- 5. DEADLOCK HANDLING
-- ============================================================

-- Deadlock: two sessions block each other
-- PostgreSQL auto-detects after deadlock_timeout (default 1s)
-- One session is killed with: ERROR: deadlock detected

-- Check deadlock_timeout:
SHOW deadlock_timeout;

-- Prevention: always access tables in the same order
-- BAD pattern:
--   Tx1: UPDATE orders WHERE id=1; UPDATE inventory WHERE id=1;
--   Tx2: UPDATE inventory WHERE id=1; UPDATE orders WHERE id=1;
-- GOOD pattern:
--   Both: UPDATE inventory WHERE id=1; UPDATE orders WHERE id=1;

-- Lock types (least to most exclusive):
-- ACCESS SHARE       ← SELECT
-- ROW SHARE          ← SELECT FOR UPDATE/SHARE
-- ROW EXCLUSIVE      ← INSERT, UPDATE, DELETE
-- SHARE UPDATE EXCL  ← VACUUM, CREATE INDEX CONCURRENTLY
-- SHARE              ← CREATE INDEX
-- SHARE ROW EXCL     ← CREATE TRIGGER
-- EXCLUSIVE          ← REFRESH MATERIALIZED VIEW CONCURRENTLY
-- ACCESS EXCLUSIVE   ← ALTER TABLE, DROP, VACUUM FULL, REINDEX

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Check index integrity:
CREATE EXTENSION IF NOT EXISTS amcheck;
SELECT bt_index_check(c.oid), c.relname
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
WHERE c.relam = (SELECT oid FROM pg_am WHERE amname = 'btree')
  AND c.relnamespace = 'public'::regnamespace;

-- 2. Create a deadlock:
-- Session 1:
-- BEGIN;
-- UPDATE orders SET total = total + 1 WHERE id = 1;
-- (wait)
-- UPDATE orders SET total = total + 1 WHERE id = 2;
--
-- Session 2:
-- BEGIN;
-- UPDATE orders SET total = total + 1 WHERE id = 2;
-- (wait)
-- UPDATE orders SET total = total + 1 WHERE id = 1;
-- → One session gets: ERROR: deadlock detected

-- 3. Write the blocking query diagnostic:
SELECT blocked.pid, blocking.pid,
  now() - blocking.query_start AS duration,
  blocking.query
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
  ON blocking.pid = ANY(pg_blocking_pids(blocked.pid));

-- 4. Test lock_timeout:
-- Session 1: BEGIN; SELECT * FROM orders FOR UPDATE;
-- Session 2: SET lock_timeout = '5s';
--            ALTER TABLE orders ADD COLUMN test_col INT;
-- → ERROR: canceling statement due to lock timeout

-- 5. Practice cancel/terminate:
-- Start a long query:
-- SELECT pg_sleep(300);
-- From another session:
-- SELECT pid, query FROM pg_stat_activity WHERE query LIKE '%pg_sleep%';
-- SELECT pg_cancel_backend(<pid>);
