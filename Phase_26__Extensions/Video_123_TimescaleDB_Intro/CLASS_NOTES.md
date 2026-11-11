# TimescaleDB — Time-Series Data
**Series:** PostgreSQL Mastery | **Phase:** Phase 26: Extensions | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! IoT sensors, stock prices, application metrics, server logs — these all generate time-series data. Regular PostgreSQL tables struggle with billions of time-stamped rows — inserts slow down, queries on recent data scan old partitions, and storage grows unmanageably. TimescaleDB solves this. It is a PostgreSQL extension that automatically partitions time-series data into chunks, making inserts fast and time-range queries efficient. Let us learn how it works.


---

## 2. Core Technical Concepts & Mechanisms

### Regular Table vs Hypertable
Time-series data has a unique pattern — data is almost always inserted in time order, queries usually filter by recent time ranges, and old data needs different retention policies than new data. Regular tables do not optimize for these patterns. TimescaleDB introduces hypertables that look like regular tables but are automatically partitioned by time under the hood.

| Regular PostgreSQL Table | TimescaleDB Hypertable |
| :--- | :--- |
| One large table for all data | Auto-partitioned into time chunks |
| Inserts slow as table grows | Inserts stay fast (write to latest chunk) |
| Full index scans on queries | Queries scan only relevant chunks |
| Manual partitioning needed | Automatic chunk management |
| No built-in retention policies | Built-in retention policies |
| No automatic compression | Built-in compression (90%+ savings) |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### TimescaleDB Setup Workflow
Here is the typical TimescaleDB workflow. Create a regular table, convert to hypertable, set up compression and retention policies, create continuous aggregates for dashboards. Once configured, everything runs automatically.

- Create regular table with timestamptz column
- Convert to hypertable: create_hypertable()
- Create indexes on time + frequently queried columns
- Add compression policy: add_compression_policy()
- Add retention policy: add_retention_policy()
- Create continuous aggregates for dashboards
- Set aggregate refresh policy
- Monitor with timescaledb_information views

### TimescaleDB Use Cases
Common use cases for TimescaleDB. IoT sensor data, application metrics and monitoring, financial tick data, server and infrastructure logs, and real-time analytics dashboards. Any workload where data has a timestamp and arrives continuously.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Common use cases for TimescaleDB |
| **IoT sensor data** | application metrics and monitoring, financial tick data, server and infrastructure logs, and real-time analytics dash... |
| **Point 3** | Any workload where data has a timestamp and arrives continuously |

### When to Use / Not Use TimescaleDB
A beginner trap — do not use TimescaleDB for non-time-series data. Regular tables with proper indexing are better for transactional data, user records, or any data without a strong time component. TimescaleDB optimizes specifically for append-heavy, time-ordered workloads.

| Good Fit | Bad Fit |
| :--- | :--- |
| Data has a timestamp column | Transactional (OLTP) data |
| Mostly INSERT, rarely UPDATE | Frequent UPDATE / DELETE |
| Queries filter by time range | No time component |
| Need time-based aggregation | Small datasets (< 10M rows) |
| High ingestion rate | Random access patterns |
| Need automatic data lifecycle | Regular tables work just fine |


---

## 3. Hands-On Commands & psql Output

### Installing TimescaleDB
**Explanation:** Install TimescaleDB. It requires a package install and shared_preload_libraries configuration, then a restart. After that, create the extension in your database.

```sql
postgres=# -- 1. Install the OS package:
postgres=# -- Debian/Ubuntu:
postgres=# --   sudo apt install timescaledb-2-postgresql-16
postgres=# -- RHEL/Rocky:
postgres=# --   sudo dnf install timescaledb-2-postgresql-16
postgres=# -- Windows: download from timescale.com
postgres=# -- 2. Run the tuning script:
postgres=# --   sudo timescaledb-tune
postgres=# -- (auto-configures postgresql.conf for time-series)
postgres=# -- 3. Or manually edit postgresql.conf:
postgres=# --   shared_preload_libraries = 'timescaledb'
postgres=# -- 4. Restart PostgreSQL:
postgres=# --   sudo systemctl restart postgresql-16
postgres=# -- 5. Create extension:
postgres=# CREATE EXTENSION timescaledb;
postgres=# -- Verify:
\dx timescaledb
postgres=# -- timescaledb | 2.x.x | public | Time-series database
```

