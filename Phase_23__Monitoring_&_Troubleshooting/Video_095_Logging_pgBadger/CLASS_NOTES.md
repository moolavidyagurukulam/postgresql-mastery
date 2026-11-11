# Logging Configuration & pgBadger — Capturing and Analyzing Performance History
**Series:** PostgreSQL Mastery | **Phase:** Phase 23: Monitoring & Troubleshooting | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! pg_stat_activity shows you what is happening RIGHT NOW. But what about yesterday's slow queries? Last week's lock conflicts? PostgreSQL's logging system captures everything — slow queries, errors, checkpoints, connections, and more. And pgBadger turns those logs into beautiful HTML reports. Let us configure logging properly and learn to read the data.


---

## 2. Core Technical Concepts & Mechanisms

### Three Layers of PostgreSQL Logging
PostgreSQL logging has three layers. First, the log destination — where logs go. Second, what gets logged — slow queries, connections, checkpoints, errors. Third, the log format — which determines what tools can parse them. Let us configure each layer.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Where (Destination)** | stderr (default), csvlog (CSV files), jsonlog (JSON, PG 15+), syslog |
| **What (Content)** | Slow queries, connections, checkpoints, locks, errors, DDL, temp files |
| **How (Format)** | log_line_prefix defines the fields in each log line — PID, timestamp, database, user |

**Notes:**
- csvlog is best for pgBadger analysis
- jsonlog (PG 15+) is best for log aggregation tools
- stderr with a good log_line_prefix works for most setups

### log_min_duration_statement vs log_statement
log_min_duration_statement versus log_statement — these are NOT the same thing. log_statement logs the query text when it STARTS. log_min_duration_statement logs the query text AND duration when it FINISHES. For performance monitoring, you want log_min_duration_statement. Setting log_statement to 'all' floods logs with every single query including fast ones.

| log_min_duration_statement | log_statement |
| :--- | :--- |
| Logs queries AFTER they finish | Logs queries BEFORE they run |
| Includes actual execution time | No duration information |
| Set threshold: 500ms, 1s, etc. | Options: none, ddl, mod, all |
| Only slow queries logged → manageable | 'all' = every single query (huge logs) |
| THIS is what you want for monitoring | Use 'ddl' for audit trail only |
| log_min_duration_statement = 500ms | Do NOT set to 'all' in production |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### pgBadger — PostgreSQL Log Analyzer
Now let us talk about pgBadger — a powerful log analyzer that reads PostgreSQL logs and generates detailed HTML reports. It shows you the slowest queries, most frequent queries, hourly traffic patterns, error distribution, checkpoint timing, connection patterns, and much more.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What It Does** | Parses PostgreSQL log files and generates detailed HTML performance reports |
| **Input** | PostgreSQL log files (stderr, csvlog, or syslog format) |
| **Output** | Interactive HTML report with charts, tables, and drill-downs |

**Notes:**
- Written in Perl — fast, handles huge log files
- Install: apt install pgbadger (or from GitHub)
- Requires log_min_duration_statement to be set
- Requires log_line_prefix to match pgBadger format
- Can generate incremental reports (daily)

### pgBadger Report Sections
The pgBadger report has several key sections. The Overview shows total queries, errors, and traffic patterns. Top Queries shows the slowest and most frequent queries. Here is what each section tells you.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | The pgBadger report has several key sections |
| **The Overview shows total queries** | errors, and traffic patterns |
| **Point 3** | Top Queries shows the slowest and most frequent queries |

### Choosing log_min_duration_statement Threshold
A common beginner trap: setting log_min_duration_statement to zero. This logs EVERY query regardless of duration — millions of log entries per hour on a busy server. Your disk fills up, the logging itself becomes a performance bottleneck, and pgBadger takes hours to parse the logs. Start with 500 milliseconds and lower to 100 milliseconds only if you need more detail.

- 0 (log everything) -- DANGER: millions of entries, disk fills fast, pgBadger slow. Only for brief debugging.
- 100ms -- Detailed — catches most sub-optimal queries. Good for development/staging.
- 500ms (recommended start) -- Balanced — catches genuinely slow queries without log flood. Good for production.
- 1000ms (1 second) -- Conservative — only the really slow queries. Good for high-traffic production.
- 5000ms (5 seconds) -- Minimal — only severely slow queries. Risk: misses many optimization opportunities.


---

## 3. Hands-On Commands & psql Output

### log_line_prefix — Essential Metadata
**Explanation:** The log_line_prefix is critical — it defines what metadata appears at the start of every log line. A good prefix includes timestamp, PID, user, database, and application name. pgBadger needs a specific prefix to parse logs correctly.

