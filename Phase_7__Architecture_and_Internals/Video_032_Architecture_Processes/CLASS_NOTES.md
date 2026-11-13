# PostgreSQL Architecture Overview & Processes
**Series:** PostgreSQL Mastery | **Phase:** Phase 9: Architecture | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we look INSIDE PostgreSQL — how it actually works under the hood. We will learn the process architecture, how client connections are handled, and what all those background processes do. Understanding this makes you a much better database administrator and developer.

### WHY Learn Architecture?
Why should you care about architecture? Because when things go wrong — and they will — you need to know where to look. If connections are being refused, you need to understand the postmaster. If queries are slow, you need to understand how memory and disk work together. If the server crashes, you need to understand WAL and checkpoints. Architecture knowledge is what separates someone who uses PostgreSQL from someone who runs it in production.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should be comfortable writing SQL — SELECT, JOINs, subqueries, CTEs. You know HOW to use PostgreSQL. Now we learn how PostgreSQL works INSIDE. In the previous class on CTEs and recursive queries, we wrote complex queries. But what happens when you hit Enter? How does PostgreSQL turn your SQL text into results? That journey starts here.

- You can write SQL: SELECT, JOIN, subqueries, CTEs
- You know how to USE PostgreSQL
- Now: how PostgreSQL WORKS internally
- Previous class: CTEs and recursive queries
- This class: the server processes that run your queries
- Next classes: memory, storage, query pipeline, MVCC

### WHY Learn Architecture?
Why should you care about architecture? Because when things go wrong — and they will — you need to know where to look. If connections are being refused, you need to understand the postmaster. If queries are slow, you need to understand how memory and disk work together. If the server crashes, you need to understand WAL and checkpoints. Architecture knowledge is what separates someone who uses PostgreSQL from someone who runs it in production.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Troubleshooting** | Know where to look when things break |
| **Performance** | Understand why queries are slow and how to fix them |
| **Crash Recovery** | Know how PostgreSQL recovers from failures |
| **Capacity Planning** | Size memory, connections, and storage correctly |
| **Production Confidence** | Run PostgreSQL knowing what happens under the hood |

### PostgreSQL Process Architecture
Here is the big picture. PostgreSQL is a client-server architecture. The server runs multiple processes — not threads. There is ONE main process called the postmaster. When a client connects, the postmaster forks a new backend process dedicated to that connection. So if you have fifty connections, you have fifty backend processes plus the postmaster plus several background worker processes. Each backend handles one client at a time.

```
[Client
(psql, app)]
[Postmaster
(PID 1 listener)]
[Backend
Process 1]
[Backend
Process 2]
[Backend
Process N]
[Background Workers
(autovacuum, WAL writer,
checkpointer, bgwriter)]
[Shared Memory
(shared_buffers, WAL buffers)]
```

### The Postmaster — The Boss Process
The postmaster is the main server process. It is the first process that starts when you run pg_ctl start or systemctl start postgresql. It listens on port fifty-four thirty-two by default. When a client connects, the postmaster authenticates them using pg_hba.conf, then forks a new backend process. The postmaster also starts and supervises all the background worker processes. If the postmaster dies, ALL connections die — it is the parent of everything.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What It Does** | Listens for connections, forks backends, supervises workers |
| **Port** | Default 5432, configured in postgresql.conf |
| **Auth** | Checks pg_hba.conf for each connection attempt |
| **Fork** | Creates a new backend process per client connection |
| **Supervision** | Restarts crashed background workers automatically |

**Notes:**
- If postmaster dies → ALL connections drop
- One postmaster per PostgreSQL instance

### Backend Processes — One Per Connection
Backend processes are where your queries actually run. Each connection gets its own dedicated backend process. When you type a SELECT in psql, YOUR backend process parses it, plans it, executes it, and sends the results back. Backends share memory through shared buffers but have their own private memory for sorting and hashing. When you disconnect, your backend process exits.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Created** | Forked by postmaster when client connects |
| **Dedicated** | One backend per connection, handles all its queries |
| **Lifecycle** | Parse → Plan → Execute → Return results |
| **Memory** | Uses shared buffers + own private memory (work_mem) |
| **Exits** | Process ends when client disconnects |