### Creating a Hypertable
**Explanation:** Create a hypertable in two steps. First, create a regular table with a timestamp column. Then convert it to a hypertable with create_hypertable. That is it — TimescaleDB handles the rest automatically.

```sql
postgres=# -- Step 1: Create a regular table:
postgres=# CREATE TABLE sensor_data (
    time        timestamptz NOT NULL,
    sensor_id   int NOT NULL,
    temperature double precision,
    humidity    double precision
);
postgres=# -- Step 2: Convert to hypertable:
postgres=# SELECT create_hypertable('sensor_data', 'time');
postgres=# -- create_hypertable
postgres=# -- (1, public, sensor_data, t)
postgres=# -- That is it! It looks and works like a regular table:
postgres=# INSERT INTO sensor_data VALUES
(now(), 1, 22.5, 45.0),
(now(), 2, 23.1, 42.0),
(now() - interval '1 hour', 1, 21.8, 47.0);
postgres=# SELECT * FROM sensor_data ORDER BY time DESC;
postgres=# -- Works exactly like a normal table!
```

### Chunks — Automatic Time Partitioning
**Explanation:** Under the hood, TimescaleDB splits the hypertable into time-based chunks. By default, each chunk covers 7 days. When you query a time range, only the relevant chunks are scanned — not the entire table. You can customize the chunk interval.

```sql
postgres=# -- View chunks:
postgres=# SELECT show_chunks('sensor_data');
postgres=# -- _timescaledb_internal._hyper_1_1_chunk
postgres=# -- _timescaledb_internal._hyper_1_2_chunk
postgres=# -- Detailed chunk info:
postgres=# SELECT chunk_name, range_start, range_end
postgres-# FROM timescaledb_information.chunks
postgres-# WHERE hypertable_name = 'sensor_data';
postgres=# -- _hyper_1_1_chunk | 2024-10-21 | 2024-10-28
postgres=# -- _hyper_1_2_chunk | 2024-10-28 | 2024-11-04
postgres=# -- Custom chunk interval (e.g., 1 day for high-volume):
postgres=# SELECT create_hypertable(
    'high_freq_data', 'time',
    chunk_time_interval => INTERVAL '1 day'
);
postgres=# -- Change interval for existing hypertable:
postgres=# SELECT set_chunk_time_interval(
    'sensor_data', INTERVAL '1 day'
);
```

### Inserting Time-Series Data
**Explanation:** Insert data just like a normal table. TimescaleDB automatically routes rows to the correct chunk. Bulk inserts with COPY are the fastest method for loading large amounts of time-series data.

```sql
postgres=# -- Single insert (same as normal):
postgres=# INSERT INTO sensor_data (time, sensor_id, temperature, humidity)
postgres-# VALUES (now(), 1, 22.5, 45.0);
postgres=# -- Bulk insert with generate_series:
postgres=# INSERT INTO sensor_data
SELECT
    time,
    (random() * 10 + 1)::int AS sensor_id,
    20 + random() * 10 AS temperature,
    40 + random() * 20 AS humidity
postgres-# FROM generate_series(
    now() - interval '30 days',
    now(),
    interval '1 minute'
) AS time;
postgres=# -- Inserts ~43,200 rows (1 per minute for 30 days)
postgres=# -- Check row count:
postgres=# SELECT count(*) FROM sensor_data;
postgres=# -- 43,200+
```

### time_bucket() — Time-Based Aggregation
**Explanation:** Time-series queries are where TimescaleDB shines. time_bucket is the key function — it groups data into time intervals like 1 hour, 5 minutes, or 1 day. Think of it as a time-aware GROUP BY.

