# pg_stat_activity & Lock Troubleshooting — Who Is Doing What and Who Is Blocking Whom
**Series:** PostgreSQL Mastery | **Phase:** Phase 23: Monitoring & Troubleshooting | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class we explored system catalogs and statistics views for overall database health. But when something is wrong RIGHT NOW — a query is stuck, connections are piling up, or the application is timing out — you need to see live activity. pg_stat_activity shows you every connection and what it is doing. pg_locks shows you who is holding locks and who is waiting. Let us master real-time troubleshooting.


---

## 2. Core Technical Concepts & Mechanisms

### pg_stat_activity — Key Columns
pg_stat_activity has one row per backend process — every active connection to your database. The most important columns are pid, state, query, and wait_event_type. State tells you if the connection is active, idle, or stuck in a transaction.

| Term | Meaning / Explanation |
| :--- | :--- |
| **pid** | Process ID — use to cancel or terminate a session |
| **state** | active, idle, idle in transaction, idle in transaction (aborted), disabled |
| **query** | The last or currently running SQL statement |
| **wait_event_type / wait_event** | What the process is waiting for (Lock, IO, Client, etc.) |
| **xact_start / query_start / state_change** | Timestamps for transaction, query, and state changes |

**Notes:**
- backend_type: 'client backend' = user connection
- datname: which database the connection is using
- usename: which PostgreSQL role is connected
- client_addr: IP address of the client

### Connection States Explained
The connection states tell a clear story. Active means running a query right now. Idle means waiting for the next query. Idle in transaction means a BEGIN was issued but no COMMIT or ROLLBACK yet — this is dangerous because it holds locks. Idle in transaction aborted means an error occurred inside a transaction but it was not rolled back.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Active** | running a query right now |
| **Idle** | waiting for the next query |
| **Idle in transaction** | a BEGIN was issued but no COMMIT or ROLLBACK yet — this is dangerous because it holds locks |
| **Idle in transaction aborted** | an error occurred inside a transaction but it was not rolled back |

### Wait Event Types
Now let us look at wait events. When a query is not actively running on CPU, it is waiting for something — a lock, disk I/O, network, or the client. The wait_event_type and wait_event columns tell you exactly what.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | When a query is not actively running on CPU, it is waiting for something — a lock, disk I/O, network, or the client |
| **Point 2** | The wait_event_type and wait_event columns tell you exactly what |

### PostgreSQL Lock Levels
Now let us dive into pg_locks — the view that shows every lock held or awaited in the system. Understanding locks is critical for diagnosing why queries are stuck. PostgreSQL uses multiple lock levels, from the lightweight AccessShareLock for SELECT to the heavy AccessExclusiveLock for ALTER TABLE.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Now let us dive into pg_locks** | the view that shows every lock held or awaited in the system |
| **Point 2** | Understanding locks is critical for diagnosing why queries are stuck |
| **PostgreSQL uses multiple lock levels** | from the lightweight AccessShareLock for SELECT to the heavy AccessExclusiveLock for ALTER TABLE |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Lock Investigation Workflow
Here is the complete lock investigation workflow — a step-by-step process you should follow whenever the application reports slowness or timeouts.

- Step 1: Check for blocked sessions -- SELECT pid, pg_blocking_pids(pid), state, query FROM pg_stat_activity WHERE cardinality(pg_blocking_pids(pid)) > 0;
- Step 2: Identify the blocker -- Look at the blocker's state — 'idle in transaction' is the most common cause
- Step 3: Decide: cancel or terminate -- pg_cancel_backend(pid) for graceful, pg_terminate_backend(pid) for force kill
- Step 4: Verify resolution -- Re-run the blocked sessions query — should now be empty
- Step 5: Prevent recurrence -- Set idle_in_transaction_session_timeout, lock_timeout, and fix application code

