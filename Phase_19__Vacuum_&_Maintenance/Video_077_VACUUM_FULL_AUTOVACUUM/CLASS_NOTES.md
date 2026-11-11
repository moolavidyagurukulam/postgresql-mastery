# VACUUM FULL & AUTOVACUUM
**Series:** PostgreSQL Mastery | **Phase:** Phase 19: Vacuum & Maintenance | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we learned that VACUUM cleans dead tuples but does not shrink the table on disk. Today we cover the two missing pieces. First, VACUUM FULL — which actually rewrites the table and returns disk space to the operating system, but at a cost. Second, AUTOVACUUM — the background process that runs VACUUM automatically so you do not have to do it manually. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand what VACUUM does — it marks dead tuple space as reusable without shrinking the file. Recap: we created a bloated table, ran VACUUM, dead tuples went to zero, but the file stayed the same size on disk. Now the question is: what if you really need that disk space back?

- Prerequisite: Dead tuples and VACUUM (previous class)
- Recap: VACUUM marks space reusable but does NOT shrink the file
- Problem: What if you need the disk space BACK?
- Problem: What if you want VACUUM to run AUTOMATICALLY?
- This class: VACUUM FULL + AUTOVACUUM

### VACUUM vs VACUUM FULL
VACUUM FULL is completely different from regular VACUUM. Instead of marking dead space as reusable, it creates a brand new copy of the table, copies only the live tuples into it, then swaps the new file for the old one. This actually reclaims disk space. But here is the critical tradeoff — VACUUM FULL takes an ACCESS EXCLUSIVE lock on the table. That means nobody can read from or write to the table while VACUUM FULL is running. For a large table, this could take hours.

| Regular VACUUM | VACUUM FULL |
| :--- | :--- |
| Marks dead space as reusable | Rewrites entire table to new file |
| Table file size UNCHANGED | Table file SHRINKS to actual data size |
| NO lock — reads/writes continue | ACCESS EXCLUSIVE LOCK — blocks everything! |
| Fast — just scans and marks | Slow — copies all live tuples |
| Safe to run in production anytime | Needs extra disk space for the copy |
| Run frequently (or let autovacuum) | Use only when disk space is critical |

### VACUUM FULL — The Hidden Costs
That is dramatic — from 9.7 megabytes down to 2.4 megabytes. But remember the cost: while VACUUM FULL was running, no other session could read or write to that table. For a 100-gigabyte table, VACUUM FULL could take hours, and your application would be completely blocked. Also notice: VACUUM FULL needs enough free disk space to hold the entire new copy of the table while it is being built.

- 1. ACCESS EXCLUSIVE LOCK — blocks ALL queries during the rewrite
- 2. Needs extra disk space — builds a complete copy before swapping
- 3. Rewrites ALL indexes — they are rebuilt from scratch too
- 4. Updates all OIDs — relfilenode changes (matters for monitoring)
- 5. Time: proportional to table size, not bloat amount
- 6. 100 GB table = hours of complete downtime for that table
- 7. Alternative: pg_repack (online, no lock — covered in a later class)

### AUTOVACUUM — Automatic Cleanup
Now let us talk about AUTOVACUUM — the most important maintenance feature in PostgreSQL. AUTOVACUUM is a background process that automatically runs VACUUM on tables that need it. It monitors every table, tracks how many dead tuples have accumulated, and kicks in when a threshold is reached. In almost all PostgreSQL installations, AUTOVACUUM should be ON. Turning it off is one of the biggest mistakes a DBA can make.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | Background daemon that runs VACUUM and ANALYZE automatically |
| **When** | Triggers when dead tuples exceed a calculated threshold per table |
| **Default** | ENABLED by default — and it should stay that way |
| **Workers** | autovacuum_max_workers (default 3) — parallel table processing |

**Notes:**
- NEVER turn off autovacuum in production
- Turning it off leads to bloat, slowdowns, and transaction ID wraparound

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description. If you want to support this free course, the donation link is also in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Transaction ID Wraparound — Why AUTOVACUUM Is Mandatory
One critical topic: transaction ID wraparound prevention. PostgreSQL uses 32-bit transaction IDs, which means there are about 4 billion possible IDs. If you never vacuum, eventually the transaction counter wraps around, and PostgreSQL has to shut down to prevent data corruption. AUTOVACUUM has a special aggressive mode that kicks in when a table's oldest unfrozen transaction ID approaches the danger zone. This is why turning off autovacuum can literally crash your database.

