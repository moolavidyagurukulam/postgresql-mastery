# postgresql.conf Deep Dive
**Series:** PostgreSQL Mastery | **Phase:** Phase 16: Administration Basics | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we dive deep into postgresql.conf — the main configuration file that controls how PostgreSQL behaves. Every setting from memory allocation to logging to query planning lives here. A poorly configured PostgreSQL runs on default settings designed for a laptop — not a production server. By the end of this class, you will know every important parameter, what it does, and how to set it correctly for your workload. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Parameter Contexts — When Changes Take Effect
Before we change anything, you need to understand the context column in pg_settings. It tells you when a change takes effect. postmaster means you must restart PostgreSQL — the setting is read only at startup. sighup means you can reload without restarting using pg_reload_conf or pg_ctl reload. superuser means any superuser can change it for their session with SET. user means any user can change it for their session. This matters because restarting PostgreSQL means brief downtime.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Before we change anything** | you need to understand the context column in pg_settings |
| **Point 2** | It tells you when a change takes effect |
| **Point 3** | postmaster means you must restart PostgreSQL — the setting is read only at startup |
| **Point 4** | sighup means you can reload without restarting using pg_reload_conf or pg_ctl reload |
| **Point 5** | superuser means any superuser can change it for their session with SET |
| **Point 6** | user means any user can change it for their session |
| **Point 7** | This matters because restarting PostgreSQL means brief downtime |

### Memory: work_mem
work_mem controls how much memory each sort or hash operation can use before spilling to disk. The default is 4 megabytes. This is per-operation, not per-connection — a single complex query with three sorts and two hash joins uses up to five times work_mem. Be careful: if you set it to 256 MB and 100 connections each run a query with 3 sorts, that is 75 GB of memory just for sorting. Start with 16 to 64 MB for most workloads, and increase it per-session for specific heavy queries.

| What It Controls | Safe Sizing |
| :--- | :--- |
| Memory per sort operation | OLTP (many connections): 16-32MB |
| Memory per hash join/aggregate | OLAP (few heavy queries): 128-256MB |
| Per-OPERATION, not per-query | Formula: RAM / (max_connections × 3) |
| Default: 4MB (too low) | Per-session override: SET work_mem = '256MB'; |
| Context: user (any session) | Check: EXPLAIN (ANALYZE, BUFFERS) |

### Planner: effective_cache_size
effective_cache_size is NOT a memory allocation — it is a hint to the query planner about how much memory is available for caching between PostgreSQL's shared_buffers and the operating system's file cache combined. A higher value makes the planner more likely to choose index scans over sequential scans, because it assumes data will be cached. Set it to about 75 percent of total RAM. On a 16 GB server, set it to 12 GB. Getting this wrong does not crash anything, but it makes the planner choose worse query plans.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What It Is** | A HINT to the planner, not an actual memory allocation |
| **What It Does** | Higher value = planner favors index scans (assumes data is cached) |
| **Default** | 4GB — too low for most servers |
| **Recommended** | 75% of total RAM (shared_buffers + OS cache combined) |

**Notes:**
- Context: user — can change per session
- Does NOT reserve or allocate any memory

### Connection Parameters
Connection parameters. max_connections controls how many simultaneous client connections PostgreSQL accepts. The default is 100. Each connection uses about 5 to 10 MB of RAM for its own work memory. Do NOT just set this to 1000 — 1000 active connections performing sorts with 32 MB work_mem could use 32 GB of RAM. Instead, keep max_connections moderate — 100 to 200 — and use a connection pooler like PgBouncer in front. We will cover PgBouncer in a later class.

| Key Settings | Best Practice |
| :--- | :--- |
| max_connections = 100 (default) | Don't set max_connections > 200 |
| Each connection: ~5-10MB overhead | Use PgBouncer for connection pooling |
| superuser_reserved_connections = 3 | Reserve 3 connections for superuser |
| Context: postmaster (restart) | Set idle timeout: 5min for apps |
| idle_in_transaction_session_timeout | Monitor with pg_stat_activity |

