# Scenario: Slow Query Diagnosis & Database Running Out of Disk Space
**Series:** PostgreSQL Mastery | **Phase:** 32 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we tackle two real-world production scenarios. First, how to diagnose and fix a slow query that is hurting your application. Second, how to handle a database that is running out of disk space. For each scenario, we follow a structured approach — diagnose the problem, fix it, and verify the fix worked.

### Production Scenarios:
Slow Query & Disk Space
Welcome to PostgreSQL Mastery. In this class, we tackle two real-world production scenarios. First, how to diagnose and fix a slow query that is hurting your application. Second, how to handle a database that is running out of disk space. For each scenario, we follow a structured approach — diagnose the problem, fix it, and verify the fix worked.

### Production Scenario Workflow
Every production scenario follows the same workflow. First, detect the problem — through monitoring alerts, user complaints, or application errors. Second, diagnose — find the root cause using PostgreSQL tools. Third, fix — apply the solution. Fourth, verify — confirm the fix resolved the problem. Fifth, prevent — add monitoring or configuration changes to prevent recurrence. We will follow this workflow for every scenario in this phase.

- 1. Detect — Alert fires, user reports slowness, application errors, dashboard shows anomaly.
- 2. Diagnose — Use pg_stat_activity, EXPLAIN ANALYZE, pg_stat_statements, logs. Find the root cause.
- 3. Fix — Apply the solution: add index, rewrite query, tune config, clear bloat, etc.
- 4. Verify — Re-run the query, check metrics, confirm user experience improved.
- 5. Prevent — Add monitoring, set alerts, document the fix, update runbooks.

### Scenario 1: Slow Query — Detection
The scenario: your application users report that the orders page is loading slowly — taking 8 seconds instead of the usual half second. Your monitoring shows database CPU spiking to 90 percent. The application logs show a specific query taking over 5 seconds. This is your starting point. Let us diagnose it.


---

## 2. Core Technical Concepts & Mechanisms

### Production Scenario Workflow
Every production scenario follows the same workflow. First, detect the problem — through monitoring alerts, user complaints, or application errors. Second, diagnose — find the root cause using PostgreSQL tools. Third, fix — apply the solution. Fourth, verify — confirm the fix resolved the problem. Fifth, prevent — add monitoring or configuration changes to prevent recurrence. We will follow this workflow for every scenario in this phase.

- 1. Detect — Alert fires, user reports slowness, application errors, dashboard shows anomaly.
- 2. Diagnose — Use pg_stat_activity, EXPLAIN ANALYZE, pg_stat_statements, logs. Find the root cause.
- 3. Fix — Apply the solution: add index, rewrite query, tune config, clear bloat, etc.
- 4. Verify — Re-run the query, check metrics, confirm user experience improved.
- 5. Prevent — Add monitoring, set alerts, document the fix, update runbooks.

### Root Cause Analysis
The EXPLAIN output tells us everything. Sequential scan on orders — scanning 2 million rows to find 3 matching rows. That is a full table scan. The Rows Removed by Filter line shows 1,999,997 rows were read and discarded. The Buffers line shows 45,123 blocks read from disk. The root cause is a missing index on the user_id and status columns. The users table join is fine — it uses the primary key index.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Symptom** | Query takes 5.2 seconds, CPU at 90% |
| **Seq Scan on orders** | Scanning all 2M rows — no index on user_id |
| **Rows Removed: 1,999,997** | Read 2M rows, kept only 3 — massive waste |
| **Buffers read: 45,123** | 45K blocks from disk — not cached, very expensive |
| **Root Cause** | Missing index on orders(user_id, status) |
| **Expected Fix** | Add composite index — query should drop to < 1 ms |

### Slow Query — Before vs After
The result is dramatic. Before the index — 5,234 milliseconds, sequential scan, 45 thousand disk reads. After the index — 0.09 milliseconds, index scan, 4 buffer hits from cache. That is a 58 thousand times improvement. CPU dropped from 90 percent back to normal. The orders page now loads in under half a second. This is the most common production scenario — a missing index causing a full table scan.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Execution Time** | Before: 5,234 ms → After: 0.09 ms (58,000x faster) |
| **Scan Type** | Before: Sequential Scan (full table) → After: Index Scan (direct lookup) |
| **Rows Scanned** | Before: 2,000,000 rows → After: 3 rows (exact match only) |
| **Disk Blocks Read** | Before: 45,123 blocks from disk → After: 0 (all from cache) |
| **Buffer Hits** | Before: 8,234 → After: 4 (minimal memory needed) |
| **CPU Impact** | Before: 90% CPU → After: Normal (barely registers) |

