# WAL & Checkpoints — Crash Safety & Recovery
**Series:** PostgreSQL Mastery | **Phase:** Phase 9: Architecture | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we take a deep look at Write-Ahead Logging and Checkpoints — the mechanisms that guarantee your data survives a crash. You will understand WHY PostgreSQL writes to WAL before data files, how checkpoints work, what settings control them, and how to monitor WAL for production health. Let us begin.

### The Problem WAL Solves
From the previous class, you know that MVCC creates multiple tuple versions and that queries go through Parse, Plan, Execute. You also know that data pages live in shared_buffers in RAM and in files on disk. The problem: if PostgreSQL modifies a page in shared_buffers and the server crashes BEFORE that page is written to disk, the change is lost. WAL solves this by recording every change FIRST in a sequential log file. On crash recovery, PostgreSQL replays the WAL to reconstruct any lost changes.

- Data pages are modified in shared_buffers (RAM)
- Modified pages = 'dirty pages' (RAM ≠ disk)
- If server crashes before dirty pages hit disk → data lost!
- WAL rule: log the change BEFORE modifying the data page
- Crash recovery: replay WAL to reconstruct lost changes
- Result: committed transactions ALWAYS survive a crash


---

## 2. Core Technical Concepts & Mechanisms

### The Problem WAL Solves
From the previous class, you know that MVCC creates multiple tuple versions and that queries go through Parse, Plan, Execute. You also know that data pages live in shared_buffers in RAM and in files on disk. The problem: if PostgreSQL modifies a page in shared_buffers and the server crashes BEFORE that page is written to disk, the change is lost. WAL solves this by recording every change FIRST in a sequential log file. On crash recovery, PostgreSQL replays the WAL to reconstruct any lost changes.

- Data pages are modified in shared_buffers (RAM)
- Modified pages = 'dirty pages' (RAM ≠ disk)
- If server crashes before dirty pages hit disk → data lost!
- WAL rule: log the change BEFORE modifying the data page
- Crash recovery: replay WAL to reconstruct lost changes
- Result: committed transactions ALWAYS survive a crash

### Write Path: WAL Before Data
Here is how a write operation works step by step. When you run an INSERT or UPDATE: first, PostgreSQL writes the change to the WAL buffer in shared memory. Second, when the transaction commits, the WAL buffer is flushed to a WAL file on disk — this is the fsync that guarantees durability. Third, at some later time, the background writer or checkpointer writes the actual dirty data page to the data file. The key insight: the data file update can happen LATER because the WAL already has the change recorded.

```
[1. Write to
WAL Buffer]
[2. COMMIT →
Flush WAL to Disk]
[3. Modify Page
in shared_buffers]
[4. Later: Write
Dirty Page to Disk]
[pg_wal/ files
(sequential, fast)]
[base/ data files
(random I/O, slower)]
```

### Checkpoints — Syncing RAM to Disk
A checkpoint is when PostgreSQL flushes ALL dirty pages from shared_buffers to disk. After a checkpoint, the data files are fully up to date — no WAL replay needed for anything before the checkpoint. This means WAL files older than the last checkpoint can be recycled. Checkpoints happen automatically based on two triggers: time — checkpoint_timeout defaults to five minutes — and WAL volume — when total WAL written since last checkpoint reaches max_wal_size, which defaults to one gigabyte.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | Flush ALL dirty pages from shared_buffers to data files |
| **When (time)** | Every checkpoint_timeout (default: 5 min) |
| **When (WAL)** | When WAL written > max_wal_size (default: 1 GB) |
| **After** | Data files fully up to date, old WAL can be recycled |
| **Cost** | Heavy I/O burst — spread with checkpoint_completion_target |

**Notes:**
- checkpoint_completion_target = 0.9 means spread I/O over 90% of interval

### Crash Recovery Process
Crash recovery is straightforward. When PostgreSQL starts after a crash, it finds the last checkpoint record in pg_control. Then it replays all WAL records AFTER that checkpoint, re-applying changes to data pages. This brings the database to a consistent state — all committed transactions are recovered, all uncommitted transactions are rolled back. The more WAL since the last checkpoint, the longer recovery takes.

