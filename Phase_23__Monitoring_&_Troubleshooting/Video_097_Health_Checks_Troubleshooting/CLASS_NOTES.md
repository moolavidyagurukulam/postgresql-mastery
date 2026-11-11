# Health Checks & Troubleshooting Scenarios — When Things Go Wrong at 3 AM
**Series:** PostgreSQL Mastery | **Phase:** Phase 23: Monitoring & Troubleshooting | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! This is the final class of Phase 23 — and it is the most practical. We are going to build a complete health check script that you can run on any PostgreSQL server to get an instant diagnosis. Then we will work through real troubleshooting scenarios — the situations you WILL face in production. When the pager goes off at 3 AM, these scripts and workflows will save you.

### Health Checks &
Troubleshooting Scenarios
Welcome back to PostgreSQL Mastery! This is the final class of Phase 23 — and it is the most practical. We are going to build a complete health check script that you can run on any PostgreSQL server to get an instant diagnosis. Then we will work through real troubleshooting scenarios — the situations you WILL face in production. When the pager goes off at 3 AM, these scripts and workflows will save you.


---

## 2. Core Technical Concepts & Mechanisms

### Five Questions a Health Check Must Answer
A health check script should answer five questions in under 30 seconds: Is PostgreSQL running? Is it accepting connections? Is it performing well? Are there any blocking issues? Is disk space okay? Let us build this script section by section.

- 1. Is PostgreSQL running? -- Check process, port, pg_isready
- 2. Is it accepting connections? -- Connection count vs max_connections, any refused connections
- 3. Is it performing well? -- Cache hit ratio, TPS, temp files, slow queries
- 4. Are there blocking issues? -- Locks, idle in transaction, long-running queries, deadlocks
- 5. Is disk space okay? -- Data directory, WAL, log files, tablespace usage

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Scenario 1: Application Timeouts
Now let us work through real troubleshooting scenarios. Scenario 1: Application timeouts. Users report the app is slow and timing out. Here is the diagnosis workflow.

- Step 1: Check pg_stat_activity -- Are queries active and running, or waiting on locks?
- Step 2: Look for blocked sessions -- pg_blocking_pids — is something holding locks?
- Step 3: Find the blocker -- Usually 'idle in transaction' — terminate it
- Step 4: Check connection count -- Near max_connections? Kill idle sessions, add pgBouncer
- Step 5: Check for slow queries -- EXPLAIN ANALYZE the slow queries, add missing indexes
- Step 6: Prevent recurrence -- Set idle_in_transaction_session_timeout, statement_timeout

### Scenario 2: Disk Full
Scenario 2: Disk space full. PostgreSQL stops accepting writes when the disk is full. WAL files are often the culprit — especially when an inactive replication slot prevents WAL recycling.

- Step 1: Check what's using space -- du -sh /var/lib/postgresql/16/main/pg_wal/ → WAL files often the cause
- Step 2: Check replication slots -- SELECT slot_name, active FROM pg_replication_slots; → inactive slots hold WAL
- Step 3: Drop inactive replication slots -- SELECT pg_drop_replication_slot('inactive_slot'); → frees WAL immediately
- Step 4: Check log files -- du -sh /var/lib/postgresql/16/main/log/ → rotate/delete old logs
- Step 5: Check for bloated tables -- VACUUM FULL on heavily bloated tables (requires ACCESS EXCLUSIVE lock)
- Step 6: Prevent recurrence -- Set max_slot_wal_keep_size, log_rotation_age, monitor disk usage

### Common Errors & Quick Fixes
Here is a quick reference for the most common error messages and what to do about them.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a quick reference for the most common error messages and what to do about them |

### Your Monitoring Toolkit — Save These
Here is your complete monitoring toolkit — save these queries.

| Task | Tool |
| :--- | :--- |
| What exists in DB? | pg_class, pg_attribute, pg_indexes |
| Table performance? | pg_stat_user_tables (scans, dead tuples) |
| Cache health? | pg_stat_database (blks_hit/blks_read) |
| Who is connected? | pg_stat_activity (state, query, duration) |
| Who blocks whom? | pg_blocking_pids() + pg_stat_activity |
| Historical patterns? | PostgreSQL logs + pgBadger reports |
| Real-time dashboards? | Prometheus + Grafana + postgres_exporter |
| Instant diagnosis? | Health check script (run on any server) |


---

## 3. Hands-On Commands & psql Output

### Health Check Part 1: Is PostgreSQL Running?
**Explanation:** Section 1: Is PostgreSQL running? We invoke pg_isready specifying the host with minus h and port with minus p. If the cluster is healthy and accepting connections, it returns exit code zero and prints accepting connections. If PostgreSQL is shutting down or out of memory, pg_isready detects it immediately without logging in.