### Comparison
If these real-world scenarios are helping you handle production issues, please support the course. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All diagnostic queries included |
| Every donation helps! | Practice exercises included |

### Disk Space — Fix Strategy
The fix is a multi-step approach. First, run VACUUM on the orders table to reclaim 54 gigabytes of dead tuple space — this is the fastest win. Second, archive old audit_log records older than 90 days to a file, then delete them. Third, consider partitioning the orders table by month so old partitions can be dropped easily. Fourth, check for unused indexes — they waste space. Let us execute each step.

- Step 1: VACUUM orders — Reclaim 54 GB of dead tuples. Run VACUUM (not VACUUM FULL — it locks the table).
- Step 2: Archive audit_log — COPY old rows to file. DELETE rows older than 90 days. Reclaim ~80 GB.
- Step 3: Drop unused indexes — Find indexes with zero scans. DROP them. Reclaim 5-20 GB.
- Step 4: Tune autovacuum — Reduce autovacuum_vacuum_scale_factor for large tables. Prevent future bloat.
- Step 5: Plan partitioning — Partition orders by month. Drop old partitions instead of DELETE. Long-term fix.

### Beginner Traps
Watch out for these traps. Never use VACUUM FULL in production without a maintenance window — it locks the entire table for reads and writes. Use VACUUM instead, or pg_repack for online table compaction. Never delete millions of rows in a single transaction — batch it in chunks of 10 thousand. Never add indexes without CONCURRENTLY in production — regular CREATE INDEX blocks writes. And never ignore slow query logs — a slow query today becomes a production outage tomorrow.

- VACUUM FULL locks the table — Use VACUUM (no FULL) or pg_repack for online compaction. FULL blocks everything.
- Large DELETE = huge WAL — Deleting 1M rows generates massive WAL, holds locks. Batch in 10K chunks.
- CREATE INDEX blocks writes — Always use CREATE INDEX CONCURRENTLY in production. Takes longer but no locks.
- Ignoring slow query logs — A 2-second query called 1000x/min = production CPU meltdown. Fix early.
- Not testing PITR after cleanup — After major deletes, verify backup still works. Test a point-in-time restore.

### Practice Exercises
Here are your practice exercises. First, create a test table with 1 million rows. Run a query without an index and record the EXPLAIN ANALYZE output. Add an index and compare. Second, update 500 thousand rows to create bloat. Check dead tuple count. Run VACUUM and measure space reclaimed. Third, find the top 5 largest tables in your database. Fourth, find all unused indexes and calculate wasted space. Fifth, set per-table autovacuum settings on your largest table.

- Exercise 1 — Create 1M-row table. EXPLAIN ANALYZE without index. Add index. Compare times.
- Exercise 2 — UPDATE 500K rows. Check n_dead_tup. VACUUM. Check space before and after.
- Exercise 3 — Find top 5 largest tables by total size (data + indexes + toast).
- Exercise 4 — Find all unused indexes (idx_scan = 0). Calculate total wasted space.
- Exercise 5 — Set autovacuum_vacuum_scale_factor = 0.01 on your largest table. Monitor.


---

## 3. Hands-On Commands & psql Output

### Scenario 1: Slow Query — Detection
**Explanation:** The scenario: your application users report that the orders page is loading slowly — taking 8 seconds instead of the usual half second. Your monitoring shows database CPU spiking to 90 percent. The application logs show a specific query taking over 5 seconds. This is your starting point. Let us diagnose it.

```sql
-- Alert: CPU at 90%, response time > 5 seconds
-- Step 1: Find the slow query in pg_stat_activity
myapp=> SELECT pid, now() - query_start AS duration,
  state, left(query, 80) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '2 seconds'
ORDER BY duration DESC;

 pid  | duration | state  | query
------+----------+--------+------------------------------------------
 4521 | 00:00:07 | active | SELECT o.id, o.total, u.name FROM orders
 4533 | 00:00:06 | active | SELECT o.id, o.total, u.name FROM orders
 4547 | 00:00:05 | active | SELECT o.id, o.total, u.name FROM orders
```