```sql
postgres=# -- Check current prefix:
postgres=# SHOW log_line_prefix;
postgres=# -- Default: '%m [%p] '
postgres=# -- Too minimal! Missing user, database, app
postgres=# -- Recommended prefix for pgBadger:
postgres=# -- log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h '
postgres=# -- Meaning of each escape:
postgres=# -- %t = timestamp without milliseconds
postgres=# -- %p = process ID
postgres=# -- %u = user name
postgres=# -- %d = database name
postgres=# -- %a = application name
postgres=# -- %h = client host
postgres=# -- %l = log line number (for multi-line statements)
postgres=# -- Example log line with this prefix:
postgres=# -- 2026-11-04 10:15:23 UTC [12345]: user=app,db=mydb,
postgres=# --   app=myapp,client=10.0.1.5 LOG: duration: 1523.456 ms
postgres=# --   statement: SELECT * FROM orders WHERE ...
postgres=# -- For csvlog format, prefix is ignored (CSV has all fields)
```

### Reading PostgreSQL Log Output
**Explanation:** Here is what the actual log output looks like with our configuration. Slow queries show the full SQL and their duration. Checkpoints show timing details. Connections and disconnections are tracked.

```sql
2026-11-04 10:15:23 UTC [12345]: user=app,db=mydb,
  app=myapp,client=10.0.1.5 LOG: duration: 1523.456 ms
  statement: SELECT o.id, o.amount, c.name
postgres-# FROM orders o JOIN customers c ON o.customer_id = c.id
postgres-# WHERE o.order_date > '2026-01-01' ORDER BY o.amount DESC
2026-11-04 10:16:00 UTC [1234]: LOG: checkpoint starting:
  time
2026-11-04 10:16:05 UTC [1234]: LOG: checkpoint complete:
  wrote 1234 buffers (5.2%); 0 WAL file(s) added,
  0 removed, 2 recycled; write=4.892 s, sync=0.123 s,
  total=5.234 s; sync files=45, longest=0.034 s
2026-11-04 10:16:10 UTC [12400]: user=report,db=mydb,
  app=pgAdmin,client=10.0.1.2 LOG: connection authorized
2026-11-04 10:16:45 UTC [12400]: user=report,db=mydb
  LOG: disconnection: session time: 0:00:35.123
```

### auto_explain — Automatic Query Plans in Logs
**Explanation:** For auto_explain — a powerful extension that automatically logs EXPLAIN ANALYZE output for slow queries. Instead of just seeing the query text, you see the full execution plan. This tells you exactly WHY a query is slow.

```sql
postgres=# -- Enable auto_explain:
postgres=# -- postgresql.conf:
postgres=# -- shared_preload_libraries = 'auto_explain'
postgres=# -- auto_explain.log_min_duration = '1s'
postgres=# -- auto_explain.log_analyze = on
postgres=# -- auto_explain.log_buffers = on
postgres=# -- auto_explain.log_format = text
postgres=# -- Or enable per-session (no restart needed):
LOAD 'auto_explain';
postgres=# SET auto_explain.log_min_duration = '500ms';
postgres=# SET auto_explain.log_analyze = on;
postgres=# -- Now any query > 500ms gets its plan logged:
postgres=# -- LOG: duration: 2345.678 ms plan:
postgres=# -- Query Text: SELECT * FROM orders WHERE ...
postgres=# -- Seq Scan on orders (cost=0.00..45678.00 rows=1000000)
postgres=# --   (actual time=0.012..2100.456 rows=1000000)
postgres=# --   Filter: (status = 'pending')
postgres=# --   Rows Removed by Filter: 0
postgres=# --   Buffers: shared hit=12345 read=6789
postgres=# -- You can see: Seq Scan (missing index!), buffer reads, etc.
```

### Running pgBadger
**Explanation:** Running pgBadger is simple — point it at your log files and it generates an HTML report. Let us see the command and the key sections of the report.

```sql
# Install pgBadger:
sudo apt install pgbadger
# Generate report from today's log:
pgbadger /var/lib/postgresql/16/main/log/postgresql-2026-11-04.log \
    -o /tmp/pgbadger_report.html
# With specific log_line_prefix:
pgbadger -p '%t [%p]: user=%u,db=%d,app=%a,client=%h ' \
    /var/lib/postgresql/16/main/log/*.log \
    -o /tmp/pgbadger_report.html
# For csvlog format:
pgbadger -f csv /var/lib/postgresql/16/main/log/*.csv \
    -o /tmp/pgbadger_report.html
# Incremental mode (daily reports, fast):
pgbadger -I -O /var/www/pgbadger/ \
    /var/lib/postgresql/16/main/log/*.log
# Output:
# [========================>] Parsed 1234567 bytes of log
# HTML report: /tmp/pgbadger_report.html
```

