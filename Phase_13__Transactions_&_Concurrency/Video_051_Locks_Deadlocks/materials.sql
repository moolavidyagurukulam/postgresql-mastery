-- =============================================
-- PostgreSQL Mastery: Row Locks, Table Locks & Deadlocks
-- Phase 13: Transactions & Concurrency | Class 108
-- =============================================
-- Row-level locking, SELECT FOR UPDATE, table locks,
-- deadlock detection, NOWAIT, SKIP LOCKED.
-- =============================================

-- === SETUP ===

CREATE TABLE IF NOT EXISTS accounts (
    id   INT PRIMARY KEY,
    name VARCHAR(50),
    bal  NUMERIC(10,2)
);

DELETE FROM accounts;
INSERT INTO accounts VALUES
(1, 'Alice', 1000.00),
(2, 'Bob',    500.00),
(3, 'Carol',  300.00);

-- === ROW-LEVEL LOCKS (Automatic) ===

-- UPDATE automatically locks the row
-- Other SELECTs can still read (MVCC: see old version)
-- Other UPDATEs on same row WAIT

-- TWO-TERMINAL DEMO:
-- Terminal A:
--   BEGIN;
--   UPDATE accounts SET bal = bal - 100 WHERE id = 1;
--   -- Row 1 is now locked by A
--
-- Terminal B:
--   SELECT * FROM accounts WHERE id = 1;
--   -- Works! Sees old value (MVCC)
--
--   UPDATE accounts SET bal = bal + 50 WHERE id = 1;
--   -- WAITS... blocked by A's lock
--
-- Terminal A:
--   COMMIT;
--   -- B's UPDATE proceeds immediately

-- === SELECT FOR UPDATE ===

-- Explicitly lock rows before updating
-- Use when you need read-then-write atomicity

-- Example: check balance then withdraw
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
-- Row is locked. Now we can safely check and update:
-- (Application checks: bal >= 100? Yes!)
UPDATE accounts SET bal = bal - 100 WHERE id = 1;
COMMIT;

-- FOR UPDATE variants:
-- FOR UPDATE             — strongest row lock
-- FOR NO KEY UPDATE      — allows FK checks on the row
-- FOR SHARE              — shared lock (multiple readers OK)
-- FOR KEY SHARE          — weakest (only blocks key changes)

-- === FOR UPDATE with JOINs ===

-- Lock only specific table's rows
-- SELECT * FROM orders o
-- JOIN customers c ON o.customer_id = c.id
-- WHERE o.status = 'pending'
-- FOR UPDATE OF o;  -- lock only orders, not customers

-- === NOWAIT ===

-- Fail immediately instead of waiting for lock
BEGIN;
-- SELECT * FROM accounts WHERE id = 1 FOR UPDATE NOWAIT;
-- If row is locked:
-- ERROR: could not obtain lock on row in relation "accounts"
COMMIT;

-- === SKIP LOCKED ===

-- Skip locked rows, return only unlocked ones
-- Perfect for job queues!

CREATE TABLE jobs (
    id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task    VARCHAR(100),
    status  VARCHAR(20) DEFAULT 'pending'
);

INSERT INTO jobs (task) VALUES
('Send email to user 1'),
('Process payment #42'),
('Generate report'),
('Clean up temp files'),
('Sync with external API');

-- Worker grabs next available job:
BEGIN;
SELECT * FROM jobs
WHERE status = 'pending'
ORDER BY id
LIMIT 1
FOR UPDATE SKIP LOCKED;
-- Returns first unlocked pending job
-- Other workers get the next one!

-- Mark it as processing
UPDATE jobs SET status = 'processing' WHERE id = 1;
COMMIT;

-- === TABLE-LEVEL LOCKS ===

-- Automatically acquired during operations:
-- SELECT:               AccessShareLock
-- INSERT/UPDATE/DELETE:  RowExclusiveLock
-- CREATE INDEX:          ShareLock (blocks writes!)
-- CREATE INDEX CONC.:    ShareUpdateExclusiveLock
-- ALTER TABLE:           AccessExclusiveLock (blocks ALL!)
-- DROP TABLE:            AccessExclusiveLock

-- Explicit table lock (rare, avoid if possible):
-- LOCK TABLE accounts IN ACCESS EXCLUSIVE MODE;

-- === MONITORING LOCKS ===

-- View all locks on user tables
SELECT
  l.pid,
  l.locktype,
  l.relation::regclass AS table_name,
  l.mode,
  l.granted,
  a.query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.relation IS NOT NULL
  AND l.locktype = 'relation'
ORDER BY l.granted, l.relation;

-- Find blocked queries
SELECT
  blocked.pid AS blocked_pid,
  blocked.query AS blocked_query,
  blocked.wait_event_type,
  blocking.pid AS blocking_pid,
  blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
  ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.wait_event_type = 'Lock';

-- Simpler: just blocked PIDs
SELECT pid, query, wait_event_type, wait_event
FROM pg_stat_activity
WHERE wait_event_type = 'Lock';

-- Kill a blocking session (last resort!):
-- SELECT pg_terminate_backend(blocking_pid);

-- === DEADLOCK ===