### Slow Query — EXPLAIN ANALYZE
**Explanation:** Three copies of the same query are running simultaneously, each taking over 5 seconds. Let us run EXPLAIN ANALYZE to see what PostgreSQL is doing internally. The output shows a sequential scan on the orders table — 2 million rows scanned. Then a nested loop join to the users table. The total cost is extremely high. The problem is clear — no index on orders.user_id, so PostgreSQL scans the entire table for every request.

```sql
myapp=> EXPLAIN (ANALYZE, BUFFERS) SELECT o.id, o.total, u.name
FROM orders o JOIN users u ON o.user_id = u.id
WHERE o.user_id = 42 AND o.status = 'pending';

 Nested Loop (actual time=5234.12..5234.45 rows=3)
   -> Seq Scan on orders o (actual time=5233.89..5234.10 rows=3)
        Filter: (user_id = 42 AND status = 'pending')
        Rows Removed by Filter: 1999997
        Buffers: shared hit=8234 read=45123
   -> Index Scan on users_pkey (actual time=0.01..0.01 rows=1)
 Planning Time: 0.15 ms
 Execution Time: 5234.52 ms
```

### Fix — Create Index CONCURRENTLY
**Explanation:** The fix is to create a composite index on orders covering user_id and status. Use CREATE INDEX CONCURRENTLY to avoid locking the table during creation — this is critical in production because a regular CREATE INDEX locks the table for writes. The index takes a few minutes to build on 2 million rows. After creation, run EXPLAIN ANALYZE again to verify the fix.

```sql
-- Create index without locking the table
myapp=> CREATE INDEX CONCURRENTLY idx_orders_user_status
  ON orders (user_id, status);
CREATE INDEX
Time: 12456.789 ms (00:12.457)

-- Verify: run EXPLAIN ANALYZE again
myapp=> EXPLAIN (ANALYZE, BUFFERS) SELECT o.id, o.total, u.name
FROM orders o JOIN users u ON o.user_id = u.id
WHERE o.user_id = 42 AND o.status = 'pending';

 Nested Loop (actual time=0.05..0.08 rows=3)
   -> Index Scan using idx_orders_user_status on orders o
        (actual time=0.03..0.04 rows=3)
        Buffers: shared hit=4
   -> Index Scan on users_pkey (actual time=0.01..0.01 rows=1)
 Execution Time: 0.09 ms
```

### Prevention — Monitoring for Slow Queries
**Explanation:** To prevent this from happening again, enable pg_stat_statements to track all query performance. Set log_min_duration_statement to 1000 to log any query taking over 1 second. Review pg_stat_user_indexes regularly to find tables with high sequential scans but low index scans — those need indexes. Set up a weekly query review process.

```sql
-- Enable slow query logging
myapp=> ALTER SYSTEM SET log_min_duration_statement = 1000;
myapp=> SELECT pg_reload_conf();

-- Find tables needing indexes (high seq scan, low idx scan)
myapp=> SELECT schemaname, relname,
  seq_scan, idx_scan,
  CASE WHEN seq_scan + idx_scan > 0
    THEN round(100.0 * idx_scan / (seq_scan + idx_scan), 1)
  END AS idx_pct
FROM pg_stat_user_tables
WHERE seq_scan > 1000
ORDER BY seq_scan DESC LIMIT 10;

 schemaname | relname  | seq_scan | idx_scan | idx_pct
------------+---------+----------+----------+--------
 public     | orders  |   145230 |    52000 |  26.4
```

### pg_stat_statements — Find Slow Queries
**Explanation:** pg_stat_statements is your best friend for finding slow queries before users complain. It tracks every query — how many times it ran, total execution time, rows returned, and buffer usage. Query it to find the top queries by total time or by mean time. This query shows the slowest queries by mean execution time. Review this weekly and add indexes for the worst performers.

```sql
myapp=> SELECT left(query, 60) AS query,
  calls,
  round(total_exec_time::numeric, 1) AS total_ms,
  round(mean_exec_time::numeric, 1) AS mean_ms,
  rows
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = 'myapp')
ORDER BY mean_exec_time DESC LIMIT 5;

 query                                   | calls | total_ms   | mean_ms | rows
-----------------------------------------+-------+------------+---------+------
 SELECT o.id, o.total, u.name FROM order | 28410 | 148732010  | 5234.1  |    3
 SELECT count(*) FROM orders WHERE creat |  1200 |    960000  |  800.0  | 1200
 UPDATE inventory SET quantity = quantit |   890 |    267000  |  300.0  |  890
```

