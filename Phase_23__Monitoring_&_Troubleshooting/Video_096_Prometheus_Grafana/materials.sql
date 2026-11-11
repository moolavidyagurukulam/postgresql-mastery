-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Prometheus & Grafana Monitoring (Classes 196-197)
-- Phase 23: Monitoring & Troubleshooting
-- ============================================================

-- ============================================================
-- 1. CREATE MONITORING ROLE
-- ============================================================

CREATE ROLE monitoring WITH LOGIN PASSWORD 'monitor123';
GRANT pg_monitor TO monitoring;

-- pg_monitor grants read access to:
-- pg_stat_activity, pg_stat_replication,
-- pg_stat_database, pg_stat_user_tables, etc.

-- ============================================================
-- 2. VERIFY postgres_exporter METRICS
-- ============================================================

-- After starting postgres_exporter on port 9187:
-- curl http://localhost:9187/metrics | grep pg_up
-- pg_up 1  → PostgreSQL is connected

-- Key metrics exposed:
-- pg_stat_database_xact_commit
-- pg_stat_database_blks_hit / blks_read
-- pg_stat_database_deadlocks
-- pg_stat_database_temp_files
-- pg_stat_user_tables_n_dead_tup
-- pg_stat_user_tables_seq_scan
-- pg_stat_activity_count
-- pg_database_size_bytes

-- ============================================================
-- 3. CUSTOM METRICS QUERIES
-- ============================================================

-- Save as /etc/postgres_exporter/queries.yaml:
-- pg_orders_by_status:
--   query: |
--     SELECT status, count(*) AS count
--     FROM orders GROUP BY status
--   metrics:
--     - status:
--         usage: "LABEL"
--     - count:
--         usage: "GAUGE"
--         description: "Number of orders by status"

-- pg_oldest_transaction:
--   query: |
--     SELECT EXTRACT(EPOCH FROM (now() - xact_start))::int AS age_seconds
--     FROM pg_stat_activity
--     WHERE xact_start IS NOT NULL
--     ORDER BY xact_start LIMIT 1
--   metrics:
--     - age_seconds:
--         usage: "GAUGE"
--         description: "Age of oldest transaction in seconds"

-- ============================================================
-- 4. PROMETHEUS CONFIGURATION
-- ============================================================

-- /etc/prometheus/prometheus.yml:
-- global:
--   scrape_interval: 15s
-- scrape_configs:
--   - job_name: 'postgresql'
--     static_configs:
--       - targets: ['localhost:9187']
--     scrape_interval: 10s

-- ============================================================
-- 5. ESSENTIAL PromQL QUERIES
-- ============================================================

-- Use these in Grafana dashboards or Prometheus UI:

-- TPS (transactions per second):
-- rate(pg_stat_database_xact_commit{datname="mydb"}[5m])

-- Cache hit ratio:
-- 100 * pg_stat_database_blks_hit / (blks_hit + blks_read)

-- Active connections:
-- pg_stat_activity_count{state="active"}

-- Dead rows top 5:
-- topk(5, pg_stat_user_tables_n_dead_tup)

-- Database size:
-- pg_database_size_bytes{datname="mydb"}

-- ============================================================
-- 6. ALERT RULES
-- ============================================================

-- /etc/prometheus/pg_alerts.yml:
-- groups:
--   - name: postgresql
--     rules:
--       - alert: PostgreSQLDown
--         expr: pg_up == 0
--         for: 1m
--       - alert: HighConnectionUsage
--         expr: sum(pg_stat_activity_count) / pg_settings_max_connections > 0.8
--         for: 5m
--       - alert: LowCacheHitRatio
--         expr: blks_hit / (blks_hit + blks_read) < 0.95
--         for: 10m

-- ============================================================
-- 7. SQL QUERIES FOR MANUAL MONITORING
-- ============================================================

-- These are the SQL equivalents of Prometheus metrics:

-- TPS (requires two snapshots):
SELECT xact_commit, xact_rollback
FROM pg_stat_database WHERE datname = current_database();
-- Run again after 60s, calculate difference / 60

-- Cache hit ratio:
SELECT
    ROUND(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2)
FROM pg_stat_database WHERE datname = current_database();

-- Connection count by state:
SELECT state, count(*)
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY state;

-- Dead rows by table:
SELECT relname, n_dead_tup
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 5;

-- Database sizes:
SELECT datname,
    pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database ORDER BY pg_database_size(datname) DESC;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a monitoring role with pg_monitor access.
-- 2. Install postgres_exporter and verify metrics at :9187.
-- 3. Write a custom metric query for your application
--    (e.g., orders by status, users by type).
-- 4. Set up Prometheus to scrape postgres_exporter.
--    Verify in Prometheus UI (Status → Targets).
-- 5. Import Grafana dashboard 9628. Take a screenshot
--    of TPS and cache hit ratio panels.
