# pg_cron — Scheduled Jobs Inside PostgreSQL
**Series:** PostgreSQL Mastery | **Phase:** Phase 26: Extensions | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Every production database has maintenance tasks that must run on a schedule — vacuum tables, refresh materialized views, delete old logs, generate reports. Traditionally, you use Linux cron or Windows Task Scheduler with a psql command. But pg_cron lets you schedule jobs directly inside PostgreSQL using standard cron syntax. The schedule, the SQL, and the execution history all live in the database. Let us set it up.


---

## 2. Core Technical Concepts & Mechanisms

### OS Cron vs pg_cron
Why use pg_cron instead of OS cron? First, the schedule is portable — it moves with the database, not tied to a server. Second, the execution history is queryable — you can see when jobs ran and if they succeeded. Third, no external scripts needed — just SQL inside PostgreSQL.

| OS Cron / Task Scheduler | pg_cron |
| :--- | :--- |
| Schedule lives outside the database | Schedule lives IN the database |
| Needs psql or script wrapper | Pure SQL — no external scripts |
| Logs in syslog or text files | History in cron.job_run_details table |
| Tied to specific server | Moves with pg_dump/pg_restore |
| No built-in retry or history | Queryable execution history |
| Separate permissions system | Uses PostgreSQL roles for access |

### Cron Schedule Syntax
The cron schedule syntax has five fields — minute, hour, day of month, month, and day of week. An asterisk means every. Let us learn the syntax before creating jobs.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Five Fields** | minute  hour  day-of-month  month  day-of-week |
| *** (asterisk)** | Every value — * in minute = every minute |
| **, (comma)** | Multiple values — 1,15 in minute = at minute 1 and 15 |
| **- (range)** | Range — 9-17 in hour = every hour from 9 to 17 |
| **/ (step)** | Step — */5 in minute = every 5 minutes |

**Notes:**
- Day of week: 0=Sunday, 1=Monday, ..., 6=Saturday
- Examples: '0 3 * * *' = daily at 3:00 AM
- '*/10 * * * *' = every 10 minutes
- '0 0 1 * *' = first of every month at midnight

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Common pg_cron Jobs
Here are common production use cases for pg_cron — the jobs every database should have.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are common production use cases for pg_cron — the jobs every database should have |

### pg_cron Limitations
A beginner trap — pg_cron runs on a fixed one-minute check interval. You cannot schedule sub-minute jobs. If you need something every 30 seconds, use a different approach like a background worker or application-level scheduling.

| Limitations | Workarounds |
| :--- | :--- |
| Minimum interval: 1 minute | Use LISTEN/NOTIFY for sub-second |
| No sub-minute scheduling | Use application scheduler for sub-minute |
| Jobs run sequentially (one at a time) | Long jobs: schedule with enough gap |
| No built-in retry on failure | Add retry logic in a wrapper function |
| History table grows — clean it regularly | Schedule history cleanup job weekly |
| Needs superuser to install | Grant cron schema usage to non-superusers |


---

## 3. Hands-On Commands & psql Output

### Installation & Setup
**Explanation:** To enable pg_cron, add pg_cron to shared_preload_libraries in postgresql.conf and restart the server. Then execute CREATE EXTENSION pg_cron inside the postgres database. pg_cron spins up an internal background worker process that wakes up every minute to evaluate scheduled jobs against the cron schedule.

```sql
# Step 1: Install the package
# Debian/Ubuntu:
sudo apt install postgresql-16-cron
# RHEL/Rocky:
sudo dnf install pg_cron_16
# Step 2: Add to shared_preload_libraries
# Edit postgresql.conf:
shared_preload_libraries = 'pg_cron'
# pg_cron runs jobs in this database (default: postgres):
cron.database_name = 'postgres'
# Step 3: Restart PostgreSQL
sudo systemctl restart postgresql-16
# Step 4: Create the extension
psql -U postgres -d postgres
postgres=# CREATE EXTENSION pg_cron;
# pg_cron creates the 'cron' schema with:
#   cron.job          — scheduled jobs
#   cron.job_run_details — execution history
```

### Creating Scheduled Jobs
**Explanation:** Let us create our first scheduled jobs. The cron.schedule function takes a job name, a cron expression, and the SQL command to run.