```sql
# Quick connectivity check:
pg_isready -h localhost -p 5432
# localhost:5432 - accepting connections
# From SQL (already connected):
SELECT
    pg_postmaster_start_time() AS started_at,
    now() - pg_postmaster_start_time() AS uptime,
    version() AS pg_version;
        started_at         |     uptime      |         pg_version
postgres=# ---------------------------+-----------------+-----------------------------
 2026-11-01 06:30:12+00    | 3 days 18:15:23 | PostgreSQL 16.4 on x86_64...
# Check if in recovery (standby) or primary:
postgres=# SELECT pg_is_in_recovery();
postgres=# -- false = primary, true = standby
# Data directory:
postgres=# SHOW data_directory;
postgres=# -- /var/lib/postgresql/16/main
```

### Health Check Part 2: Connection Health
**Explanation:** Section 2: Connection health. We query pg_stat_activity to monitor how many connections are active versus idle in transaction. An idle in transaction connection holds open table locks, preventing autovacuum from cleaning dead tuples. Track this regularly to avert connection pool exhaustion.

```sql
SELECT
    (SELECT setting::int FROM pg_settings
postgres-# WHERE name = 'max_connections') AS max_conn,
    count(*) AS total_conn,
    count(*) FILTER (WHERE state = 'active') AS active,
    count(*) FILTER (WHERE state = 'idle') AS idle,
    count(*) FILTER (
postgres-# WHERE state = 'idle in transaction'
    ) AS idle_in_txn,
    count(*) FILTER (
postgres-# WHERE state = 'idle in transaction'
postgres-# AND now() - state_change > interval '5 minutes'
    ) AS old_idle_txn,
    ROUND(100.0 * count(*) / (
postgres=# SELECT setting::int FROM pg_settings
postgres-# WHERE name = 'max_connections'
    ), 1) AS usage_pct
postgres-# FROM pg_stat_activity
postgres-# WHERE backend_type = 'client backend';
 max_conn | total | active | idle | idle_in_txn | old_idle_txn | usage_pct
postgres=# ----------+-------+--------+------+-------------+--------------+----------
      100 |    42 |      8 |   30 |           4 |            2 |      42.0
postgres=# -- ALERTS:
postgres=# -- usage_pct > 80%: WARNING
postgres=# -- old_idle_txn > 0: these sessions need to be terminated
```

### Health Check Part 3: Performance Metrics
**Explanation:** Section 3: Performance metrics. Cache hit ratio, temporary file usage, and autovacuum status — the three numbers that tell you if performance is healthy.

```sql
postgres=# -- Cache hit ratio:
SELECT
    'Cache Hit Ratio' AS check,
    ROUND(100.0 * blks_hit /
      NULLIF(blks_hit + blks_read, 0), 2) || '%' AS value,
    CASE WHEN 100.0 * blks_hit /
      NULLIF(blks_hit + blks_read, 0) < 95
      THEN 'CRITICAL'
      WHEN 100.0 * blks_hit /
      NULLIF(blks_hit + blks_read, 0) < 99
      THEN 'WARNING' ELSE 'OK'
    END AS status
postgres-# FROM pg_stat_database
postgres-# WHERE datname = current_database();
      check       | value  | status
postgres=# ------------------+--------+--------
 Cache Hit Ratio  | 99.15% | OK
postgres=# -- Temp files (work_mem spills):
postgres=# SELECT temp_files, pg_size_pretty(temp_bytes) AS temp_size
postgres-# FROM pg_stat_database
postgres-# WHERE datname = current_database();
postgres=# -- Tables needing vacuum:
postgres=# SELECT relname, n_dead_tup,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup, 0), 1) AS bloat_pct,
    last_autovacuum
postgres-# FROM pg_stat_user_tables
postgres-# WHERE n_dead_tup > 10000
postgres-# ORDER BY n_dead_tup DESC LIMIT 5;
```

### Health Check Part 4: Blocking Issues
**Explanation:** Section 4: Blocking issues. Long-running queries, lock chains, and deadlocks.

```sql
postgres=# -- Long-running queries (> 5 minutes):
postgres=# SELECT pid, usename,
    now() - query_start AS duration,
    LEFT(query, 60) AS query
postgres-# FROM pg_stat_activity
postgres-# WHERE state = 'active'
postgres-# AND now() - query_start > interval '5 minutes'
postgres-# ORDER BY query_start;
postgres=# -- Blocked sessions:
postgres=# SELECT pid, usename,
    pg_blocking_pids(pid) AS blocked_by,
    now() - query_start AS wait_time,
    LEFT(query, 60) AS query
postgres-# FROM pg_stat_activity
postgres-# WHERE cardinality(pg_blocking_pids(pid)) > 0;
postgres=# -- Recent deadlocks:
postgres=# SELECT deadlocks FROM pg_stat_database
postgres-# WHERE datname = current_database();
postgres=# -- Oldest open transaction:
postgres=# SELECT pid, usename, state,
    now() - xact_start AS txn_age,
    LEFT(query, 60) AS query
postgres-# FROM pg_stat_activity
postgres-# WHERE xact_start IS NOT NULL
postgres-# ORDER BY xact_start
postgres-# LIMIT 1;
```

