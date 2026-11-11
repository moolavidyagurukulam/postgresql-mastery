-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- TimescaleDB — Time-Series Data (Class 229)
-- Phase 26: Extensions
-- ============================================================

-- ============================================================
-- INSTALLATION
-- ============================================================

-- 1. Install OS package:
--    Debian/Ubuntu: sudo apt install timescaledb-2-postgresql-16
--    RHEL/Rocky:    sudo dnf install timescaledb-2-postgresql-16

-- 2. Run tuning (optional but recommended):
--    sudo timescaledb-tune

-- 3. Or manually in postgresql.conf:
--    shared_preload_libraries = 'timescaledb'

-- 4. Restart PostgreSQL:
--    sudo systemctl restart postgresql-16

-- 5. Create extension:
CREATE EXTENSION timescaledb;

-- ============================================================
-- 1. CREATE A HYPERTABLE
-- ============================================================

-- Step 1: regular table with timestamptz:
CREATE TABLE sensor_data (
    time        timestamptz NOT NULL,
    sensor_id   int NOT NULL,
    temperature double precision,
    humidity    double precision
);

-- Step 2: convert to hypertable:
SELECT create_hypertable('sensor_data', 'time');

-- Custom chunk interval:
-- SELECT create_hypertable('sensor_data', 'time',
--     chunk_time_interval => INTERVAL '1 day');

-- ============================================================
-- 2. INSERT DATA
-- ============================================================

-- Single insert:
INSERT INTO sensor_data VALUES (now(), 1, 22.5, 45.0);

-- Bulk insert (30 days of data, 1 row per minute):
INSERT INTO sensor_data
SELECT
    time,
    (random() * 10 + 1)::int AS sensor_id,
    20 + random() * 10 AS temperature,
    40 + random() * 20 AS humidity
FROM generate_series(
    now() - interval '30 days',
    now(),
    interval '1 minute'
) AS time;

SELECT count(*) FROM sensor_data;

-- ============================================================
-- 3. TIME_BUCKET — Time-Based Aggregation
-- ============================================================

-- Hourly averages:
SELECT
    time_bucket('1 hour', time) AS hour,
    avg(temperature) AS avg_temp,
    avg(humidity) AS avg_humidity
FROM sensor_data
WHERE time > now() - interval '24 hours'
GROUP BY hour
ORDER BY hour;

-- 5-minute buckets per sensor:
SELECT
    time_bucket('5 minutes', time) AS bucket,
    sensor_id,
    avg(temperature) AS avg_temp,
    max(temperature) AS max_temp
FROM sensor_data
WHERE time > now() - interval '1 hour'
GROUP BY bucket, sensor_id
ORDER BY bucket, sensor_id;

-- Daily summary:
SELECT
    time_bucket('1 day', time) AS day,
    count(*) AS readings,
    round(avg(temperature)::numeric, 2) AS avg_temp
FROM sensor_data
GROUP BY day
ORDER BY day DESC LIMIT 7;

-- ============================================================
-- 4. CONTINUOUS AGGREGATES
-- ============================================================

CREATE MATERIALIZED VIEW hourly_stats
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS hour,
    sensor_id,
    avg(temperature) AS avg_temp,
    min(temperature) AS min_temp,
    max(temperature) AS max_temp,
    count(*) AS readings
FROM sensor_data
GROUP BY hour, sensor_id;

-- Query the aggregate (precomputed — instant!):
SELECT * FROM hourly_stats
WHERE hour > now() - interval '24 hours'
ORDER BY hour, sensor_id;

-- Auto-refresh policy:
SELECT add_continuous_aggregate_policy(
    'hourly_stats',
    start_offset => INTERVAL '3 hours',
    end_offset   => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

-- ============================================================
-- 5. COMPRESSION
-- ============================================================

-- Enable compression:
ALTER TABLE sensor_data SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'sensor_id',
    timescaledb.compress_orderby = 'time DESC'
);

-- Automatic compression policy (compress after 7 days):
SELECT add_compression_policy(
    'sensor_data',
    compress_after => INTERVAL '7 days'
);

-- Check compression stats:
SELECT
    chunk_name,
    before_compression_total_bytes,
    after_compression_total_bytes
FROM chunk_compression_stats('sensor_data');

-- ============================================================
-- 6. RETENTION POLICIES
-- ============================================================

-- Auto-drop data older than 90 days:
SELECT add_retention_policy(
    'sensor_data',
    drop_after => INTERVAL '90 days'
);

-- Manual drop:
SELECT drop_chunks('sensor_data', older_than => INTERVAL '90 days');

-- ============================================================
-- 7. ANALYTICS FUNCTIONS
-- ============================================================

-- Latest reading per sensor:
SELECT
    sensor_id,
    last(temperature, time) AS latest_temp,
    last(humidity, time) AS latest_humidity,
    max(time) AS last_seen
FROM sensor_data
GROUP BY sensor_id;

-- First and last per day:
SELECT
    time_bucket('1 day', time) AS day,
    sensor_id,
    first(temperature, time) AS opening_temp,
    last(temperature, time) AS closing_temp
FROM sensor_data
WHERE time > now() - interval '7 days'
GROUP BY day, sensor_id
ORDER BY day, sensor_id;

-- ============================================================
-- 8. VIEWING CHUNKS AND JOBS
-- ============================================================

-- List chunks:
SELECT show_chunks('sensor_data');

-- Detailed chunk info:
SELECT chunk_name, range_start, range_end
FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data';

-- View active jobs (compression, retention, refresh):
SELECT * FROM timescaledb_information.jobs
WHERE hypertable_name = 'sensor_data';

-- ============================================================
-- 9. PERFORMANCE INDEXES
-- ============================================================

-- Composite index for common queries:
CREATE INDEX idx_sensor_time
    ON sensor_data (sensor_id, time DESC);

-- Verify chunk exclusion:
EXPLAIN SELECT * FROM sensor_data
WHERE time > now() - interval '1 hour';

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a hypertable for web request logs with columns:
--    time, endpoint, status_code, response_ms.
--    Insert 10,000 rows using generate_series.

-- 2. Use time_bucket to find average response time per hour.

-- 3. Create a continuous aggregate for daily stats.

-- 4. Enable compression and check the storage savings.

-- 5. Use first() and last() to find the first and last
--    response time each hour.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP MATERIALIZED VIEW IF EXISTS hourly_stats;
-- DROP TABLE IF EXISTS sensor_data;
-- DROP EXTENSION IF EXISTS timescaledb;
