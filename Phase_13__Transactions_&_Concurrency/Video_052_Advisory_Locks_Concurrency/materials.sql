-- =============================================
-- PostgreSQL Mastery: Advisory Locks & Concurrency Patterns
-- Phase 13: Transactions & Concurrency | Class 109
-- =============================================
-- pg_advisory_lock, pg_try_advisory_lock, session vs
-- transaction advisory locks, optimistic locking,
-- idempotent upserts, concurrency patterns.
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

-- === SESSION-LEVEL ADVISORY LOCKS ===

-- Advisory locks are voluntary — not tied to any table or row
-- Your application decides what the lock key means
-- Key is a BIGINT (or two INT4 values)

-- Acquire a session-level advisory lock (blocks if held)
SELECT pg_advisory_lock(12345);

-- Check if lock is held (returns true/false, never waits)
SELECT pg_try_advisory_lock(12345);
-- Returns: t (already held by this session)

-- Release the lock
SELECT pg_advisory_unlock(12345);

-- TWO-TERMINAL DEMO:
-- Terminal A:
--   SELECT pg_advisory_lock(12345);
--   -- Lock acquired
--
-- Terminal B:
--   SELECT pg_advisory_lock(12345);
--   -- WAITS... blocked by A
--
-- Terminal A:
--   SELECT pg_advisory_unlock(12345);
--   -- B immediately acquires the lock

-- === TRY LOCK (Non-Blocking) ===

-- Returns true if acquired, false if already held
-- Perfect for singleton processes!

SELECT pg_try_advisory_lock(99999);
-- t = got the lock, we're the only instance
-- f = someone else has it, exit gracefully

SELECT pg_advisory_unlock(99999);

-- === TWO-KEY ADVISORY LOCKS ===

-- Use two INT4 keys for entity-specific locks
-- e.g., entity_type=1 (customer), entity_id=42

SELECT pg_advisory_lock(1, 42);
-- Locks "customer 42"

SELECT pg_advisory_unlock(1, 42);

-- === TRANSACTION-LEVEL ADVISORY LOCKS ===

-- Auto-released at COMMIT or ROLLBACK (no manual unlock needed)
BEGIN;
SELECT pg_advisory_xact_lock(55555);
-- Do work...
COMMIT;
-- Lock is automatically released

-- Try version:
BEGIN;
SELECT pg_try_advisory_xact_lock(55555);
-- Returns true/false
COMMIT;

-- === SESSION vs TRANSACTION ADVISORY LOCKS ===

-- Session-level:
--   pg_advisory_lock(key)         — blocks
--   pg_try_advisory_lock(key)     — non-blocking
--   pg_advisory_unlock(key)       — manual release
--   Survives COMMIT/ROLLBACK!

-- Transaction-level:
--   pg_advisory_xact_lock(key)    — blocks
--   pg_try_advisory_xact_lock(key) — non-blocking
--   Auto-released at COMMIT/ROLLBACK
--   No unlock function needed

-- === MONITORING ADVISORY LOCKS ===

-- View all advisory locks
SELECT pid, locktype, classid, objid, mode, granted
FROM pg_locks
WHERE locktype = 'advisory';

-- Find who holds a specific advisory lock
SELECT l.pid, a.query, l.granted
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.locktype = 'advisory'
  AND l.objid = 12345;

-- === SINGLETON CRON JOB PATTERN ===

-- Only one instance of a job runs at a time
-- At the start of your cron job script:

-- SELECT pg_try_advisory_lock(hash_of_job_name);
-- If returns false → another instance running → exit
-- If returns true → we're the only one → proceed
-- Lock released when session disconnects

-- Example with a named lock (hash the job name):
SELECT pg_try_advisory_lock(hashtext('daily_report_job'));
-- t = we got it, run the job
-- f = another instance is running, skip

SELECT pg_advisory_unlock(hashtext('daily_report_job'));

-- === ENTITY PROCESSING PATTERN ===

-- Lock a specific entity so only one worker processes it
-- Use two-key lock: (entity_type, entity_id)

-- Worker 1: processing customer 100
-- SELECT pg_advisory_lock(1, 100);
-- ... process customer 100 ...
-- SELECT pg_advisory_unlock(1, 100);

-- Worker 2: tries customer 100 → waits (or use try_lock to skip)
-- Worker 2: processes customer 101 instead

-- === OPTIMISTIC LOCKING PATTERN ===

CREATE TABLE products (
    id      INT PRIMARY KEY,
    name    VARCHAR(100),
    price   NUMERIC(10,2),
    version INT DEFAULT 1
);

INSERT INTO products VALUES (1, 'Widget', 29.99, 1);

-- User A reads: id=1, version=1
-- User B reads: id=1, version=1

-- User A updates with version check:
UPDATE products
SET price = 34.99, version = version + 1
WHERE id = 1 AND version = 1;
-- UPDATE 1 → success! Version is now 2

-- User B tries with stale version:
UPDATE products
SET price = 39.99, version = version + 1
WHERE id = 1 AND version = 1;
-- UPDATE 0 → 0 rows! Conflict detected!
-- Application should: notify user or retry with fresh data

-- Check current state:
SELECT * FROM products WHERE id = 1;

-- === IDEMPOTENT UPSERT PATTERN ===