```sql
postgres=# -- Average temperature per hour:
SELECT
    time_bucket('1 hour', time) AS hour,
    avg(temperature) AS avg_temp,
    avg(humidity) AS avg_humidity
postgres-# FROM sensor_data
postgres-# WHERE time > now() - interval '24 hours'
postgres-# GROUP BY hour
postgres-# ORDER BY hour;
postgres=# -- 5-minute buckets:
SELECT
    time_bucket('5 minutes', time) AS bucket,
    sensor_id,
    avg(temperature) AS avg_temp,
    max(temperature) AS max_temp
postgres-# FROM sensor_data
postgres-# WHERE time > now() - interval '1 hour'
postgres-# GROUP BY bucket, sensor_id
postgres-# ORDER BY bucket, sensor_id;
postgres=# -- Daily summary:
SELECT
    time_bucket('1 day', time) AS day,
    count(*) AS readings,
    round(avg(temperature)::numeric, 2) AS avg_temp
postgres-# FROM sensor_data
postgres-# GROUP BY day
postgres-# ORDER BY day DESC LIMIT 7;
```

### Continuous Aggregates — Precomputed Rollups
**Explanation:** Continuous aggregates pre-compute time_bucket queries and update automatically as new data arrives. This means your dashboard queries are instant instead of scanning millions of rows every time.

```sql
postgres=# -- Create a continuous aggregate for hourly stats:
postgres=# CREATE MATERIALIZED VIEW hourly_stats
postgres=# WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS hour,
    sensor_id,
    avg(temperature) AS avg_temp,
    min(temperature) AS min_temp,
    max(temperature) AS max_temp,
    count(*) AS readings
postgres-# FROM sensor_data
postgres-# GROUP BY hour, sensor_id;
postgres=# -- Query the aggregate (instant — precomputed!):
postgres=# SELECT * FROM hourly_stats
postgres-# WHERE hour > now() - interval '24 hours'
postgres-# ORDER BY hour, sensor_id;
postgres=# -- Set refresh policy (auto-update):
postgres=# SELECT add_continuous_aggregate_policy(
    'hourly_stats',
    start_offset => INTERVAL '3 hours',
    end_offset   => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);
```

### Compression — 90%+ Storage Savings
**Explanation:** Compression reduces storage by 90 percent or more. TimescaleDB compresses old chunks that are no longer being written to. You can enable automatic compression with a policy.

```sql
postgres=# -- Enable compression on the hypertable:
postgres=# ALTER TABLE sensor_data SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'sensor_id',
    timescaledb.compress_orderby = 'time DESC'
);
postgres=# -- Manually compress a chunk:
postgres=# SELECT compress_chunk('_timescaledb_internal._hyper_1_1_chunk');
postgres=# -- Add automatic compression policy:
postgres=# -- Compress chunks older than 7 days:
postgres=# SELECT add_compression_policy(
    'sensor_data',
    compress_after => INTERVAL '7 days'
);
postgres=# -- Check compression stats:
SELECT
    chunk_name,
    before_compression_total_bytes,
    after_compression_total_bytes,
    round(
        (1 - after_compression_total_bytes::numeric /
         before_compression_total_bytes) * 100
    ) AS compression_pct
postgres-# FROM chunk_compression_stats('sensor_data');
postgres=# -- Typically 90-95% compression!
```

### Retention Policies — Auto-Drop Old Data
**Explanation:** Data retention policies automatically drop old chunks. Instead of running DELETE on millions of rows — which is slow and leaves dead tuples — TimescaleDB simply drops entire chunks. This is instant and reclaims disk space immediately.

```sql
postgres=# -- Add retention policy — drop data older than 90 days:
postgres=# SELECT add_retention_policy(
    'sensor_data',
    drop_after => INTERVAL '90 days'
);
postgres=# -- Manual drop of old chunks:
postgres=# SELECT drop_chunks(
    'sensor_data',
    older_than => INTERVAL '90 days'
);
postgres=# -- Why this is better than DELETE:
postgres=# -- DELETE FROM sensor_data
postgres=# -- WHERE time < now() - interval '90 days';
postgres=# -- ↑ Slow: scans all rows, creates dead tuples,
postgres=# --   needs VACUUM, does not reclaim disk space
postgres=# -- DROP CHUNKS:
postgres=# -- ↑ Instant: drops entire chunk files,
postgres=# --   reclaims disk space immediately,
postgres=# --   no dead tuples, no VACUUM needed
postgres=# -- View active policies:
postgres=# SELECT * FROM timescaledb_information.jobs
postgres-# WHERE hypertable_name = 'sensor_data';
```

