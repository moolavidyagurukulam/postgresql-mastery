# System Catalogs & Statistics Views — PostgreSQL's Internal Dashboard
**Series:** PostgreSQL Mastery | **Phase:** Phase 23: Monitoring & Troubleshooting | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! We now enter Phase 23 — Monitoring and Troubleshooting. In previous phases we tuned PostgreSQL for performance and partitioned tables for scale. But how do you know if your database is healthy RIGHT NOW? PostgreSQL has a rich set of internal views — system catalogs and statistics views — that tell you everything: which tables are bloated, which indexes are unused, how many cache hits you get, and much more. Let us learn to read PostgreSQL's internal dashboard.


---

## 2. Core Technical Concepts & Mechanisms

### System Catalogs vs Statistics Views
PostgreSQL stores metadata about every object in system catalogs. These are regular tables in the pg_catalog schema that describe your database structure. Statistics views, on the other hand, are in the pg_catalog schema too but they track runtime performance — how many rows were scanned, how many cache hits, how many dead tuples need vacuuming.

| System Catalogs (Structure) | Statistics Views (Performance) |
| :--- | :--- |
| pg_class: all tables, indexes, sequences | pg_stat_user_tables: table access stats |
| pg_namespace: schemas | pg_stat_user_indexes: index usage |
| pg_attribute: columns | pg_stat_activity: active connections |
| pg_index: index definitions | pg_stat_database: database-level stats |
| pg_constraint: constraints | pg_statio_user_tables: table I/O |
| pg_proc: functions and procedures | pg_stat_bgwriter: background writer |
| Describe WHAT exists in the database | Describe HOW the database is performing |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### pg_catalog vs information_schema
Let us look at the most useful information_schema views. While pg_catalog is PostgreSQL-specific, information_schema is SQL-standard and portable across databases. It is simpler but less detailed.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Let us look at the most useful information_schema views |
| **While pg_catalog is PostgreSQL** | specific, information_schema is SQL-standard and portable across databases |
| **Point 3** | It is simpler but less detailed |

### Monitoring Thresholds — When to Act
Here are the key thresholds you should monitor. These are the numbers that tell you whether to act or not.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are the key thresholds you should monitor. These are the numbers that tell you whether to act or not |


---

## 3. Hands-On Commands & psql Output

### pg_class — Every Object in Your Database
**Explanation:** Let us start with pg_class — the most fundamental system catalog. Every table, index, view, sequence, and materialized view is a row in pg_class. The relkind column tells you what type of object it is. The relpages and reltuples columns tell you the estimated size.

```sql
postgres=# -- List all user tables with size estimates:
SELECT
    relname AS table_name,
    relkind AS type,
    relpages AS pages,
    reltuples::bigint AS est_rows,
    pg_size_pretty(
      pg_total_relation_size(oid)
    ) AS total_size
postgres-# FROM pg_class
postgres-# WHERE relnamespace = 'public'::regnamespace
postgres-# AND relkind = 'r'  -- 'r' = ordinary table
postgres-# ORDER BY pg_total_relation_size(oid) DESC;
  table_name  | type | pages | est_rows | total_size
postgres=# --------------+------+-------+----------+-----------
 orders       | r    | 18456 |  1000000 | 245 MB
 customers    | r    |   892 |    50000 | 12 MB
 products     | r    |   123 |     5000 | 1600 kB
postgres=# -- relkind values:
postgres=# -- 'r' = table, 'i' = index, 'S' = sequence,
postgres=# -- 'v' = view, 'm' = materialized view,
postgres=# -- 'p' = partitioned table, 'I' = partitioned index
```

### pg_namespace & pg_attribute — Schemas and Columns
**Explanation:** pg_namespace lists all schemas. pg_attribute lists all columns. You can join these to get a complete picture of any table's structure — columns, types, nullable, defaults — all from the catalog.