### Beginner Trap: shared_buffers Too High
Here is a beginner trap: setting shared_buffers too high. If you set shared_buffers to 75 percent of RAM, the OS has almost no memory left for its own file cache. PostgreSQL relies on the OS cache as a second layer — when data is not in shared_buffers, the OS cache is the next stop before hitting disk. Starving the OS cache makes all file I/O slower, including WAL writes. The 25 percent rule exists because the remaining 75 percent serves the OS cache, work_mem, maintenance_work_mem, and the system itself.

- 1 -- Only 4GB left for everything else
- 2 -- File reads go to disk instead of OS cache — slower I/O
- 3 -- Not enough free memory for sort operations → spill to disk
- 4 -- Linux OOM killer may terminate PostgreSQL process!
- 5 -- shared_buffers = 25% RAM, effective_cache_size = 75% RAM

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too. Now let us look at the complete parameter decision framework.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Quick Reference: Server Sizing
Here is your quick reference for setting postgresql.conf on different server sizes. These are starting points — monitor your workload and adjust from there.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is your quick reference for setting postgresql.conf on different server sizes |
| **These are starting points** | monitor your workload and adjust from there |

### Tuning Order — What to Change First
Here is the decision framework for which parameters to tune first. Start with memory, then planner, then WAL, then logging. Do not change everything at once — change one parameter, test, observe, then move to the next.

- 1 -- shared_buffers, effective_cache_size, work_mem, maintenance_work_mem
- 2 -- random_page_cost (1.1 for SSD), effective_io_concurrency (200 for SSD)
- 3 -- max_wal_size, checkpoint_completion_target
- 4 -- log_min_duration_statement, log_statement = 'ddl'
- 5 -- Lower scale_factor, raise cost_limit for faster vacuum
- 6 -- max_connections — keep low, use PgBouncer

### Practice Exercises
Time to practice. Open psql and try these queries. First, run SHOW config_file to find your postgresql.conf location. Second, query pg_settings to find all parameters with context equals postmaster — these are the ones that need a restart. Third, find your current memory settings: shared_buffers, work_mem, maintenance_work_mem, effective_cache_size. Fourth, query pg_file_settings to check for any config file errors. Fifth, find all non-default parameters using the source column.

- 1 -- SHOW config_file; — note the path for the next class
- 2 -- SELECT name FROM pg_settings WHERE context = 'postmaster' ORDER BY name;
- 3 -- SELECT name, setting, unit FROM pg_settings WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size');
- 4 -- SELECT * FROM pg_file_settings WHERE error IS NOT NULL;
- 5 -- SELECT name, setting, boot_val FROM pg_settings WHERE source <> 'default';


---

## 3. Hands-On Commands & psql Output

### Finding postgresql.conf
**Explanation:** Where is postgresql.conf? On Windows, it is typically in C colon backslash Program Files backslash PostgreSQL backslash 16 backslash data. On Linux, it is usually in slash etc slash postgresql slash 16 slash main, or in the data directory. You can ask PostgreSQL itself where the file is by running SHOW config_file. You can also see every current setting with SHOW ALL, or query the pg_settings catalog for detailed information including description, min, max, and whether a restart is required.

```sql
postgres=# SHOW config_file;
               config_file
----------------------------------------------
 C:/Program Files/PostgreSQL/16/data/postgresql.conf
(1 row)
postgres=# SHOW data_directory;
            data_directory
----------------------------------------------
 C:/Program Files/PostgreSQL/16/data
(1 row)
postgres=# SELECT name, setting, unit, context
FROM pg_settings WHERE name = 'shared_buffers';
      name      | setting | unit | context
----------------+---------+------+------------
 shared_buffers | 16384   | 8kB  | postmaster
(1 row)
```