- 1. PostgreSQL uses 32-bit transaction IDs (xid) — about 4 billion total
- 2. Each INSERT/UPDATE/DELETE consumes a transaction ID
- 3. Old tuples have old xids — VACUUM FREEZE marks them as 'frozen'
- 4. Frozen tuples are visible to ALL future transactions (no xid needed)
- 5. If unfrozen tuples get too old (2 billion xids behind)...
- 6. PostgreSQL SHUTS DOWN to prevent data corruption!
- 7. autovacuum_freeze_max_age = 200,000,000 (aggressive vacuum trigger)
- 8. This is the #1 reason to NEVER disable autovacuum

### Beginner Trap: Making AUTOVACUUM Too Gentle
Here is a common beginner trap with AUTOVACUUM. You see AUTOVACUUM running and consuming resources, so you lower the cost limit or increase the cost delay to make it gentler. The result? AUTOVACUUM becomes so slow it can never keep up with the rate of dead tuple creation. Bloat keeps growing, performance drops, and eventually you hit transaction ID wraparound. The fix is not to slow down autovacuum — it is to tune it properly for your workload and give it enough resources to finish.

| The Mistake | The Fix |
| :--- | :--- |
| AUTOVACUUM uses too much I/O! | Default cost_delay = 2ms is usually fine |
| Set cost_delay = 50ms (very slow) | Increase cost_limit if vacuum is too slow |
| Set cost_limit = 50 (very low) | More workers for many tables |
| AUTOVACUUM can never finish... | Lower scale_factor for large tables |
| Bloat grows unchecked | Monitor: is autovacuum keeping up? |
| Transaction ID wraparound risk! | Check n_dead_tup trend over time |


---

## 3. Hands-On Commands & psql Output

### VACUUM FULL — Demo
**Explanation:** Let us see VACUUM FULL in action. We will create a bloated table, check its size, then run VACUUM FULL and watch the file shrink.

```sql
postgres=# -- Create and bloat a table
postgres=# CREATE TABLE full_test (
    id SERIAL PRIMARY KEY,
    data TEXT
);
postgres=# INSERT INTO full_test (data)
postgres=# SELECT 'Row ' || g FROM generate_series(1, 50000) AS g;
postgres=# -- Update all rows 3 times to create massive bloat
postgres=# UPDATE full_test SET data = 'V2: ' || id;
postgres=# UPDATE full_test SET data = 'V3: ' || id;
postgres=# UPDATE full_test SET data = 'V4: ' || id;
postgres=# -- Check size BEFORE
postgres=# SELECT pg_size_pretty(pg_relation_size('full_test')) AS before_size;
 before_size
postgres=# -------------
 9728 kB
```

### Regular VACUUM vs VACUUM FULL — Size Comparison
**Explanation:** The table is 9.7 megabytes but only has 50,000 live rows. Let us first try regular VACUUM, then VACUUM FULL, and compare.

```sql
postgres=# -- Regular VACUUM first
postgres=# VACUUM full_test;
postgres=# SELECT pg_size_pretty(pg_relation_size('full_test')) AS after_vacuum;
 after_vacuum
postgres=# --------------
 9728 kB
postgres=# -- Still 9728 kB! Regular VACUUM does not shrink.
postgres=# -- Now VACUUM FULL
postgres=# VACUUM FULL full_test;
postgres=# SELECT pg_size_pretty(pg_relation_size('full_test')) AS after_full;
 after_full
postgres=# ------------
 2432 kB
postgres=# -- Dropped from 9728 kB to 2432 kB!
postgres=# -- VACUUM FULL reclaimed 7296 kB of disk space
```

### AUTOVACUUM Trigger Formula
**Explanation:** How does AUTOVACUUM decide when to vacuum a table? It uses a formula. The threshold equals autovacuum_vacuum_threshold plus autovacuum_vacuum_scale_factor multiplied by the number of live tuples. By default, the threshold is 50 plus 20 percent of the table rows. So for a 10,000-row table, AUTOVACUUM kicks in after 2,050 dead tuples accumulate. For a 1-million-row table, it waits until 200,050 dead tuples — that is a lot of bloat before cleanup!

```sql
-- Formula: when to VACUUM a table
-- dead_tuples > threshold + scale_factor * n_live_tup

-- Default values:
SHOW autovacuum_vacuum_threshold;     -- 50
SHOW autovacuum_vacuum_scale_factor;   -- 0.2 (20%)

-- Examples:
-- 1,000-row table:   50 + 0.2 * 1,000  =    250 dead tuples
-- 10,000-row table:  50 + 0.2 * 10,000 =  2,050 dead tuples
-- 1M-row table:      50 + 0.2 * 1M     = 200,050 dead tuples!
-- 100M-row table:    50 + 0.2 * 100M   = 20,000,050 dead tuples!!!

-- The scale_factor is TOO HIGH for large tables!
-- You must tune it per-table for big tables.
```

