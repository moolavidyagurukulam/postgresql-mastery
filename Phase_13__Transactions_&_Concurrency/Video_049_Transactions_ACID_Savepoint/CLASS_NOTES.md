# Transactions, ACID & SAVEPOINT — All or Nothing
**Series:** PostgreSQL Mastery | **Phase:** Phase 13: Transactions & Concurrency | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn about transactions — the mechanism that keeps your data consistent even when things go wrong. A transaction groups multiple SQL statements into a single unit of work. Either ALL of them succeed, or NONE of them succeed. We will learn BEGIN, COMMIT, ROLLBACK, the ACID properties, SAVEPOINT for partial rollback, and how psql auto-commit works. Let us begin.

### Why Transactions Matter
The classic example: transferring money between two bank accounts. You must subtract from account A AND add to account B. If the system crashes after the subtraction but before the addition, money disappears! A transaction wraps both operations together. If anything fails, ROLLBACK undoes everything. If both succeed, COMMIT makes them permanent. This is the all-or-nothing guarantee.


---

## 2. Core Technical Concepts & Mechanisms

### Why Transactions Matter
The classic example: transferring money between two bank accounts. You must subtract from account A AND add to account B. If the system crashes after the subtraction but before the addition, money disappears! A transaction wraps both operations together. If anything fails, ROLLBACK undoes everything. If both succeed, COMMIT makes them permanent. This is the all-or-nothing guarantee.

| Without Transaction | With Transaction |
| :--- | :--- |
| UPDATE accounts SET bal = bal - 100 WHERE id = 1; | BEGIN; |
| -- CRASH HAPPENS HERE -- | UPDATE accounts SET bal = bal - 100 WHERE id = 1; |
| UPDATE accounts SET bal = bal + 100 WHERE id = 2; | UPDATE accounts SET bal = bal + 100 WHERE id = 2; |
| Result: $100 vanished into thin air! | COMMIT;  -- both happen or neither |
| Data is INCONSISTENT | Data is ALWAYS consistent |

### ACID Properties
ACID is the set of four properties that every transaction guarantees. Atomicity means all or nothing — either the entire transaction commits, or nothing changes. Consistency means the database moves from one valid state to another — constraints are always enforced. Isolation means concurrent transactions do not see each other's uncommitted changes. Durability means once committed, the changes survive even a power failure — the WAL, or Write-Ahead Log, makes this possible.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Atomicity** | All or nothing — entire transaction succeeds or fails together |
| **Consistency** | Constraints enforced — database always in a valid state |
| **Isolation** | Concurrent transactions don't see uncommitted changes |
| **Durability** | Committed data survives crashes (WAL guarantees this) |

**Notes:**
- PostgreSQL implements ALL four properties
- WAL (Write-Ahead Log) provides Durability
- MVCC provides Isolation (covered in next class)

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Auto-Commit in psql
In psql, auto-commit is ON by default. This means every single statement is automatically wrapped in its own transaction. When you type an INSERT and press enter, it is immediately committed. There is no BEGIN or COMMIT needed — psql adds them automatically. You only need explicit BEGIN when you want MULTIPLE statements in one transaction. You can turn off auto-commit with backslash set AUTOCOMMIT off — then every statement needs an explicit COMMIT.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Default** | AUTOCOMMIT = on — every statement auto-commits |
| **Meaning** | INSERT → automatic BEGIN + INSERT + COMMIT |
| **Explicit BEGIN** | Disables auto-commit until COMMIT or ROLLBACK |
| **Turn off** | \set AUTOCOMMIT off — manual COMMIT needed |
| **Check** | \echo :AUTOCOMMIT — shows current setting |

**Notes:**
- Application code should use explicit transactions
- psql auto-commit is for convenience only

### When to Use Explicit Transactions
When should you use explicit transactions? Here is the decision framework. For single statements, psql auto-commit is fine — no BEGIN needed. For multiple related changes — like transferring money or migrating schema — always use BEGIN and COMMIT. For risky operations, add SAVEPOINT before each risky step. In application code, ALWAYS use explicit transactions — never rely on auto-commit. And set idle_in_transaction_session_timeout to catch forgotten transactions.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | When should you use explicit transactions? |
| **For single statements** | psql auto-commit is fine — no BEGIN needed |
| **For multiple related changes** | like transferring money or migrating schema — always use BEGIN and COMMIT |
| **For risky operations** | add SAVEPOINT before each risky step |
| **In application code** | ALWAYS use explicit transactions — never rely on auto-commit |
| **Point 6** | And set idle_in_transaction_session_timeout to catch forgotten transactions |

### Practice Exercises
Practice exercises: create a table, use BEGIN and COMMIT to wrap multiple operations, use ROLLBACK to undo changes, create savepoints and roll back to them, trigger the aborted transaction error and recover with savepoints, test DDL rollback with CREATE TABLE inside a transaction, and check pg_stat_activity for active transactions.

