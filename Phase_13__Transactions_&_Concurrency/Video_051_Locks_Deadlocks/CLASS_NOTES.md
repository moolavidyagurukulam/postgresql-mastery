# Row Locks, Table Locks & Deadlocks
**Series:** PostgreSQL Mastery | **Phase:** Phase 13: Transactions & Concurrency | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover locks — the mechanism PostgreSQL uses to coordinate access between concurrent transactions. Row-level locks protect individual rows during updates. Table-level locks protect entire tables during DDL operations. Deadlocks happen when two transactions wait for each other forever. We will learn how locks work, how to detect them, and how to avoid deadlocks. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Row-Level Locks — Automatic with UPDATE
PostgreSQL uses row-level locking by default. When you UPDATE a row inside a transaction, that row is locked until the transaction ends. Other transactions can still READ the row — they see the old version thanks to MVCC. But if another transaction tries to UPDATE the SAME row, it must WAIT until the first transaction commits or rolls back. This is automatic — you do not need to lock rows manually.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Automatic** | UPDATE, DELETE, SELECT FOR UPDATE lock the row |
| **Readers OK** | Other transactions can still SELECT (read old version) |
| **Writers wait** | Other UPDATEs on same row block until lock released |
| **Release** | Lock released on COMMIT or ROLLBACK |
| **No deadlock alone** | Single-row locks rarely cause deadlocks by themselves |

**Notes:**
- MVCC: readers never block writers, writers never block readers
- Only writer-vs-writer conflicts cause waiting

### Common Table Lock Modes
Table-level locks are taken automatically during DDL operations. CREATE INDEX locks the table for writes. ALTER TABLE takes an exclusive lock that blocks everything. DROP TABLE also takes an exclusive lock. For most DML — INSERT, UPDATE, DELETE — PostgreSQL takes only a weak table lock that allows other DML to proceed. The strong locks are needed only for schema changes.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Table-level locks** | taken automatically during DDL operations |
| **SQL takes only a weak table lock that** | other DML to proceed |
| **The strong locks** | needed only for schema changes |

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Preventing Deadlocks
The key rule to prevent deadlocks: always lock rows in the same order. If every transaction updates rows by ascending ID, they will never form a cycle. Transaction A locks row 1, then row 2. Transaction B also locks row 1 first — it waits for A — then gets row 2 after A is done. No cycle, no deadlock. Also keep transactions short — the longer a transaction holds locks, the higher the chance of conflicts.

| Causes | Prevention |
| :--- | :--- |
| Locking rows in DIFFERENT order | Always lock rows in SAME order (e.g., by ID) |
| Long-running transactions holding locks | Keep transactions SHORT |
| Updating many rows in one transaction | Use SELECT ... FOR UPDATE NOWAIT or SKIP LOCKED |
| Missing indexes (lock escalation) | Add indexes to reduce lock contention |
| Application doing SELECT then UPDATE separately | Use retry logic for deadlock errors (40P01) |

### Practice Exercises
Practice exercises: lock a row with SELECT FOR UPDATE and observe another session waiting. Create a deadlock between two sessions and see the error. Use pg_locks to monitor active locks. Try NOWAIT and SKIP LOCKED options. Practice keeping transactions short to minimize lock contention.

- 1. A: BEGIN + SELECT FOR UPDATE → B: UPDATE same row (waits)
- 2. A: COMMIT → B unblocks
- 3. Create a deadlock: A locks row 1, B locks row 2, cross
- 4. Query pg_locks: find waiting locks (granted=f)
- 5. Use pg_blocking_pids() to find the blocker
- 6. Try FOR UPDATE NOWAIT → instant error
- 7. Try FOR UPDATE SKIP LOCKED → skips locked rows


---

## 3. Hands-On Commands & psql Output

### SELECT FOR UPDATE — Explicit Row Lock
**Explanation:** SELECT FOR UPDATE explicitly locks rows for a future update. This is used when you need to read a value, make a decision, and then update — all without another transaction changing the value in between. For example: check if there is enough inventory, then decrement it. Without FOR UPDATE, another transaction could decrement the same stock between your SELECT and UPDATE.