### Health Check Part 5: Disk Usage
**Explanation:** Section 5: Disk usage. Check the database size, largest tables, WAL directory, and available disk space.

```sql
postgres=# -- Database size:
SELECT
    pg_size_pretty(pg_database_size(
      current_database())) AS db_size;
postgres=# -- Top 5 largest tables:
SELECT
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(oid)) AS total,
    pg_size_pretty(pg_table_size(oid)) AS data,
    pg_size_pretty(
      pg_indexes_size(oid)) AS indexes
postgres-# FROM pg_class
postgres-# WHERE relkind = 'r'
postgres-# AND relnamespace = 'public'::regnamespace
postgres-# ORDER BY pg_total_relation_size(oid) DESC
postgres-# LIMIT 5;
 table_name | total  | data   | indexes
postgres=# ------------+--------+--------+---------
 orders     | 245 MB | 180 MB | 65 MB
 audit_log  | 128 MB | 100 MB | 28 MB
postgres=# -- WAL directory size (from command line):
postgres=# -- du -sh /var/lib/postgresql/16/main/pg_wal/
postgres=# -- 1.2G  pg_wal/
postgres=# -- Disk free (from SQL):
postgres=# -- SELECT * FROM pg_tablespace;
```

### Complete Health Check Script
**Explanation:** Now let us put it all together in one complete health check script. Run this script and get a full report in seconds.

```sql
-- ====== POSTGRESQL HEALTH CHECK ======
\echo '=== 1. SERVER INFO ==='
SELECT version();
SELECT pg_postmaster_start_time() AS started,
  now() - pg_postmaster_start_time() AS uptime,
  pg_is_in_recovery() AS is_standby;

\echo '=== 2. CONNECTIONS ==='
SELECT count(*) AS total,
  count(*) FILTER (WHERE state='active') AS active,
  count(*) FILTER (WHERE state='idle in transaction') AS idle_txn,
  (SELECT setting::int FROM pg_settings
   WHERE name='max_connections') AS max_conn
FROM pg_stat_activity
WHERE backend_type = 'client backend';

\echo '=== 3. CACHE HIT RATIO ==='
SELECT ROUND(100.0 * blks_hit /
  NULLIF(blks_hit+blks_read, 0), 2) AS pct
FROM pg_stat_database
WHERE datname = current_database();

\echo '=== 4. BLOATED TABLES ==='
SELECT relname, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC LIMIT 5;

\echo '=== 5. BLOCKED SESSIONS ==='
SELECT pid, pg_blocking_pids(pid) blocked_by
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;

\echo '=== 6. DATABASE SIZE ==='
SELECT pg_size_pretty(
  pg_database_size(current_database()));
```

### Scenario 3: Sudden Slow Performance
**Explanation:** Scenario 3: Sudden performance degradation. Queries that were fast yesterday are slow today. The usual suspects are stale statistics, missing vacuum, or a query plan change.

```sql
postgres=# -- Check 1: When was the last ANALYZE?
postgres=# SELECT relname, last_analyze, last_autoanalyze,
       n_dead_tup
postgres-# FROM pg_stat_user_tables
postgres-# WHERE relname = 'orders';
postgres=# -- If last_analyze is old → stale statistics:
postgres=# ANALYZE orders;
postgres=# -- Check 2: Has the table bloated?
postgres=# SELECT relname, n_dead_tup,
  pg_size_pretty(pg_total_relation_size(relid))
postgres-# FROM pg_stat_user_tables
postgres-# WHERE relname = 'orders';
postgres=# -- If dead_tup is high:
postgres=# VACUUM ANALYZE orders;
postgres=# -- Check 3: Did the query plan change?
postgres=# EXPLAIN (ANALYZE, BUFFERS)
postgres=# SELECT * FROM orders WHERE customer_id = 42;
postgres=# -- Look for Seq Scan where you expect Index Scan
postgres=# -- → ANALYZE fixes stale stats that cause bad plans
postgres=# -- Check 4: Did someone drop an index?
postgres=# SELECT indexname FROM pg_indexes
postgres-# WHERE tablename = 'orders';
postgres=# -- Compare to expected indexes
```

### Scenario 4: Connection Limit Reached
**Explanation:** Scenario 4: Too many connections. The application gets 'FATAL: too many connections for role' or 'FATAL: sorry, too many clients already'. Here is the emergency response.