- 1. BEGIN → INSERT → UPDATE → COMMIT (all succeed)
- 2. BEGIN → DELETE → ROLLBACK (undo the delete)
- 3. BEGIN → SAVEPOINT sp1 → bad INSERT → ROLLBACK TO sp1 → COMMIT
- 4. Trigger 'transaction is aborted' error → recover with ROLLBACK
- 5. BEGIN → CREATE TABLE → INSERT → ROLLBACK (DDL rollback!)
- 6. Nested savepoints: sp1 → sp2 → ROLLBACK TO sp2 → RELEASE sp1
- 7. Check pg_stat_activity for your transaction
- 8. Set idle_in_transaction_session_timeout and test it


---

## 3. Hands-On Commands & psql Output

### BEGIN, COMMIT, ROLLBACK
**Explanation:** BEGIN starts a transaction. COMMIT saves all changes permanently. ROLLBACK undoes everything since BEGIN. In between, you can run any number of INSERT, UPDATE, DELETE, and other statements. Nothing is visible to other sessions until you COMMIT. If your session disconnects or crashes, PostgreSQL automatically rolls back the open transaction.

```sql
-- Setup: bank accounts
practice=# CREATE TABLE accounts (
  id   INT PRIMARY KEY,
  name VARCHAR(50),
  bal  NUMERIC(10,2)
);
practice=# INSERT INTO accounts VALUES (1,'Alice',1000), (2,'Bob',500);

-- Transaction: transfer $200 from Alice to Bob
practice=# BEGIN;
BEGIN
practice=*# UPDATE accounts SET bal = bal - 200 WHERE id = 1;
UPDATE 1
practice=*# UPDATE accounts SET bal = bal + 200 WHERE id = 2;
UPDATE 1
practice=*# COMMIT;
COMMIT

practice=# SELECT * FROM accounts;
 id | name  |  bal
----+-------+--------
  1 | Alice | 800.00
  2 | Bob   | 700.00
```

### ROLLBACK — Undo Everything
**Explanation:** Now let us see ROLLBACK in action. We start a transaction, make changes, then decide we do not want them. ROLLBACK undoes everything — the table goes back to the state before BEGIN. Notice the psql prompt changes from hash to asterisk-hash when you are inside a transaction — that is your visual reminder.

```sql
practice=# BEGIN;
BEGIN
practice=*# DELETE FROM accounts WHERE id = 2;
DELETE 1
practice=*# SELECT * FROM accounts;
 id | name  |  bal
----+-------+--------
  1 | Alice | 800.00

-- Oops! We didn't mean to delete Bob
practice=*# ROLLBACK;
ROLLBACK

-- Bob is back! ROLLBACK undid the DELETE
practice=# SELECT * FROM accounts;
 id | name  |  bal
----+-------+--------
  1 | Alice | 800.00
  2 | Bob   | 700.00
```

### Two Terminals — Isolation Demo
**Explanation:** Two terminals demonstrate isolation. Terminal A starts a transaction and inserts a row. Terminal B queries the same table but CANNOT see the new row — because Terminal A has not committed yet. Only after Terminal A commits does Terminal B see the change. This is the default Read Committed isolation level.

```sql
-- TERMINAL A: starts a transaction
[A] practice=# BEGIN;
[A] practice=*# INSERT INTO accounts VALUES (3, 'Carol', 300);
INSERT 0 1

-- TERMINAL B: queries — Carol is NOT visible yet!
[B] practice=# SELECT * FROM accounts;
 id | name  |  bal
----+-------+--------
  1 | Alice | 800.00
  2 | Bob   | 700.00
(2 rows)  -- No Carol!

-- TERMINAL A: commits
[A] practice=*# COMMIT;

-- TERMINAL B: NOW Carol is visible
[B] practice=# SELECT * FROM accounts;
  1 | Alice | 800.00
  2 | Bob   | 700.00
  3 | Carol | 300.00
(3 rows)  -- Carol appears after COMMIT!
```

### SAVEPOINT — Partial Rollback
**Explanation:** SAVEPOINT lets you create checkpoints inside a transaction. If something fails after a savepoint, you can ROLLBACK TO that savepoint — undoing only the work after it — and continue the transaction. Without savepoints, any error inside a transaction forces you to ROLLBACK the entire thing. Savepoints are essential for complex transactions with multiple steps where partial failure is expected.

