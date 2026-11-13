-- =============================================
-- PostgreSQL Mastery: Architecture & Processes
-- Phase 9: Architecture | Classes 67-68
-- =============================================
-- Process architecture, connections, background workers.
-- =============================================

-- === YOUR OWN BACKEND PID ===
SELECT pg_backend_pid();

-- === ALL ACTIVE CONNECTIONS ===
SELECT pid, datname, usename, client_addr,
       state, backend_start, query_start,
       LEFT(query, 60) AS query_preview
FROM pg_stat_activity
WHERE datname IS NOT NULL
ORDER BY backend_start;

-- === CONNECTIONS BY STATE ===
SELECT state, COUNT(*) AS connections
FROM pg_stat_activity
WHERE datname IS NOT NULL
GROUP BY state
ORDER BY connections DESC;
-- States: active, idle, idle in transaction,
-- idle in transaction (aborted), fastpath function call, disabled

-- === CONNECTION LIMITS ===
SHOW max_connections;      -- default: 100
SHOW superuser_reserved_connections;  -- default: 3

-- Available vs used
SELECT
  (SELECT setting::INT FROM pg_settings WHERE name = 'max_connections') AS max,
  COUNT(*) AS current,
  (SELECT setting::INT FROM pg_settings WHERE name = 'max_connections') - COUNT(*) AS available
FROM pg_stat_activity;

-- === BACKGROUND PROCESSES ===
-- From Linux/Mac shell:
-- $ ps aux | grep postgres
-- Shows: postmaster, checkpointer, background writer,
-- walwriter, autovacuum launcher, stats collector, archiver,
-- logical replication launcher, and backend processes

-- From inside PostgreSQL:
SELECT pid, backend_type, state
FROM pg_stat_activity
ORDER BY backend_type;
-- backend_type shows: client backend, autovacuum launcher,
-- background writer, checkpointer, walwriter, etc.

-- === SERVER VERSION AND UPTIME ===
SELECT version();
SELECT pg_postmaster_start_time();
SELECT now() - pg_postmaster_start_time() AS uptime;

-- === DATABASE SIZE ===
SELECT pg_size_pretty(pg_database_size('practice')) AS db_size;

-- === CANCEL AND TERMINATE CONNECTIONS ===

-- Find long-running queries
SELECT pid, state,
       now() - query_start AS duration,
       LEFT(query, 80) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND pid <> pg_backend_pid()
ORDER BY duration DESC;

-- Cancel a query (gentle — connection stays alive)
-- SELECT pg_cancel_backend(<pid>);

-- Terminate a connection (forceful — drops the connection)
-- SELECT pg_terminate_backend(<pid>);

-- Kill all idle connections to a database
-- SELECT pg_terminate_backend(pid)
-- FROM pg_stat_activity
-- WHERE datname = 'practice'
--   AND state = 'idle'
--   AND pid <> pg_backend_pid();

-- === IDLE IN TRANSACTION — Common Problem ===

-- Find connections stuck "idle in transaction"
SELECT pid, usename, state,
       now() - state_change AS idle_duration,
       LEFT(query, 60) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY idle_duration DESC;

-- These HOLD LOCKS and block autovacuum!
-- Set a timeout to auto-kill them:
-- idle_in_transaction_session_timeout = '5min'  (in postgresql.conf)

-- === AUTOVACUUM STATUS ===

-- Check if autovacuum is running
SELECT pid, datname, relid::regclass AS table_name,
       phase, heap_blks_total, heap_blks_scanned
FROM pg_stat_progress_vacuum;
-- Empty = no vacuum running right now

-- Autovacuum settings
SHOW autovacuum;                    -- on (never turn off!)
SHOW autovacuum_max_workers;        -- 3 (concurrent workers)
SHOW autovacuum_naptime;            -- 1min (check interval)
SHOW autovacuum_vacuum_threshold;   -- 50 (min dead tuples)
SHOW autovacuum_vacuum_scale_factor; -- 0.2 (20% of table)
-- Vacuum triggers when: dead_tuples > threshold + scale_factor * table_rows

-- === PROCESS ARCHITECTURE SUMMARY ===

-- Postmaster (PID 1 of cluster)
--   ├── Checkpointer         — flushes dirty buffers to disk
--   ├── Background Writer    — gradually writes dirty buffers
--   ├── WAL Writer           — flushes WAL buffers to disk
--   ├── Autovacuum Launcher  — starts vacuum workers
--   │   ├── Autovacuum Worker 1
--   │   ├── Autovacuum Worker 2
--   │   └── Autovacuum Worker 3
--   ├── Stats Collector      — collects pg_stat_* data
--   ├── Archiver             — archives completed WAL files
--   ├── Logical Rep Launcher — manages logical replication
--   ├── Backend (user 1)     — handles client connection
--   ├── Backend (user 2)     — handles client connection
--   └── Backend (user N)     — handles client connection

-- === PRACTICE EXERCISES ===

-- Exercise 1: Your backend PID
SELECT pg_backend_pid();

-- Exercise 2: All connections
SELECT pid, datname, usename, state FROM pg_stat_activity
WHERE datname IS NOT NULL;

-- Exercise 3: Connection count by state
SELECT state, COUNT(*) FROM pg_stat_activity
WHERE datname IS NOT NULL GROUP BY state;

-- Exercise 4: Max connections and current usage
SHOW max_connections;
SELECT COUNT(*) AS current FROM pg_stat_activity;

-- Exercise 5: Server uptime
SELECT now() - pg_postmaster_start_time() AS uptime;

-- Exercise 6: Find long-running queries (> 5 seconds)
SELECT pid, now() - query_start AS duration, LEFT(query, 60) AS query
FROM pg_stat_activity
WHERE state = 'active' AND query_start < now() - INTERVAL '5 seconds';

-- Exercise 7: Background process types
SELECT backend_type, COUNT(*)
FROM pg_stat_activity
GROUP BY backend_type ORDER BY backend_type;

-- =============================================
-- Next Class: Memory Architecture
-- =============================================


-- =============================================
-- ANSWER KEY — ARCHITECTURE & PROCESS SOLUTIONS
-- =============================================

-- 1. Inspect Own Backend PID
SELECT pg_backend_pid() AS my_session_pid;

-- 2. Query Client Connections and Queries
SELECT pid, usename, datname, client_addr, state, query
FROM pg_stat_activity
WHERE backend_type = 'client backend';

-- 3. Group Connections by State
SELECT state, count(*) AS connection_count
FROM pg_stat_activity
GROUP BY state
ORDER BY connection_count DESC;

-- 4. Check Connection Limits & Superuser Reserves
SHOW max_connections;
SHOW superuser_reserved_connections;

-- 5. Cancel or Terminate Stuck Connection
-- SELECT pg_cancel_backend(pid);     -- Graceful query interrupt (SIGINT)
-- SELECT pg_terminate_backend(pid);  -- Forceful connection termination (SIGTERM)
