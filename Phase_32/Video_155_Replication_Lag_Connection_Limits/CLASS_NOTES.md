# Scenario: Replication Lag & Connection Limit Reached
**Series:** PostgreSQL Mastery | **Phase:** 32 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we tackle two more production scenarios. First, replication lag is increasing on your standby server — reads are returning stale data. Second, the connection limit is reached — new connections are being refused and your application is throwing errors. We follow the same workflow — detect, diagnose, fix, verify, prevent.

### Production Scenarios:
Replication Lag & Connections
Welcome to PostgreSQL Mastery. In this class, we tackle two more production scenarios. First, replication lag is increasing on your standby server — reads are returning stale data. Second, the connection limit is reached — new connections are being refused and your application is throwing errors. We follow the same workflow — detect, diagnose, fix, verify, prevent.

### Scenario 1: Replication Lag — Detection
The scenario. Your monitoring shows replication lag on the standby has jumped from milliseconds to 45 seconds and climbing. Users reading from the replica see stale data — an order placed 30 seconds ago does not appear. If lag continues to grow, the standby becomes useless for reads and may fall too far behind to recover. Let us diagnose why.


---

## 2. Core Technical Concepts & Mechanisms

### Common Causes of Replication Lag
Replication lag has several common causes. The primary is doing heavy writes — a bulk data load, a large UPDATE, or a migration script. The standby has insufficient resources — slow disk, not enough CPU, or limited memory. Network issues between primary and standby cause WAL shipping delays. Long-running queries on the standby with hot_standby_feedback enabled prevent the standby from applying WAL. Let us check each one.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Heavy writes on primary** | Bulk INSERT/UPDATE, data migration, schema change generating massive WAL |
| **Slow standby I/O** | Standby disk is slower than primary. WAL replay cannot keep up with write rate. |
| **Network bottleneck** | Bandwidth between primary and standby saturated. WAL segments delayed in transit. |
| **Long queries on standby** | hot_standby_feedback=on + long query blocks WAL replay to avoid conflict. |
| **max_wal_senders reached** | No available WAL sender slots. New replication connections refused. |
| **Standby paused** | pg_wal_replay_pause() was called and never resumed. Check recovery state. |

### Root Cause Analysis
The root cause is a combination. A bulk data import on the primary is generating 500 megabytes of WAL per minute. Meanwhile, a long-running reporting query on the standby has been running for 25 minutes, and with hot_standby_feedback enabled, it is blocking WAL replay to avoid conflicting with that query. The standby cannot apply WAL while the reporting query holds a snapshot. The lag is growing every second.

- Primary: bulk import running — Generating ~500 MB WAL/minute. Bulk INSERT of 10 million rows from CSV file.
- Standby: 25-minute reporting query — SELECT with GROUP BY scanning 3 months of data. Holds a snapshot.
- hot_standby_feedback = on — Standby tells primary not to vacuum rows the query needs. Prevents conflict.
- WAL replay blocked — Standby cannot apply WAL that conflicts with the running query. Lag grows.
- Combined effect — Fast writes + blocked replay = rapidly increasing lag (460 MB and growing).

### Prevention — Replication Lag
To prevent this in the future, set max_standby_streaming_delay to 30 seconds — any query blocking replay longer than 30 seconds is automatically cancelled. Move heavy reporting queries to a dedicated analytics replica that tolerates higher lag. If doing bulk imports, batch them in smaller chunks with short pauses to let the standby catch up. Monitor lag and alert at 10 seconds.

- max_standby_streaming_delay = 30s — Auto-cancel queries blocking replay > 30 seconds on standby.
- Dedicated analytics replica — Route heavy reports to a separate replica. Tolerates lag. Protects fast reads.
- Batch bulk imports — Insert in 10K-50K row batches. pg_sleep(0.1) between batches. Gives standby time.
- Monitor lag — Alert at 10 seconds lag. Alert at 30 seconds critical. Dashboard with lag trend.
- Tune wal_keep_size — Keep enough WAL for standby to recover. Default 0 = rely on archiving. Set 2-5 GB.

### Root Cause Analysis
The root cause has two parts. First, 120 idle connections mean the application is not using a connection pool — each web request opens a new database connection and does not close it properly. Second, 50 idle in transaction connections mean the application starts transactions but sometimes forgets to COMMIT or ROLLBACK — perhaps due to error handling bugs. Each leaked connection holds resources and counts against max_connections.

