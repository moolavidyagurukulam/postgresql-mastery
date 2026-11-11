# Scenario: Table Bloat & Primary Server Failover
**Series:** PostgreSQL Mastery | **Phase:** 32 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we tackle two more production scenarios. First, table bloat is causing performance degradation — your tables are twice the size they should be and queries are getting slower. Second, your primary server goes down and you need to failover to the standby. We follow the same structured workflow for each scenario.

### Production Scenarios:
Table Bloat & Failover
Welcome to PostgreSQL Mastery. In this class, we tackle two more production scenarios. First, table bloat is causing performance degradation — your tables are twice the size they should be and queries are getting slower. Second, your primary server goes down and you need to failover to the standby. We follow the same structured workflow for each scenario.

### Scenario 1: Table Bloat — Detection
The scenario. Your monitoring shows query response times increasing gradually over the past two weeks. Tables that should be 50 gigabytes are showing as 95 gigabytes on disk. VACUUM is running but the tables keep growing. This is table bloat — dead rows that VACUUM cannot fully reclaim, or autovacuum falling behind on a busy table. Let us diagnose the extent and fix it.


---

## 2. Core Technical Concepts & Mechanisms

### How Table Bloat Happens
PostgreSQL uses MVCC — Multi-Version Concurrency Control. When you UPDATE a row, PostgreSQL does not modify it in place. It creates a new version and marks the old one as dead. When you DELETE, the row is marked dead but not removed. VACUUM reclaims dead rows. But if VACUUM falls behind — because the table is too busy, or a long transaction holds a snapshot — dead rows accumulate. The table grows even though live data has not changed. This is bloat.

- UPDATE creates new row version — Old version marked dead. New version inserted. Table grows by one row per UPDATE.
- DELETE marks rows as dead — Row not physically removed. Just invisible to new transactions. Space not reclaimed.
- VACUUM reclaims dead rows — Marks space as reusable. But does NOT shrink the file — just frees internal pages.
- Autovacuum falls behind — High UPDATE/DELETE rate overwhelms autovacuum workers. Dead rows accumulate.
- Long transactions prevent cleanup — Any open transaction holds a snapshot. VACUUM cannot remove rows visible to it.
- Result: bloated table — Table is 95 GB but only 50 GB is live data. 45 GB is dead rows = wasted space.

### VACUUM vs VACUUM FULL vs pg_repack
Understanding the three options is critical. VACUUM marks dead space as reusable — fast, no locks, but the file does not shrink. VACUUM FULL rewrites the entire table to a new file — the file shrinks, but it locks the table for the entire duration. pg_repack also rewrites the table but works online — no exclusive lock. For production, always use VACUUM for routine maintenance and pg_repack when you need to actually shrink the file.

| Term | Meaning / Explanation |
| :--- | :--- |
| **VACUUM** | Marks dead space reusable. Fast. No locks. File does NOT shrink. |
| **VACUUM FULL** | Rewrites table to new file. File shrinks. LOCKS TABLE entirely. Do NOT use in production. |
| **pg_repack** | Rewrites table online. File shrinks. No exclusive lock. Safe for production. |
| **When to use VACUUM** | Routine maintenance. After bulk DELETE. Regular autovacuum. |
| **When to use pg_repack** | Table bloat > 50%. File needs to shrink. Production with no downtime window. |

### Scenario 2: Primary Server Down
The second scenario. At 3 AM, your primary PostgreSQL server goes down. The monitoring alert fires — primary unreachable. Application errors are flooding in — connection refused. You have a standby server with streaming replication. You need to promote it to become the new primary. Time is critical — every second of downtime costs money. This is the most stressful production scenario.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Time** | 3:00 AM — primary unreachable. Monitoring alert fires. |
| **Symptom** | Application: connection refused. All writes failing. |
| **Setup** | Primary (10.0.1.10) + Standby (10.0.1.20) with streaming replication. |
| **Standby status** | Last seen: 0 bytes lag. Standby is up to date. |
| **Goal** | Promote standby to primary. Redirect application traffic. Minimum downtime. |
| **RTO target** | Under 5 minutes from detection to application recovery. |