### Tuning AUTOVACUUM Per-Table
**Explanation:** For large tables, the default 20 percent scale factor is way too aggressive — it lets millions of dead tuples pile up before cleanup. The fix is to set per-table autovacuum settings with lower scale factors. For a table with millions of rows, set the scale factor to 1 or 2 percent, or even use a fixed threshold with a scale factor of zero.

```sql
postgres=# -- Reduce scale factor for a large table
postgres=# ALTER TABLE orders SET (
    autovacuum_vacuum_scale_factor = 0.02,
    autovacuum_vacuum_threshold = 1000
);
postgres=# -- Now: vacuum after 1000 + 2% of live tuples
postgres=# -- 1M rows: triggers at 21,000 dead tuples (vs 200,050 default)
postgres=# -- For very large tables, use fixed threshold only
postgres=# ALTER TABLE audit_log SET (
    autovacuum_vacuum_scale_factor = 0,
    autovacuum_vacuum_threshold = 10000
);
postgres=# -- Always vacuum after 10,000 dead tuples regardless of table size
postgres=# -- Check current per-table settings
postgres=# SELECT relname, reloptions
postgres-# FROM pg_class
postgres-# WHERE reloptions IS NOT NULL
postgres-# AND relkind = 'r';
 relname   |                     reloptions
postgres=# -----------+----------------------------------------------------
 orders    | {autovacuum_vacuum_scale_factor=0.02,
           |  autovacuum_vacuum_threshold=1000}
```

### Monitoring AUTOVACUUM Activity
**Explanation:** How do you check if AUTOVACUUM is actually running and keeping up? Query pg_stat_user_tables — it shows the last time each table was vacuumed, both manually and by autovacuum. If last_autovacuum is NULL or very old, AUTOVACUUM may not be running or may be overwhelmed.

```sql
postgres=# -- Check autovacuum activity per table
postgres=# SELECT relname,
       n_dead_tup,
       last_vacuum,
       last_autovacuum,
       autovacuum_count,
       vacuum_count
postgres-# FROM pg_stat_user_tables
postgres-# ORDER BY n_dead_tup DESC;
 relname     | n_dead_tup | last_vacuum | last_autovacuum     | autovacuum_count
postgres=# -------------+------------+-------------+---------------------+-----------------
 orders      |       1205 | NULL        | 2026-11-04 10:15:32 |               47
 products    |         12 | NULL        | 2026-11-04 10:14:58 |               23
 bloat_test  |          0 | 10:20:15    | NULL                |                0
postgres=# -- Check if autovacuum is currently running
postgres=# SELECT pid, datname, relid::regclass AS table_name,
       phase, heap_blks_scanned, heap_blks_total
postgres-# FROM pg_stat_progress_vacuum;
```

### Checking Transaction ID Age (Wraparound Risk)
**Explanation:** You can check how close your tables are to the wraparound danger zone with this query. The age function shows how many transactions old the oldest unfrozen row is. If this number approaches 200 million, autovacuum becomes aggressive. If it ever reaches 2 billion, PostgreSQL stops accepting writes.

```sql
postgres=# -- Check oldest unfrozen xid per table
postgres=# SELECT c.relname,
       age(c.relfrozenxid) AS xid_age,
       CASE
         WHEN age(c.relfrozenxid) > 150000000 THEN 'WARNING'
         WHEN age(c.relfrozenxid) > 1000000000 THEN 'CRITICAL'
         ELSE 'OK'
       END AS status
postgres-# FROM pg_class c
postgres-# JOIN pg_namespace n ON n.oid = c.relnamespace
postgres-# WHERE c.relkind = 'r'
postgres-# AND n.nspname = 'public'
postgres-# ORDER BY age(c.relfrozenxid) DESC;
 relname     |  xid_age  | status
postgres=# -------------+-----------+--------
 orders      |    284523 | OK
 products    |    152087 | OK
 customers   |     98445 | OK
postgres=# -- Database-level check:
postgres=# SELECT datname, age(datfrozenxid) AS db_xid_age
postgres-# FROM pg_database
postgres-# ORDER BY age(datfrozenxid) DESC;
```

### AUTOVACUUM ANALYZE Settings
**Explanation:** Let us look at the AUTOVACUUM ANALYZE side. AUTOVACUUM does not only vacuum — it also runs ANALYZE to update table statistics. The trigger formula is similar: autovacuum_analyze_threshold plus autovacuum_analyze_scale_factor times the row count. Default is 50 plus 10 percent. Accurate statistics are critical because the query planner uses them to choose the best execution plan. Stale statistics lead to bad query plans and slow queries.