| Term | Meaning / Explanation |
| :--- | :--- |
| **120 idle connections** | App not using connection pool. Opens new connection per request, never closes. |
| **50 idle in transaction** | Transactions started but never committed/rolled back. Error handling bug in app. |
| **No connection pooler** | No PgBouncer between app and database. Each process holds a direct connection. |
| **No idle timeout** | idle_in_transaction_session_timeout not set. Leaked transactions stay forever. |
| **max_connections = 200** | Default is 100, increased to 200 but still not enough for unpooled connections. |

### Comparison
If these real-world scenarios are helping you troubleshoot production issues, please support the course. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All diagnostic queries included |
| Every donation helps! | PgBouncer config template |

### PgBouncer Pool Modes
PgBouncer has three pool modes. Transaction mode assigns a server connection only during a transaction — when the transaction ends, the connection returns to the pool. This is the most efficient for web applications. Session mode assigns a connection for the entire client session — similar to no pooling. Statement mode assigns per statement — fastest but does not support transactions. Use transaction mode for web apps.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Transaction Mode** | Connection returned to pool after each transaction. Best for web apps. |
| **Session Mode** | Connection held for entire client session. Like no pooling. For legacy apps. |
| **Statement Mode** | Connection returned after each statement. Fastest but no multi-statement transactions. |
| **Recommended** | Transaction mode for most web applications. Session mode only if needed. |

**Notes:**
- Transaction mode: 1000 app connections can share 25 PG connections
- Session mode: each app connection needs one PG connection

### Beginner Traps
Watch out for these traps. Never increase max_connections as the first response — each connection uses about 10 megabytes of memory. 1000 connections means 10 gigabytes just for connection overhead. Use a pooler instead. Never terminate all connections blindly — check if a connection is doing important work first. Never use PgBouncer in statement mode with applications that use transactions. And never ignore idle in transaction connections — they hold locks and prevent VACUUM.

- Raising max_connections blindly — Each connection uses ~10 MB RAM. 1000 conn = 10 GB overhead. Use a pooler instead.
- Terminating connections blindly — Check what each connection is doing. pg_terminate_backend kills mid-transaction work.
- PgBouncer statement mode + transactions — Statement mode does not support multi-statement transactions. Use transaction mode.
- Ignoring idle in transaction — These hold row locks and block VACUUM. Set timeout to auto-kill them.
- No superuser reserved slots — Always keep superuser_reserved_connections = 3 (default). Ensures DBA can connect.

### Practice Exercises
Here are your practice exercises. First, set up streaming replication and monitor lag with pg_stat_replication. Run a bulk INSERT on the primary and observe lag increase. Second, run a long query on the standby and observe how it affects replay lag. Cancel it and watch lag recover. Third, check your current connection count by state. Identify idle and idle in transaction connections. Fourth, install PgBouncer, configure transaction mode, and connect your application through it. Fifth, set idle_in_transaction_session_timeout and test that leaked transactions are killed automatically.

- Exercise 1 — Monitor replication lag. Bulk INSERT on primary. Observe lag increase and recovery.
- Exercise 2 — Run long query on standby. Watch lag grow. Cancel query. Observe lag recovery.
- Exercise 3 — Check pg_stat_activity by state. Count idle and idle-in-transaction connections.
- Exercise 4 — Install PgBouncer. Configure transaction mode. Connect app through port 6432.
- Exercise 5 — Set idle_in_transaction_session_timeout = 5min. Start transaction, wait. Verify kill.


---

## 3. Hands-On Commands & psql Output

### Scenario 1: Replication Lag — Detection
**Explanation:** The scenario. Your monitoring shows replication lag on the standby has jumped from milliseconds to 45 seconds and climbing. Users reading from the replica see stale data — an order placed 30 seconds ago does not appear. If lag continues to grow, the standby becomes useless for reads and may fall too far behind to recover. Let us diagnose why.

```sql
-- ALERT: Replication lag > 30 seconds and increasing
-- Step 1: Check lag on PRIMARY
primary=> SELECT client_addr, state, sent_lsn, replay_lsn,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
  pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_pretty
FROM pg_stat_replication;

 client_addr  | state     | lag_bytes  | lag_pretty
--------------+-----------+------------+-----------
 10.0.1.20    | streaming |  482344960 | 460 MB

-- Step 2: Check lag on STANDBY
standby=> SELECT now() - pg_last_xact_replay_timestamp() AS lag;
      lag
---------------
 00:00:45.123
```