### Comparison
If these production scenarios are preparing you for real-world emergencies, please support the course. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | Failover runbook included |
| Every donation helps! | pg_repack commands included |

### Redirect Application Traffic
After promotion, redirect your application to the new primary. If you use a DNS name for the database, update DNS to point to the standby's IP address. If you use a load balancer like HAProxy, it detects the promotion automatically. If you use Patroni, it handles everything — promotion and traffic redirection. For manual failover, update the application connection string or DNS record.

- Option 1: DNS Update — Update db.myapp.com to point to 10.0.1.20 (new primary). TTL matters — low TTL.
- Option 2: HAProxy — HAProxy checks pg_is_in_recovery(). Auto-routes writes to new primary.
- Option 3: Connection String — Update app config: PGHOST=10.0.1.20. Restart app instances. Fastest manual method.
- Option 4: Patroni (automated) — Patroni promotes + updates DCS + redirects traffic. No manual steps needed.
- Verify application works — Check app logs for successful connections. Test a write operation. Monitor errors.

### Patroni Automatic Failover
For production systems, use Patroni for automatic failover. Patroni monitors the primary. If the primary is unreachable, Patroni automatically promotes the most up-to-date standby. It updates the DCS — etcd or Consul — with the new primary information. HAProxy reads the DCS and routes traffic to the new primary. The entire failover happens in under 30 seconds with zero manual intervention.

```
[Application]
[HAProxy]
[Primary
(Patroni)]
[Standby
(Patroni)]
[etcd (DCS)]
```

### Beginner Traps
Watch out for these traps. Never use VACUUM FULL on a production table without a maintenance window — it locks the table completely. Never promote the standby without confirming the primary is truly down — split brain is catastrophic. Never run without a standby after failover — build a new one immediately. And never assume your failover works — test it quarterly. A failover you have never tested will fail when it matters most.

- VACUUM FULL locks the table — Use pg_repack for online table rebuild. VACUUM FULL only during maintenance windows.
- Promoting without confirming — Verify primary is truly down. Split brain (two primaries) causes data loss.
- No standby after failover — Build new standby immediately. Running without HA = one failure from total outage.
- Never testing failover — Test quarterly: promote standby, fail back. Document exact steps and timing.
- Forgetting DNS TTL — Set DNS TTL to 30 seconds before failover. High TTL = clients connect to dead primary.

### Practice Exercises
Here are your practice exercises. First, create a test table, update all rows 5 times to create bloat. Measure bloat with pg_stat_user_tables. Run VACUUM and measure the difference. Second, install pg_repack and rebuild a bloated table online. Third, set up primary and standby with streaming replication. Practice manual promotion with pg_ctl promote. Fourth, after promotion, build a new standby from the promoted server. Fifth, install Patroni and test automatic failover by stopping the primary.

- Exercise 1 — Create table, UPDATE all rows 5 times. Check bloat. VACUUM. Measure difference.
- Exercise 2 — Install pg_repack. Run on bloated table. Compare size before and after.
- Exercise 3 — Set up primary + standby. Stop primary. Promote standby. Verify writes work.
- Exercise 4 — After promotion: pg_basebackup to build new standby. Verify replication.
- Exercise 5 — Install Patroni + etcd. Stop primary. Watch automatic promotion (< 30 seconds).


---

## 3. Hands-On Commands & psql Output

### Scenario 1: Table Bloat — Detection
**Explanation:** The scenario. Your monitoring shows query response times increasing gradually over the past two weeks. Tables that should be 50 gigabytes are showing as 95 gigabytes on disk. VACUUM is running but the tables keep growing. This is table bloat — dead rows that VACUUM cannot fully reclaim, or autovacuum falling behind on a busy table. Let us diagnose the extent and fix it.