CREATE TABLE payments (
    payment_id VARCHAR(50) PRIMARY KEY,
    amount     NUMERIC(10,2),
    status     VARCHAR(20) DEFAULT 'processed',
    created_at TIMESTAMP DEFAULT NOW()
);

-- First request: inserts normally
INSERT INTO payments (payment_id, amount)
VALUES ('PAY-001', 99.99)
ON CONFLICT (payment_id) DO NOTHING;
-- INSERT 0 1

-- Duplicate request: silently ignored (no error!)
INSERT INTO payments (payment_id, amount)
VALUES ('PAY-001', 99.99)
ON CONFLICT (payment_id) DO NOTHING;
-- INSERT 0 0

-- Or update on conflict:
INSERT INTO payments (payment_id, amount)
VALUES ('PAY-002', 149.99)
ON CONFLICT (payment_id) DO UPDATE
SET status = 'reprocessed',
    amount = EXCLUDED.amount;

-- Check results:
SELECT * FROM payments;

-- === JOB QUEUE WITH SKIP LOCKED ===

CREATE TABLE task_queue (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task_name  VARCHAR(100),
    status     VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO task_queue (task_name) VALUES
('Send welcome email'),
('Process refund #101'),
('Generate monthly report'),
('Sync inventory'),
('Archive old records');

-- Worker grabs next job (non-blocking):
BEGIN;
SELECT * FROM task_queue
WHERE status = 'pending'
ORDER BY id
LIMIT 1
FOR UPDATE SKIP LOCKED;
-- Returns first UNLOCKED pending task
-- Other workers get the next one!

-- Mark as processing:
UPDATE task_queue SET status = 'processing' WHERE id = 1;
COMMIT;

-- Multiple workers can run this same query simultaneously
-- Each gets a different task — no blocking, no conflicts!

-- === PRACTICE EXERCISES ===

-- Exercise 1: Session advisory lock (two terminals)
-- A: SELECT pg_advisory_lock(100);
-- B: SELECT pg_advisory_lock(100); → waits
-- A: SELECT pg_advisory_unlock(100); → B unblocks

-- Exercise 2: Try lock
SELECT pg_try_advisory_lock(200);
-- Should return true (no one else has it)
SELECT pg_try_advisory_lock(200);
-- Still true (same session can re-acquire)
SELECT pg_advisory_unlock(200);
SELECT pg_advisory_unlock(200);
-- Unlock once per acquire!

-- Exercise 3: Transaction-level lock
BEGIN;
SELECT pg_advisory_xact_lock(300);
-- Lock is held
COMMIT;
-- Lock is auto-released (no unlock needed)

-- Exercise 4: Optimistic locking
UPDATE products SET price = 24.99, version = version + 1
WHERE id = 1 AND version = 2;
-- Check: did UPDATE affect 1 row or 0?

-- Exercise 5: Idempotent upsert
INSERT INTO payments (payment_id, amount)
VALUES ('PAY-003', 75.00)
ON CONFLICT (payment_id) DO NOTHING;
-- Run it twice — second time inserts 0 rows

-- Exercise 6: Job queue with SKIP LOCKED
-- Open two terminals, both run:
-- BEGIN;
-- SELECT * FROM task_queue WHERE status='pending'
--   ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED;
-- They get different rows!

-- Exercise 7: Monitor advisory locks
SELECT * FROM pg_locks WHERE locktype = 'advisory';

-- === CLEANUP ===
DROP TABLE IF EXISTS task_queue;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS products;
-- Keep accounts for next phase

-- =============================================
-- Next Phase: PL/pgSQL Programming
-- =============================================


-- =============================================
-- === PRACTICE EXERCISES & VERIFIED SOLUTIONS ===
-- =============================================

-- Exercise 1: Session Advisory Lock Blocking Test
-- Terminal A:
SELECT pg_advisory_lock(100);

-- Terminal B:
-- SELECT pg_advisory_lock(100); -- WAITS...

-- Terminal A:
SELECT pg_advisory_unlock(100);
-- Terminal B unblocks!
-- Terminal B releases:
-- SELECT pg_advisory_unlock(100);

-- Exercise 2: Non-Blocking Try Lock
SELECT pg_try_advisory_lock(200); -- Returns true (acquired)
-- In concurrent session: SELECT pg_try_advisory_lock(200); -- Returns false immediately!
SELECT pg_advisory_unlock(200);

-- Exercise 3: Transaction-Level Advisory Lock
BEGIN;
SELECT pg_advisory_xact_lock(300);
UPDATE accounts SET bal = bal - 50 WHERE id = 1;
COMMIT; -- Auto-released!

-- Exercise 4: Optimistic Concurrency with Version Column
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS version INT DEFAULT 1;

-- Attempt atomic update:
UPDATE accounts
SET bal = 800.00, version = version + 1
WHERE id = 1 AND version = 1;

-- Exercise 5: Idempotent Upsert
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id INT PRIMARY KEY,
    theme VARCHAR(20),
    updated_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO user_preferences (user_id, theme)
VALUES (1, 'dark')
ON CONFLICT (user_id)
DO UPDATE SET theme = EXCLUDED.theme, updated_at = NOW();

SELECT * FROM user_preferences;