### Diagnosis — Find the Root Cause
**Explanation:** Diagnose step by step. First, check if the standby has long-running queries — these can block WAL replay. Here we find a reporting query running for 25 minutes. While that query runs, the standby cannot apply WAL that would change data the query is reading. Second, check the primary's write rate — pg_stat_wal shows how much WAL is being generated. A bulk import is generating 500 megabytes per minute.

```sql
-- On STANDBY: check for long-running queries
standby=> SELECT pid, now() - query_start AS duration,
  left(query, 60) AS query
FROM pg_stat_activity
WHERE state = 'active' ORDER BY duration DESC;

 pid  | duration        | query
------+-----------------+-------------------------------------
 8821 | 00:25:12.456    | SELECT date_trunc('month', created_

-- On PRIMARY: check WAL generation rate
primary=> SELECT pg_size_pretty(
  pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')
) AS total_wal_generated;
 total_wal_generated
---------------------
 89 GB
```

### Fix — Resolve Replication Lag
**Explanation:** The immediate fix: cancel or terminate the long-running query on the standby. Once the query is gone, WAL replay resumes and the standby catches up. For the bulk import, you can throttle it — add a small delay between batches. For the long term, set max_standby_streaming_delay to limit how long a query can block replay. And move heavy reporting to a dedicated replica that tolerates lag.

```sql
-- Immediate: cancel the blocking query on standby
standby=> SELECT pg_cancel_backend(8821);
 pg_cancel_backend
-------------------
 t

-- Watch lag recover (run on primary, repeat every 5 sec)
primary=> SELECT pg_size_pretty(
  pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag
FROM pg_stat_replication;
 lag     -- 460 MB → 200 MB → 50 MB → 0 bytes

-- Long-term: limit standby delay to 30 seconds
-- On standby postgresql.conf:
-- max_standby_streaming_delay = 30s
-- (queries running > 30s are cancelled automatically)
```

### Scenario 2: Connection Limit — Detection
**Explanation:** The second scenario. Your application suddenly starts throwing errors — FATAL: too many connections for role app_user. Or FATAL: sorry, too many clients already. Users cannot log in. The application is down. Your monitoring shows max_connections reached. This is an emergency that affects every user. Let us diagnose immediately.

```sql
-- ERROR in application logs:
FATAL: sorry, too many clients already
FATAL: remaining connection slots are reserved for
  non-replication superuser connections

-- Check current vs max connections
myapp=> SELECT count(*) AS current_connections,
  (SELECT setting::int FROM pg_settings
   WHERE name = 'max_connections') AS max_connections
FROM pg_stat_activity;

 current_connections | max_connections
---------------------+----------------
                 198 |            200
```

### Diagnosis — Where Are Connections Going?
**Explanation:** 198 of 200 connections are used. Let us find out who is holding them. Group connections by state and by user. We find 120 connections in idle state — meaning the application opened connections and is not using them. 50 connections are idle in transaction — a transaction was started but never committed or rolled back. Only 28 connections are actually active. The problem is connection leaks and idle transactions.

```sql
-- Connections by state
myapp=> SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
 state               | count
---------------------+-------
 active              |    28
 idle                |   120
 idle in transaction |    50

-- Connections by user
myapp=> SELECT usename, count(*) FROM pg_stat_activity GROUP BY usename ORDER BY count DESC;
 usename    | count
------------+-------
 app_user   |   165
 report_user|    25
 postgres   |     5
 repl_user  |     3
```

### Immediate Fix — Kill Idle Transactions
**Explanation:** The immediate fix is to terminate the idle in transaction connections that have been stuck for more than 5 minutes. This frees up 50 connections immediately. Then set idle_in_transaction_session_timeout to automatically kill future leaked transactions. This buys you time while you deploy the real fix — a connection pooler.

```sql
-- Kill idle-in-transaction connections > 5 minutes
myapp=> SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND now() - state_change > interval '5 minutes';
 pg_terminate_backend
  (48 rows terminated)

-- Set timeout to auto-kill future leaked transactions
myapp=> ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';
myapp=> SELECT pg_reload_conf();

-- Verify connections freed
myapp=> SELECT count(*) FROM pg_stat_activity;
 count
-------
   150
```