```sql
postgres=# -- Check current connections:
postgres=# SELECT usename, count(*),
    count(*) FILTER (WHERE state = 'idle') AS idle
postgres-# FROM pg_stat_activity
postgres-# WHERE backend_type = 'client backend'
postgres-# GROUP BY usename ORDER BY count(*) DESC;
 usename | count | idle
postgres=# ---------+-------+------
 app     |    85 |   72
 report  |    12 |   10
 admin   |     3 |    2
postgres=# -- 72 idle connections from app! → connection leak
postgres=# -- Emergency: terminate idle connections:
postgres=# SELECT pg_terminate_backend(pid)
postgres-# FROM pg_stat_activity
postgres-# WHERE state = 'idle'
postgres-# AND usename = 'app'
postgres-# AND now() - state_change > interval '10 minutes';
postgres=# -- Long-term fix:
postgres=# -- 1. Use pgBouncer (connection pooling)
postgres=# -- 2. Fix connection leak in application code
postgres=# -- 3. Set idle_session_timeout = '10min' (PG 14+)
postgres=# -- 4. Keep max_connections reasonable (50-200)
```

### Scenario 5: Autovacuum Not Keeping Up
**Explanation:** Scenario 5: Autovacuum is not keeping up. Tables are bloating, queries are getting slower, and transaction ID wraparound warnings appear in the logs.

```sql
postgres=# -- Check autovacuum status:
postgres=# SELECT relname, n_dead_tup,
    last_autovacuum,
    autovacuum_count,
    ROUND(100.0 * n_dead_tup /
      NULLIF(n_live_tup, 0), 1) AS bloat_pct
postgres-# FROM pg_stat_user_tables
postgres-# WHERE n_dead_tup > 50000
postgres-# ORDER BY n_dead_tup DESC;
postgres=# -- Check for wraparound danger:
postgres=# SELECT relname,
    age(relfrozenxid) AS xid_age,
    pg_size_pretty(pg_total_relation_size(oid)) AS size
postgres-# FROM pg_class
postgres-# WHERE relkind = 'r'
postgres-# ORDER BY age(relfrozenxid) DESC
postgres-# LIMIT 5;
postgres=# -- If xid_age > 200,000,000 → wraparound danger!
postgres=# -- If xid_age > 1,000,000,000 → CRITICAL
postgres=# -- Fix: tune autovacuum for busy tables:
postgres=# ALTER TABLE orders SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_analyze_scale_factor = 0.005,
    autovacuum_vacuum_cost_delay = 2
);
postgres=# -- Emergency: manual vacuum
postgres=# VACUUM (VERBOSE) orders;
```

### Scenario 6: Replication Lag Growing
**Explanation:** Scenario 6: Replication lag growing. The standby is falling behind the primary. Reads on the standby return stale data.

```sql
postgres=# -- On PRIMARY — check replication status:
SELECT
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
    pg_size_pretty(
      pg_wal_lsn_diff(sent_lsn, replay_lsn)
    ) AS lag_pretty
postgres-# FROM pg_stat_replication;
 client_addr  | state     | lag_pretty
postgres=# --------------+-----------+-----------
 10.0.1.10    | streaming | 256 MB
postgres=# -- 256 MB lag! Check why:
postgres=# -- 1. Standby under heavy read load?
postgres=# -- 2. Network bandwidth saturated?
postgres=# -- 3. Standby disk I/O too slow?
postgres=# -- 4. max_wal_senders full? (check pg_stat_replication count)
postgres=# -- Check replication slots for WAL retention:
postgres=# SELECT slot_name, active,
    pg_size_pretty(
      pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS retained_wal
postgres-# FROM pg_replication_slots;
postgres=# -- Inactive slot with huge retained_wal → DROP it
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. A health check script answers five questions: is it running, accepting connections, performing well, blocking anything, and has disk space. The six key troubleshooting scenarios are: application timeouts from locks, disk full from WAL or logs, sudden slowness from stale stats, connection limit from leaks, autovacuum falling behind, and replication lag growing. Always follow the workflow: diagnose with pg_stat views, fix the immediate issue, then prevent recurrence with configuration. This completes Phase 23. Next we begin Phase 24 — Replication and High Availability.

- **Health check: 5 questions in 30 seconds (script in materials)**
- **Scenario 1: Timeouts → find blocker → terminate → set timeouts**
- **Scenario 2: Disk full → check WAL, slots, logs → free space**
- **Scenario 3: Sudden slowness → ANALYZE, check dead tuples, plans**
- **Scenario 4: Connection limit → kill idle, fix leak, add pgBouncer**
- **Scenario 5: Autovacuum behind → tune per-table, manual VACUUM**
- **Scenario 6: Replication lag → check standby I/O, network, slots**
- **Workflow: Diagnose → Fix → Prevent recurrence**
- **Phase 23 Complete! Next: Replication & High Availability**


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
