-- =============================================
-- PostgreSQL Mastery: Transactions, ACID & SAVEPOINT
-- Phase 13: Transactions & Concurrency | Classes 103-105
-- =============================================
-- BEGIN, COMMIT, ROLLBACK, ACID properties,
-- SAVEPOINT, nested savepoints, auto-commit.
-- =============================================

-- === SETUP ===

CREATE TABLE accounts (
    id   INT PRIMARY KEY,
    name VARCHAR(50),
    bal  NUMERIC(10,2)
);

INSERT INTO accounts VALUES
(1, 'Alice', 1000.00),
(2, 'Bob',    500.00),
(3, 'Carol',  300.00);

-- === BASIC TRANSACTION: BEGIN / COMMIT ===

-- Transfer $200 from Alice to Bob
BEGIN;
UPDATE accounts SET bal = bal - 200 WHERE id = 1;  -- Alice: 1000→800
UPDATE accounts SET bal = bal + 200 WHERE id = 2;  -- Bob: 500→700
COMMIT;

SELECT * FROM accounts;
-- Alice: 800, Bob: 700, Carol: 300

-- === ROLLBACK — Undo Everything ===

BEGIN;
DELETE FROM accounts WHERE id = 3;  -- Carol deleted
SELECT * FROM accounts;             -- Carol gone
ROLLBACK;                            -- Undo!

SELECT * FROM accounts;
-- Carol is back! ROLLBACK undid the DELETE

-- === ACID PROPERTIES ===

-- Atomicity: all or nothing
-- If any statement in a transaction fails,
-- EVERYTHING in the transaction is rolled back

-- Consistency: constraints are always enforced
-- INSERT INTO accounts VALUES (1, 'Dupe', 0);
-- ERROR: duplicate key → the insert is rejected
-- The database is never in an inconsistent state

-- Isolation: other sessions don't see uncommitted changes
-- (demonstrated with two-terminal example in the video)
-- Session A: BEGIN; INSERT; → Session B: SELECT → row not visible
-- Session A: COMMIT; → Session B: SELECT → row now visible

-- Durability: committed data survives crashes
-- PostgreSQL writes to WAL before COMMIT returns
-- Even if the server crashes immediately after COMMIT,
-- the changes are recovered from WAL on restart

-- === ABORTED TRANSACTION ERROR ===

-- When any statement fails inside a transaction,
-- the transaction enters "aborted" state

BEGIN;
INSERT INTO accounts VALUES (1, 'Dupe', 0);
-- ERROR: duplicate key value violates unique constraint

-- Now EVERY command fails:
-- SELECT * FROM accounts;
-- ERROR: current transaction is aborted, commands ignored
-- until end of transaction block

-- The ! in psql prompt shows aborted state: practice=!#

-- Only ROLLBACK works now:
ROLLBACK;

-- === SAVEPOINT — Partial Rollback ===

BEGIN;

-- Step 1: successful operation
UPDATE accounts SET bal = bal + 100 WHERE id = 1;  -- Alice +100

-- Create a savepoint after step 1
SAVEPOINT sp1;

-- Step 2: risky operation
UPDATE accounts SET bal = bal - 999999 WHERE id = 2;  -- Oops!

-- Roll back only step 2 (keeps step 1)
ROLLBACK TO sp1;

-- Step 2 retry: correct amount
UPDATE accounts SET bal = bal - 50 WHERE id = 2;  -- Bob -50

COMMIT;

SELECT * FROM accounts;
-- Alice: 900 (800+100), Bob: 650 (700-50), Carol: 300

-- === SAVEPOINT: Recovery from Error ===

BEGIN;

SAVEPOINT before_risky;

-- This will fail (duplicate key)
INSERT INTO accounts VALUES (1, 'Dupe', 0);
-- ERROR: duplicate key

-- Without savepoint, transaction is aborted!
-- But WITH savepoint, we can recover:
ROLLBACK TO before_risky;

-- Transaction is still alive! We can continue:
INSERT INTO accounts VALUES (4, 'Dave', 200);

COMMIT;

SELECT * FROM accounts;
-- Dave (id=4) is now in the table

-- === NESTED SAVEPOINTS ===

BEGIN;

INSERT INTO accounts VALUES (5, 'Eve', 150);

SAVEPOINT sp1;
INSERT INTO accounts VALUES (6, 'Frank', 100);

SAVEPOINT sp2;
INSERT INTO accounts VALUES (7, 'Grace', 75);

-- Undo only Grace
ROLLBACK TO sp2;

-- Release sp1: Frank becomes part of main transaction
RELEASE SAVEPOINT sp1;

COMMIT;

SELECT * FROM accounts;
-- Eve(5) and Frank(6) committed, Grace(7) gone

-- === AUTO-COMMIT IN PSQL ===

