# Routine Maintenance Checklist & Schedule
**Series:** PostgreSQL Mastery | **Phase:** Phase 19: Vacuum & Maintenance | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! This is the final class of Phase 19. We have learned VACUUM, VACUUM FULL, AUTOVACUUM, ANALYZE, REINDEX, and pg_repack. Now we bring everything together into a complete routine maintenance checklist and schedule. After this class, you will have a production-ready maintenance plan that keeps your PostgreSQL database healthy, fast, and safe. Let us begin.

### Why Routine Maintenance Matters
Think of PostgreSQL maintenance like car maintenance. You do not wait for the engine to seize before changing the oil. You follow a schedule — check oil weekly, rotate tires monthly, full service annually. Database maintenance works the same way. Daily checks catch small problems before they become big. Weekly tasks prevent bloat from building up. Monthly tasks keep everything optimized. Skip maintenance, and your database degrades silently until something breaks at 3 AM.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand all the maintenance tools from this phase — VACUUM, VACUUM FULL, AUTOVACUUM, ANALYZE, REINDEX, and pg_repack. Recap: VACUUM cleans dead tuples. AUTOVACUUM does it automatically. ANALYZE updates planner statistics. REINDEX rebuilds bloated indexes. pg_repack does online table reorganization. Now we combine them into a daily, weekly, and monthly schedule.

- Prerequisite: VACUUM, VACUUM FULL, AUTOVACUUM (previous classes)
- Prerequisite: ANALYZE, REINDEX, pg_repack (previous class)
- Now: Building a complete maintenance schedule
- Goal: A checklist you can use in production starting today

### Why Routine Maintenance Matters
Think of PostgreSQL maintenance like car maintenance. You do not wait for the engine to seize before changing the oil. You follow a schedule — check oil weekly, rotate tires monthly, full service annually. Database maintenance works the same way. Daily checks catch small problems before they become big. Weekly tasks prevent bloat from building up. Monthly tasks keep everything optimized. Skip maintenance, and your database degrades silently until something breaks at 3 AM.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Without maintenance** | Tables bloat, indexes decay, statistics go stale, queries slow down |
| **Transaction ID wraparound** | Without VACUUM FREEZE, PostgreSQL eventually STOPS accepting writes |
| **Silent degradation** | Performance drops 5% per month — nobody notices until it is 50% slower |
| **With a schedule** | Catch problems early, prevent outages, maintain consistent performance |

**Notes:**
- Most maintenance is handled by AUTOVACUUM — but you still need to MONITOR it
- AUTOVACUUM is your autopilot; monitoring is your dashboard

### Weekly Maintenance Tasks
Now for the weekly maintenance tasks. These are things AUTOVACUUM handles for most tables, but you should verify it is keeping up and handle edge cases it misses.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Now for the weekly maintenance tasks |
| **Point 2** | These are things AUTOVACUUM handles for most tables, but you should verify it is keeping up and handle edge cases it misses |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description — the complete maintenance script is included. If you want to support this free course, the donation link is also in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Monthly Maintenance Tasks
Monthly tasks are deeper maintenance operations. These are things you schedule during a maintenance window or run with CONCURRENTLY options.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Monthly tasks are deeper maintenance operations |
| **Point 2** | These are things you schedule during a maintenance window or run with CONCURRENTLY options |

### Common Maintenance Mistakes
Here are the most common maintenance mistakes beginners make. Each one can cause serious problems in production. Learn these now so you do not have to learn them the hard way at 3 AM.

| The Mistake | The Consequence |
| :--- | :--- |
| Turning off AUTOVACUUM | Bloat grows → wraparound → DB shuts down |
| Running VACUUM FULL during peak hours | Table locked → app hangs → users see errors |
| Never checking transaction ID age | Aggressive vacuum surprise → performance spike |
| Ignoring unused indexes | Slower writes, wasted disk and memory |
| No backup verification | Backup fails when you need it most |
| No monitoring at all | Silent degradation until catastrophic failure |

### Phase 19 Quick Reference
Here is a quick reference card for all the maintenance commands we covered in this phase.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a quick reference card for all the maintenance commands we covered in this phase |


---

## 3. Hands-On Commands & psql Output

