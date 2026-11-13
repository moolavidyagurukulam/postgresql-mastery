# Isolation Levels — What One Transaction Sees of Another
**Series:** PostgreSQL Mastery | **Phase:** Phase 13: Transactions & Concurrency | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we explore isolation levels — the rules that control what one transaction can see of another transaction's changes. PostgreSQL offers three isolation levels: Read Committed, Repeatable Read, and Serializable. Each prevents different concurrency problems. Understanding these is essential for building correct, concurrent applications. Let us begin.

### Concurrency Problems
There are three concurrency problems that isolation levels address. A dirty read happens when you see another transaction's UNCOMMITTED changes — PostgreSQL never allows this. A non-repeatable read happens when you read a row, another transaction changes it, and you read it again and get different values. A phantom read happens when you run the same query twice and get different rows because another transaction inserted or deleted rows between your reads.


---

## 2. Core Technical Concepts & Mechanisms

### Concurrency Problems
There are three concurrency problems that isolation levels address. A dirty read happens when you see another transaction's UNCOMMITTED changes — PostgreSQL never allows this. A non-repeatable read happens when you read a row, another transaction changes it, and you read it again and get different values. A phantom read happens when you run the same query twice and get different rows because another transaction inserted or deleted rows between your reads.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Dirty Read** | See uncommitted changes from another transaction |
| **Non-Repeatable Read** | Same row returns different values on re-read |
| **Phantom Read** | Same query returns different rows on re-run |

**Notes:**
- PostgreSQL NEVER allows dirty reads (even at lowest level)
- Higher isolation = fewer problems, but more overhead

### Serializable — Strictest Isolation
Serializable is the strictest isolation level. It guarantees that concurrent transactions produce the same result as if they had been executed one after another — serially. PostgreSQL detects dependency cycles between transactions and aborts one of them with a serialization error. This prevents ALL concurrency anomalies, but your application must be prepared to retry failed transactions.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Guarantee** | Result equals some serial execution order |
| **How** | PG detects dependency cycles, aborts one transaction |
| **Error** | ERROR: could not serialize access → retry! |
| **Cost** | More overhead, more retries, but 100% correct |
| **When to use** | Financial calculations, inventory management, critical data |

**Notes:**
- Your app MUST have retry logic for serialization failures
- SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

### Isolation Level Comparison
Here is the complete comparison of all three isolation levels. Read Committed is the default and works for most applications. Repeatable Read prevents non-repeatable reads and phantoms — use it for reports that must be consistent within a single transaction. Serializable prevents everything — use it for critical financial operations where absolute correctness is required.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is the complete comparison of all three isolation levels |
| **Point 2** | Read Committed is the default and works for most applications |
| **Repeatable Read prevents non** | repeatable reads and phantoms — use it for reports that must be consistent within a single transaction |
| **Serializable prevents everything** | use it for critical financial operations where absolute correctness is required |

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Which Isolation Level Should I Use?
A practical decision framework for choosing an isolation level. For most web applications, Read Committed is sufficient. For reports that must be consistent — like a financial statement where totals must match — use Repeatable Read. For operations where incorrect results could cause real damage — like double-spending or inventory overselling — use Serializable with retry logic.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | A practical decision framework for choosing an isolation level |
| **For most web applications** | Read Committed is sufficient |
| **For reports that must be consistent** | like a financial statement where totals must match — use Repeatable Read |
| **Point 4** | For operations where incorrect results could cause real damage — like double-spending or inventory overselling — use Serializable with retry logic |

### Practice Exercises
Practice exercises: test Read Committed behavior with two sessions, set Repeatable Read and observe the frozen snapshot, trigger a serialization error and understand why it happens, check the current isolation level, and discuss which level fits different scenarios.

- 1. Open two psql sessions (two terminals)
- 2. Read Committed: A reads, B updates+commits, A re-reads → different!
- 3. Repeatable Read: A reads, B updates+commits, A re-reads → same!
- 4. Repeatable Read: A tries to UPDATE same row B changed → error
- 5. SHOW transaction_isolation; in both sessions
- 6. SET SESSION ... REPEATABLE READ; check it sticks
- 7. Discuss: which level for your application?


