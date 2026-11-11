# Scenario: Data Corruption Recovery & Blocking Queries
**Series:** PostgreSQL Mastery | **Phase:** 32 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we face two critical scenarios. Data corruption — PostgreSQL detects corrupted pages and refuses to read a table. And blocking queries — one long transaction is blocking 50 other sessions. Both need quick, correct action. Let us walk through detect, diagnose, fix, and prevent for each.

### Production Scenarios:
Data Corruption & Blocking
Welcome to PostgreSQL Mastery. In this class, we face two critical scenarios. Data corruption — PostgreSQL detects corrupted pages and refuses to read a table. And blocking queries — one long transaction is blocking 50 other sessions. Both need quick, correct action. Let us walk through detect, diagnose, fix, and prevent for each.

### Scenario 1: Data Corruption — Detection
The scenario. Your application throws an error: could not read block 4523 of relation orders. Or you see a WARNING in the PostgreSQL log: page verification failed, calculated checksum does not match. Data corruption means the bytes on disk do not match what PostgreSQL expects. This can happen from disk failure, filesystem bugs, RAM errors, or incomplete writes during a crash. Do not panic — but act quickly.


---

## 2. Core Technical Concepts & Mechanisms

### Common Causes of Data Corruption
Data corruption has several causes. Disk hardware failure — bad sectors, dying SSD. RAM errors — a bit flip changes data in memory before it is written. Filesystem bugs — rare but real, especially with certain configurations. Power loss during write — incomplete 8K page write. Kernel or storage driver bugs. The first line of defense is data checksums — they detect corruption but do not fix it. The real fix comes from backups.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Disk failure** | Bad sectors, dying SSD, RAID controller failure. Most common cause. |
| **RAM errors** | Bit flips corrupt data in memory before writing to disk. Use ECC RAM. |
| **Power loss** | Incomplete 8K page write. PostgreSQL uses WAL to protect, but not if fsync fails. |
| **Filesystem bugs** | Rare. ext4 and XFS are well-tested. Avoid experimental filesystems. |
| **Storage driver bugs** | Virtualization layers, SAN firmware. Hard to diagnose. |
| **Data checksums** | Detect corruption on read. Enabled at initdb. Cannot be toggled later (PG 16). |

### Recovery Options (Best to Worst)
You have several recovery options depending on the severity. Option one: if only a few pages are corrupted, use zero_damaged_pages to skip them — you lose those rows but recover the rest. Option two: restore the table from a backup using pg_restore with the table option. Option three: point-in-time recovery — restore the entire database to a point before the corruption. Option four: if you have a standby, the standby might have clean copies of those pages.

- 1. Restore from standby — If standby has clean data: pg_dump the table from standby, restore to primary.
- 2. Restore table from backup — pg_restore -d myapp -t orders backup.dump. Replaces only the corrupted table.
- 3. Point-in-time recovery (PITR) — Restore entire cluster to timestamp before corruption. Loses all changes after that point.
- 4. zero_damaged_pages — Skip corrupted pages. Lose rows in those pages. Last resort — data loss is permanent.
- 5. pg_filedump (forensic) — Read raw page data. Extract surviving tuples from damaged pages. Expert-level recovery.

### Preventing Data Corruption
Prevention is critical because corruption recovery always means some data loss. Enable data checksums at initdb — always. Use ECC RAM to prevent bit flips. Monitor disk health with SMART tools. Never set fsync to off in production — ever. Test backups regularly by restoring them. And monitor for checksum failures in the logs. One detected corruption might mean more is coming.

- Enable data_checksums — initdb --data-checksums. Detects corruption on page read. Always enable.
- Use ECC RAM — Error-Correcting Code memory. Prevents bit flips. Required for production servers.
- Never disable fsync — fsync = off means data loss on crash. Only for disposable test databases.
- Monitor disk health — SMART monitoring: smartctl -a /dev/sda. Alert on reallocated sectors.
- Test backup restores — Monthly: restore backup to test server. Verify row counts. Automated if possible.
- Use full_page_writes = on — Default is on. Prevents torn page writes after crash. Never turn it off.

### Comparison
If these real-world troubleshooting scenarios are helping you prepare for production emergencies, please support the course. Your donation keeps this content free and available for everyone.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | Lock diagnostic queries |
| Every donation helps! | Corruption recovery runbook |

### PostgreSQL Lock Types
Understanding lock types helps you predict conflicts. ACCESS SHARE is taken by SELECT — it blocks nothing except ACCESS EXCLUSIVE. ROW EXCLUSIVE is taken by INSERT, UPDATE, DELETE — it blocks schema changes. SHARE lock is taken by CREATE INDEX — it blocks writes but allows reads. ACCESS EXCLUSIVE is taken by ALTER TABLE, DROP, VACUUM FULL — it blocks everything. The rule: the more exclusive the lock, the more it blocks.