-- By default, AUTOCOMMIT is ON in psql
-- Every statement is its own transaction:
-- INSERT INTO accounts VALUES (8, 'Heidi', 50);
-- ↑ This is automatically: BEGIN; INSERT; COMMIT;

-- Check auto-commit setting:
-- \echo :AUTOCOMMIT
-- Output: on

-- Turn off auto-commit (manual COMMIT needed):
-- \set AUTOCOMMIT off
-- Now: INSERT → stays uncommitted until you type COMMIT

-- Turn it back on:
-- \set AUTOCOMMIT on

-- Application code (Python, Java, etc.) usually has
-- auto-commit OFF by default — you MUST call commit()

-- === TRANSACTION COMMANDS SUMMARY ===

-- BEGIN;             -- Start transaction (also: START TRANSACTION)
-- COMMIT;            -- Save all changes (also: END)
-- ROLLBACK;          -- Undo all changes (also: ABORT)
-- SAVEPOINT name;    -- Create checkpoint
-- ROLLBACK TO name;  -- Undo to checkpoint
-- RELEASE SAVEPOINT; -- Remove checkpoint (merge into txn)

-- === PRACTICE EXERCISES ===

-- Exercise 1: Basic transaction
BEGIN;
UPDATE accounts SET bal = bal + 10 WHERE id = 1;
UPDATE accounts SET bal = bal - 10 WHERE id = 2;
COMMIT;

-- Exercise 2: Rollback
BEGIN;
DELETE FROM accounts WHERE bal < 200;
SELECT * FROM accounts;  -- some rows deleted
ROLLBACK;
SELECT * FROM accounts;  -- all rows restored

-- Exercise 3: Savepoint
BEGIN;
UPDATE accounts SET bal = 0 WHERE id = 1;
SAVEPOINT sp1;
UPDATE accounts SET bal = 0 WHERE id = 2;
ROLLBACK TO sp1;       -- only id=2 update undone
COMMIT;
-- Check: id=1 has bal=0, id=2 unchanged

-- Exercise 4: Aborted transaction
BEGIN;
INSERT INTO accounts VALUES (1, 'Dupe', 0);  -- ERROR!
-- Try: SELECT 1;  → still fails
ROLLBACK;  -- must rollback to continue

-- Exercise 5: Transfer with validation
BEGIN;
-- Check balance first
-- SELECT bal FROM accounts WHERE id = 1;  -- enough?
UPDATE accounts SET bal = bal - 100 WHERE id = 1 AND bal >= 100;
UPDATE accounts SET bal = bal + 100 WHERE id = 2;
COMMIT;

-- Exercise 6: Nested savepoints
BEGIN;
SAVEPOINT a;
INSERT INTO accounts VALUES (10, 'Test1', 10);
SAVEPOINT b;
INSERT INTO accounts VALUES (11, 'Test2', 20);
ROLLBACK TO b;   -- Test2 gone
RELEASE SAVEPOINT a;  -- Test1 stays
COMMIT;

-- Cleanup exercise data
DELETE FROM accounts WHERE id > 7;

-- === CLEANUP ===
-- Reset balances for next class
UPDATE accounts SET bal = CASE id
  WHEN 1 THEN 1000 WHEN 2 THEN 500 WHEN 3 THEN 300
  ELSE bal END
WHERE id IN (1, 2, 3);

-- DELETE FROM accounts WHERE id > 3;
-- DROP TABLE IF EXISTS accounts;

-- =============================================
-- Next Class: Isolation Levels
-- =============================================


-- =============================================
-- === PRACTICE EXERCISES & VERIFIED SOLUTIONS ===
-- =============================================

-- Exercise 1: Atomic Fund Transfer
BEGIN;
UPDATE accounts SET bal = bal - 100 WHERE id = 1;
UPDATE accounts SET bal = bal + 100 WHERE id = 2;
COMMIT;

SELECT * FROM accounts;

-- Exercise 2: Abort and Rollback
BEGIN;
DELETE FROM accounts WHERE id = 3;
ROLLBACK;

SELECT * FROM accounts WHERE id = 3;

-- Exercise 3: Guarding Errors with SAVEPOINT
BEGIN;
UPDATE accounts SET bal = bal + 50 WHERE id = 1;
SAVEPOINT sp_risky;

-- This fails due to primary key duplicate
INSERT INTO accounts (id, name, bal) VALUES (1, 'Duplicate Alice', 0);

-- Recover without aborting the transaction
ROLLBACK TO SAVEPOINT sp_risky;
COMMIT;

SELECT * FROM accounts WHERE id = 1;

-- Exercise 4: Transactional DDL
BEGIN;
ALTER TABLE accounts ADD COLUMN status VARCHAR(20) DEFAULT 'active';
SELECT * FROM accounts;
ROLLBACK;

\d accounts

-- Exercise 5: Monitoring Active Transactions
SELECT
    pid,
    usename,
    state,
    NOW() - xact_start AS xact_duration,
    query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_duration DESC;