---

## 3. Hands-On Commands & psql Output

### Read Committed (Default)
**Explanation:** Read Committed is the default isolation level. Each statement in the transaction sees only data committed BEFORE that statement started. If another transaction commits while yours is running, your next statement WILL see those new changes. This means different statements in the same transaction can see different versions of the data. For most applications, this is fine.

```sql
-- TERMINAL A: Read Committed (default)
[A] practice=# BEGIN;
[A] practice=*# SELECT bal FROM accounts WHERE id = 1;
  bal
--------
 1000.00

-- TERMINAL B: commits a change while A is open
[B] practice=# UPDATE accounts SET bal = 900 WHERE id = 1;
UPDATE 1  -- committed immediately (auto-commit)

-- TERMINAL A: reads again — sees NEW value!
[A] practice=*# SELECT bal FROM accounts WHERE id = 1;
  bal
--------
 900.00  -- Non-repeatable read!

[A] practice=*# COMMIT;
-- Read Committed: each statement sees latest commits
```

### Repeatable Read — Frozen Snapshot
**Explanation:** Repeatable Read gives you a consistent snapshot of the database taken at the START of the transaction. Every query in the transaction sees the same data — no matter what other transactions commit in between. If another transaction changes data that your transaction is also trying to change, you get a serialization error and must retry.

```sql
-- TERMINAL A: Repeatable Read
[A] practice=# BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
[A] practice=*# SELECT bal FROM accounts WHERE id = 1;
 900.00

-- TERMINAL B: changes Alice's balance
[B] practice=# UPDATE accounts SET bal = 800 WHERE id = 1;
UPDATE 1

-- TERMINAL A: reads again — still sees 900!
[A] practice=*# SELECT bal FROM accounts WHERE id = 1;
 900.00  -- Same value! Snapshot is frozen

-- But if A tries to UPDATE the same row:
[A] practice=*# UPDATE accounts SET bal = 950 WHERE id = 1;
ERROR:  could not serialize access due to
        concurrent update

[A] practice=!# ROLLBACK;
-- Must retry the entire transaction!
```

### Setting Isolation Levels
**Explanation:** You can set the isolation level per transaction with BEGIN TRANSACTION ISOLATION LEVEL. Or set the default for the entire session. Or even set it globally in postgresql.conf. The syntax is always the same — just the scope changes. Most applications use Read Committed and only switch to higher levels for specific operations that need it.

```sql
-- Per transaction (most common)
practice=# BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- Or:
practice=# BEGIN;
practice=*# SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Per session (all transactions in this connection)
practice=# SET SESSION CHARACTERISTICS AS
TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Check current level
practice=# SHOW transaction_isolation;
 transaction_isolation
-----------------------
 read committed

-- Global default (postgresql.conf):
-- default_transaction_isolation = 'read committed'
```

### Application Retry Pattern (Pseudocode)
**Explanation:** When a serialization error occurs — ERROR: could not serialize access — your application must catch this error and retry the entire transaction from the beginning. Not just the failed statement — the entire transaction. This is the tradeoff for higher isolation: correctness in exchange for retry logic. Here is the pattern every application should follow.

```sql
-- Application retry loop (pseudocode):
--
-- max_retries = 3
-- FOR attempt IN 1..max_retries:
--   BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
--   TRY:
--     -- all your SQL operations here
--     UPDATE accounts SET bal = bal - 100 WHERE id = 1;
--     UPDATE accounts SET bal = bal + 100 WHERE id = 2;
--     COMMIT;
--     break;  -- success, exit loop
--   CATCH serialization_failure:
--     ROLLBACK;
--     -- wait briefly, then retry
--     continue;
--
-- PostgreSQL error code: 40001 (serialization_failure)
-- Your ORM/driver will have a specific exception class
```


---


## 6. Hands-On Practice Exercises & Verified Solutions