| Term | Meaning / Explanation |
| :--- | :--- |
| **ACCESS SHARE** | Taken by: SELECT. Blocks: nothing except ACCESS EXCLUSIVE. |
| **ROW SHARE** | Taken by: SELECT FOR UPDATE/SHARE. Blocks: ACCESS EXCLUSIVE. |
| **ROW EXCLUSIVE** | Taken by: INSERT, UPDATE, DELETE. Blocks: SHARE, EXCLUSIVE locks. |
| **SHARE** | Taken by: CREATE INDEX (non-concurrent). Blocks: writes. Allows reads. |
| **ACCESS EXCLUSIVE** | Taken by: ALTER TABLE, DROP, VACUUM FULL. Blocks EVERYTHING. |

### Beginner Traps
Common traps. Never set zero_damaged_pages on permanently — it silently throws away data. Use it only for emergency reading, then restore from backup. Never run ALTER TABLE on busy tables without lock_timeout — it blocks the entire table. Never ignore deadlock errors — they indicate a code pattern problem that will keep recurring. And never skip enabling checksums — without them, corruption is silent and spreads.

- zero_damaged_pages left on — Silently discards corrupted data on every read. Use only for emergency diagnosis.
- DDL without lock_timeout — ALTER TABLE blocks the world. Always SET lock_timeout = '5s' before DDL.
- Ignoring deadlock errors — Deadlocks = code bug. Fix transaction ordering. They will recur until fixed.
- No data checksums — Without checksums, corruption is SILENT. You serve wrong data without knowing.
- Long transactions — BEGIN without COMMIT holds locks for hours. Set idle_in_transaction_session_timeout.

### Practice Exercises
Practice exercises. First, enable amcheck extension and verify indexes on a test table. Second, create two sessions that deadlock each other — update rows in opposite order. Watch PostgreSQL detect and resolve it. Third, write the blocking query diagnostic — join pg_stat_activity with pg_blocking_pids. Fourth, test the lock_timeout pattern — start a long transaction, then try ALTER TABLE with a 5-second lock_timeout. Fifth, practice the pg_cancel_backend and pg_terminate_backend workflow.

- Exercise 1 — CREATE EXTENSION amcheck. Run bt_index_check on each index. Verify all pass.
- Exercise 2 — Two psql sessions. Update rows in opposite order to trigger deadlock. Read the error.
- Exercise 3 — Write the blocking PID query. Join pg_stat_activity with pg_blocking_pids().
- Exercise 4 — Session 1: BEGIN; SELECT * FROM t FOR UPDATE. Session 2: SET lock_timeout='5s'; ALTER TABLE t...
- Exercise 5 — Find a long query with pg_stat_activity. Cancel it. Terminate if needed. Verify.


---

## 3. Hands-On Commands & psql Output

### Scenario 1: Data Corruption — Detection
**Explanation:** The scenario. Your application throws an error: could not read block 4523 of relation orders. Or you see a WARNING in the PostgreSQL log: page verification failed, calculated checksum does not match. Data corruption means the bytes on disk do not match what PostgreSQL expects. This can happen from disk failure, filesystem bugs, RAM errors, or incomplete writes during a crash. Do not panic — but act quickly.

```sql
-- Application error:
ERROR: invalid page in block 4523 of relation base/16384/24680
HINT: See server log for details.

-- PostgreSQL log:
WARNING: page verification failed, calculated checksum
  does not match expected value
ERROR: invalid page in block 4523 of relation
  base/16384/24680

-- Check if checksums are enabled:
myapp=> SHOW data_checksums;
 data_checksums
----------------
 on
```

### Assess the Damage
**Explanation:** First, figure out what is corrupted. Identify the table from the relation file number. Check if the corruption is in a single page or widespread. Try to read the table — see where it fails. Use the amcheck extension to verify index integrity. If only a few pages are corrupted, you might recover most data. If widespread, you need to restore from backup.

```sql
-- Identify the corrupted table from file number
myapp=> SELECT relname FROM pg_class WHERE relfilenode = 24680;
 relname
---------
 orders

-- Try reading the table to find all bad pages
myapp=> SET zero_damaged_pages = on;
myapp=> SELECT count(*) FROM orders;
WARNING: invalid page in block 4523, zeroing out page
WARNING: invalid page in block 4524, zeroing out page
  count
---------
 1999847   (expected 2000000 — ~153 rows lost)

-- Check index integrity
myapp=> CREATE EXTENSION IF NOT EXISTS amcheck;
myapp=> SELECT bt_index_check('orders_pkey');
 (OK — index is clean)
```