```sql
postgres=# -- Vacuum a table every night at 3 AM:
postgres=# SELECT cron.schedule(
    'nightly-vacuum',
    '0 3 * * *',
    'VACUUM ANALYZE public.orders'
);
 schedule
postgres=# ----------
        1
postgres=# -- Refresh a materialized view every hour:
postgres=# SELECT cron.schedule(
    'hourly-refresh-dashboard',
    '0 * * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY dashboard_stats'
);
postgres=# -- Delete old logs every Sunday at midnight:
postgres=# SELECT cron.schedule(
    'weekly-log-cleanup',
    '0 0 * * 0',
    $$DELETE FROM app_logs WHERE created_at < now() - interval '90 days'$$
);
postgres=# -- Run every 5 minutes:
postgres=# SELECT cron.schedule(
    'frequent-check',
    '*/5 * * * *',
    'SELECT process_pending_queue()'
);
```

### Viewing Jobs and History
**Explanation:** To see all scheduled jobs, query the cron.job table. To see execution history, query cron.job_run_details.

```sql
postgres=# -- List all scheduled jobs:
postgres=# SELECT jobid, jobname, schedule, command, active
postgres-# FROM cron.job ORDER BY jobid;
 jobid |        jobname         |  schedule   | active
postgres=# -------+------------------------+-------------+--------
     1 | nightly-vacuum         | 0 3 * * *   | t
     2 | hourly-refresh-dashboard| 0 * * * *   | t
     3 | weekly-log-cleanup     | 0 0 * * 0   | t
     4 | frequent-check         | */5 * * * * | t
postgres=# -- View execution history:
postgres=# SELECT jobid, jobname, status,
       start_time, end_time,
       return_message
postgres-# FROM cron.job_run_details
postgres-# ORDER BY start_time DESC
postgres-# LIMIT 5;
 jobid |    jobname     | status    |     start_time
postgres=# -------+----------------+-----------+--------------------
     4 | frequent-check | succeeded | 2024-11-04 10:05:00
     4 | frequent-check | succeeded | 2024-11-04 10:00:00
     2 | hourly-refresh | succeeded | 2024-11-04 10:00:00
```

### Managing Jobs — Modify, Pause, Delete
**Explanation:** You can modify, pause, resume, and delete jobs using the cron functions.

```sql
postgres=# -- Change the schedule of a job:
postgres=# SELECT cron.alter_job(
    job_id := 1,
    schedule := '0 4 * * *'  -- change from 3 AM to 4 AM
);
postgres=# -- Pause a job (deactivate):
postgres=# UPDATE cron.job SET active = false
postgres-# WHERE jobname = 'frequent-check';
postgres=# -- Resume a job:
postgres=# UPDATE cron.job SET active = true
postgres-# WHERE jobname = 'frequent-check';
postgres=# -- Delete a job:
postgres=# SELECT cron.unschedule('nightly-vacuum');
postgres=# -- or by ID:
postgres=# SELECT cron.unschedule(1);
postgres=# -- Clean old history (keep last 30 days):
postgres=# DELETE FROM cron.job_run_details
postgres-# WHERE end_time < now() - interval '30 days';
```

### Running Jobs on Other Databases
**Explanation:** pg_cron can also run jobs on other databases in the same cluster. By default, jobs run on the database where pg_cron is installed. Use cron.schedule_in_database to target a different database.

```sql
postgres=# -- Schedule a job on a different database:
postgres=# SELECT cron.schedule_in_database(
    'vacuum-app-db',         -- job name
    '0 3 * * *',             -- schedule
    'VACUUM ANALYZE orders', -- SQL command
    'app_db'                 -- target database
);
postgres=# -- Check which database each job targets:
postgres=# SELECT jobname, schedule, database, command
postgres-# FROM cron.job;
     jobname      | schedule  | database |      command
postgres=# ------------------+-----------+----------+------------------
 vacuum-app-db    | 0 3 * * * | app_db   | VACUUM ANALYZE..
 hourly-refresh   | 0 * * * * | postgres | REFRESH MATER..
```