- 1. Server starts after crash
- 2. Reads pg_control to find last checkpoint location
- 3. Opens WAL files starting from that checkpoint
- 4. Replays each WAL record: re-applies changes to data pages
- 5. Committed transactions → recovered (changes restored)
- 6. Uncommitted transactions → rolled back (changes undone)
- 7. Database is now consistent — ready to accept connections

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### WAL Levels
wal_level controls how much information PostgreSQL writes to WAL. There are three levels. Minimal writes the least — enough for crash recovery but NOT enough for replication. Replica — the default — writes enough for both crash recovery AND streaming replication. Logical writes everything needed for logical replication, which allows selective table-level replication. Most production servers use replica or logical.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | wal_level controls how much information PostgreSQL writes to WAL |
| **Point 2** | There are three levels |
| **Minimal writes the least** | enough for crash recovery but NOT enough for replication |
| **Replica** | the default — writes enough for both crash recovery AND streaming replication |
| **Point 5** | Logical writes everything needed for logical replication, which allows selective table-level replication |
| **Point 6** | Most production servers use replica or logical |

### WAL & Checkpoint Tuning Guide
Here are the production recommendations for WAL and checkpoint settings. The defaults are conservative — they work for small servers but need tuning for real workloads. The most common change is increasing max_wal_size if you see frequent WAL-triggered checkpoints. And if you use replication, make sure wal_level is set to replica or logical.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Here** | the production recommendations for WAL and checkpoint settings |
| **The defaults** | conservative — they work for small servers but need tuning for real workloads |
| **The most common change** | increasing max_wal_size if you see frequent WAL-triggered checkpoints |
| **And if you** | replication, make sure wal_level is set to replica or logical |

### synchronous_commit: Safety vs Speed
synchronous_commit is a critical setting. When ON — the default — COMMIT waits until WAL is flushed to disk. This guarantees zero data loss. When OFF, COMMIT returns immediately without waiting for the disk flush. This is faster but you can lose the last few hundred milliseconds of transactions in a crash. For most applications, keep it ON. Only turn it off for data you can afford to lose — like session logs or analytics events.

| ON (Default — Safe) | OFF (Faster — Risky) |
| :--- | :--- |
| COMMIT waits for WAL disk flush | COMMIT returns before WAL flush |
| Zero data loss on crash | Can lose last ~200ms of commits on crash |
| Slightly slower commits | Faster commit throughput |
| Use for: financial data, orders, user data | Use for: logs, analytics, session data |

### Practice Exercises
Practice exercises: check your WAL settings, monitor checkpoint frequency, compare timed versus requested checkpoints, force a manual checkpoint, and check the background writer stats. These monitoring queries are essential for production PostgreSQL.

- 1. SHOW wal_level, max_wal_size, checkpoint_timeout
- 2. Check WAL size: SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir()
- 3. Compare checkpoints: checkpoints_timed vs checkpoints_req
- 4. CHECKPOINT; — force manual checkpoint
- 5. Check pg_stat_bgwriter for buffers_checkpoint vs buffers_backend
- 6. SHOW synchronous_commit; — verify your durability setting
- 7. List WAL files: SELECT * FROM pg_ls_waldir() ORDER BY modification DESC


---

## 3. Hands-On Commands & psql Output

### WAL Files and Settings
**Explanation:** WAL files live in the pg_wal directory. Each file is sixteen megabytes by default. PostgreSQL writes to them sequentially — this is important because sequential writes are MUCH faster than random writes. As the server runs, new WAL files are created. Old WAL files that are no longer needed get recycled — renamed and reused. Never delete WAL files manually — PostgreSQL manages them automatically.

```sql
-- List WAL files
practice=# SELECT name, pg_size_pretty(size) AS size, modification
FROM pg_ls_waldir() ORDER BY modification DESC LIMIT 5;
           name           |  size  |      modification
--------------------------+--------+-----------------------
 000000010000000000000003 | 16 MB  | 2024-01-15 10:30:45
 000000010000000000000002 | 16 MB  | 2024-01-15 10:15:22
 000000010000000000000001 | 16 MB  | 2024-01-15 09:45:10

-- Total WAL size on disk
practice=# SELECT pg_size_pretty(sum(size)) AS total_wal FROM pg_ls_waldir();
 total_wal
-----------
 48 MB

-- Key WAL settings
practice=# SHOW wal_level;              -- replica (default)
practice=# SHOW max_wal_size;           -- 1GB (checkpoint trigger)
practice=# SHOW min_wal_size;           -- 80MB (minimum kept)
practice=# SHOW wal_segment_size;       -- 16MB (per file)
```

### Monitor Checkpoint Activity
**Explanation:** You can check the last checkpoint status and monitor checkpoint frequency. If checkpoints happen too often, it means max_wal_size is too small for your write workload and you are doing unnecessary I/O. If they happen too rarely, recovery after a crash takes longer because there is more WAL to replay. The logs show warnings when checkpoints are triggered by WAL size rather than the timer — that is your signal to increase max_wal_size.