```sql
postgres=# -- List all schemas:
postgres=# SELECT nspname AS schema_name,
       nspowner::regrole AS owner
postgres-# FROM pg_namespace
postgres-# WHERE nspname NOT LIKE 'pg_%'
postgres-# AND nspname != 'information_schema';
 schema_name | owner
postgres=# -------------+----------
 public      | pg_database_owner
postgres=# -- List columns of a table:
SELECT
    a.attname AS column_name,
    pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
    a.attnotnull AS not_null,
    pg_get_expr(d.adbin, d.adrelid) AS default_value
postgres-# FROM pg_attribute a
postgres-# LEFT JOIN pg_attrdef d
postgres-# ON a.attrelid = d.adrelid AND a.attnum = d.adnum
postgres-# WHERE a.attrelid = 'orders'::regclass
postgres-# AND a.attnum > 0        -- skip system columns
postgres-# AND NOT a.attisdropped   -- skip dropped columns
postgres-# ORDER BY a.attnum;
 column_name  |     data_type     | not_null | default_value
postgres=# --------------+-------------------+----------+--------------------
 id           | bigint            | t        | nextval('orders...')
 customer_id  | integer           | t        |
 amount       | numeric(10,2)     | t        |
 status       | text              | t        | 'pending'::text
 order_date   | date              | t        |
```

### pg_indexes — Index Details
**Explanation:** pg_index and pg_indexes give you details about every index — which columns it covers, whether it is unique, whether it is valid. This is essential for finding duplicate or unused indexes.

```sql
postgres=# -- List all indexes on a table:
SELECT
    indexname,
    indexdef
postgres-# FROM pg_indexes
postgres-# WHERE tablename = 'orders';
     indexname          |            indexdef
postgres=# ------------------------+-------------------------------
 orders_pkey            | CREATE UNIQUE INDEX orders_pkey
                        |   ON public.orders USING btree (id)
 idx_orders_customer    | CREATE INDEX idx_orders_customer
                        |   ON public.orders USING btree (customer_id)
 idx_orders_date        | CREATE INDEX idx_orders_date
                        |   ON public.orders USING btree (order_date)
postgres=# -- Find INVALID indexes (failed CREATE INDEX CONCURRENTLY):
postgres=# SELECT c.relname AS index_name,
       i.indisvalid AS is_valid
postgres-# FROM pg_index i
postgres-# JOIN pg_class c ON i.indexrelid = c.oid
postgres-# WHERE NOT i.indisvalid;
postgres=# -- If any results: DROP and recreate those indexes
```

### pg_stat_user_tables — Table Health Dashboard
**Explanation:** Now let us move to statistics views — the performance side. pg_stat_user_tables is the most important view for table health. It shows sequential scans versus index scans, live and dead tuples, and when the last vacuum and analyze ran.

```sql
SELECT
    relname AS table_name,
    seq_scan,
    idx_scan,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    ROUND(100.0 * n_dead_tup /
      NULLIF(n_live_tup + n_dead_tup, 0), 1)
postgres-# AS dead_pct,
    last_vacuum,
    last_autovacuum,
    last_analyze
postgres-# FROM pg_stat_user_tables
postgres-# ORDER BY n_dead_tup DESC;
 table_name | seq_scan | idx_scan | live_rows | dead_rows | dead_pct | last_autovacuum
postgres=# ------------+----------+----------+-----------+-----------+----------+------------------
 orders     |       15 |    48230 |   1000000 |     25430 |      2.5 | 2026-11-03 14:22
 customers  |      892 |     3210 |     50000 |       120 |      0.2 | 2026-11-03 14:22
 products   |     1205 |      890 |      5000 |        45 |      0.9 | 2026-11-03 14:23
postgres=# -- RED FLAGS:
postgres=# -- high seq_scan + low idx_scan = missing index
postgres=# -- dead_pct > 10% = vacuum not keeping up
postgres=# -- last_autovacuum = NULL = autovacuum never ran!
```