### Memory: shared_buffers
**Explanation:** Let us start with memory parameters — the most impactful settings. shared_buffers is the amount of RAM PostgreSQL uses for caching table and index data. The default is 128 megabytes — absurdly low for any real server. The rule of thumb: set it to 25 percent of total system RAM. On a 16 GB server, set it to 4 GB. On a 64 GB server, set it to 16 GB. Going above 40 percent rarely helps and can hurt because the OS file cache needs memory too.

```sql
postgres=# SHOW shared_buffers;
 shared_buffers
----------------
 128MB
(1 row)
-- 
-- -- Recommended values:
-- --   4 GB RAM  → shared_buffers = 1GB
-- --   8 GB RAM  → shared_buffers = 2GB
-- --  16 GB RAM  → shared_buffers = 4GB
-- --  32 GB RAM  → shared_buffers = 8GB
-- --  64 GB RAM  → shared_buffers = 16GB
-- -- Context: postmaster (requires restart)
```

### Memory: maintenance_work_mem
**Explanation:** maintenance_work_mem controls memory for maintenance operations like VACUUM, CREATE INDEX, and ALTER TABLE ADD FOREIGN KEY. These run less frequently but benefit enormously from more memory. The default is 64 megabytes. Set it to 512 MB or 1 GB on servers with enough RAM. Since only a few maintenance operations run at a time, you can afford to be generous. autovacuum_work_mem overrides this specifically for autovacuum workers — if not set, autovacuum uses maintenance_work_mem.

```sql
postgres=# SHOW maintenance_work_mem;
 maintenance_work_mem
----------------------
 64MB
(1 row)
postgres=# SHOW autovacuum_work_mem;
 autovacuum_work_mem
---------------------
 -1
(1 row)
-- -- -1 means: use maintenance_work_mem value
-- 
-- -- Recommended:
-- --   maintenance_work_mem = 512MB to 1GB
-- --   autovacuum_work_mem = 256MB (separate limit for vacuum)
-- -- Context: user (changeable per session)
```

### Checking Settings and Pending Changes
**Explanation:** Let us see how to check what the current settings are and whether any pending changes need a reload or restart. The pg_settings view has all the information. The pending_restart column tells you if a parameter has been changed but needs a restart to take effect. The pg_file_settings view shows what is in the config files, even before reloading — useful to check for syntax errors.

```sql
postgres=# SELECT name, setting, unit, source, pending_restart
FROM pg_settings WHERE pending_restart = true;
      name      | setting | unit |      source      | pending_restart
----------------+---------+------+------------------+----------------
 shared_buffers | 16384   | 8kB  | configuration file | t
(1 row)
-- -- shared_buffers changed in file but needs restart
postgres=# SELECT sourcefile, name, setting, applied, error
FROM pg_file_settings WHERE error IS NOT NULL;
 sourcefile | name | setting | applied | error
------------+------+---------+---------+-------
(0 rows)
-- -- No config errors — good!
```

### Beginner Trap: Reload vs Restart Confusion
**Explanation:** Another trap: changing parameters that need a restart, then only doing a reload. You change shared_buffers in postgresql.conf and run pg_reload_conf. It succeeds — no error. But SHOW shared_buffers still shows the old value. The parameter did not actually change because it requires a restart. Always check the context column in pg_settings to know whether a parameter needs reload or restart.

```sql
postgres=# -- You edited postgresql.conf: shared_buffers = '4GB'
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
(1 row)
postgres=# SHOW shared_buffers;
 shared_buffers
----------------
 128MB
(1 row)
-- -- Still 128MB! Reload is NOT enough.
-- -- shared_buffers has context = postmaster → RESTART needed
postgres=# SELECT name, context FROM pg_settings WHERE name = 'shared_buffers';
      name      |  context
----------------+------------
 shared_buffers | postmaster
(1 row)
```