-- TWO-TERMINAL DEMO:
-- Terminal A:
--   BEGIN;
--   UPDATE accounts SET bal = bal - 10 WHERE id = 1;  -- locks row 1
--
-- Terminal B:
--   BEGIN;
--   UPDATE accounts SET bal = bal - 10 WHERE id = 2;  -- locks row 2
--
-- Terminal A:
--   UPDATE accounts SET bal = bal + 10 WHERE id = 2;  -- waits for B
--
-- Terminal B:
--   UPDATE accounts SET bal = bal + 10 WHERE id = 1;  -- waits for A
--   ERROR: deadlock detected
--   DETAIL: Process B waits for ... blocked by process A
--           Process A waits for ... blocked by process B
--   HINT: See server log for query details.

-- PostgreSQL detects deadlocks within deadlock_timeout (default 1s)
SHOW deadlock_timeout;  -- 1s

-- === PREVENTING DEADLOCKS ===

-- Rule 1: Always lock rows in the SAME ORDER
-- Bad:  A locks (1, then 2), B locks (2, then 1) → deadlock!
-- Good: Both lock (1, then 2) → no deadlock, B waits for A

-- Rule 2: Keep transactions SHORT
-- Less time holding locks = less chance of conflict

-- Rule 3: Use SELECT ... FOR UPDATE at the start
-- Lock all needed rows at once, then do your work

-- Rule 4: Use NOWAIT or SKIP LOCKED when appropriate
-- Fail fast instead of waiting and risking deadlock

-- Rule 5: Add indexes!
-- Without an index, UPDATE may lock more rows than needed
-- (full table scan acquires locks on all examined rows)

-- === lock_timeout ===

-- Maximum time to wait for a lock before giving up
SET lock_timeout = '5s';

-- Now any lock wait > 5 seconds raises an error:
-- ERROR: canceling statement due to lock timeout

-- Per-transaction:
-- SET LOCAL lock_timeout = '3s';

-- Reset:
SET lock_timeout = 0;  -- no timeout (wait forever)

-- === PRACTICE EXERCISES ===

-- Exercise 1: Row lock demo (two terminals)
-- A: BEGIN; UPDATE accounts SET bal=0 WHERE id=1;
-- B: UPDATE accounts SET bal=0 WHERE id=1; → waits
-- A: COMMIT; → B unblocks

-- Exercise 2: SELECT FOR UPDATE
BEGIN;
SELECT * FROM accounts WHERE id = 2 FOR UPDATE;
-- Check bal, then update
UPDATE accounts SET bal = bal - 50 WHERE id = 2;
COMMIT;

-- Exercise 3: SKIP LOCKED (job queue)
-- Open two terminals
-- Both run: SELECT ... LIMIT 1 FOR UPDATE SKIP LOCKED
-- They get different rows!

-- Exercise 4: Monitor locks
SELECT pid, locktype, relation::regclass, mode, granted
FROM pg_locks WHERE relation IS NOT NULL;

-- Exercise 5: Find blocked queries
SELECT pid, query, wait_event_type
FROM pg_stat_activity WHERE wait_event_type = 'Lock';

-- Exercise 6: Deadlock demo (two terminals)
-- Follow the deadlock sequence from above
-- Observe the ERROR: deadlock detected message

-- Exercise 7: Set lock_timeout
SET lock_timeout = '3s';
-- Try acquiring a lock that's held → timeout after 3s
SET lock_timeout = 0;

-- === CLEANUP ===
DROP TABLE IF EXISTS jobs;
-- UPDATE accounts SET bal = CASE id
--   WHEN 1 THEN 1000 WHEN 2 THEN 500 WHEN 3 THEN 300 END
-- WHERE id IN (1,2,3);

-- =============================================
-- Next Class: Advisory Locks & Concurrency Patterns
-- =============================================


-- =============================================
-- === PRACTICE EXERCISES & VERIFIED SOLUTIONS ===
-- =============================================

-- Exercise 1: Explicit Row Locking with SELECT FOR UPDATE
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
UPDATE accounts SET bal = bal - 100 WHERE id = 1;
COMMIT;

-- Exercise 2: Non-Blocking Work Queue with SKIP LOCKED
CREATE TABLE IF NOT EXISTS job_queue (
    id SERIAL PRIMARY KEY,
    payload TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending'
);

INSERT INTO job_queue (payload) VALUES ('Send Email 1'), ('Process Invoice 2'), ('Sync CRM 3');

-- Worker 1:
BEGIN;
SELECT * FROM job_queue
WHERE status = 'pending'
ORDER BY id
LIMIT 1
FOR UPDATE SKIP LOCKED;

-- Mark completed and commit:
UPDATE job_queue SET status = 'completed' WHERE id = 1;
COMMIT;

-- Exercise 3: Simulating a Deadlock
-- Terminal A:
-- BEGIN;
-- UPDATE accounts SET bal = bal - 10 WHERE id = 1;

-- Terminal B:
-- BEGIN;
-- UPDATE accounts SET bal = bal - 20 WHERE id = 2;

-- Terminal A:
-- UPDATE accounts SET bal = bal + 10 WHERE id = 2; -- WAITS on B

-- Terminal B:
-- UPDATE accounts SET bal = bal + 20 WHERE id = 1; -- DEADLOCK! One session is aborted.

-- Exercise 4: Setting Deadlock Timeout
SHOW deadlock_timeout;
SET deadlock_timeout = '500ms';

-- Exercise 5: Lock Monitoring Query
SELECT
    blocked_locks.pid     AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid    AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query    AS blocked_statement,
    blocking_activity.query   AS blocking_statement
FROM  pg_catalog.pg_locks         blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks         blocking_locks 
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;