```sql
practice=# BEGIN;
practice=*# UPDATE accounts SET bal = bal + 100 WHERE id = 1;
UPDATE 1  -- Alice: 800 → 900

-- Create a savepoint after the first update
practice=*# SAVEPOINT sp1;
SAVEPOINT

practice=*# UPDATE accounts SET bal = bal - 999999 WHERE id = 2;
UPDATE 1  -- Oops, accidentally overdrew Bob!

-- Roll back to savepoint (only undoes Bob's update)
practice=*# ROLLBACK TO sp1;
ROLLBACK

-- Alice's +100 is still in effect!
practice=*# UPDATE accounts SET bal = bal - 50 WHERE id = 2;
UPDATE 1  -- Bob: correct deduction

practice=*# COMMIT;
COMMIT
```

### Beginner Trap: Aborted Transaction
**Explanation:** A critical error beginners hit: when any statement inside a transaction fails, the transaction enters an aborted state. After that, EVERY subsequent command fails with 'current transaction is aborted, commands ignored until end of transaction block.' The only way out is ROLLBACK. With savepoints, you can recover from the error without losing your entire transaction.

```sql
practice=# BEGIN;
practice=*# INSERT INTO accounts VALUES (1, 'Dupe', 0);
ERROR:  duplicate key value violates unique constraint
        "accounts_pkey"

-- Transaction is now ABORTED — everything fails!
practice=!# SELECT * FROM accounts;
ERROR:  current transaction is aborted, commands
ignored until end of transaction block

-- Notice the ! in the prompt: practice=!#
-- Only ROLLBACK works now
practice=!# ROLLBACK;
ROLLBACK

-- Fix: use SAVEPOINT before risky operations
-- BEGIN; SAVEPOINT sp1; risky_insert;
-- If error: ROLLBACK TO sp1; continue;
```

### Fix: Savepoint Guards Risky Operations
**Explanation:** Here is the fix for aborted transactions: wrap risky operations in a savepoint. BEGIN your transaction, do the safe operations first, then SAVEPOINT before the risky INSERT. If the INSERT fails, ROLLBACK TO the savepoint — the transaction is no longer aborted, and your earlier work is preserved. This is the standard pattern in application code.

```sql
practice=# BEGIN;
practice=*# UPDATE accounts SET bal = bal + 50 WHERE id = 1;
UPDATE 1  -- safe operation done

practice=*# SAVEPOINT before_risky;
SAVEPOINT

practice=*# INSERT INTO accounts VALUES (1, 'Dupe', 0);
ERROR:  duplicate key value violates unique constraint

-- Recover! Roll back only the failed INSERT
practice=!# ROLLBACK TO before_risky;
ROLLBACK

-- Transaction is healthy again — earlier UPDATE preserved
practice=*# COMMIT;
COMMIT
practice=# SELECT bal FROM accounts WHERE id = 1;
  850.00  -- The +50 update survived!
```

### Beginner Trap: DDL is Transactional in PG!
**Explanation:** Beginner trap: DDL commands like CREATE TABLE, ALTER TABLE, and DROP TABLE are transactional in PostgreSQL! This is special — MySQL auto-commits DDL immediately. In PostgreSQL, you can put CREATE TABLE inside a transaction and ROLLBACK to undo it. This makes schema migrations safer — wrap all your changes in a transaction, and if any step fails, ROLLBACK undoes the entire migration.

```sql
practice=# BEGIN;
practice=*# CREATE TABLE test_ddl (id INT);
CREATE TABLE
practice=*# INSERT INTO test_ddl VALUES (1), (2), (3);
INSERT 0 3

-- Table exists inside the transaction
practice=*# SELECT * FROM test_ddl;
 id
----
  1
  2
  3

practice=*# ROLLBACK;
ROLLBACK

-- Table is GONE — CREATE TABLE was rolled back!
practice=# SELECT * FROM test_ddl;
ERROR:  relation "test_ddl" does not exist

-- MySQL would have auto-committed the CREATE TABLE
-- PostgreSQL lets you roll back DDL — safer migrations!
```

### Nested Savepoints
**Explanation:** Nested savepoints let you create savepoints within savepoints. SAVEPOINT sp1, then do some work, SAVEPOINT sp2, do more work. You can ROLLBACK TO sp2 to undo only the latest work, or ROLLBACK TO sp1 to undo everything after sp1. RELEASE SAVEPOINT removes a savepoint — the work becomes part of the outer transaction. This pattern is common in application code that calls nested functions, each managing its own recovery point.

```sql
practice=# BEGIN;
practice=*# INSERT INTO accounts VALUES (4, 'Dave', 200);

practice=*# SAVEPOINT sp1;
practice=*# INSERT INTO accounts VALUES (5, 'Eve', 150);

practice=*# SAVEPOINT sp2;
practice=*# INSERT INTO accounts VALUES (6, 'Frank', 100);

-- Undo only Frank (rollback to sp2)
practice=*# ROLLBACK TO sp2;
-- Dave and Eve still present, Frank gone

-- Release sp1: Eve's work merges into main transaction
practice=*# RELEASE SAVEPOINT sp1;

practice=*# COMMIT;
COMMIT
-- Result: Dave(4) and Eve(5) committed, Frank(6) gone
```