### Restore Corrupted Table from Backup
**Explanation:** The safest recovery is restoring the corrupted table from a recent backup. First, rename the corrupted table. Then restore just that table from your pg_dump backup. Verify the row count matches. If you use pgBackRest or Barman, they can restore individual files. After recovery, rebuild all indexes on the restored table and run ANALYZE.

```sql
-- Step 1: Rename corrupted table
myapp=> ALTER TABLE orders RENAME TO orders_corrupted;

-- Step 2: Restore from last night's backup
$ pg_restore -d myapp -t orders /backups/myapp_nightly.dump
pg_restore: creating TABLE "public.orders"
pg_restore: processing data for table "public.orders"

-- Step 3: Verify row count
myapp=> SELECT count(*) FROM orders;
 1998500   (backup was 2 hours old — some recent rows missing)

-- Step 4: Rebuild indexes and analyze
myapp=> REINDEX TABLE orders;
myapp=> ANALYZE orders;
-- Step 5: Drop corrupted table when verified
myapp=> DROP TABLE orders_corrupted;
```

### Scenario 2: Blocking Queries — Detection
**Explanation:** Second scenario. Users report that the application is hanging. Queries that normally take milliseconds are stuck. You check pg_stat_activity and find 50 sessions in the waiting state — all waiting for the same lock. One session has been running an ALTER TABLE for 20 minutes and it is blocking everyone. This is lock contention — one query holds a lock that prevents all other queries from proceeding.

```sql
-- Find waiting sessions
myapp=> SELECT count(*), wait_event_type, wait_event
FROM pg_stat_activity WHERE wait_event IS NOT NULL
GROUP BY wait_event_type, wait_event ORDER BY count DESC;
 count | wait_event_type |  wait_event
-------+-----------------+---------------
    50 | Lock            | relation
     3 | Lock            | transactionid
     2 | IO              | DataFileRead
```

### Find the Blocker
**Explanation:** The critical query is finding WHO is blocking WHOM. PostgreSQL 16 has the pg_blocking_pids function — it returns the PIDs that are blocking a given session. We can join this with pg_stat_activity to see the blocker's query, how long it has been running, and what lock it holds. Here we find PID 5678 running ALTER TABLE ADD COLUMN for 20 minutes, blocking 50 sessions.

```sql
-- Find who is blocking whom
myapp=> SELECT blocked.pid AS blocked_pid,
  blocked.query AS blocked_query,
  blocking.pid AS blocking_pid,
  blocking.query AS blocking_query,
  now() - blocking.query_start AS blocking_duration
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
  ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
LIMIT 5;

 blocked_pid | blocked_query          | blocking_pid | blocking_query                      | blocking_duration
-------------+------------------------+--------------+-------------------------------------+------------------
        7001 | SELECT * FROM orders.. |         5678 | ALTER TABLE orders ADD COLUMN ...   | 00:20:34
        7002 | INSERT INTO orders ... |         5678 | ALTER TABLE orders ADD COLUMN ...   | 00:20:34
        7003 | UPDATE orders SET ...  |         5678 | ALTER TABLE orders ADD COLUMN ...   | 00:20:34
```

### Fix — Cancel the Blocker
**Explanation:** You have two choices. If the ALTER TABLE is almost done, you might wait. But 20 minutes with 50 sessions blocked — you need to act. Cancel the blocking query with pg_cancel_backend. If cancel does not work within a few seconds, terminate it with pg_terminate_backend. Then schedule the ALTER TABLE for a maintenance window when traffic is low. Never run DDL on large tables during peak hours.

```sql
-- Try graceful cancel first
myapp=> SELECT pg_cancel_backend(5678);
 t

-- If cancel doesn't work after 5 seconds:
myapp=> SELECT pg_terminate_backend(5678);
 t

-- Verify blocked sessions are free
myapp=> SELECT count(*) FROM pg_stat_activity
WHERE wait_event_type = 'Lock';
 count
-------
     0   (all unblocked!)
```

### Safe DDL — lock_timeout Pattern
**Explanation:** The root cause was running ALTER TABLE during production hours. In PostgreSQL, ALTER TABLE ADD COLUMN needs an ACCESS EXCLUSIVE lock — it blocks every other operation on the table. The safe pattern: use lock_timeout so your DDL gives up quickly instead of blocking everyone. And for adding columns, add with a DEFAULT — in PostgreSQL 16, this is instant because the default is stored in the catalog, not written to every row.

