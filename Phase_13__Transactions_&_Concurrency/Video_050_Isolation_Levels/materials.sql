-- =============================================
-- PostgreSQL Mastery: Isolation Levels
-- Phase 13: Transactions & Concurrency | Classes 106-107
-- =============================================
-- Read Committed, Repeatable Read, Serializable,
-- concurrency anomalies, retry patterns.
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

-- === CHECK CURRENT ISOLATION LEVEL ===

SHOW transaction_isolation;
-- read committed (default)

SHOW default_transaction_isolation;
-- read committed

-- === READ COMMITTED (Default) ===

-- Each STATEMENT sees only data committed before it started
-- Different statements in the same transaction can see
-- different versions of the data

-- TWO-TERMINAL DEMO:
-- Terminal A:
--   BEGIN;
--   SELECT bal FROM accounts WHERE id = 1;  → 1000
--
-- Terminal B:
--   UPDATE accounts SET bal = 900 WHERE id = 1;
--   (auto-committed)
--
-- Terminal A:
--   SELECT bal FROM accounts WHERE id = 1;  → 900!
--   -- Non-repeatable read: same row, different value
--   COMMIT;

-- Reset
UPDATE accounts SET bal = 1000 WHERE id = 1;

-- === REPEATABLE READ ===

-- Snapshot is taken at the START of the transaction
-- ALL queries in the transaction see the same snapshot
-- Even if other transactions commit changes

-- TWO-TERMINAL DEMO:
-- Terminal A:
--   BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
--   SELECT bal FROM accounts WHERE id = 1;  → 1000
--
-- Terminal B:
--   UPDATE accounts SET bal = 800 WHERE id = 1;
--   (auto-committed)
--
-- Terminal A:
--   SELECT bal FROM accounts WHERE id = 1;  → 1000!
--   -- Still sees the snapshot value!
--
--   -- But if A tries to UPDATE the same row:
--   UPDATE accounts SET bal = 950 WHERE id = 1;
--   ERROR: could not serialize access due to concurrent update
--   ROLLBACK;  -- must retry entire transaction

-- Reset
UPDATE accounts SET bal = 1000 WHERE id = 1;

-- === SERIALIZABLE ===

-- Strictest level: guarantees serial-equivalent execution
-- PostgreSQL detects dependency cycles between transactions
-- and aborts one with a serialization error

-- Example: write skew anomaly
-- Scenario: at least one doctor must be on call
-- Two doctors each check: "other doctor is on call"
-- Both then mark themselves as off-call → nobody on call!

-- Serializable prevents this by detecting the dependency

-- TWO-TERMINAL DEMO:
-- Terminal A:
--   BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
--   SELECT COUNT(*) FROM accounts WHERE bal > 500;  → 1
--   INSERT INTO accounts VALUES (4, 'Dave', 200);
--   -- (waiting to commit)
--
-- Terminal B:
--   BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
--   SELECT COUNT(*) FROM accounts WHERE bal > 500;  → 1
--   INSERT INTO accounts VALUES (5, 'Eve', 150);
--   COMMIT;  → success
--
-- Terminal A:
--   COMMIT;
--   ERROR: could not serialize access due to read/write
--          dependencies among transactions
--   -- Must retry!

-- === SETTING ISOLATION LEVELS ===

-- Per transaction:
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT 1;
COMMIT;

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT 1;
COMMIT;

BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT 1;
COMMIT;

-- Alternative syntax:
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- Must be first command after BEGIN!
SELECT 1;
COMMIT;

-- Per session:
SET SESSION CHARACTERISTICS AS
TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SHOW transaction_isolation;
-- repeatable read

-- Reset to default:
SET SESSION CHARACTERISTICS AS
TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Global (postgresql.conf):
-- default_transaction_isolation = 'read committed'
-- Requires reload: SELECT pg_reload_conf();

-- === READ ONLY TRANSACTIONS ===

-- Mark a transaction as read-only for safety
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT * FROM accounts;
-- INSERT INTO accounts VALUES (10, 'X', 0);
-- ERROR: cannot execute INSERT in a read-only transaction
COMMIT;

-- Useful for reports: consistent snapshot + no accidental writes

-- === CONCURRENCY ANOMALIES REFERENCE ===

-- DIRTY READ: see uncommitted data
-- → PostgreSQL NEVER allows this (not even Read Uncommitted)
-- (PG treats Read Uncommitted as Read Committed)

-- NON-REPEATABLE READ: same row, different values
-- → Allowed in Read Committed
-- → Prevented in Repeatable Read and Serializable

-- PHANTOM READ: same query, different rows
-- → Allowed in Read Committed
-- → Prevented in Repeatable Read and Serializable

-- SERIALIZATION ANOMALY: result differs from any serial order
-- → Allowed in Read Committed and Repeatable Read
-- → Prevented in Serializable

-- === APPLICATION RETRY PATTERN ===

-- When using Repeatable Read or Serializable,
-- your application MUST handle serialization errors
-- PostgreSQL error code: 40001

-- Python example (psycopg2):
-- import psycopg2
-- MAX_RETRIES = 3
-- for attempt in range(MAX_RETRIES):
--     try:
--         with conn:
--             with conn.cursor() as cur:
--                 cur.execute("BEGIN ISOLATION LEVEL SERIALIZABLE")
--                 cur.execute("UPDATE accounts SET bal = bal - 100 WHERE id = 1")
--                 cur.execute("UPDATE accounts SET bal = bal + 100 WHERE id = 2")
--                 conn.commit()
--                 break
--     except psycopg2.extensions.TransactionRollbackError:
--         conn.rollback()
--         continue

-- === PRACTICE EXERCISES ===

-- Exercise 1: Check your isolation level
SHOW transaction_isolation;

-- Exercise 2: Read Committed demo (needs two terminals)
-- A: BEGIN; SELECT bal FROM accounts WHERE id=1;
-- B: UPDATE accounts SET bal=999 WHERE id=1;
-- A: SELECT bal FROM accounts WHERE id=1; → sees 999

-- Exercise 3: Repeatable Read demo (needs two terminals)
-- A: BEGIN ISOLATION LEVEL REPEATABLE READ;
-- A: SELECT bal FROM accounts WHERE id=1;
-- B: UPDATE accounts SET bal=888 WHERE id=1;
-- A: SELECT bal FROM accounts WHERE id=1; → still sees old value

-- Exercise 4: Serialization error
-- A: BEGIN ISOLATION LEVEL REPEATABLE READ;
-- A: SELECT * FROM accounts WHERE id=1;
-- B: UPDATE accounts SET bal=777 WHERE id=1;
-- A: UPDATE accounts SET bal=666 WHERE id=1; → ERROR!
-- A: ROLLBACK;

-- Exercise 5: Read-only transaction
BEGIN TRANSACTION READ ONLY;
SELECT * FROM accounts;
-- INSERT INTO accounts VALUES (99, 'X', 0); → ERROR!
COMMIT;

-- Exercise 6: Session-level isolation
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SHOW transaction_isolation;
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- === CLEANUP ===
-- DELETE FROM accounts WHERE id > 3;
-- UPDATE accounts SET bal = CASE id
--   WHEN 1 THEN 1000 WHEN 2 THEN 500 WHEN 3 THEN 300 END
-- WHERE id IN (1,2,3);

-- =============================================
-- Next Class: Row Locks, Table Locks & Deadlocks
-- =============================================
