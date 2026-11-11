-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Connection & Disk I/O Tuning (Classes 178-179)
-- Phase 21: Performance Tuning
-- ============================================================

-- ============================================================
-- 1. CONNECTION PARAMETERS
-- ============================================================

-- Current settings:
SHOW max_connections;
SHOW superuser_reserved_connections;

-- Connection usage:
SELECT count(*) AS total,
  count(*) FILTER (WHERE state = 'active') AS active,
  count(*) FILTER (WHERE state = 'idle') AS idle,
  count(*) FILTER (WHERE state = 'idle in transaction') AS idle_txn
FROM pg_stat_activity
WHERE backend_type = 'client backend';

-- Available connection slots:
SELECT setting::int AS max_conn,
       (SELECT count(*) FROM pg_stat_activity) AS used
FROM pg_settings
WHERE name = 'max_connections';

-- ============================================================
-- 2. CONNECTION TIMEOUT PARAMETERS
-- ============================================================

SHOW idle_in_transaction_session_timeout;  -- default 0 (disabled!)
SHOW statement_timeout;                     -- default 0 (disabled!)
SHOW lock_timeout;                          -- default 0 (wait forever!)

-- Recommended production settings:
-- idle_in_transaction_session_timeout = '5min'
-- statement_timeout = '60s'
-- lock_timeout = '10s'

-- TCP keepalive settings:
SHOW tcp_keepalives_idle;      -- seconds before first keepalive
SHOW tcp_keepalives_interval;  -- seconds between retries
SHOW tcp_keepalives_count;     -- retries before giving up

-- Find idle in transaction sessions:
SELECT pid, now() - xact_start AS txn_age,
       state, left(query, 50) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY xact_start;

-- ============================================================
-- 3. DISK I/O PARAMETERS
-- ============================================================

-- Current settings:
SHOW random_page_cost;           -- default 4.0 (HDD)
SHOW seq_page_cost;              -- default 1.0
SHOW effective_io_concurrency;   -- default 1
SHOW maintenance_io_concurrency; -- default 10

-- For SSD storage:
-- random_page_cost = 1.1
-- effective_io_concurrency = 200
-- maintenance_io_concurrency = 10

-- Impact of random_page_cost:
SET random_page_cost = 4.0;
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;

SET random_page_cost = 1.1;
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;

RESET random_page_cost;

-- ============================================================
-- 4. I/O TIMING
-- ============================================================

-- Enable I/O timing:
-- postgresql.conf: track_io_timing = on

-- Or per-session:
SET track_io_timing = on;

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_id = 42;
-- Look for: I/O Timings: shared read=X.XXX

RESET track_io_timing;

-- ============================================================
-- 5. pgBOUNCER EXAMPLE CONFIG
-- ============================================================

-- pgbouncer.ini:
--
-- [databases]
-- mydb = host=127.0.0.1 port=5432 dbname=mydb
--
-- [pgbouncer]
-- pool_mode = transaction
-- default_pool_size = 50
-- max_client_conn = 1000
-- listen_port = 6432
-- listen_addr = *
-- auth_type = md5
-- auth_file = /etc/pgbouncer/userlist.txt
-- server_idle_timeout = 600
-- reserve_pool_size = 5
-- reserve_pool_timeout = 3

-- Application connects to:
-- psql -h 127.0.0.1 -p 6432 -U myuser -d mydb
-- (port 6432 = pgBouncer, not 5432 = PostgreSQL)

-- ============================================================
-- 6. MONITORING I/O PERFORMANCE
-- ============================================================

-- Per-table I/O:
SELECT relname,
  heap_blks_read,
  heap_blks_hit,
  ROUND(100.0 * heap_blks_hit /
    NULLIF(heap_blks_hit + heap_blks_read, 0), 2)
    AS cache_hit_pct
FROM pg_statio_user_tables
WHERE heap_blks_read + heap_blks_hit > 100
ORDER BY heap_blks_read DESC
LIMIT 10;

-- Per-index I/O:
SELECT indexrelname,
  idx_blks_read,
  idx_blks_hit,
  ROUND(100.0 * idx_blks_hit /
    NULLIF(idx_blks_hit + idx_blks_read, 0), 2)
    AS cache_hit_pct
FROM pg_statio_user_indexes
WHERE idx_blks_read + idx_blks_hit > 100
ORDER BY idx_blks_read DESC
LIMIT 10;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Check your current connection count. How many are idle?
-- 2. Set random_page_cost to 4.0 then 1.1.
--    Compare EXPLAIN plans for a WHERE clause with an index.
-- 3. Enable track_io_timing. Run EXPLAIN (ANALYZE, BUFFERS).
--    Find the I/O Timings line.
-- 4. Check pg_statio_user_tables for tables with low cache hit ratio.
-- 5. Calculate the optimal pool_size for your server
--    (CPU cores × 2).