### Daily Check 1: Dead Tuple Report
**Explanation:** Here is your daily monitoring checklist. These are quick queries you run every morning — or better yet, set up as automated alerts. Each one takes seconds to run and tells you if something needs attention.

```sql
-- Tables with significant dead tuples
SELECT relname,
       n_live_tup,
       n_dead_tup,
       ROUND(n_dead_tup::numeric /
         NULLIF(n_live_tup, 0) * 100, 1) AS dead_pct,
       last_autovacuum,
       last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- ALERT if any table has > 20% dead tuples
-- ALERT if last_autovacuum is NULL or older than 24 hours
-- ACTION: If autovacuum is behind, run VACUUM ANALYZE manually
```

### Daily Check 2: Size Monitoring
**Explanation:** Daily check number two — database and table sizes. Track growth so you can plan capacity. A sudden size jump might mean a runaway query or a failed VACUUM.

```sql
-- Database sizes
SELECT datname,
       pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;

-- Top 10 largest tables (including indexes and TOAST)
SELECT relname,
       pg_size_pretty(pg_total_relation_size(relid)) AS total,
       pg_size_pretty(pg_relation_size(relid)) AS table_only,
       pg_size_pretty(pg_indexes_size(relid)) AS indexes
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;

-- WAL directory size
SELECT count(*) AS wal_files,
       pg_size_pretty(sum(size)) AS wal_total
FROM pg_ls_waldir();
```

### Daily Check 3: Transaction ID Age
**Explanation:** Daily check number three — transaction ID age. This is the one that can shut down your database if ignored. Check that no table is approaching the 200-million-xid aggressive vacuum threshold.

```sql
-- Tables closest to wraparound
SELECT c.relname,
       age(c.relfrozenxid) AS xid_age,
       CASE
         WHEN age(c.relfrozenxid) > 150000000
           THEN 'WARNING — approaching aggressive vacuum'
         WHEN age(c.relfrozenxid) > 1000000000
           THEN 'CRITICAL — wraparound imminent!'
         ELSE 'OK'
       END AS status
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog','information_schema')
ORDER BY age(c.relfrozenxid) DESC
LIMIT 10;

-- ALERT if any xid_age > 150,000,000
-- ACTION: VACUUM FREEZE on affected tables immediately
```

### Daily Check 4: Long-Running Queries & Connections
**Explanation:** Daily check number four — long-running queries and idle connections. These can hold locks, block autovacuum, and prevent dead tuple cleanup.

```sql
-- Queries running longer than 5 minutes
SELECT pid, now() - query_start AS duration,
       state, query
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < now() - '5 min'::interval
ORDER BY duration DESC;

-- Idle in transaction (blocks autovacuum!)
SELECT pid, now() - state_change AS idle_time,
       query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND state_change < now() - '10 min'::interval;

-- ALERT if idle-in-transaction > 10 minutes
-- ACTION: Investigate and terminate if safe:
-- SELECT pg_terminate_backend(pid);
```

### Weekly Health Check Script
**Explanation:** Here is a complete weekly health check script that combines all the weekly tasks into one query you can run.

```sql
-- Unused indexes (wasting disk and slowing writes)
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size,
       idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND pg_relation_size(indexrelid) > 1024 * 1024
ORDER BY pg_relation_size(indexrelid) DESC;

-- Inactive replication slots (WAL leak!)
SELECT slot_name, active,
       pg_size_pretty(
         pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
       ) AS retained_wal
FROM pg_replication_slots
WHERE NOT active;

-- Tables autovacuum has not touched in 7 days
SELECT relname, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
WHERE last_autovacuum < now() - '7 days'::interval
   OR last_autovacuum IS NULL
ORDER BY n_dead_tup DESC;
```

### Actual Cron Entries
**Explanation:** And here is that cron schedule as actual cron entries you can copy and paste.