**Notes:**
- 50 connections = 50 backend processes
- Each uses ~5-10 MB base + work_mem per sort/hash

### Background Worker Processes
Now the background worker processes. These run continuously and handle maintenance tasks that keep PostgreSQL healthy. You never interact with them directly — they run automatically. There are seven main background workers. Let us go through each one.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Now the background worker processes |
| **Point 2** | These run continuously and handle maintenance tasks that keep PostgreSQL healthy |
| **You never interact with them directly** | they run automatically |
| **Point 4** | There are seven main background workers |

### Autovacuum — The Essential Cleanup Worker
The autovacuum launcher deserves special attention. It starts autovacuum worker processes that clean up dead rows left by UPDATE and DELETE. Without autovacuum, your tables would bloat — growing larger and larger with dead data. Autovacuum also updates the statistics that the query planner uses to choose good execution plans. Never disable autovacuum in production — it is essential for PostgreSQL health.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Launcher** | Background process that decides WHEN to vacuum |
| **Workers** | Separate processes that actually do the cleaning |
| **Dead Rows** | UPDATE/DELETE leave dead tuples — vacuum reclaims space |
| **Statistics** | ANALYZE updates stats for the query planner |
| **Default Workers** | 3 concurrent workers (autovacuum_max_workers) |

**Notes:**
- NEVER disable autovacuum in production!
- Tables with heavy UPDATE/DELETE need more frequent vacuuming

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. You can download today's class materials and practice files from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Every bit helps us keep creating. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Connection Limits & Pooling
Connection management is critical in production. Each connection uses memory — typically five to ten megabytes base plus work_mem for each sort or hash operation. One hundred connections means over a gigabyte just for connection overhead. This is why connection poolers like PgBouncer exist — they share a small number of actual database connections across many application threads.

| Direct Connections | With Connection Pooler |
| :--- | :--- |
| Each = one backend process | PgBouncer sits between app and PG |
| ~5-10 MB memory per connection | App opens 500 connections to pooler |
| Default max_connections = 100 | Pooler opens 20 real PG connections |
| 100 connections ≈ 1+ GB overhead | Huge memory savings |
| 500+ connections = very expensive | Essential for production at scale |

### Beginner Trap: Never kill -9 Postmaster!
Beginner trap: NEVER kill the postmaster process with kill minus nine on Linux, or End Task on the main postgres.exe in Windows. Killing the postmaster kills ALL connections instantly and forces crash recovery on restart. If you need to stop ONE misbehaving connection, use pg_terminate_backend with the specific PID. If you need to stop the entire server cleanly, use pg_ctl stop or systemctl stop postgresql — these send a graceful shutdown signal so connections finish cleanly and checkpoints complete.

| WRONG (Dangerous) | CORRECT (Safe) |
| :--- | :--- |
| kill -9 <postmaster_pid> | pg_terminate_backend(pid) — one connection |
| Kills ALL connections instantly | pg_ctl stop -m smart — wait for all to finish |
| No checkpoint — dirty data in memory | pg_ctl stop -m fast — rollback active txns |
| Forces crash recovery on restart | pg_ctl stop -m immediate — like crash (last resort) |
| Can corrupt data if WAL is incomplete | systemctl stop postgresql — calls pg_ctl stop |

### Practice Exercises
Practice exercises: check your backend PID, query pg_stat_activity, look at connection states, check max_connections, find idle-in-transaction connections, and try cancelling a query. These are the diagnostic commands you will use constantly when managing a PostgreSQL server.

