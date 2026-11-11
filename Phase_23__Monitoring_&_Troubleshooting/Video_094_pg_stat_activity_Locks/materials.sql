-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- pg_stat_activity & Lock Troubleshooting (Classes 192-193)
-- Phase 23: Monitoring & Troubleshooting
-- ============================================================

-- ============================================================
-- 1. pg_stat_activity — Live Connections
-- ============================================================

-- All active connections:
SELECT
    pid, usename AS user, client_addr, state,
    now() - query_start AS query_duration,
    now() - xact_start AS txn_duration,
    wait_event_type, wait_event,
    LEFT(query, 80) AS query
FROM pg_stat_activity
WHERE backend_type = 'client backend'
  AND pid != pg_backend_pid()
ORDER BY query_start;

-- Long-running queries (> 5 minutes):
SELECT pid, usename, now() - query_start AS duration,
       state, query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '5 minutes'
  AND backend_type = 'client backend'
ORDER BY query_start;

-- Idle in transaction sessions:
SELECT pid, usename,
    now() - xact_start AS txn_age,
    now() - state_change AS idle_time,
    LEFT(query, 60) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - state_change > interval '5 minutes'
ORDER BY xact_start;

-- ============================================================
-- 2. CANCEL & TERMINATE
-- ============================================================

-- Cancel a running query (graceful):
-- SELECT pg_cancel_backend(12346);

-- Terminate a connection (force kill):
-- SELECT pg_terminate_backend(12347);

-- Cancel all long queries on a table:
-- SELECT pg_cancel_backend(pid)
-- FROM pg_stat_activity
-- WHERE state = 'active'
--   AND query ILIKE '%orders%'
--   AND now() - query_start > interval '10 minutes';

-- ============================================================
-- 3. CONNECTION MONITORING
-- ============================================================

SELECT
    count(*) AS total,
    count(*) FILTER (WHERE state = 'active') AS active,
    count(*) FILTER (WHERE state = 'idle') AS idle,
    count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_txn,
    (SELECT setting::int FROM pg_settings
     WHERE name = 'max_connections') AS max_conn,
    ROUND(100.0 * count(*) / (
      SELECT setting::int FROM pg_settings
      WHERE name = 'max_connections'
    ), 1) AS usage_pct
FROM pg_stat_activity
WHERE backend_type = 'client backend';

-- Per-user breakdown:
SELECT usename, count(*) AS connections
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY usename ORDER BY count(*) DESC;

-- ============================================================
-- 4. LOCK INVESTIGATION
-- ============================================================

-- Who is blocking whom (simple version):
SELECT
    pid, usename, state,
    pg_blocking_pids(pid) AS blocked_by,
    now() - query_start AS duration,
    LEFT(query, 60) AS query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;

-- Detailed blocker chain:
SELECT
    blocked.pid AS blocked_pid,
    blocked.usename AS blocked_user,
    LEFT(blocked.query, 50) AS blocked_query,
    blocker.pid AS blocker_pid,
    blocker.usename AS blocker_user,
    blocker.state AS blocker_state,
    LEFT(blocker.query, 50) AS blocker_query
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid AND NOT bl.granted
JOIN pg_locks gr ON gr.locktype = bl.locktype
    AND gr.database IS NOT DISTINCT FROM bl.database
    AND gr.relation IS NOT DISTINCT FROM bl.relation
    AND gr.page IS NOT DISTINCT FROM bl.page
    AND gr.tuple IS NOT DISTINCT FROM bl.tuple
    AND gr.pid != bl.pid AND gr.granted
JOIN pg_stat_activity blocker ON blocker.pid = gr.pid
WHERE blocked.state = 'active';

-- Locks held by a specific session:
-- SELECT l.locktype, l.relation::regclass, l.mode, l.granted
-- FROM pg_locks l WHERE l.pid = 12347 AND l.locktype = 'relation';

-- ============================================================
-- 5. ADVISORY LOCKS
-- ============================================================

-- Acquire (blocking):
-- SELECT pg_advisory_lock(12345);

-- Try without blocking:
-- SELECT pg_try_advisory_lock(12345);

-- Release:
-- SELECT pg_advisory_unlock(12345);

-- Check active advisory locks:
SELECT * FROM pg_locks WHERE locktype = 'advisory';

-- ============================================================
-- 6. DEADLOCK INFORMATION
-- ============================================================

SELECT deadlocks FROM pg_stat_database
WHERE datname = current_database();

-- ============================================================
-- 7. TIMEOUT SETTINGS
-- ============================================================

SHOW idle_in_transaction_session_timeout;
SHOW statement_timeout;
SHOW lock_timeout;
SHOW deadlock_timeout;
SHOW log_lock_waits;

-- Recommended production settings:
-- idle_in_transaction_session_timeout = '5min'
-- statement_timeout = '60s'
-- lock_timeout = '10s'
-- deadlock_timeout = '1s'    (default)
-- log_lock_waits = on

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Query pg_stat_activity. How many connections are active?
--    How many are idle? Any idle in transaction?
-- 2. Open two psql sessions. In session A: BEGIN; UPDATE a row.
--    In session B: UPDATE the same row. Check pg_blocking_pids.
-- 3. Use pg_cancel_backend to cancel session B's blocked query.
-- 4. Check your connection usage percentage.
--    How close are you to max_connections?
-- 5. Set lock_timeout = '5s' in a session.
--    Try to acquire a lock held by another session.
--    See the timeout error after 5 seconds.