```sql
-- Checkpoint settings
practice=# SHOW checkpoint_timeout;
 checkpoint_timeout
--------------------
 5min

practice=# SHOW checkpoint_completion_target;
 checkpoint_completion_target
------------------------------
 0.9

-- Checkpoint statistics
practice=# SELECT checkpoints_timed, checkpoints_req,
  checkpoint_write_time, checkpoint_sync_time
FROM pg_stat_bgwriter;
 checkpoints_timed | checkpoints_req | write_time | sync_time
-------------------+-----------------+------------+-----------
               124 |               3 |     456789 |      1234

-- checkpoints_timed: triggered by timeout (normal)
-- checkpoints_req: triggered by WAL size (increase max_wal_size!)
```

### Manual Checkpoint and Control File
**Explanation:** You can also trigger a manual checkpoint and see the control file information. pg_controldata shows the last checkpoint location, timeline, and WAL position. This is useful for debugging recovery issues. The CHECKPOINT command forces an immediate checkpoint — useful before a planned shutdown or backup.

```sql
-- Force a checkpoint now
practice=# CHECKPOINT;
CHECKPOINT

-- Check current WAL position
practice=# SELECT pg_current_wal_lsn() AS current_wal;
 current_wal
-------------
 0/3A2B4C8

-- Background writer / checkpoint stats
practice=# SELECT
  checkpoints_timed,    -- scheduled checkpoints
  checkpoints_req,      -- WAL-triggered (want this low!)
  buffers_checkpoint,   -- pages written by checkpointer
  buffers_backend       -- pages written by backends (bad!)
FROM pg_stat_bgwriter;

-- buffers_backend > 0 means backends writing dirty pages
-- This is slow! Increase shared_buffers or bgwriter settings
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. WAL guarantees crash safety — every change is logged before data files are modified. WAL files are sequential sixteen-megabyte files in pg_wal. Checkpoints flush dirty pages to disk, letting old WAL be recycled. Crash recovery replays WAL from the last checkpoint. wal_level controls what WAL records — use replica or logical for replication. synchronous_commit ON means zero data loss; OFF trades safety for speed. Monitor checkpoints_req — if it is high, increase max_wal_size. This completes our Architecture phase! In the next phase, we move to Advanced SQL — UNION, window functions, and more. See you there!

- **WAL rule: log change BEFORE modifying data page**
- **pg_wal/ holds 16 MB WAL files (sequential writes = fast)**
- **Checkpoints flush dirty pages, allow WAL recycling**
- **Crash recovery: replay WAL from last checkpoint**
- **wal_level: minimal, replica (default), logical**
- **max_wal_size: increase if checkpoints_req is high**
- **synchronous_commit ON = zero data loss (default)**
- **Monitor: pg_stat_bgwriter, pg_ls_waldir()**


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


---

## 8. Practice Exercises & Verified Answer Key

### Exercise 1: Inspect WAL & Checkpoint Parameters
```sql
SHOW wal_level;
SHOW max_wal_size;
SHOW min_wal_size;
SHOW checkpoint_timeout;
SHOW checkpoint_completion_target;
```
*Explanation:* `wal_level` controls amount of WAL logging (minimal, replica, logical). `max_wal_size` triggers checkpoints if WAL volume exceeds this limit. `checkpoint_completion_target = 0.9` smooths disk I/O over 90% of the checkpoint duration.

### Exercise 2: Monitor Timed vs Requested Checkpoints (PG 16)
```sql
SELECT num_timed,
       num_requested,
       checkpoint_write_time,
       checkpoint_sync_time,
       buffers_written
FROM pg_stat_checkpointer;
```
*Explanation:* If `num_requested` is high, checkpoints are being triggered by WAL volume spikes rather than time, indicating that `max_wal_size` needs to be increased.

### Exercise 3: Audit Physical WAL Segments
```sql
SELECT count(*) AS segment_count,
       pg_size_pretty(sum(size)) AS total_wal_size
FROM pg_ls_waldir();
```
*Explanation:* Measures active WAL segment files on disk in `$PGDATA/pg_wal`.

### Exercise 4: Force Manual Checkpoint
```sql
CHECKPOINT;
```
*Explanation:* Forces an immediate checkpoint, flushing all modified (dirty) pages from `shared_buffers` to permanent disk storage and updating `pg_control`.

### Exercise 5: Synchronous Commit Trade-Off
```sql
SET synchronous_commit = 'off';
-- bulk data loading operations
SET synchronous_commit = 'on';
```
*Explanation:* With `synchronous_commit = off`, transactions return success immediately to the client without waiting for an `fsync` of the WAL buffer. Up to a few hundred milliseconds of committed data could be lost on power failure, but the database itself never suffers corruption.