### Finding Tables That Need Indexes
**Explanation:** One of the most powerful diagnostic queries: finding tables that need indexes. If a table has many sequential scans and few or zero index scans, it is being scanned fully on every query. This table likely needs an index on the columns used in WHERE clauses.

```sql
postgres=# -- Tables with too many sequential scans:
SELECT
    relname AS table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    pg_size_pretty(
      pg_total_relation_size(relid)
    ) AS size
postgres-# FROM pg_stat_user_tables
postgres-# WHERE seq_scan > 100
postgres-# AND (idx_scan IS NULL OR idx_scan = 0)
postgres-# AND pg_total_relation_size(relid) > 1024 * 1024  -- > 1MB
postgres-# ORDER BY seq_tup_read DESC;
 table_name | seq_scan | seq_tup_read | idx_scan | size
postgres=# ------------+----------+--------------+----------+--------
 audit_log  |      430 |     21500000 |        0 | 340 MB
 events     |      215 |      8600000 |        0 | 128 MB
postgres=# -- audit_log has 430 sequential scans reading 21.5M rows
postgres=# -- with ZERO index scans → definitely needs an index!
postgres=# -- Check the most common WHERE clauses and add indexes
```

### Finding Unused Indexes
**Explanation:** The opposite problem: unused indexes. Every index slows down INSERT, UPDATE, and DELETE because PostgreSQL must update the index too. If an index is never scanned, it is wasting disk space and slowing down writes for nothing.

```sql
postgres=# -- Indexes that are never used:
SELECT
    s.relname AS table_name,
    s.indexrelname AS index_name,
    s.idx_scan AS times_used,
    pg_size_pretty(
      pg_relation_size(s.indexrelid)
    ) AS index_size
postgres-# FROM pg_stat_user_indexes s
postgres-# JOIN pg_index i ON s.indexrelid = i.indexrelid
postgres-# WHERE s.idx_scan = 0          -- never used
postgres-# AND NOT i.indisunique         -- not a unique constraint
postgres-# AND NOT i.indisprimary        -- not a primary key
postgres-# AND s.relname NOT LIKE '%_pkey'
postgres-# ORDER BY pg_relation_size(s.indexrelid) DESC;
 table_name |      index_name       | times_used | index_size
postgres=# ------------+-----------------------+------------+-----------
 orders     | idx_orders_old_status  |          0 | 42 MB
 customers  | idx_cust_legacy_phone  |          0 | 8192 kB
postgres=# -- These indexes cost write performance + disk space
postgres=# -- but provide zero benefit. Consider dropping them.
postgres=# -- WARNING: reset stats first, wait a full business cycle
postgres=# -- (1 week+) before deciding an index is truly unused
```

### pg_stat_database — Database Overview
**Explanation:** pg_stat_database gives you a bird's-eye view of the entire database — total transactions, cache hit ratio, temporary file usage, conflicts, and deadlocks.

```sql
SELECT
    datname AS database,
    numbackends AS connections,
    xact_commit AS commits,
    xact_rollback AS rollbacks,
    blks_read,
    blks_hit,
    ROUND(100.0 * blks_hit /
      NULLIF(blks_hit + blks_read, 0), 2)
postgres-# AS cache_hit_pct,
    temp_files,
    pg_size_pretty(temp_bytes) AS temp_size,
    deadlocks,
    conflicts
postgres-# FROM pg_stat_database
postgres-# WHERE datname = current_database();
 database | connections | commits  | rollbacks | cache_hit_pct | temp_files | deadlocks
postgres=# ----------+-------------+----------+-----------+---------------+------------+----------
 mydb     |          12 | 2845630  |       342 |         99.12 |         15 |         2
postgres=# -- KEY METRICS:
postgres=# -- cache_hit_pct < 99% → shared_buffers too small
postgres=# -- temp_files > 0 → work_mem too small (spilling to disk)
postgres=# -- deadlocks > 0 → application has lock ordering issues
postgres=# -- rollbacks/commits ratio → high = application errors
```