### Exercise 1: Demonstrating Non-Repeatable Reads
**Challenge:** Run two concurrent sessions under `READ COMMITTED` to observe how statement-level snapshots expose intermediate changes.
```sql
-- Session A:
BEGIN;
SELECT bal FROM accounts WHERE id = 1; -- 1000.00

-- Session B:
UPDATE accounts SET bal = 850.00 WHERE id = 1;

-- Session A:
SELECT bal FROM accounts WHERE id = 1; -- 850.00!
COMMIT;
```
*Explanation:* Under Read Committed, every query takes a fresh snapshot. Because Session B committed between the two queries, Session A sees the updated row value.

### Exercise 2: Frozen Transaction Snapshots
**Challenge:** Execute the same test under `REPEATABLE READ` and verify that Session A remains insulated from Session B's committed updates.
```sql
-- Session A:
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT bal FROM accounts WHERE id = 1; -- 850.00

-- Session B:
UPDATE accounts SET bal = 700.00 WHERE id = 1;

-- Session A:
SELECT bal FROM accounts WHERE id = 1; -- Still 850.00!
COMMIT;
```
*Explanation:* Under Repeatable Read, the MVCC snapshot is frozen at transaction start, ignoring any transactions that commit after our snapshot horizon.

### Exercise 3: Concurrent Update Serialization Failure
**Challenge:** Attempt to update the same row in Session A after Session B has already committed a modification to it under `REPEATABLE READ`.
```sql
-- Session A:
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT bal FROM accounts WHERE id = 1;

-- Session B:
UPDATE accounts SET bal = 600.00 WHERE id = 1;

-- Session A:
UPDATE accounts SET bal = 650.00 WHERE id = 1;
-- ERROR: could not serialize access due to concurrent update
ROLLBACK;
```
*Explanation:* PostgreSQL employs first-committer-wins. Because Session A cannot see Session B's committed change, updating the row would overwrite Session B's data, triggering a serialization error.

### Exercise 4: Simulating Write Skew
**Challenge:** Reproduce the classic hospital on-call dilemma under `REPEATABLE READ` where concurrent transactions violate business invariants without updating the same row.
```sql
-- Session A:
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM on_call WHERE is_on_call = true; -- returns 2
UPDATE on_call SET is_on_call = false WHERE doctor_id = 1;
COMMIT;

-- Session B:
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM on_call WHERE is_on_call = true; -- returns 2
UPDATE on_call SET is_on_call = false WHERE doctor_id = 2;
COMMIT;
```
*Explanation:* Both transactions commit because they update disjoint rows. However, the system invariant (at least one doctor on-call) is violated.

### Exercise 5: Eliminating Write Skew with SERIALIZABLE
**Challenge:** Re-run the on-call scenario under `SERIALIZABLE` and verify that PostgreSQL SSI detects the dependency cycle.
```sql
-- Session A & B run under:
BEGIN ISOLATION LEVEL SERIALIZABLE;
-- Session B receives:
-- ERROR: could not serialize access due to read/write dependencies among transactions (SQLSTATE 40001)
```
*Explanation:* Serializable Snapshot Isolation detects the read-write dependency cycle between transactions and aborts the victim transaction with error `40001`, preserving the invariant.


## 7. Key Takeaways & Cheat Sheet

Let us recap. Read Committed — the default — shows latest committed data per statement. Repeatable Read freezes a snapshot at transaction start — same data throughout. Serializable guarantees serial-equivalent execution — the strictest. Higher isolation means more correctness but requires retry logic for serialization errors. PostgreSQL NEVER allows dirty reads at any level. Choose the level based on your consistency requirements. In the next class, we cover locks — row-level locking, table locking, deadlocks, and how to debug lock conflicts. See you there!

- **Read Committed: default, sees latest commits per statement**
- **Repeatable Read: frozen snapshot from txn start**
- **Serializable: serial-equivalent, retries required**
- **PostgreSQL NEVER allows dirty reads**
- **SET TRANSACTION ISOLATION LEVEL ...**
- **Serialization error (40001): retry entire transaction**
- **Most apps: Read Committed is sufficient**
- **Critical ops: Serializable with retry logic**


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