```sql
-- Queries getting slower over 2 weeks. Table sizes growing.
-- Step 1: Check actual vs expected table sizes
myapp=> SELECT relname,
  pg_size_pretty(pg_relation_size(oid)) AS table_size,
  n_live_tup, n_dead_tup,
  round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 1) AS dead_pct
FROM pg_stat_user_tables JOIN pg_class ON relname = pg_class.relname
WHERE schemaname = 'public'
ORDER BY pg_relation_size(pg_class.oid) DESC LIMIT 5;

 relname   | table_size | n_live_tup | n_dead_tup | dead_pct
-----------+------------+------------+------------+---------
 orders    |  95 GB     |    2000000 |    1200000 |   37.5
 sessions  |  12 GB     |     100000 |     800000 |   88.9
 audit_log |  45 GB     |    3000000 |     150000 |    4.8
```

### Check Autovacuum and Blocking Transactions
**Explanation:** First, check why autovacuum is not keeping up. Check when it last ran on each table. Check if there are long-running transactions preventing cleanup. The oldest transaction sets the cleanup horizon — VACUUM cannot remove any rows newer than that transaction. Here we find a forgotten transaction open for 3 days — that is blocking all VACUUM cleanup across every table.

```sql
-- When did autovacuum last run?
myapp=> SELECT relname, last_autovacuum, last_autoanalyze,
  autovacuum_count FROM pg_stat_user_tables
WHERE relname IN ('orders', 'sessions') ORDER BY relname;
 relname  | last_autovacuum     | autovacuum_count
----------+---------------------+-----------------
 orders   | 2026-11-03 14:30:00 |              45
 sessions | 2026-11-02 09:15:00 |              12

-- Check for old transactions blocking VACUUM
myapp=> SELECT pid, xact_start, now() - xact_start AS age,
  state, left(query, 50) AS query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL ORDER BY xact_start LIMIT 3;
 pid  | age            | state               | query
------+----------------+---------------------+----------
 3456 | 3 days 04:12:33| idle in transaction | BEGIN
```

### Fix — Reclaim Bloated Space
**Explanation:** The fix has three steps. First, terminate the 3-day-old idle transaction — this is blocking VACUUM everywhere. Second, run VACUUM on the bloated tables — this reclaims dead rows but does not shrink the file. Third, for the sessions table with 89 percent dead rows, use pg_repack — it rebuilds the table online without locking. pg_repack is the safe alternative to VACUUM FULL because it does not lock the table.

```sql
-- Step 1: Kill the blocking transaction
myapp=> SELECT pg_terminate_backend(3456);
 t

-- Step 2: VACUUM the bloated tables
myapp=> VACUUM VERBOSE orders;
INFO: vacuuming "public.orders"
INFO: removed 1200000 dead row versions in 156000 pages
VACUUM

-- Step 3: For severely bloated table, use pg_repack
-- (rebuilds table online, no locks)
$ pg_repack -d myapp -t sessions
INFO: repacking table "public.sessions"
INFO: 12 GB → 1.5 GB (88% reduction)
```

### Prevention — Table Bloat
**Explanation:** To prevent bloat, tune autovacuum per table for large busy tables. Set idle_in_transaction_session_timeout to kill forgotten transactions. Monitor the oldest transaction age — if it is older than a few hours, investigate. Use the pgstattuple extension to measure exact bloat percentage. And schedule pg_repack monthly for tables with chronic bloat.

```sql
-- Aggressive autovacuum for busy tables
myapp=> ALTER TABLE orders SET (
  autovacuum_vacuum_scale_factor = 0.01,
  autovacuum_vacuum_cost_delay = 2,
  autovacuum_vacuum_cost_limit = 1000);

-- Kill forgotten transactions automatically
myapp=> ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';

-- Monitor oldest transaction age
myapp=> SELECT max(age(backend_xmin)) AS oldest_xmin_age
FROM pg_stat_activity WHERE backend_xmin IS NOT NULL;
 oldest_xmin_age
-----------------
          125340
-- Alert if > 1,000,000 (approaching wraparound)
```