```sql
-- TERMINAL A: lock Alice's row for update
[A] practice=# BEGIN;
[A] practice=*# SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
 id | name  |   bal
----+-------+---------
  1 | Alice | 1000.00
-- Row is now locked by Terminal A

-- TERMINAL B: tries to update Alice → WAITS!
[B] practice=# UPDATE accounts SET bal = 500 WHERE id = 1;
-- (hanging... waiting for A's lock)

-- TERMINAL A: does its update and commits
[A] practice=*# UPDATE accounts SET bal = bal - 100 WHERE id = 1;
[A] practice=*# COMMIT;

-- TERMINAL B: unblocks immediately after A commits
UPDATE 1  -- B's update now proceeds

-- FOR UPDATE variants:
-- FOR NO KEY UPDATE: weaker lock (allows FK checks)
-- FOR SHARE: shared lock (multiple readers, no writers)
-- FOR KEY SHARE: weakest (allows non-key updates)
```

### Monitoring Locks
**Explanation:** You can monitor locks using pg_locks and pg_stat_activity. The pg_locks view shows every lock currently held or awaited. The pg_blocking_pids function tells you which process is blocking another. When a query seems stuck, these tools tell you exactly what it is waiting for and who is holding the lock.

```sql
-- See all current locks
practice=# SELECT pid, locktype, relation::regclass, mode, granted
FROM pg_locks WHERE relation IS NOT NULL;
  pid  | locktype |  relation  |       mode       | granted
-------+----------+------------+------------------+---------
 12345 | relation | accounts   | RowExclusiveLock | t
 12346 | relation | accounts   | RowExclusiveLock | f
-- granted=f means WAITING for the lock

-- Find who is blocking whom
practice=# SELECT
  blocked.pid AS blocked_pid,
  blocked.query AS blocked_query,
  blocking.pid AS blocking_pid,
  blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
  ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.wait_event_type = 'Lock';
```

### Deadlock — Two Transactions Stuck
**Explanation:** A deadlock happens when two transactions each hold a lock that the other needs. Transaction A locks row 1 and waits for row 2. Transaction B locks row 2 and waits for row 1. Neither can proceed — they are stuck forever. PostgreSQL detects this within one second by default and aborts one of the transactions with ERROR: deadlock detected.

```sql
-- TERMINAL A:
[A] practice=# BEGIN;
[A] practice=*# UPDATE accounts SET bal = bal - 10 WHERE id = 1;
UPDATE 1  -- A holds lock on row 1

-- TERMINAL B:
[B] practice=# BEGIN;
[B] practice=*# UPDATE accounts SET bal = bal - 10 WHERE id = 2;
UPDATE 1  -- B holds lock on row 2

-- Now they cross!
[A] practice=*# UPDATE accounts SET bal = bal + 10 WHERE id = 2;
-- (waiting for B's lock on row 2...)

[B] practice=*# UPDATE accounts SET bal = bal + 10 WHERE id = 1;
ERROR:  deadlock detected
DETAIL: Process 12346 waits for ShareLock on
  transaction 789; blocked by process 12345.
Process 12345 waits for ShareLock on
  transaction 790; blocked by process 12346.

-- PG killed B's transaction → A can now proceed
-- [A] COMMIT;  -- A succeeds
```

### NOWAIT and SKIP LOCKED
**Explanation:** NOWAIT and SKIP LOCKED are powerful options for handling lock contention. FOR UPDATE NOWAIT raises an error immediately if the row is locked — no waiting. FOR UPDATE SKIP LOCKED silently skips locked rows and returns only the unlocked ones. SKIP LOCKED is perfect for job queues — multiple workers grab the next unlocked job without blocking each other.

```sql
-- NOWAIT: fail immediately if row is locked
practice=# BEGIN;
practice=*# SELECT * FROM accounts WHERE id = 1 FOR UPDATE NOWAIT;
ERROR:  could not obtain lock on row in relation
        "accounts"
-- Fails instantly instead of waiting
practice=!# ROLLBACK;

-- SKIP LOCKED: skip locked rows, return the rest
-- Perfect for job queues!
practice=# BEGIN;
practice=*# SELECT * FROM accounts
ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED;
 id | name  |   bal
----+-------+---------
  2 | Bob   | 500.00
-- Skipped id=1 (locked by another txn), got id=2
practice=*# COMMIT;
```