### Loading CSV Logs into PostgreSQL
**Explanation:** You can also load CSV logs directly into PostgreSQL for SQL analysis. PostgreSQL has a predefined table structure for this. This lets you query your log data with SQL — very powerful for custom analysis.

```sql
-- Create the log table (PG 16 format):
CREATE TABLE postgres_log (
    log_time           TIMESTAMPTZ,
    user_name          TEXT,
    database_name      TEXT,
    process_id         INTEGER,
    connection_from    TEXT,
    session_id         TEXT,
    session_line_num   BIGINT,
    command_tag        TEXT,
    session_start_time TIMESTAMPTZ,
    virtual_transaction_id TEXT,
    transaction_id     BIGINT,
    error_severity     TEXT,
    sql_state_code     TEXT,
    message            TEXT,
    detail             TEXT,
    hint               TEXT,
    internal_query     TEXT,
    internal_query_pos INTEGER,
    context            TEXT,
    query              TEXT,
    query_pos          INTEGER,
    location           TEXT,
    application_name   TEXT,
    backend_type       TEXT,
    leader_pid         INTEGER,
    query_id           BIGINT
);

-- Load CSV log file:
COPY postgres_log FROM
  '/var/lib/postgresql/16/main/log/postgresql-2026-11-04.csv'
  WITH (FORMAT csv);
```

### Querying CSV Logs with SQL
**Explanation:** Once loaded, you can run powerful SQL queries on your logs. Find the slowest queries, busiest hours, most common errors, and more.

```sql
postgres=# -- Top 10 slowest queries from logs:
SELECT
    log_time,
    user_name,
    database_name,
    SUBSTRING(message FROM 'duration: ([0-9.]+) ms')
      ::numeric AS duration_ms,
    LEFT(query, 80) AS query_text
postgres-# FROM postgres_log
postgres-# WHERE message LIKE 'duration:%'
postgres-# ORDER BY duration_ms DESC
postgres-# LIMIT 10;
postgres=# -- Error distribution:
postgres=# SELECT error_severity, COUNT(*) AS count
postgres-# FROM postgres_log
postgres-# WHERE error_severity IN ('ERROR', 'FATAL', 'PANIC')
postgres-# GROUP BY error_severity
postgres-# ORDER BY count DESC;
postgres=# -- Hourly query distribution:
SELECT
    date_trunc('hour', log_time) AS hour,
    COUNT(*) AS queries
postgres-# FROM postgres_log
postgres-# WHERE message LIKE 'duration:%'
postgres-# GROUP BY hour
postgres-# ORDER BY hour;
```

### Log Rotation & Retention
**Explanation:** Log rotation and retention are important for disk management. Configure rotation by time and size, and set up a cron job to delete old logs.