### Manual Failover — Step by Step
**Explanation:** If you do not have an automatic failover tool like Patroni, you must promote the standby manually. First, verify the primary is truly down — try to connect, check the process, check the server. Do not promote if the primary is just slow. Once confirmed, promote the standby using pg_ctl promote or the pg_promote function. The standby exits recovery mode and starts accepting writes.

```sql
# Step 1: Verify primary is truly down
$ pg_isready -h 10.0.1.10 -p 5432
10.0.1.10:5432 - no response

# Step 2: Check standby is up and current
standby$ psql -c "SELECT pg_is_in_recovery();"
 t   (still in recovery = still standby)
standby$ psql -c "SELECT pg_last_xact_replay_timestamp();"
 2026-11-05 02:59:58  (1 minute ago = nearly caught up)

# Step 3: PROMOTE the standby
standby$ pg_ctl promote -D /var/lib/postgresql/16/main
waiting for server to promote.... done
server promoted

# Step 4: Verify it accepts writes
standby$ psql -c "SELECT pg_is_in_recovery();"
 f   (FALSE = now a primary!)
```

### Post-Failover — Build New Standby
**Explanation:** After the application is running on the new primary, you have post-failover tasks. First, set up a new standby — you are now running without high availability. Build a new standby from the new primary using pg_basebackup. Second, investigate why the old primary went down — hardware failure, disk full, out of memory, kernel panic. Fix it. Third, decide whether to make the old primary the new standby or decommission it.

```sql
# On the new standby server (old primary if recovered):
# Step 1: Stop PostgreSQL
$ sudo systemctl stop postgresql

# Step 2: Remove old data directory
$ sudo rm -rf /var/lib/postgresql/16/main/*

# Step 3: Base backup from new primary
$ pg_basebackup -h 10.0.1.20 -U repl_user -D /var/lib/postgresql/16/main -R -P -X stream
24091/24091 kB (100%), 1/1 tablespace

# -R creates standby.signal + primary_conninfo
# Step 4: Start as standby
$ sudo systemctl start postgresql
$ psql -c "SELECT pg_is_in_recovery();"
 t  (TRUE = running as standby)
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these traps. Never use VACUUM FULL on a production table without a maintenance window — it locks the table completely. Never promote the standby without confirming the primary is truly down — split brain is catastrophic. Never run without a standby after failover — build a new one immediately. And never assume your failover works — test it quarterly. A failover you have never tested will fail when it matters most.

- VACUUM FULL locks the table — Use pg_repack for online table rebuild. VACUUM FULL only during maintenance windows.
- Promoting without confirming — Verify primary is truly down. Split brain (two primaries) causes data loss.
- No standby after failover — Build new standby immediately. Running without HA = one failure from total outage.
- Never testing failover — Test quarterly: promote standby, fail back. Document exact steps and timing.
- Forgetting DNS TTL — Set DNS TTL to 30 seconds before failover. High TTL = clients connect to dead primary.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. Table bloat: check dead tuple percentage, kill old transactions blocking VACUUM, run VACUUM for routine cleanup, use pg_repack to actually shrink files online. Tune autovacuum per table. Failover: verify primary is truly down, promote standby with pg_ctl promote, redirect application traffic, build a new standby immediately. Use Patroni for automatic failover in production. Test failover quarterly — a plan you have never tested will fail.

- **Bloat: dead rows from UPDATE/DELETE not reclaimed by VACUUM**
- **Kill old transactions blocking VACUUM (idle_in_transaction_session_timeout)**
- **VACUUM: reclaims space but file does NOT shrink**
- **pg_repack: rebuilds table online, file shrinks, no locks**
- **Never VACUUM FULL in production — locks entire table**
- **Failover: verify primary down → promote standby → redirect traffic**
- **Build new standby immediately after failover (pg_basebackup -R)**
- **Use Patroni for automatic failover (< 30 seconds, zero manual)**


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