### Scenario 2: Disk Space — Detection
**Explanation:** The second scenario. Your monitoring alert fires — database disk usage is at 92 percent. The database has 500 gigabytes allocated and 460 gigabytes are used. At the current growth rate, you have about 3 days before the disk is full. When PostgreSQL runs out of disk, it stops accepting writes — your application goes down. This is urgent. Let us diagnose where the space is going.

```sql
-- ALERT: Disk usage at 92% (460 GB / 500 GB)
-- Estimated time to full: 3 days

-- Step 1: Check total database size
myapp=> SELECT pg_size_pretty(pg_database_size('myapp'));
 pg_size_pretty
----------------
 438 GB

-- Step 2: Check all database sizes
myapp=> SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database ORDER BY pg_database_size(datname) DESC;
 datname  | pg_size_pretty
----------+----------------
 myapp    | 438 GB
 postgres | 8 MB
 template1| 8 MB
```

### Diagnosis — Largest Tables
**Explanation:** The myapp database is 438 gigabytes. Let us find which tables are using the most space. This query shows each table's total size — data plus indexes plus toast. The orders table is the largest at 180 gigabytes. But look at the audit_log table — 120 gigabytes. That is a logging table that probably has old data we can archive. And the orders_archive table at 85 gigabytes might have data that can be moved to cold storage.

```sql
myapp=> SELECT schemaname || '.' || tablename AS table_name,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS data,
  pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) AS indexes
FROM pg_tables WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 5;

 table_name           | total  | data   | indexes
----------------------+--------+--------+--------
 public.orders        | 180 GB | 120 GB | 60 GB
 public.audit_log     | 120 GB | 100 GB | 20 GB
 public.orders_archive|  85 GB |  70 GB | 15 GB
 public.products      |  30 GB |  20 GB | 10 GB
 public.users         |  15 GB |  10 GB |  5 GB
```

### Check Table Bloat
**Explanation:** Before deleting data, check for table bloat. Bloat happens when dead rows from UPDATE and DELETE operations are not reclaimed by VACUUM. The dead tuple ratio shows what percentage of each table is wasted space. If the orders table has 30 percent dead tuples, that is 54 gigabytes of wasted space that VACUUM can reclaim. High bloat means autovacuum is falling behind.

```sql
myapp=> SELECT schemaname, relname,
  n_live_tup, n_dead_tup,
  CASE WHEN n_live_tup > 0
    THEN round(100.0 * n_dead_tup / (n_live_tup + n_dead_tup), 1)
  END AS dead_pct,
  last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 5;

 schemaname | relname    | n_live_tup | n_dead_tup | dead_pct | last_autovacuum
------------+-----------+------------+------------+----------+-----------------
 public     | orders    |   2000000  |    850000  |   29.8   | 3 days ago
 public     | audit_log |   5000000  |    200000  |    3.8   | 1 day ago
 public     | products  |    500000  |     50000  |    9.1   | 2 days ago
```

### Execute Disk Space Fixes
**Explanation:** Execute the fixes in order. VACUUM the orders table first — this reclaims dead tuple space without locking. Then archive and delete old audit_log data. The COPY command exports old records to a compressed file. Then delete those records in batches — never delete millions of rows in one transaction, it will lock the table and generate massive WAL. Use batched deletes of 10,000 rows at a time.

```sql
-- Step 1: VACUUM orders (reclaim dead tuples)
myapp=> VACUUM VERBOSE orders;
INFO: vacuuming "public.orders"
INFO: table "orders": removed 850000 dead row versions
VACUUM

-- Step 2: Archive old audit_log to file
myapp=> \COPY (SELECT * FROM audit_log WHERE created_at < now() - interval '90 days') TO '/tmp/audit_archive.csv' CSV HEADER;

-- Step 3: Batched delete (10K rows at a time)
myapp=> DELETE FROM audit_log WHERE ctid IN (
  SELECT ctid FROM audit_log
  WHERE created_at < now() - interval '90 days'
  LIMIT 10000);
DELETE 10000
-- Repeat until 0 rows deleted, then VACUUM audit_log
```

### Find and Drop Unused Indexes
**Explanation:** Unused indexes waste disk space and slow down writes — every INSERT and UPDATE must maintain every index. Find indexes with zero scans since the last statistics reset. If an index has never been used and the table has had thousands of scans, that index is dead weight. Drop it. But always verify with your team first — some indexes may be used by nightly batch jobs that run infrequently.