### Monitoring Active Transactions
**Explanation:** Transaction monitoring. You can check what transactions are active right now using pg_stat_activity. This shows the process ID, the current state (active, idle, or idle in transaction), how long the transaction has been open, and what query is running. Long-running 'idle in transaction' sessions are dangerous — they hold locks and prevent VACUUM from cleaning up dead rows.

```sql
practice=# SELECT pid, state, xact_start,
  AGE(NOW(), xact_start) AS duration,
  LEFT(query, 50) AS query
FROM pg_stat_activity
WHERE state != 'idle' ORDER BY xact_start;
  pid  |        state        |       duration       | query
-------+---------------------+----------------------+------------------
 12345 | idle in transaction | 00:15:32.123456      | UPDATE accounts...
 12346 | active              | 00:00:01.234567      | SELECT * FROM...

-- 'idle in transaction' for 15 minutes = problem!
-- Holds locks, blocks VACUUM, wastes resources
-- Set idle_in_transaction_session_timeout to auto-kill:
practice=# SET idle_in_transaction_session_timeout = '5min';
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Aborted Transaction
A critical error beginners hit: when any statement inside a transaction fails, the transaction enters an aborted state. After that, EVERY subsequent command fails with 'current transaction is aborted, commands ignored until end of transaction block.' The only way out is ROLLBACK. With savepoints, you can recover from the error without losing your entire transaction.

```sql
BEGIN;
INSERT INTO accounts VALUES (1, 'Dupe', 0);
ERROR:  duplicate key value violates unique constraint
        "accounts_pkey"

-- Transaction is now ABORTED — everything fails!
SELECT * FROM accounts;
ERROR:  current transaction is aborted, commands
ignored until end of transaction block

-- Notice the ! in the prompt: practice=!#
-- Only ROLLBACK works now
ROLLBACK;
ROLLBACK

-- Fix: use SAVEPOINT before risky operations
-- BEGIN; SAVEPOINT sp1; risky_insert;
-- If error: ROLLBACK TO sp1; continue;
```

### Beginner Trap: DDL is Transactional in PG!
Beginner trap: DDL commands like CREATE TABLE, ALTER TABLE, and DROP TABLE are transactional in PostgreSQL! This is special — MySQL auto-commits DDL immediately. In PostgreSQL, you can put CREATE TABLE inside a transaction and ROLLBACK to undo it. This makes schema migrations safer — wrap all your changes in a transaction, and if any step fails, ROLLBACK undoes the entire migration.

```sql
BEGIN;
CREATE TABLE test_ddl (id INT);
CREATE TABLE
INSERT INTO test_ddl VALUES (1), (2), (3);
INSERT 0 3

-- Table exists inside the transaction
SELECT * FROM test_ddl;
 id
----
  1
  2
  3

ROLLBACK;
ROLLBACK

-- Table is GONE — CREATE TABLE was rolled back!
SELECT * FROM test_ddl;
ERROR:  relation "test_ddl" does not exist

-- MySQL would have auto-committed the CREATE TABLE
-- PostgreSQL lets you roll back DDL — safer migrations!
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. BEGIN starts a transaction, COMMIT saves it, ROLLBACK undoes it. ACID guarantees Atomicity, Consistency, Isolation, and Durability. SAVEPOINT creates recovery points inside a transaction — essential for handling errors without losing earlier work. DDL is transactional in PostgreSQL — you can ROLLBACK a CREATE TABLE. The aborted transaction error means you must ROLLBACK — use savepoints to prevent it. Monitor long transactions with pg_stat_activity and kill idle ones with idle_in_transaction_session_timeout.

- **BEGIN; ... COMMIT; — all or nothing**
- **ROLLBACK; — undo everything since BEGIN**
- **ACID: Atomic, Consistent, Isolated, Durable**
- **SAVEPOINT sp1; — checkpoint inside transaction**
- **ROLLBACK TO sp1; — undo to savepoint, keep going**
- **RELEASE SAVEPOINT sp1; — merge into main txn**
- **DDL is transactional — ROLLBACK undoes CREATE TABLE**
- **Aborted txn: only ROLLBACK works (! in prompt)**
- **pg_stat_activity — monitor open transactions**


---

## 8. Downloadable SQL Script Instructions

Every command demonstrated in this video is compiled into the companion `materials.sql` file.

To execute it directly in PostgreSQL:

```bash
# From your command line:
psql -U postgres -d postgres -f materials.sql

# Or from inside psql prompt:
postgres=# \i materials.sql
```