### Finding Non-Default Parameters
**Explanation:** Here is a handy query to find all parameters that are different from their defaults. This is great for auditing a server you did not configure — you can immediately see what has been customized.

```sql
postgres=# SELECT name, setting, unit, boot_val, source
FROM pg_settings
WHERE source <> 'default'
  AND source <> 'override'
ORDER BY name;
          name          |  setting  | unit |  boot_val  |       source
------------------------+-----------+------+------------+------------------
 DateStyle              | ISO, MDY  |      | ISO, MDY   | configuration file
 lc_messages            | en_US.UTF-8|     |            | configuration file
 log_destination        | stderr    |      | stderr     | configuration file
 log_timezone           | Asia/Kolkata|    |            | configuration file
 max_connections        | 100       |      | 100        | configuration file
 shared_buffers         | 16384     | 8kB  | 16384      | configuration file
 timezone               | Asia/Kolkata|    | GMT        | configuration file
(7 rows)
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — Complete Memory Config — 16GB Server
Here is the complete memory configuration picture. Let us say you have a 16 GB server. shared_buffers gets 4 GB — that is PostgreSQL's own cache. The OS file cache gets about 8 GB — the kernel caches recently read files. work_mem gets 32 MB per sort — moderate for mixed workloads. maintenance_work_mem gets 1 GB for VACUUM and index builds. effective_cache_size is set to 12 GB — telling the planner that 4 GB shared buffers plus 8 GB OS cache equals 12 GB of effective caching. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `shared_buffers` | `4GB` | **`[RESTART]`** (Postmaster Restart) | 25% of 16GB RAM (Default: 128MB) |
| `work_mem` | `32MB` | `[RELOAD]` (Live Reload `SIGHUP`) | Per sort/hash operation (Default: 4MB) |
| `maintenance_work_mem` | `1GB` | `[RELOAD]` (Live Reload `SIGHUP`) | For VACUUM, CREATE INDEX (Default: 64MB) |
| `autovacuum_work_mem` | `256MB` | `[RELOAD]` (Live Reload `SIGHUP`) | Separate limit for autovacuum (Default: -1) |
| `effective_cache_size` | `12GB` | `[RELOAD]` (Live Reload `SIGHUP`) | 75% of RAM — planner hint (Default: 4GB) |
| `huge_pages` | `try` | **`[RESTART]`** (Postmaster Restart) | Use huge pages if OS supports it (Default: try) |
| `temp_buffers` | `32MB` | `[SESSION]` (Per Connection) | Per-session temp table cache (Default: 8MB) |


### File: `postgresql.conf` — WAL & Checkpoint Parameters
Now WAL and checkpoint parameters. wal_buffers controls the shared memory for WAL records before they are written to disk. The default auto setting calculates it as one thirty-second of shared_buffers, which is usually fine — about 64 MB on a 2 GB shared_buffers. checkpoint_completion_target controls how aggressively PostgreSQL spreads checkpoint writes over time. The default 0.9 is good — it means finish 90 percent of dirty page writes before the next checkpoint. max_wal_size controls how much WAL accumulates before a checkpoint is forced. The default 1 GB is too low for write-heavy workloads. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `wal_level` | `replica` | **`[RESTART]`** (Postmaster Restart) | Default. Enables replication & archiving (Default: replica) |
| `wal_buffers` | `-1` | **`[RESTART]`** (Postmaster Restart) | Auto: 1/32 of shared_buffers (usually fine) (Default: -1) |
| `max_wal_size` | `4GB` | `[RELOAD]` (Live Reload `SIGHUP`) | Default 1GB — raise for write-heavy loads (Default: 1GB) |
| `min_wal_size` | `1GB` | `[RELOAD]` (Live Reload `SIGHUP`) | Keep at least this much WAL space (Default: 80MB) |
| `checkpoint_completion_target` | `0.9` | `[RELOAD]` (Live Reload `SIGHUP`) | Spread writes over 90% of checkpoint interval (Default: 0.9) |
| `checkpoint_timeout` | `10min` | `[RELOAD]` (Live Reload `SIGHUP`) | Default 5min — can raise to 15min (Default: 5min) |


### File: `postgresql.conf` — Logging Parameters
Logging parameters determine what PostgreSQL records about its activity. log_destination controls where logs go — stderr is the default on Windows, syslog on Linux. logging_collector must be on to capture logs to files. log_directory and log_filename control where log files are saved and how they are named. log_min_duration_statement is extremely useful — it logs only queries that take longer than the specified time. Set it to 1000 for one second, or 500 for half a second, to catch slow queries without flooding your logs. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `logging_collector` | `on` | **`[RESTART]`** (Postmaster Restart) | Capture logs to files (Default: off) |
| `log_destination` | `'stderr'` | `[RELOAD]` (Live Reload `SIGHUP`) | stderr (Windows) or csvlog (Default: 'stderr') |
| `log_directory` | `'log'` | `[RELOAD]` (Live Reload `SIGHUP`) | Relative to data directory (Default: 'log') |
| `log_filename` | `'postgresql-%Y-%m-%d.log'` | `[RELOAD]` (Live Reload `SIGHUP`) | Daily rotation (Default: 'postgresql-%Y-%m-%d_%H%M%S.log') |
| `log_min_duration_statement` | `1000` | `[RELOAD]` (Live Reload `SIGHUP`) | Log queries > 1 second (ms) (Default: -1) |
| `log_statement` | `'ddl'` | `[SETTING]` | Log all DDL commands |
| `log_connections` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Log each new connection (Default: off) |
| `log_disconnections` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Log each disconnection (Default: off) |
| `log_line_prefix` | `'%t [%p]: [%l-1] user=%u,db=%d '` | `[SETTING]` | Rich log prefix |


### File: `postgresql.conf` — Planner / Performance Parameters
Query planner parameters. random_page_cost tells the planner how expensive a random disk read is compared to a sequential read. The default is 4.0, meaning random I/O is 4 times more expensive than sequential. If your database fits in RAM or runs on SSD, lower this to 1.1 — this makes the planner favor index scans more aggressively. effective_io_concurrency tells PostgreSQL how many concurrent I/O operations the disk can handle. For SSD, set it to 200. For a single spinning disk, leave it at 1. You can apply these parameters without downtime by executing SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `random_page_cost` | `1.1` | `[RELOAD]` (Live Reload `SIGHUP`) | Default 4.0 — lower for SSD (1.1-1.5) (Default: 4.0) |
| `seq_page_cost` | `1.0` | `[RELOAD]` (Live Reload `SIGHUP`) | Baseline cost (usually leave at 1.0) (Default: 1.0) |
| `effective_io_concurrency` | `200` | `[RELOAD]` (Live Reload `SIGHUP`) | Default 1 — raise for SSD (Default: 1) |
| `default_statistics_target` | `200` | `[RELOAD]` (Live Reload `SIGHUP`) | Default 100 — more histogram buckets (Default: 100) |
| `jit` | `on` | `[SETTING]` | Just-In-Time compilation for complex queries |
| `parallel_tuple_cost` | `0.01` | `[SETTING]` | Cost of passing row between workers |
| `max_parallel_workers_per_gather` | `4` | `[RELOAD]` (Live Reload `SIGHUP`) | Default 2 — raise for analytics (Default: 2) |


### File: `postgresql.conf` — Autovacuum Parameters
Autovacuum parameters. Autovacuum runs in the background, cleaning up dead rows left by UPDATE and DELETE operations. The defaults are conservative — designed to never impact a small database. On busy production tables, you often need to make autovacuum more aggressive. autovacuum_vacuum_scale_factor is the fraction of the table that must be dead before vacuum kicks in — the default 0.2 means 20 percent. For a 10-million-row table, that is 2 million dead rows before cleanup. Lower it to 0.05 or even 0.01 for large tables. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `autovacuum` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | NEVER turn off in production (Default: on) |
| `autovacuum_max_workers` | `5` | **`[RESTART]`** (Postmaster Restart) | Default 3 — raise for many tables (Default: 3) |
| `autovacuum_vacuum_threshold` | `50` | `[RELOAD]` (Live Reload `SIGHUP`) | Min dead rows before vacuum (Default: 50) |
| `autovacuum_vacuum_scale_factor` | `0.05` | `[RELOAD]` (Live Reload `SIGHUP`) | Default 0.2 — lower for large tables (Default: 0.2) |
| `autovacuum_analyze_threshold` | `50` | `[SETTING]` | Min changed rows before analyze |
| `autovacuum_analyze_scale_factor` | `0.025` | `[SETTING]` | Default 0.1 — lower for better plans |
| `autovacuum_vacuum_cost_delay` | `2` | `[RELOAD]` (Live Reload `SIGHUP`) | Default 2ms — lower = faster vacuum (Default: 2ms) |
| `autovacuum_vacuum_cost_limit` | `1000` | `[RELOAD]` (Live Reload `SIGHUP`) | Default 200 — raise for faster vacuum (Default: -1) |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: shared_buffers Too High
Here is a beginner trap: setting shared_buffers too high. If you set shared_buffers to 75 percent of RAM, the OS has almost no memory left for its own file cache. PostgreSQL relies on the OS cache as a second layer — when data is not in shared_buffers, the OS cache is the next stop before hitting disk. Starving the OS cache makes all file I/O slower, including WAL writes. The 25 percent rule exists because the remaining 75 percent serves the OS cache, work_mem, maintenance_work_mem, and the system itself.

- 1 -- Only 4GB left for everything else
- 2 -- File reads go to disk instead of OS cache — slower I/O
- 3 -- Not enough free memory for sort operations → spill to disk
- 4 -- Linux OOM killer may terminate PostgreSQL process!
- 5 -- shared_buffers = 25% RAM, effective_cache_size = 75% RAM

### Beginner Trap: Reload vs Restart Confusion
Another trap: changing parameters that need a restart, then only doing a reload. You change shared_buffers in postgresql.conf and run pg_reload_conf. It succeeds — no error. But SHOW shared_buffers still shows the old value. The parameter did not actually change because it requires a restart. Always check the context column in pg_settings to know whether a parameter needs reload or restart.

```sql
-- You edited postgresql.conf: shared_buffers = '4GB'
SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
(1 row)
SHOW shared_buffers;
 shared_buffers