- 1. SELECT pg_backend_pid(); — find your own process
- 2. Query pg_stat_activity — see all connections
- 3. Group connections by state (active, idle)
- 4. SHOW max_connections; — check the limit
- 5. Open two psql sessions — verify both appear in pg_stat_activity
- 6. pg_cancel_backend on a long query from another session
- 7. Check background processes: ps aux | grep postgres (Linux)


---

## 3. Hands-On Commands & psql Output

### See PostgreSQL Processes — OS Level
**Explanation:** You can see all PostgreSQL processes from the operating system. The ps command shows the postmaster and all its children. In PostgreSQL sixteen, you can also see every connection from inside psql using pg_stat_activity. And pg_backend_pid gives you YOUR own backend process ID. Let us see this in action.

```sql
-- Show all PostgreSQL processes (Linux/Mac)
$ ps aux | grep postgres | head -15
postgres  1234  ... postgres: postmaster
postgres  1240  ... postgres: checkpointer
postgres  1241  ... postgres: background writer
postgres  1242  ... postgres: walwriter
postgres  1243  ... postgres: autovacuum launcher
postgres  1244  ... postgres: stats collector
postgres  1245  ... postgres: logical replication launcher
postgres  5678  ... postgres: postgres practice [local] idle

-- postmaster = main listener
-- 5678 = your backend (connected to 'practice' database)
-- Windows: check Task Manager for postgres.exe processes
```

### See Connections — pg_stat_activity
**Explanation:** From inside psql, use pg_stat_activity to see all connections. This shows the process ID, database name, user, client address, current state, and what query is running. You can see your own connection, other users' connections, and identify idle connections that should be closed. pg_backend_pid tells you which process is handling YOUR session.

```sql
-- Your own backend PID
practice=# SELECT pg_backend_pid();
 pg_backend_pid
----------------
           5678

-- All active connections
practice=# SELECT pid, datname, usename, state, query
FROM pg_stat_activity WHERE datname IS NOT NULL;
  pid  | datname  | usename  | state  | query
-------+----------+----------+--------+------------------
  5678 | practice | postgres | active | SELECT pid, ...
  5690 | practice | webapp   | idle   |
(2 rows)

-- state: active (running), idle (waiting), idle in transaction
```

### Check Connection Settings
**Explanation:** You can check and set the maximum connections in PostgreSQL. SHOW max_connections tells you the current limit. To change it, edit postgresql.conf and restart. You can also see current connection usage from pg_stat_activity. If connections are being refused, either increase max_connections or — better — add a connection pooler.

```sql
-- Current maximum connections
practice=# SHOW max_connections;
 max_connections
-----------------
 100

-- How many connections are in use right now?
practice=# SELECT count(*) AS active_connections
FROM pg_stat_activity WHERE datname IS NOT NULL;
 active_connections
--------------------
                  2

-- Connections by state
practice=# SELECT state, count(*) FROM pg_stat_activity
WHERE datname IS NOT NULL GROUP BY state;
  state  | count
---------+-------
 active  |     1
 idle    |     1
```

### Cancel or Terminate a Connection
**Explanation:** If a connection is stuck or misbehaving, you can terminate it. pg_cancel_backend cancels the current query but keeps the connection alive. pg_terminate_backend kills the entire connection. Use cancel first — it is less disruptive. Only use terminate if cancel does not work.

```sql
-- Find the stuck query
practice=# SELECT pid, state, query, now() - query_start AS duration
FROM pg_stat_activity
WHERE state = 'active' AND pid <> pg_backend_pid();

-- Cancel the query (gentle — connection stays)
practice=# SELECT pg_cancel_backend(5690);
 pg_cancel_backend
-------------------
 t

-- Terminate the connection (forceful — connection drops)
practice=# SELECT pg_terminate_backend(5690);
 pg_terminate_backend
----------------------
 t

-- Try pg_cancel_backend FIRST, pg_terminate only if needed
```

### Find Idle-in-Transaction Connections
**Explanation:** A practical monitoring query: find connections that have been idle in transaction for too long. These hold locks and block VACUUM. This query shows the PID, how long the transaction has been open, and what query started it. In production, set the idle_in_transaction_session_timeout parameter to automatically kill these after a set time — for example, five minutes.