### pg_statio_user_tables — Table I/O Statistics
**Explanation:** pg_statio_user_tables shows the I/O layer — how many blocks were read from disk versus served from the buffer cache. A low cache hit ratio on a specific table means that table's data is being constantly read from disk, which is slow.

```sql
postgres=# -- Per-table cache hit ratio:
SELECT
    relname AS table_name,
    heap_blks_read AS disk_reads,
    heap_blks_hit AS cache_hits,
    ROUND(100.0 * heap_blks_hit /
      NULLIF(heap_blks_hit + heap_blks_read, 0), 2)
postgres-# AS cache_hit_pct,
    idx_blks_read AS idx_disk,
    idx_blks_hit AS idx_cache,
    ROUND(100.0 * idx_blks_hit /
      NULLIF(idx_blks_hit + idx_blks_read, 0), 2)
postgres-# AS idx_cache_hit_pct
postgres-# FROM pg_statio_user_tables
postgres-# WHERE heap_blks_read + heap_blks_hit > 100
postgres-# ORDER BY heap_blks_read DESC
postgres-# LIMIT 10;
 table_name | disk_reads | cache_hits | cache_hit_pct | idx_cache_hit_pct
postgres=# ------------+------------+------------+---------------+------------------
 orders     |       1234 |     890234 |         99.86 |            99.92
 audit_log  |      45678 |      12345 |         21.28 |            45.67
postgres=# -- audit_log: only 21% cache hit → this table's working
postgres=# -- set does NOT fit in shared_buffers
postgres=# -- Options: increase shared_buffers, partition the table,
postgres=# -- or archive old data
```

### Measuring Table Bloat
**Explanation:** Table bloat is a silent performance killer. When PostgreSQL updates or deletes a row, the old version stays on disk until VACUUM removes it. If VACUUM cannot keep up, dead tuples accumulate and the table grows far larger than it needs to be. Here is how to measure bloat.

```sql
postgres=# -- Quick bloat estimate using pg_stat_user_tables:
SELECT
    relname AS table_name,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    ROUND(100.0 * n_dead_tup /
      NULLIF(n_live_tup, 0), 1) AS bloat_pct,
    pg_size_pretty(
      pg_total_relation_size(relid)
    ) AS total_size,
    last_autovacuum
postgres-# FROM pg_stat_user_tables
postgres-# WHERE n_dead_tup > 1000
postgres-# ORDER BY n_dead_tup DESC;
 table_name | live_rows | dead_rows | bloat_pct | total_size | last_autovacuum
postgres=# ------------+-----------+-----------+-----------+------------+------------------
 orders     |   1000000 |    250000 |      25.0 | 340 MB     | 2026-10-28 09:15
 sessions   |    500000 |     85000 |      17.0 | 89 MB      | NULL
postgres=# -- orders: 25% bloat! VACUUM is not keeping up
postgres=# -- sessions: autovacuum NEVER ran (NULL) → configure it!
postgres=# -- Fix: run VACUUM manually, or tune autovacuum:
postgres=# VACUUM (VERBOSE) orders;
postgres=# -- Or for severe bloat:
postgres=# -- VACUUM FULL orders;  (locks table, rewrites it)
```

### pg_stat_bgwriter — Checkpoint & Writer Stats
**Explanation:** pg_stat_bgwriter tells you about the background writer and checkpointer. The key metric is buffers_checkpoint versus buffers_backend — if the backend is writing many buffers directly, the checkpointer is not keeping up and your clients are doing I/O they should not have to do.