----------------
 128MB
(1 row)
-- Still 128MB! Reload is NOT enough.
-- shared_buffers has context = postmaster → RESTART needed
SELECT name, context FROM pg_settings WHERE name = 'shared_buffers';
      name      |  context
----------------+------------
 shared_buffers | postmaster
(1 row)
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review what we covered. postgresql.conf is the main configuration file controlling memory, WAL, connections, logging, planner, and autovacuum. Parameters have contexts: postmaster needs restart, sighup needs reload, user or superuser can be set per session. The key memory formula is 25 percent for shared_buffers and 75 percent for effective_cache_size. work_mem is per-operation — be careful with high values and many connections. Always check pg_settings for current values and pg_file_settings for config errors.

- **SHOW config_file; to find the file location**
- **pg_settings: every parameter with context, source, pending_restart**
- **pg_file_settings: check for config errors before reload**
- **Memory: shared_buffers=25%RAM, effective_cache_size=75%RAM**
- **work_mem: per-operation, not per-connection — careful!**
- **WAL: raise max_wal_size for write-heavy workloads**
- **Logging: log_min_duration_statement catches slow queries**
- **Autovacuum: lower scale_factor for large tables**
- **Connections: keep max_connections low, use PgBouncer**
- **Context: postmaster=restart, sighup=reload, user=SET**


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