### pg_cancel_backend vs pg_terminate_backend
A beginner trap: trying to cancel queries using pg_cancel_backend on a session that is idle in transaction. pg_cancel_backend only cancels the CURRENT query. If the session is idle in transaction, there is no running query to cancel — you must use pg_terminate_backend instead.

| pg_cancel_backend(pid) | pg_terminate_backend(pid) |
| :--- | :--- |
| Cancels the current RUNNING query | KILLS the entire connection |
| Session stays connected | Session is disconnected |
| Transaction is rolled back | All locks released immediately |
| Application can retry the query | Application must reconnect |
| Does NOTHING on idle sessions | Works on any state including idle |
| Safe — preferred first step | Use when cancel doesn't work |

### Live Troubleshooting Cheat Sheet
Here is your complete troubleshooting cheat sheet for live issues.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is your complete troubleshooting cheat sheet for live issues |


---

## 3. Hands-On Commands & psql Output

### pg_stat_activity — See All Active Queries
**Explanation:** Here is the essential pg_stat_activity query. This shows you every active connection, what it is running, and how long it has been running. Sort by duration to find the longest-running queries.

```sql
SELECT
    pid,
    usename AS user,
    client_addr,
    state,
    now() - query_start AS query_duration,
    now() - xact_start AS txn_duration,
    wait_event_type,
    wait_event,
    LEFT(query, 80) AS query
postgres-# FROM pg_stat_activity
postgres-# WHERE backend_type = 'client backend'
postgres-# AND pid != pg_backend_pid()  -- exclude yourself
postgres-# ORDER BY query_start;
  pid  | user  | client_addr | state  | query_duration | wait_event_type | query
postgres=# -------+-------+-------------+--------+----------------+-----------------+------
 12345 | app   | 10.0.1.5    | active | 00:00:00.5     |                 | SELECT * FROM orders WHERE...
 12346 | app   | 10.0.1.5    | active | 00:02:15.3     | Lock            | UPDATE orders SET status...
 12347 | admin | 10.0.1.1    | idle in transaction | 00:45:00  | Client | COMMIT
 12348 | app   | 10.0.1.6    | idle   | 00:00:05.0     | Client          | SELECT 1
postgres=# -- pid 12346: running for 2+ minutes, waiting on a Lock!
postgres=# -- pid 12347: idle in transaction for 45 minutes → blocking!
```

### Finding Long-Running Queries
**Explanation:** Finding long-running queries is the most common troubleshooting task. A query running for minutes or hours could be holding locks, consuming memory, or saturating I/O. Here is how to find them.

```sql
postgres=# -- Queries running longer than 5 minutes:
SELECT
    pid,
    usename,
    now() - query_start AS duration,
    state,
    query
postgres-# FROM pg_stat_activity
postgres-# WHERE state = 'active'
postgres-# AND now() - query_start > interval '5 minutes'
postgres-# AND backend_type = 'client backend'
postgres-# ORDER BY query_start;
  pid  | usename | duration  | state  | query
postgres=# -------+---------+-----------+--------+-----------------------------------
 12346 | app     | 00:12:34  | active | SELECT * FROM orders o JOIN...
 12350 | report  | 00:45:21  | active | SELECT date_trunc('month',...
postgres=# -- Cancel a query (graceful — rolls back current statement):
postgres=# SELECT pg_cancel_backend(12346);
postgres=# -- Returns: true
postgres=# -- If cancel doesn't work, terminate (kills connection):
postgres=# SELECT pg_terminate_backend(12346);
postgres=# -- Returns: true
postgres=# -- WARNING: terminates the entire connection, not just the query
```

### Killing Idle-in-Transaction Sessions
**Explanation:** The most dangerous state is idle in transaction. A session that began a transaction and then stopped sending queries — maybe the application crashed, maybe a developer left psql open — holds all its locks indefinitely. Other sessions waiting for those locks pile up until the application appears frozen.