```sql
# PostgreSQL.conf handles rotation:
# log_rotation_age = '1d'     # new file every day
# log_rotation_size = '100MB'  # also rotate at 100MB
# log_truncate_on_rotation = on  # overwrite old files
# Keep 30 days of logs with cron:
# /etc/cron.daily/pg-log-cleanup:
find /var/lib/postgresql/16/main/log/ \
    -name 'postgresql-*.log' \
    -mtime +30 -delete
find /var/lib/postgresql/16/main/log/ \
    -name 'postgresql-*.csv' \
    -mtime +30 -delete
# Generate daily pgBadger report via cron:
# /etc/cron.daily/pgbadger-report:
pgbadger -I \
    -O /var/www/pgbadger/ \
    /var/lib/postgresql/16/main/log/postgresql-$(date +%Y-%m-%d)*.log
# Check log directory size:
du -sh /var/lib/postgresql/16/main/log/
# 2.3G  /var/lib/postgresql/16/main/log/
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — Production Logging Configuration
Here is the complete logging configuration for a production PostgreSQL server. We will go through each parameter. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `logging_collector` | `on` | **`[RESTART]`** (Postmaster Restart) | on to capture stdout/stderr to files (Default: off) |
| `log_destination` | `stderr` | `[RELOAD]` (Live Reload `SIGHUP`) | 'stderr', 'csvlog', or 'jsonlog' (Default: 'stderr') |
| `log_directory` | `log` | `[RELOAD]` (Live Reload `SIGHUP`) | Directory under $PGDATA for log files (Default: 'log') |
| `log_filename` | `postgresql-%Y-%m-%d_%H%M%S.log` | `[RELOAD]` (Live Reload `SIGHUP`) | Log naming pattern (Default: 'postgresql-%Y-%m-%d_%H%M%S.log') |
| `log_rotation_age` | `1d` | `[SETTING]` |  |
| `log_rotation_size` | `100MB` | `[SETTING]` |  |


### File: `postgresql.conf` — What to Log — Query Performance
Now the most important parameter: log_min_duration_statement. This logs any query that takes longer than the threshold. Set it to capture slow queries without flooding the logs with fast ones. You can apply these parameters without downtime by executing SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `log_min_duration_statement` | `500ms` | `[RELOAD]` (Live Reload `SIGHUP`) | 250ms to log slow queries (Default: -1) |
| `log_statement` | `ddl` | `[SETTING]` |  |
| `log_checkpoints` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | on to log checkpoint frequency & I/O (Default: off) |
| `log_connections` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | on to log connection attempts (Default: off) |
| `log_disconnections` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | on to log session closures (Default: off) |
| `log_lock_waits` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | on to log queries waiting > deadlock_timeout (Default: off) |
| `log_temp_files` | `0` | `[RELOAD]` (Live Reload `SIGHUP`) | 0 to log all disk spills by work_mem (Default: -1) |


### File: `postgresql.conf` — CSV Log Format — Richest Data for pgBadger
csvlog format gives pgBadger the richest data. It includes every field in a structured CSV format — timestamp, user, database, PID, error severity, SQL state, message, detail, hint, query, and more. Here is how to enable it. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `logging_collector` | `on` | **`[RESTART]`** (Postmaster Restart) | on to capture stdout/stderr to files (Default: off) |
| `log_destination` | `csvlog` | `[RELOAD]` (Live Reload `SIGHUP`) | 'stderr', 'csvlog', or 'jsonlog' (Default: 'stderr') |
| `log_filename` | `postgresql-%Y-%m-%d_%H%M%S` | `[RELOAD]` (Live Reload `SIGHUP`) | Log naming pattern (Default: 'postgresql-%Y-%m-%d_%H%M%S.log') |
| `log_min_duration_statement` | `500ms` | `[RELOAD]` (Live Reload `SIGHUP`) | 250ms to log slow queries (Default: -1) |
| `log_checkpoints` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | on to log checkpoint frequency & I/O (Default: off) |
| `log_connections` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | on to log connection attempts (Default: off) |
| `log_disconnections` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | on to log session closures (Default: off) |


### File: `postgresql.conf` — Complete Production Logging Config
Here is your complete production logging configuration — all parameters in one place. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `logging_collector` | `on` | **`[RESTART]`** (Postmaster Restart) | on to capture stdout/stderr to files (Default: off) |
| `log_destination` | `csvlog` | `[RELOAD]` (Live Reload `SIGHUP`) | 'stderr', 'csvlog', or 'jsonlog' (Default: 'stderr') |
| `log_directory` | `log` | `[RELOAD]` (Live Reload `SIGHUP`) | Directory under $PGDATA for log files (Default: 'log') |
| `log_filename` | `postgresql-%Y-%m-%d_%H%M%S` | `[RELOAD]` (Live Reload `SIGHUP`) | Log naming pattern (Default: 'postgresql-%Y-%m-%d_%H%M%S.log') |
| `log_rotation_age` | `1d` | `[SETTING]` |  |
| `log_min_duration_statement` | `500ms` | `[RELOAD]` (Live Reload `SIGHUP`) | 250ms to log slow queries (Default: -1) |
| `log_checkpoints` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | on to log checkpoint frequency & I/O (Default: off) |
| `log_connections` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | on to log connection attempts (Default: off) |
| `log_disconnections` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | on to log session closures (Default: off) |
| `log_lock_waits` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | on to log queries waiting > deadlock_timeout (Default: off) |
| `log_temp_files` | `0` | `[RELOAD]` (Live Reload `SIGHUP`) | 0 to log all disk spills by work_mem (Default: -1) |
| `log_statement` | `ddl` | `[SETTING]` |  |



---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. PostgreSQL logging captures slow queries, errors, checkpoints, connections, and locks. Set log_min_duration_statement to 500 milliseconds for production — not zero. Use a good log_line_prefix or csvlog format for pgBadger compatibility. auto_explain logs full execution plans for slow queries. pgBadger generates HTML reports showing slowest queries, traffic patterns, and errors. Set up daily log rotation and pgBadger cron jobs. In the next class, we cover Prometheus and Grafana for real-time monitoring dashboards.

- **log_min_duration_statement = 500ms: log slow queries**
- **log_statement = ddl: audit all schema changes**
- **log_checkpoints, log_connections, log_lock_waits: on**
- **log_temp_files = 0: catch work_mem spills**
- **csvlog format: richest data for pgBadger**
- **auto_explain: log execution plans for slow queries**
- **pgBadger: HTML reports from log files**
- **Key sections: top queries, errors, checkpoints, connections**
- **Daily cron: rotate logs, generate pgBadger reports**
- **NEVER set log_min_duration_statement = 0 in production**
- **Next: Prometheus & Grafana Monitoring**


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