### Analytics Functions — first() & last()
**Explanation:** TimescaleDB provides useful analytics functions. first and last return the value at the earliest or latest timestamp. These are perfect for getting the most recent reading from each sensor.

```sql
postgres=# -- Latest reading from each sensor:
SELECT
    sensor_id,
    last(temperature, time) AS latest_temp,
    last(humidity, time) AS latest_humidity,
    max(time) AS last_seen
postgres-# FROM sensor_data
postgres-# GROUP BY sensor_id
postgres-# ORDER BY sensor_id;
postgres=# -- First reading of each day per sensor:
SELECT
    time_bucket('1 day', time) AS day,
    sensor_id,
    first(temperature, time) AS opening_temp,
    last(temperature, time) AS closing_temp
postgres-# FROM sensor_data
postgres-# WHERE time > now() - interval '7 days'
postgres-# GROUP BY day, sensor_id
postgres-# ORDER BY day, sensor_id;
postgres=# -- Combine with time_bucket for powerful rollups:
SELECT
    time_bucket('1 hour', time) AS hour,
    first(temperature, time) AS first_temp,
    last(temperature, time) AS last_temp,
    max(temperature) - min(temperature) AS temp_range
postgres-# FROM sensor_data
postgres-# WHERE sensor_id = 1
postgres-# GROUP BY hour
postgres-# ORDER BY hour DESC LIMIT 10;
```

### Performance Tips
**Explanation:** Performance tips. Always include the time column in your WHERE clause — this enables chunk exclusion. Create composite indexes on time plus your most common filter columns. Use continuous aggregates for dashboard queries. And set compression early — it saves both storage and query time on old data.

```sql
postgres=# -- GOOD: time filter enables chunk exclusion:
postgres=# SELECT avg(temperature) FROM sensor_data
postgres-# WHERE time > now() - interval '1 hour';
postgres=# -- Scans only the latest chunk!
postgres=# -- BAD: no time filter scans ALL chunks:
postgres=# SELECT avg(temperature) FROM sensor_data
postgres-# WHERE sensor_id = 1;
postgres=# -- Scans every chunk — slow!
postgres=# -- BETTER: add time filter even if you have other filters:
postgres=# SELECT avg(temperature) FROM sensor_data
postgres-# WHERE sensor_id = 1
postgres-# AND time > now() - interval '24 hours';
postgres=# -- Only scans recent chunks
postgres=# -- Composite index for common queries:
postgres=# CREATE INDEX idx_sensor_time
postgres-# ON sensor_data (sensor_id, time DESC);
postgres=# -- Check chunk exclusion with EXPLAIN:
postgres=# EXPLAIN SELECT * FROM sensor_data
postgres-# WHERE time > now() - interval '1 hour';
postgres=# -- Should show only 1-2 chunks scanned
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. TimescaleDB is a PostgreSQL extension for time-series data. Hypertables look like regular tables but are auto-partitioned into time chunks. time_bucket groups data into intervals for aggregation. Continuous aggregates pre-compute rollups for instant dashboard queries. Compression saves 90 percent or more storage. Retention policies auto-drop old chunks instantly. Always include time in WHERE clauses for chunk exclusion. In the next class, we explore Citus for distributed PostgreSQL.

- **Extension for time-series workloads**
- **create_hypertable(): auto-partition by time**
- **time_bucket(): GROUP BY time intervals**
- **Continuous aggregates: precomputed rollups**
- **Compression: 90%+ storage savings**
- **Retention: drop_chunks (instant, no VACUUM)**
- **first() / last(): analytics functions**
- **Always filter by time for chunk exclusion**
- **Best for: IoT, metrics, logs, finance**
- **Not for: OLTP, small datasets, no-time data**
- **Next: Citus — Distributed PostgreSQL**


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