```sql
# Daily health check (6 AM)
0 6 * * * psql -U postgres -d prod -f /scripts/health_check.sql \
  | mail -s 'PG Daily Health' dba@company.com
# Daily VACUUM ANALYZE (2 AM)
0 2 * * * psql -U postgres -d prod -c 'VACUUM ANALYZE;'
# Weekly REINDEX on bloat-prone tables (Sunday 3 AM)
0 3 * * 0 psql -U postgres -d prod -c \
  "REINDEX TABLE CONCURRENTLY orders;"
# Monthly pg_repack (1st of month, 4 AM)
0 4 1 * * pg_repack -U postgres -d prod -t orders -t audit_log
# Monthly full ANALYZE (1st of month, 6 AM)
0 6 1 * * psql -U postgres -d prod -c 'ANALYZE (VERBOSE);'
# Weekly backup verify (Sunday 1 AM)
0 1 * * 0 pgbackrest --stanza=prod verify
```

### Complete Daily Health Check Script
**Explanation:** Here is the complete daily monitoring script that you can save as a SQL file and run automatically. It covers all four daily checks in one query.

```sql
-- === DAILY HEALTH CHECK ===

-- 1. Dead tuple alert
SELECT '1. BLOAT' AS check, relname,
       n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC LIMIT 5;

-- 2. Database sizes
SELECT '2. SIZES' AS check, datname,
       pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database WHERE datistemplate = false;

-- 3. XID age
SELECT '3. XID' AS check, c.relname,
       age(c.relfrozenxid) AS xid_age
FROM pg_class c JOIN pg_namespace n
  ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname = 'public'
ORDER BY age(c.relfrozenxid) DESC LIMIT 5;

-- 4. Long queries
SELECT '4. LONG' AS check, pid,
       now() - query_start AS duration
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < now() - '5 min'::interval;
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `crontab -e (as postgres user)` — Production Maintenance Cron Schedule
Here is a production cron schedule that automates the routine maintenance. AUTOVACUUM handles most vacuuming, but we add scheduled tasks for the things it does not cover.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `Daily 6AM` | `health_check.sql` | `[SETTING]` | Run daily monitoring queries, email results |
| `Daily 2AM` | `VACUUM ANALYZE` | `[SETTING]` | Full-database vacuum + analyze (supplements autovacuum) |
| `Sunday 3AM` | `REINDEX CONCURRENTLY` | `[SETTING]` | Weekly index rebuild on known bloat-prone tables |
| `1st of month 4AM` | `pg_repack` | `[SETTING]` | Monthly online repack of heavily-updated tables |
| `1st of month 6AM` | `ANALYZE (full)` | `[SETTING]` | Full statistics refresh after monthly repack |
| `Sunday 1AM` | `pgbackrest verify` | `[SETTING]` | Weekly backup integrity verification |



---

## 5. Common Beginner Traps & How to Fix Them

### Common Maintenance Mistakes
Here are the most common maintenance mistakes beginners make. Each one can cause serious problems in production. Learn these now so you do not have to learn them the hard way at 3 AM.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us do a complete Phase 19 review. We covered six classes across four videos. Dead tuples and bloat — why they exist and how to measure them. VACUUM — cleans dead tuples, marks space reusable, does not shrink files. VACUUM FULL — rewrites the table, shrinks the file, but locks everything. AUTOVACUUM — automatic background cleanup, tune per-table for large tables. ANALYZE — updates planner statistics for accurate query plans. REINDEX — rebuilds bloated or corrupted indexes. pg_repack — online table reorganization without locks. And now, a complete maintenance checklist and cron schedule.

- **Dead Tuples: old row versions from UPDATE/DELETE (MVCC side effect)**
- **VACUUM: marks dead space reusable, updates FSM/VM, does NOT shrink file**
- **VACUUM FULL: rewrites table, shrinks file, ACCESS EXCLUSIVE LOCK**
- **AUTOVACUUM: automatic VACUUM + ANALYZE — NEVER turn it off**
- **Tune autovacuum per-table: lower scale_factor for large tables**
- **ANALYZE: updates planner statistics — stale stats = bad query plans**
- **REINDEX CONCURRENTLY: rebuild indexes without blocking writes**
- **pg_repack: online VACUUM FULL — no lock, needs PRIMARY KEY**
- **Daily: dead tuples, sizes, XID age, long queries**
- **Weekly: unused indexes, replication slots, autovacuum health**
- **Monthly: REINDEX, pg_repack, full ANALYZE, backup test**


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