```sql
SELECT
    checkpoints_timed,
    checkpoints_req,
    buffers_checkpoint,
    buffers_clean,
    buffers_backend,
    ROUND(100.0 * buffers_backend /
      NULLIF(buffers_checkpoint + buffers_clean
             + buffers_backend, 0), 1)
postgres-# AS backend_write_pct,
    maxwritten_clean
postgres-# FROM pg_stat_bgwriter;
 checkpoints_timed | checkpoints_req | buffers_checkpoint | buffers_backend | backend_write_pct
postgres=# -------------------+-----------------+--------------------+-----------------+------------------
              1245 |              23 |            8923456 |           12345 |               0.1
postgres=# -- KEY METRICS:
postgres=# -- checkpoints_req > 0: forced checkpoints (max_wal_size too small)
postgres=# -- backend_write_pct > 1%: clients writing buffers themselves
postgres=# --   → increase shared_buffers or tune bgwriter
postgres=# -- maxwritten_clean > 0: bgwriter hit bgwriter_lru_maxpages limit
postgres=# --   → increase bgwriter_lru_maxpages
```

### Resetting Statistics
**Explanation:** You can reset statistics counters to measure fresh. This is useful when you make a configuration change and want to see the impact from a clean baseline. Use pg_stat_reset for the current database.

```sql
postgres=# -- Reset statistics for the current database:
postgres=# SELECT pg_stat_reset();
postgres=# -- All counters (seq_scan, idx_scan, blks_read, etc.)
postgres=# -- reset to zero for this database
postgres=# -- Reset statistics for a specific table:
postgres=# SELECT pg_stat_reset_single_table_counters(
    'orders'::regclass::oid
);
postgres=# -- Reset shared statistics (bgwriter, WAL, etc.):
postgres=# SELECT pg_stat_reset_shared('bgwriter');
postgres=# -- IMPORTANT: Don't reset on production without thinking!
postgres=# -- You lose historical data about index usage, etc.
postgres=# -- Best practice:
postgres=# -- 1. Record current stats (snapshot)
postgres=# -- 2. Make your change
postgres=# -- 3. Wait for a full business cycle (1 week)
postgres=# -- 4. Compare new stats to snapshot
postgres=# -- OR: use pg_stat_statements (tracks query-level stats)
```

### Quick Health Check Query
**Explanation:** Here is a complete quick-check diagnostic query you can run any time to get a snapshot of database health. Save this query — it is the single most useful monitoring query you will ever write.

```sql
-- Run this for an instant health snapshot:
SELECT 'Cache Hit Ratio' AS metric,
  ROUND(100.0 * sum(blks_hit) /
    NULLIF(sum(blks_hit) + sum(blks_read), 0), 2)
    || '%' AS value
FROM pg_stat_database
WHERE datname = current_database()
UNION ALL
SELECT 'Active Connections',
  count(*)::text
FROM pg_stat_activity
WHERE state = 'active'
UNION ALL
SELECT 'Dead Rows (top table)',
  relname || ': ' || n_dead_tup::text
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 1
UNION ALL
SELECT 'Unused Indexes',
  count(*)::text
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE '%_pkey'
UNION ALL
SELECT 'Database Size',
  pg_size_pretty(pg_database_size(
    current_database()))
UNION ALL
SELECT 'Temp Files (disk spills)',
  temp_files::text
FROM pg_stat_database
WHERE datname = current_database();
```

### Beginner Trap: Stats After Restart
**Explanation:** A common beginner trap: using pg_stat_user_tables data right after a restart. Statistics are accumulated since the last reset or server start. If you just restarted PostgreSQL, all counters are zero and give misleading results. Wait for at least one full business day before drawing conclusions from statistics.

```sql
postgres=# -- Check when stats were last reset:
SELECT
    stats_reset
postgres-# FROM pg_stat_database
postgres-# WHERE datname = current_database();
       stats_reset
postgres=# ------------------------
 2026-11-01 06:30:15+00
postgres=# -- If this is recent (just restarted), stats are incomplete!
postgres=# -- Wait at least 24 hours for meaningful data
postgres=# -- Check server uptime:
SELECT
    pg_postmaster_start_time() AS started,
    now() - pg_postmaster_start_time() AS uptime;
        started         |     uptime
postgres=# ------------------------+------------------
 2026-11-01 06:30:12+00 | 3 days 08:15:23
postgres=# -- 3+ days of uptime → stats are meaningful
postgres=# -- < 1 day → be cautious with conclusions
```