### Real Fix — Deploy PgBouncer
**Explanation:** The real fix is to deploy PgBouncer as a connection pooler between your application and PostgreSQL. PgBouncer maintains a pool of database connections and multiplexes application connections through them. Your application connects to PgBouncer on port 6432. PgBouncer reuses a small pool of actual PostgreSQL connections. 1000 application connections can share 25 database connections in transaction mode.

```sql
# Install PgBouncer
$ sudo apt install pgbouncer

# /etc/pgbouncer/pgbouncer.ini
[databases]
myapp = host=127.0.0.1 port=5432 dbname=myapp

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
min_pool_size = 5
reserve_pool_size = 5

# App connects to port 6432 now, NOT 5432
```

### PgBouncer — Monitor Pool Status
**Explanation:** How large should the pool be? A good starting point is 2 to 3 times the number of CPU cores on the database server. A 4-core server should have a pool of 8 to 12 connections. More connections do not mean more performance — PostgreSQL performs worse with too many concurrent queries due to context switching. Monitor the pool — if wait time is high, increase pool_size slightly. If active connections are always less than pool_size, decrease it.

```sql
# Connect to PgBouncer admin console
$ psql -h 127.0.0.1 -p 6432 -U pgbouncer pgbouncer

pgbouncer=# SHOW POOLS;
 database | user     | cl_active | cl_waiting | sv_active | sv_idle | pool_size
----------+----------+-----------+------------+-----------+---------+----------
 myapp    | app_user |       145 |          0 |        12 |      13 |       25

-- cl_active: 145 app connections active
-- cl_waiting: 0 (no one waiting — pool is big enough)
-- sv_active: 12 PG connections working
-- sv_idle: 13 PG connections available
-- 145 app connections sharing 25 PG connections!
```

### Prevention — Connection Management
**Explanation:** To prevent connection exhaustion in the future, always use a connection pooler in production. Set idle_in_transaction_session_timeout to 5 minutes to auto-kill leaked transactions. Set idle_session_timeout to 30 minutes to close truly idle connections. Set connection limits per role so no single application can take all connections. Monitor connection count and alert at 80 percent of max_connections.

```sql
-- Auto-kill leaked transactions after 5 minutes
myapp=> ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';

-- Close idle sessions after 30 minutes
myapp=> ALTER SYSTEM SET idle_session_timeout = '30min';

-- Limit connections per role
myapp=> ALTER ROLE app_user CONNECTION LIMIT 100;
myapp=> ALTER ROLE report_user CONNECTION LIMIT 20;

myapp=> SELECT pg_reload_conf();

-- Monitor: alert at 80% of max_connections
-- max_connections = 200 → alert at 160
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these traps. Never increase max_connections as the first response — each connection uses about 10 megabytes of memory. 1000 connections means 10 gigabytes just for connection overhead. Use a pooler instead. Never terminate all connections blindly — check if a connection is doing important work first. Never use PgBouncer in statement mode with applications that use transactions. And never ignore idle in transaction connections — they hold locks and prevent VACUUM.

- Raising max_connections blindly — Each connection uses ~10 MB RAM. 1000 conn = 10 GB overhead. Use a pooler instead.
- Terminating connections blindly — Check what each connection is doing. pg_terminate_backend kills mid-transaction work.
- PgBouncer statement mode + transactions — Statement mode does not support multi-statement transactions. Use transaction mode.
- Ignoring idle in transaction — These hold row locks and block VACUUM. Set timeout to auto-kill them.
- No superuser reserved slots — Always keep superuser_reserved_connections = 3 (default). Ensures DBA can connect.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. Replication lag: check pg_stat_replication for lag bytes, look for long queries blocking replay on the standby, set max_standby_streaming_delay, use dedicated replicas for heavy reporting. Connection exhaustion: group connections by state to find leaks, kill idle in transaction connections, deploy PgBouncer for connection pooling, set timeouts to auto-kill leaked connections, limit connections per role, and alert at 80 percent of max_connections.

- **Replication lag: check pg_stat_replication for lag_bytes**
- **Long queries on standby block WAL replay — cancel or set timeout**
- **max_standby_streaming_delay = 30s auto-cancels blocking queries**
- **Dedicated analytics replica for heavy reports (tolerates lag)**
- **Connection limit: group by state — find idle and idle in transaction**
- **PgBouncer: 1000 app connections share 25 PG connections**
- **idle_in_transaction_session_timeout = 5min auto-kills leaked txns**
- **Never raise max_connections as first fix — use a pooler**


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