```sql
postgres=# -- Find idle-in-transaction sessions:
SELECT
    pid,
    usename,
    now() - xact_start AS txn_age,
    now() - state_change AS idle_time,
    LEFT(query, 60) AS last_query
postgres-# FROM pg_stat_activity
postgres-# WHERE state = 'idle in transaction'
postgres-# AND now() - state_change > interval '5 minutes'
postgres-# ORDER BY xact_start;
  pid  | usename | txn_age   | idle_time | last_query
postgres=# -------+---------+-----------+-----------+---------------------------
 12347 | admin   | 00:45:00  | 00:44:50  | UPDATE orders SET status...
postgres=# -- This session has been holding locks for 45 minutes!
postgres=# -- Terminate it:
postgres=# SELECT pg_terminate_backend(12347);
postgres=# -- PREVENT this with a timeout:
postgres=# -- postgresql.conf:
postgres=# -- idle_in_transaction_session_timeout = '5min'
postgres=# -- Kills sessions idle in transaction for > 5 minutes
```

### Finding Lock Blockers
**Explanation:** The most critical diagnostic query: finding who is blocking whom. This query joins pg_stat_activity with pg_locks to show the chain — the blocker and the blocked sessions.

```sql
postgres=# -- Who is blocking whom?
SELECT
    blocked.pid AS blocked_pid,
    blocked.usename AS blocked_user,
    LEFT(blocked.query, 50) AS blocked_query,
    now() - blocked.query_start AS blocked_duration,
    blocker.pid AS blocker_pid,
    blocker.usename AS blocker_user,
    blocker.state AS blocker_state,
    LEFT(blocker.query, 50) AS blocker_query
postgres-# FROM pg_stat_activity blocked
postgres-# JOIN pg_locks bl ON bl.pid = blocked.pid
postgres-# AND NOT bl.granted
postgres-# JOIN pg_locks gr ON gr.locktype = bl.locktype
postgres-# AND gr.database IS NOT DISTINCT FROM bl.database
postgres-# AND gr.relation IS NOT DISTINCT FROM bl.relation
postgres-# AND gr.page IS NOT DISTINCT FROM bl.page
postgres-# AND gr.tuple IS NOT DISTINCT FROM bl.tuple
postgres-# AND gr.pid != bl.pid
postgres-# AND gr.granted
postgres-# JOIN pg_stat_activity blocker ON blocker.pid = gr.pid
postgres-# WHERE blocked.state = 'active';
 blocked_pid | blocked_query          | blocker_pid | blocker_state
postgres=# -------------+------------------------+-------------+-------------------
       12346 | UPDATE orders SET s... |       12347 | idle in transaction
```

### pg_blocking_pids — Simpler Blocker Query
**Explanation:** PostgreSQL 14 introduced the pg_blocking_pids function which makes finding blockers much simpler. Instead of the complex lock join, you can use this single function call.

```sql
postgres=# -- Simpler blocker detection (PG 14+):
SELECT
    pid,
    usename,
    state,
    pg_blocking_pids(pid) AS blocked_by,
    now() - query_start AS duration,
    LEFT(query, 60) AS query
postgres-# FROM pg_stat_activity
postgres-# WHERE cardinality(pg_blocking_pids(pid)) > 0;
  pid  | usename | state  | blocked_by | duration  | query
postgres=# -------+---------+--------+------------+-----------+---------
 12346 | app     | active | {12347}    | 00:02:15  | UPDATE orders...
 12349 | app     | active | {12347}    | 00:01:45  | DELETE FROM orders...
postgres=# -- Both pid 12346 and 12349 are blocked by pid 12347!
postgres=# -- Check what 12347 is doing:
postgres=# SELECT pid, state, LEFT(query, 60)
postgres-# FROM pg_stat_activity WHERE pid = 12347;
  pid  |       state        | query
postgres=# -------+--------------------+---------------------------
 12347 | idle in transaction | UPDATE orders SET status...
```