```sql
myapp=> SELECT schemaname, relname, indexrelname,
  idx_scan,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND pg_relation_size(indexrelid) > 1048576
ORDER BY pg_relation_size(indexrelid) DESC;

 schemaname | relname  | indexrelname         | idx_scan | size
------------+---------+----------------------+----------+------
 public     | orders  | idx_orders_old_status|        0 | 8 GB
 public     | audit_log| idx_audit_source     |        0 | 5 GB

-- Drop unused index (verify with team first!)
myapp=> DROP INDEX CONCURRENTLY idx_orders_old_status;
DROP INDEX
```

### Tune Autovacuum Per Table
**Explanation:** To prevent future bloat on large tables, tune autovacuum per table. The default autovacuum_vacuum_scale_factor is 0.2 — meaning autovacuum triggers when 20 percent of rows are dead. On a 2-million-row table, that is 400 thousand dead rows before cleanup. Set it lower — 0.01 or 0.05 — for large, frequently updated tables. This keeps bloat under control.

```sql
-- Set aggressive autovacuum for orders table
myapp=> ALTER TABLE orders SET (
  autovacuum_vacuum_scale_factor = 0.01,
  autovacuum_vacuum_threshold = 1000,
  autovacuum_analyze_scale_factor = 0.005
);
ALTER TABLE

-- Verify settings
myapp=> SELECT relname, reloptions
FROM pg_class WHERE relname = 'orders';
 relname | reloptions
---------+--------------------------------------------
 orders  | {autovacuum_vacuum_scale_factor=0.01,
         |  autovacuum_vacuum_threshold=1000,
         |  autovacuum_analyze_scale_factor=0.005}
```

### Verify Space Reclaimed
**Explanation:** After all fixes, verify the space reclaimed. Check the database size again — it should be significantly smaller. Set up monitoring alerts at 70 percent and 85 percent disk usage so you catch the next occurrence early. Add a weekly job to check for bloat and unused indexes. Document the archive procedure so anyone on the team can execute it.

```sql
myapp=> SELECT pg_size_pretty(pg_database_size('myapp'));
 pg_size_pretty
----------------
 295 GB

-- Space reclaimed: 438 GB -> 295 GB = 143 GB freed!
-- Disk usage: 295/500 = 59% (was 92%)

-- Set up monitoring alerts:
-- 70% disk → Warning alert
-- 85% disk → Critical alert
-- Bloat > 20% → Warning alert
-- Autovacuum not running > 3 days → Warning alert
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these traps. Never use VACUUM FULL in production without a maintenance window — it locks the entire table for reads and writes. Use VACUUM instead, or pg_repack for online table compaction. Never delete millions of rows in a single transaction — batch it in chunks of 10 thousand. Never add indexes without CONCURRENTLY in production — regular CREATE INDEX blocks writes. And never ignore slow query logs — a slow query today becomes a production outage tomorrow.

- VACUUM FULL locks the table — Use VACUUM (no FULL) or pg_repack for online compaction. FULL blocks everything.
- Large DELETE = huge WAL — Deleting 1M rows generates massive WAL, holds locks. Batch in 10K chunks.
- CREATE INDEX blocks writes — Always use CREATE INDEX CONCURRENTLY in production. Takes longer but no locks.
- Ignoring slow query logs — A 2-second query called 1000x/min = production CPU meltdown. Fix early.
- Not testing PITR after cleanup — After major deletes, verify backup still works. Test a point-in-time restore.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. For slow queries — use pg_stat_activity to find them, EXPLAIN ANALYZE to diagnose, CREATE INDEX CONCURRENTLY to fix, and pg_stat_statements to prevent. For disk space — check table sizes to find the biggest, check bloat with dead tuple counts, VACUUM to reclaim dead space, archive and delete old data in batches, drop unused indexes, and tune autovacuum per table. Always follow the workflow — detect, diagnose, fix, verify, prevent.

- **Slow query: pg_stat_activity → EXPLAIN ANALYZE → CREATE INDEX CONCURRENTLY**
- **pg_stat_statements: find slow queries before users complain**
- **Always CREATE INDEX CONCURRENTLY in production (no table locks)**
- **Disk space: check table sizes, dead tuples, unused indexes**
- **VACUUM reclaims dead space (never VACUUM FULL in production)**
- **Delete in batches (10K rows) — never millions in one transaction**
- **Tune autovacuum per table for large, frequently updated tables**
- **Workflow: Detect → Diagnose → Fix → Verify → Prevent**


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