---


## 6. Hands-On Practice Exercises & Verified Solutions

### Exercise 1: Explicit Row Locking via SELECT FOR UPDATE
**Challenge:** Lock an account row using `SELECT FOR UPDATE` before applying a balance decrement.
```sql
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
UPDATE accounts SET bal = bal - 100 WHERE id = 1;
COMMIT;
```
*Explanation:* The `FOR UPDATE` clause acquires an exclusive row-level lock, guaranteeing that any competing transaction attempting to read or write row 1 with a lock must wait until commit.

### Exercise 2: Building a Parallel Queue with SKIP LOCKED
**Challenge:** Select and lock the next pending job from `job_queue` using `FOR UPDATE SKIP LOCKED`.
```sql
BEGIN;
SELECT * FROM job_queue
WHERE status = 'pending'
ORDER BY id
LIMIT 1
FOR UPDATE SKIP LOCKED;

UPDATE job_queue SET status = 'completed' WHERE id = 1;
COMMIT;
```
*Explanation:* `SKIP LOCKED` instructs PostgreSQL to bypass any rows currently locked by other concurrent workers, eliminating lock wait times and enabling high concurrency.

### Exercise 3: Simulating and Resolving a Deadlock
**Challenge:** Intentionally cause a deadlock by having Session A update rows 1 then 2, while Session B updates rows 2 then 1.
```sql
-- Session A:
BEGIN; UPDATE accounts SET bal = bal - 10 WHERE id = 1;
-- Session B:
BEGIN; UPDATE accounts SET bal = bal - 20 WHERE id = 2;
-- Session A:
UPDATE accounts SET bal = bal + 10 WHERE id = 2; -- waits on B
-- Session B:
UPDATE accounts SET bal = bal + 20 WHERE id = 1; -- triggers deadlock!
```
*Explanation:* PostgreSQL detects the dependency cycle and automatically aborts one session with `ERROR: deadlock detected` to allow the other to complete.

### Exercise 4: Configuring Deadlock Detection Timeout
**Challenge:** Inspect and configure the `deadlock_timeout` parameter.
```sql
SHOW deadlock_timeout;
SET deadlock_timeout = '500ms';
```
*Explanation:* Adjusts the threshold before the background wait-for cycle detector runs. Shorter values detect deadlocks faster at the expense of slight CPU overhead.

### Exercise 5: Investigating Lock Contention via pg_locks
**Challenge:** Query PostgreSQL system catalogs to pinpoint blocking and blocked session PIDs.
```sql
SELECT
    blocked_locks.pid     AS blocked_pid,
    blocking_locks.pid    AS blocking_pid,
    blocked_activity.query    AS blocked_statement,
    blocking_activity.query   AS blocking_statement
FROM  pg_catalog.pg_locks         blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks         blocking_locks 
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```
*Explanation:* Directly reveals which transaction is holding locks and which queries are queued behind it.


## 7. Key Takeaways & Cheat Sheet

Let us recap. Row locks are automatic with UPDATE and DELETE — readers never blocked, writers wait. SELECT FOR UPDATE explicitly locks rows for future changes. Table locks protect schema changes — ALTER TABLE blocks everything. Deadlocks happen when transactions lock rows in different order — PostgreSQL detects and kills one. Prevent deadlocks by locking in consistent order and keeping transactions short. NOWAIT fails immediately if locked, SKIP LOCKED skips locked rows. In the next class, we cover advisory locks for application-level coordination. See you there!

- **Row locks: automatic with UPDATE/DELETE**
- **MVCC: readers never block writers, writers never block readers**
- **SELECT ... FOR UPDATE: explicit row lock**
- **Table locks: DDL takes strong locks, DML takes weak**
- **Deadlock: PG detects in ~1s, aborts one transaction**
- **Prevent: lock rows in same order, keep txns short**
- **NOWAIT: fail immediately if row locked**
- **SKIP LOCKED: skip locked rows (job queue pattern)**


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