### Deadlock Detection & Prevention
**Explanation:** Deadlocks happen when two sessions each hold a lock the other needs. PostgreSQL automatically detects deadlocks and kills one of the sessions. But you should investigate why deadlocks happen and fix the application logic.

```sql
postgres=# -- Deadlock scenario:
postgres=# -- Session A: UPDATE orders SET amount = 100 WHERE id = 1;
postgres=# --            UPDATE orders SET amount = 200 WHERE id = 2;
postgres=# -- Session B: UPDATE orders SET amount = 300 WHERE id = 2;
postgres=# --            UPDATE orders SET amount = 400 WHERE id = 1;
postgres=# -- → DEADLOCK!
postgres=# -- PostgreSQL detects it and kills one:
postgres=# -- ERROR: deadlock detected
postgres=# -- DETAIL: Process 12346 waits for ShareLock on transaction 5432;
postgres=# --   blocked by process 12347.
postgres=# --   Process 12347 waits for ShareLock on transaction 5431;
postgres=# --   blocked by process 12346.
postgres=# -- Check deadlock count:
postgres=# SELECT deadlocks FROM pg_stat_database
postgres-# WHERE datname = current_database();
postgres=# -- PREVENTION:
postgres=# -- 1. Always lock rows in the same order (ORDER BY id)
postgres=# -- 2. Keep transactions short
postgres=# -- 3. Use SELECT FOR UPDATE NOWAIT to fail fast
postgres=# -- 4. Set lock_timeout:
postgres=# SET lock_timeout = '10s';
postgres=# -- Query fails after 10s instead of waiting forever
```

### Inspecting Locks Held by a Session
**Explanation:** You can also check what locks a specific session holds — useful for understanding why a particular session is blocking others.

```sql
postgres=# -- All locks held by pid 12347:
SELECT
    l.locktype,
    l.relation::regclass AS table_name,
    l.mode,
    l.granted,
    l.pid
postgres-# FROM pg_locks l
postgres-# WHERE l.pid = 12347
postgres-# AND l.locktype = 'relation'
postgres-# ORDER BY l.relation;
 locktype |  table_name | mode               | granted | pid
postgres=# ----------+-------------+--------------------+---------+------
 relation | orders      | RowExclusiveLock   | t       | 12347
 relation | orders_pkey | RowExclusiveLock   | t       | 12347
 relation | customers   | AccessShareLock    | t       | 12347
postgres=# -- pid 12347 holds RowExclusiveLock on orders
postgres=# -- (from an UPDATE/INSERT/DELETE)
postgres=# -- and AccessShareLock on customers (from a SELECT)
postgres=# -- If another session tries ALTER TABLE orders or
postgres=# -- VACUUM FULL orders, it will be blocked!
```

### Connection Monitoring
**Explanation:** Connection monitoring is also critical. If connections climb toward max_connections, new connections are refused and the application crashes. Here is how to monitor connection usage.

```sql
postgres=# -- Connection usage summary:
SELECT
    count(*) AS total,
    count(*) FILTER (WHERE state = 'active') AS active,
    count(*) FILTER (WHERE state = 'idle') AS idle,
    count(*) FILTER (
postgres-# WHERE state = 'idle in transaction'
    ) AS idle_in_txn,
    (SELECT setting::int FROM pg_settings
postgres-# WHERE name = 'max_connections') AS max_conn,
    ROUND(100.0 * count(*) / (
postgres=# SELECT setting::int FROM pg_settings
postgres-# WHERE name = 'max_connections'
    ), 1) AS usage_pct
postgres-# FROM pg_stat_activity
postgres-# WHERE backend_type = 'client backend';
 total | active | idle | idle_in_txn | max_conn | usage_pct
postgres=# -------+--------+------+-------------+----------+----------
    85 |     12 |   68 |           5 |      100 |      85.0
postgres=# -- 85% used! Only 15 slots left.
postgres=# -- 68 idle connections → connection pool leak?
postgres=# -- 5 idle in transaction → these hold locks for nothing
postgres=# -- Per-user breakdown:
postgres=# SELECT usename, count(*) AS connections
postgres-# FROM pg_stat_activity
postgres-# WHERE backend_type = 'client backend'
postgres-# GROUP BY usename
postgres-# ORDER BY count(*) DESC;
```