### Index Usage Analysis
**Explanation:** pg_stat_user_indexes helps you find the index usage pattern — which indexes are heavily used and which are dead weight. Combine this with index size to find the biggest waste.

```sql
postgres=# -- Complete index usage report:
SELECT
    t.relname AS table_name,
    i.indexrelname AS index_name,
    i.idx_scan AS scans,
    i.idx_tup_read AS rows_read,
    i.idx_tup_fetch AS rows_fetched,
    pg_size_pretty(
      pg_relation_size(i.indexrelid)
    ) AS index_size,
    CASE
      WHEN i.idx_scan = 0 THEN 'UNUSED'
      WHEN i.idx_scan < 10 THEN 'RARELY USED'
      ELSE 'ACTIVE'
    END AS status
postgres-# FROM pg_stat_user_indexes i
postgres-# JOIN pg_stat_user_tables t ON i.relid = t.relid
postgres-# ORDER BY pg_relation_size(i.indexrelid) DESC;
 table  |      index_name       | scans | index_size | status
postgres=# --------+-----------------------+-------+------------+-----------
 orders | idx_orders_customer   | 48230 | 21 MB      | ACTIVE
 orders | orders_pkey           | 12100 | 21 MB      | ACTIVE
 orders | idx_orders_old_status  |     0 | 42 MB      | UNUSED
 orders | idx_orders_date        |     3 | 21 MB      | RARELY USED
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Stats After Restart
A common beginner trap: using pg_stat_user_tables data right after a restart. Statistics are accumulated since the last reset or server start. If you just restarted PostgreSQL, all counters are zero and give misleading results. Wait for at least one full business day before drawing conclusions from statistics.

```sql
-- Check when stats were last reset:
SELECT
    stats_reset
FROM pg_stat_database
WHERE datname = current_database();
       stats_reset
------------------------
 2026-11-01 06:30:15+00
-- If this is recent (just restarted), stats are incomplete!
-- Wait at least 24 hours for meaningful data
-- Check server uptime:
SELECT
    pg_postmaster_start_time() AS started,
    now() - pg_postmaster_start_time() AS uptime;
        started         |     uptime
------------------------+------------------
 2026-11-01 06:30:12+00 | 3 days 08:15:23
-- 3+ days of uptime → stats are meaningful
-- < 1 day → be cautious with conclusions
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. System catalogs like pg_class, pg_attribute, and pg_index describe your database structure. Statistics views like pg_stat_user_tables, pg_statio_user_tables, and pg_stat_database track runtime performance. Use them to find missing indexes, unused indexes, table bloat, cache hit ratios, and checkpoint problems. Always check stats_reset to know when data collection started. In the next class, we dive into pg_stat_activity for live connection monitoring and pg_locks for troubleshooting lock conflicts.

- **pg_class: every table, index, view, sequence in the database**
- **pg_stat_user_tables: seq_scan vs idx_scan, dead tuples, vacuum times**
- **pg_statio_user_tables: cache hit ratio per table**
- **pg_stat_database: overall cache hits, temp files, deadlocks**
- **pg_stat_bgwriter: checkpoint and background writer health**
- **Find missing indexes: high seq_scan, zero idx_scan**
- **Find unused indexes: idx_scan = 0, not PK/unique**
- **Measure bloat: dead_rows / live_rows percentage**
- **Monitor thresholds: cache > 99%, dead < 5%, temp = 0**
- **Wait 24h+ after restart before trusting statistics**
- **Next: pg_stat_activity & Lock Troubleshooting**


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