```sql
practice=# SELECT pid, usename, state,
  AGE(NOW(), state_change) AS idle_duration,
  LEFT(query, 60) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY state_change;
  pid  | usename | state               | idle_duration  | last_query
-------+---------+---------------------+----------------+-----------
  5690 | webapp  | idle in transaction | 00:12:34.567   | UPDATE ...

-- This connection has been idle in transaction for 12 minutes!
-- It holds locks and blocks VACUUM.

-- Auto-kill idle-in-transaction after 5 minutes:
practice=# ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';
ALTER SYSTEM
practice=# SELECT pg_reload_conf();
 t
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Never kill -9 Postmaster!
Beginner trap: NEVER kill the postmaster process with kill minus nine on Linux, or End Task on the main postgres.exe in Windows. Killing the postmaster kills ALL connections instantly and forces crash recovery on restart. If you need to stop ONE misbehaving connection, use pg_terminate_backend with the specific PID. If you need to stop the entire server cleanly, use pg_ctl stop or systemctl stop postgresql — these send a graceful shutdown signal so connections finish cleanly and checkpoints complete.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. PostgreSQL uses a multi-process architecture — not threads. The postmaster listens for connections and forks a backend process for each one. Each backend handles one client's queries. Background workers handle maintenance: checkpointer, background writer, WAL writer, autovacuum, stats collector, archiver, and logical replication launcher. Never disable autovacuum. Use pg_stat_activity to monitor connections. Use pg_cancel_backend and pg_terminate_backend to manage stuck queries. In the next class, we dive into Memory Architecture — shared buffers, work_mem, and how PostgreSQL uses RAM. See you there!

- **Multi-process: postmaster + backends + background workers**
- **Postmaster: listens on port 5432, forks backends**
- **One backend per connection (~5-10 MB each)**
- **7 background workers: checkpointer, bgwriter, WAL writer, autovacuum, stats, archiver, logical rep**
- **pg_stat_activity: see all connections and their state**
- **pg_backend_pid(): your own process ID**
- **pg_cancel_backend(pid): cancel query (gentle)**
- **pg_terminate_backend(pid): kill connection (forceful)**


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

### Exercise 1: Inspect Own Backend Process ID
```sql
SELECT pg_backend_pid() AS my_session_pid;
```
*Explanation:* PostgreSQL assigns a dedicated backend process for every client connection. `pg_backend_pid()` reveals your current session process identifier.

### Exercise 2: Monitor All Active Client Connections
```sql
SELECT pid, usename, datname, client_addr, state, LEFT(query, 50) AS current_query
FROM pg_stat_activity
WHERE backend_type = 'client backend';
```
*Explanation:* `pg_stat_activity` is the primary dynamic catalog view for real-time connection telemetry.

### Exercise 3: Aggregate Connection States
```sql
SELECT state, count(*) AS connection_count
FROM pg_stat_activity
GROUP BY state
ORDER BY connection_count DESC;
```
*Explanation:* Categorizing connections by `active`, `idle`, and `idle in transaction` helps detect connection leaks and application connection-pool misconfigurations.

### Exercise 4: Inspect Connection Ceilings
```sql
SHOW max_connections;
SHOW superuser_reserved_connections;
```
*Explanation:* `max_connections` defines the total concurrency ceiling. `superuser_reserved_connections` reserves slots for administrators to troubleshoot full servers.

### Exercise 5: Cancel vs Terminate Stuck Backends
```sql
-- Graceful cancellation of current running query (SIGINT):
SELECT pg_cancel_backend(12345);

-- Forceful termination of entire connection (SIGTERM):
SELECT pg_terminate_backend(12345);
```
*Explanation:* Always attempt `pg_cancel_backend` first. Never run OS `kill -9` on Postgres processes to avoid server-wide crash recovery!