```sql
-- ANALYZE trigger formula:
-- changed_tuples > threshold + scale_factor * n_live_tup

SHOW autovacuum_analyze_threshold;     -- 50
SHOW autovacuum_analyze_scale_factor;  -- 0.1 (10%)

-- Per-table tuning for large tables:
ALTER TABLE orders SET (
    autovacuum_analyze_scale_factor = 0.01,
    autovacuum_analyze_threshold = 500
);
-- Now: re-analyze after 500 + 1% of rows change

-- Check last analyze time:
SELECT relname, last_analyze, last_autoanalyze,
       analyze_count, autoanalyze_count
FROM pg_stat_user_tables
ORDER BY last_autoanalyze DESC NULLS LAST;
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — AUTOVACUUM Configuration Parameters
Here are all the important AUTOVACUUM configuration parameters. These are server-level defaults — but you can override most of them per-table as we just showed. The most critical ones are autovacuum itself — make sure it is ON — the cost delay which controls how aggressive autovacuum is, and the scale factor which determines the trigger threshold. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `autovacuum` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Master switch — NEVER turn this off (Default: on) |
| `autovacuum_max_workers` | `3` | **`[RESTART]`** (Postmaster Restart) | Max tables vacuumed in parallel (increase for many tables) (Default: 3) |
| `autovacuum_naptime` | `1min` | `[RELOAD]` (Live Reload `SIGHUP`) | Delay between autovacuum runs (checks all databases) (Default: 1min) |
| `autovacuum_vacuum_threshold` | `50` | `[RELOAD]` (Live Reload `SIGHUP`) | Minimum dead tuples before considering vacuum (Default: 50) |
| `autovacuum_vacuum_scale_factor` | `0.2` | `[RELOAD]` (Live Reload `SIGHUP`) | Fraction of table size added to threshold (lower for big tables) (Default: 0.2) |
| `autovacuum_vacuum_cost_delay` | `2ms` | `[RELOAD]` (Live Reload `SIGHUP`) | Pause between I/O bursts (higher = gentler on production I/O) (Default: 2ms) |
| `autovacuum_vacuum_cost_limit` | `200` | `[RELOAD]` (Live Reload `SIGHUP`) | I/O cost limit before pausing (higher = faster but more I/O) (Default: -1) |


### File: `postgresql.conf — Production Settings` — Production AUTOVACUUM Configuration
For AUTOVACUUM tuning in production, here is a proven configuration for a medium to large PostgreSQL server. These settings are more aggressive than defaults but are standard practice for databases with millions of rows. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `autovacuum` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Always on — non-negotiable (Default: on) |
| `autovacuum_max_workers` | `5` | **`[RESTART]`** (Postmaster Restart) | More workers for databases with many tables (Default: 3) |
| `autovacuum_naptime` | `30s` | `[RELOAD]` (Live Reload `SIGHUP`) | Check more frequently (default 1min) (Default: 1min) |
| `autovacuum_vacuum_cost_delay` | `2ms` | `[RELOAD]` (Live Reload `SIGHUP`) | Keep default — fast enough without overwhelming I/O (Default: 2ms) |
| `autovacuum_vacuum_cost_limit` | `800` | `[RELOAD]` (Live Reload `SIGHUP`) | 4x default — let autovacuum do more work per cycle (Default: -1) |
| `maintenance_work_mem` | `512MB` | `[RELOAD]` (Live Reload `SIGHUP`) | More memory for VACUUM operations (default 64MB) (Default: 64MB) |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Making AUTOVACUUM Too Gentle
Here is a common beginner trap with AUTOVACUUM. You see AUTOVACUUM running and consuming resources, so you lower the cost limit or increase the cost delay to make it gentler. The result? AUTOVACUUM becomes so slow it can never keep up with the rate of dead tuple creation. Bloat keeps growing, performance drops, and eventually you hit transaction ID wraparound. The fix is not to slow down autovacuum — it is to tune it properly for your workload and give it enough resources to finish.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. VACUUM FULL rewrites the table and shrinks it on disk, but takes an ACCESS EXCLUSIVE lock — use it only during maintenance windows or when disk space is critical. AUTOVACUUM runs VACUUM and ANALYZE automatically in the background — never turn it off. Tune autovacuum per-table for large tables by lowering the scale factor. Monitor dead tuples and transaction ID age to make sure autovacuum is keeping up. In the next class, we cover ANALYZE in depth, REINDEX, and pg_repack.

- **VACUUM FULL: rewrites table, shrinks file, but LOCKS the entire table**
- **VACUUM FULL needs free disk space for the copy — plan ahead**
- **AUTOVACUUM: automatic background VACUUM + ANALYZE — always keep it ON**
- **Trigger formula: dead_tuples > threshold + scale_factor * n_live_tup**
- **Default scale_factor (0.2) too high for large tables — tune per-table**
- **Transaction ID wraparound: VACUUM FREEZE prevents catastrophic shutdown**
- **Monitor: pg_stat_user_tables, age(relfrozenxid), pg_stat_progress_vacuum**
- **Next: ANALYZE, REINDEX & pg_repack**


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