```sql
-- Set lock_timeout so DDL gives up fast
myapp=> SET lock_timeout = '5s';

-- Now try the ALTER TABLE
myapp=> ALTER TABLE orders ADD COLUMN notes TEXT DEFAULT '';
ALTER TABLE   (instant! default stored in catalog, PG 11+)

-- If it can't get the lock within 5 seconds:
ERROR: canceling statement due to lock timeout
-- Good! It gave up instead of blocking 50 sessions.
-- Retry during low traffic, or use:
myapp=> CREATE INDEX CONCURRENTLY idx_orders_notes ON orders(notes);
CREATE INDEX   (no lock on reads/writes)
```

### Lock Monitoring & Prevention
**Explanation:** To prevent blocking incidents, set up lock monitoring. Use the pg_locks view to see all locks in the system. Set lock_timeout at the session or role level so no query can block others indefinitely. Set log_lock_waits to on so PostgreSQL logs when a session waits more than deadlock_timeout for a lock. And set statement_timeout as a safety net — no query should run for 20 minutes without investigation.

```sql
-- See all locks currently held
myapp=> SELECT locktype, relation::regclass, mode, granted, pid
FROM pg_locks WHERE relation IS NOT NULL ORDER BY relation;
 locktype | relation | mode                | granted | pid
----------+----------+---------------------+---------+-----
 relation | orders   | AccessShareLock     | t       | 7001
 relation | orders   | RowExclusiveLock    | t       | 7002

-- Prevention settings:
myapp=> ALTER SYSTEM SET log_lock_waits = on;
myapp=> ALTER SYSTEM SET lock_timeout = '30s';
myapp=> ALTER SYSTEM SET statement_timeout = '300s';
myapp=> SELECT pg_reload_conf();
```

### Deadlock Detection
**Explanation:** A deadlock is when two sessions block each other — session A waits for session B, and session B waits for session A. PostgreSQL detects deadlocks automatically and kills one session to break the cycle. The deadlock_timeout setting controls how long PostgreSQL waits before checking — default is 1 second. You see ERROR: deadlock detected in the logs. Fix deadlocks by ensuring all transactions access tables in the same order.

```sql
-- PostgreSQL detects deadlocks automatically:
ERROR: deadlock detected
DETAIL: Process 7001 waits for ShareLock on transaction 500;
  blocked by process 7002.
Process 7002 waits for ShareLock on transaction 499;
  blocked by process 7001.
HINT: See server log for query details.

-- Prevention: access tables in consistent order
-- BAD:  Tx1: UPDATE orders, UPDATE inventory
--       Tx2: UPDATE inventory, UPDATE orders
-- GOOD: Both: UPDATE inventory, UPDATE orders

myapp=> SHOW deadlock_timeout;
 1s   (checks for deadlock after 1 second of waiting)
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Common traps. Never set zero_damaged_pages on permanently — it silently throws away data. Use it only for emergency reading, then restore from backup. Never run ALTER TABLE on busy tables without lock_timeout — it blocks the entire table. Never ignore deadlock errors — they indicate a code pattern problem that will keep recurring. And never skip enabling checksums — without them, corruption is silent and spreads.

- zero_damaged_pages left on — Silently discards corrupted data on every read. Use only for emergency diagnosis.
- DDL without lock_timeout — ALTER TABLE blocks the world. Always SET lock_timeout = '5s' before DDL.
- Ignoring deadlock errors — Deadlocks = code bug. Fix transaction ordering. They will recur until fixed.
- No data checksums — Without checksums, corruption is SILENT. You serve wrong data without knowing.
- Long transactions — BEGIN without COMMIT holds locks for hours. Set idle_in_transaction_session_timeout.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Summary. Data corruption: enable checksums, use ECC RAM, test backups monthly. Recovery: standby restore first, then backup restore, PITR as last resort, zero_damaged_pages only for emergency reading. Blocking queries: use pg_blocking_pids to find the blocker, pg_cancel_backend to stop it, always use lock_timeout before DDL. Deadlocks are auto-detected — fix by consistent table access order. Monitor with log_lock_waits and statement_timeout.

- **Corruption: enable data_checksums, use ECC RAM, test backups monthly**
- **Recovery priority: standby → backup → PITR → zero_damaged_pages**
- **zero_damaged_pages: emergency only, never leave on permanently**
- **Blocking: pg_blocking_pids() finds the blocker PID**
- **Fix: pg_cancel_backend() → pg_terminate_backend() if needed**
- **Prevention: SET lock_timeout before DDL (ALTER TABLE blocks everything)**
- **Deadlocks: auto-detected, fix by consistent table access ordering**
- **Monitor: log_lock_waits = on, statement_timeout as safety net**


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