### Advisory Locks — Application-Level Coordination
**Explanation:** Let us look at advisory locks — a special type of lock that applications use voluntarily to coordinate work. Unlike row locks, advisory locks are not tied to any table. They are useful for ensuring only one instance of a cron job runs at a time.

```sql
postgres=# -- Acquire an advisory lock (blocks if already held):
postgres=# SELECT pg_advisory_lock(12345);
postgres=# -- Returns immediately if lock is free
postgres=# -- Blocks if another session holds lock 12345
postgres=# -- Try to acquire without blocking:
postgres=# SELECT pg_try_advisory_lock(12345);
postgres=# -- Returns TRUE if acquired, FALSE if already held
postgres=# -- Release:
postgres=# SELECT pg_advisory_unlock(12345);
postgres=# -- USE CASE: ensure only one cron job runs:
postgres=# -- In your cron script:
postgres=# -- IF pg_try_advisory_lock(100) THEN
postgres=# --     ... run the job ...
postgres=# --     SELECT pg_advisory_unlock(100);
postgres=# -- ELSE
postgres=# --     RAISE NOTICE 'Job already running, skipping';
postgres=# -- END IF;
postgres=# -- Check active advisory locks:
postgres=# SELECT * FROM pg_locks
postgres-# WHERE locktype = 'advisory';
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — Production Timeout Settings
Here are the essential timeout parameters that prevent lock problems before they start. Setting these in production is critical. You can apply these parameters without downtime by executing SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `idle_in_transaction_session_timeout` | `5min` | `[RELOAD]` (Live Reload `SIGHUP`) | 10min to kill hung locks (Default: 0) |
| `statement_timeout` | `60s` | `[RELOAD]` (Live Reload `SIGHUP`) | 30s to prevent runaway queries (Default: 0) |
| `lock_timeout` | `10s` | `[RELOAD]` (Live Reload `SIGHUP`) | 5s to prevent lock queue pileup (Default: 0) |
| `deadlock_timeout` | `1s` | `[RELOAD]` (Live Reload `SIGHUP`) | Time before checking for deadlocks (Default: 1s) |
| `log_lock_waits` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | on to log queries waiting > deadlock_timeout (Default: off) |



---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. pg_stat_activity shows every connection — its state, query, duration, and wait events. Use it to find long-running queries, idle-in-transaction sessions, and connection usage. pg_locks combined with pg_blocking_pids identifies who is blocking whom. pg_cancel_backend gracefully cancels queries; pg_terminate_backend force-kills connections. Set idle_in_transaction_session_timeout, statement_timeout, and lock_timeout to prevent lock problems automatically. In the next class, we cover logging configuration and pgBadger for analyzing historical performance.

- **pg_stat_activity: one row per connection — state, query, wait events**
- **States: active, idle, idle in transaction (dangerous!)**
- **Find long queries: WHERE state='active' ORDER BY query_start**
- **pg_blocking_pids(pid): shows who blocks a given session**
- **pg_cancel_backend: cancel query (session stays)**
- **pg_terminate_backend: kill connection (session dropped)**
- **Lock levels: AccessShare (SELECT) → AccessExclusive (ALTER TABLE)**
- **Deadlocks: auto-detected, fix by consistent lock ordering**
- **Set timeouts: idle_in_transaction, statement, lock_timeout**
- **log_lock_waits = on: log when sessions wait for locks**
- **Next: Logging Configuration & pgBadger**


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