### Complete Example: Nightly Aggregation
**Explanation:** Let us build a complete example — a job that aggregates daily order statistics every night and stores them in a summary table.

```sql
postgres=# -- Create summary table:
postgres=# CREATE TABLE daily_order_stats (
    stat_date date PRIMARY KEY,
    order_count int,
    total_revenue numeric(12,2),
    avg_order_value numeric(10,2),
    computed_at timestamptz DEFAULT now()
);
postgres=# -- Schedule nightly aggregation at 1:05 AM:
postgres=# SELECT cron.schedule(
    'nightly-order-stats',
    '5 1 * * *',
    $$INSERT INTO daily_order_stats
        (stat_date, order_count, total_revenue, avg_order_value)
    SELECT
        current_date - 1,
        count(*),
        sum(amount),
        avg(amount)
postgres-# FROM orders
postgres-# WHERE created_at >= current_date - 1
postgres-# AND created_at < current_date
postgres-# ON CONFLICT (stat_date) DO UPDATE SET
        order_count = EXCLUDED.order_count,
        total_revenue = EXCLUDED.total_revenue,
        avg_order_value = EXCLUDED.avg_order_value,
        computed_at = now()$$
);
```

### Monitoring Failed Jobs
**Explanation:** Important — pg_cron jobs run as the user who created them. If a job fails, the error is recorded in cron.job_run_details. Always monitor the history for failed jobs.

```sql
postgres=# -- Find failed jobs:
postgres=# SELECT jobname, status, return_message,
       start_time, end_time
postgres-# FROM cron.job_run_details
postgres-# WHERE status = 'failed'
postgres-# ORDER BY start_time DESC;
    jobname     | status |     return_message
postgres=# ----------------+--------+----------------------------
 nightly-vacuum | failed | ERROR: relation "old_table"
                |        |   does not exist
postgres=# -- Count failures per job:
postgres=# SELECT j.jobname,
       count(*) FILTER (WHERE d.status = 'succeeded') AS ok,
       count(*) FILTER (WHERE d.status = 'failed') AS fail
postgres-# FROM cron.job j
postgres-# LEFT JOIN cron.job_run_details d ON d.jobid = j.jobid
postgres-# WHERE d.start_time > now() - interval '7 days'
postgres-# GROUP BY j.jobname;
```

### Non-Superuser Access
**Explanation:** To let non-superusers manage their own cron jobs, grant them access to the cron schema and functions.

```sql
postgres=# -- Grant access to app_user:
postgres=# GRANT USAGE ON SCHEMA cron TO app_user;
postgres=# GRANT SELECT ON cron.job TO app_user;
postgres=# GRANT SELECT ON cron.job_run_details TO app_user;
postgres=# -- app_user can now schedule jobs (runs as app_user):
postgres=# -- As app_user:
postgres=# SELECT cron.schedule(
    'my-cleanup',
    '0 2 * * *',
    'DELETE FROM my_table WHERE expired = true'
);
postgres=# -- Job runs with app_user's privileges
postgres=# -- app_user can only see/modify their own jobs:
postgres=# SELECT jobname, schedule FROM cron.job
postgres-# WHERE username = current_user;
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. pg_cron schedules SQL jobs inside PostgreSQL using standard cron syntax. Install the package, add to shared_preload_libraries, restart, then CREATE EXTENSION. Use cron.schedule to create jobs and cron.unschedule to remove them. Check cron.job_run_details for execution history. Jobs can target other databases with schedule_in_database. Monitor for failures and clean history regularly. In the next class, we learn pgcrypto — encryption and hashing inside PostgreSQL.

- **Schedule SQL jobs with standard cron syntax**
- **Needs shared_preload_libraries + restart**
- **cron.schedule('name', '* * * * *', 'SQL'): create job**
- **cron.unschedule('name'): delete job**
- **cron.job: list all scheduled jobs**
- **cron.job_run_details: execution history**
- **cron.schedule_in_database: target other databases**
- **cron.alter_job: change schedule or command**
- **Minimum interval: 1 minute (no sub-minute)**
- **Monitor for failed jobs in job_run_details**
- **Clean history table regularly**
- **Next: pgcrypto — Encryption & Hashing**


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
