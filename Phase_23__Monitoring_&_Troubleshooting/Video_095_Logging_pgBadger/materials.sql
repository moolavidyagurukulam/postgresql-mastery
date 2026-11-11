-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Logging Configuration & pgBadger (Classes 194-195)
-- Phase 23: Monitoring & Troubleshooting
-- ============================================================

-- ============================================================
-- 1. LOGGING CONFIGURATION
-- ============================================================

-- Current logging settings:
SHOW logging_collector;
SHOW log_destination;
SHOW log_directory;
SHOW log_filename;
SHOW log_line_prefix;
SHOW log_min_duration_statement;
SHOW log_statement;
SHOW log_checkpoints;
SHOW log_connections;
SHOW log_disconnections;
SHOW log_lock_waits;
SHOW log_temp_files;

-- ============================================================
-- 2. RECOMMENDED PRODUCTION CONFIG
-- ============================================================

-- postgresql.conf:
-- logging_collector = on
-- log_destination = 'csvlog'
-- log_directory = 'log'
-- log_filename = 'postgresql-%Y-%m-%d_%H%M%S'
-- log_rotation_age = '1d'
-- log_rotation_size = '100MB'
-- log_min_duration_statement = 500  -- in ms
-- log_statement = 'ddl'
-- log_checkpoints = on
-- log_connections = on
-- log_disconnections = on
-- log_lock_waits = on
-- log_temp_files = 0
-- log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h '

-- ============================================================
-- 3. auto_explain EXTENSION
-- ============================================================

-- postgresql.conf (requires restart):
-- shared_preload_libraries = 'auto_explain'
-- auto_explain.log_min_duration = '1s'
-- auto_explain.log_analyze = on
-- auto_explain.log_buffers = on
-- auto_explain.log_format = text

-- Or per-session (no restart):
LOAD 'auto_explain';
SET auto_explain.log_min_duration = '500ms';
SET auto_explain.log_analyze = on;

-- ============================================================
-- 4. LOADING CSV LOGS INTO POSTGRESQL
-- ============================================================

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

-- Load CSV:
-- COPY postgres_log FROM '/path/to/postgresql.csv' WITH (FORMAT csv);

-- ============================================================
-- 5. QUERYING LOADED LOGS
-- ============================================================

-- Top 10 slowest queries:
SELECT
    log_time, user_name, database_name,
    SUBSTRING(message FROM 'duration: ([0-9.]+) ms')::numeric AS duration_ms,
    LEFT(query, 80) AS query_text
FROM postgres_log
WHERE message LIKE 'duration:%'
ORDER BY duration_ms DESC
LIMIT 10;

-- Error distribution:
SELECT error_severity, COUNT(*) AS count
FROM postgres_log
WHERE error_severity IN ('ERROR', 'FATAL', 'PANIC')
GROUP BY error_severity ORDER BY count DESC;

-- Hourly query distribution:
SELECT date_trunc('hour', log_time) AS hour, COUNT(*) AS queries
FROM postgres_log
WHERE message LIKE 'duration:%'
GROUP BY hour ORDER BY hour;

-- ============================================================
-- 6. pgBadger COMMANDS
-- ============================================================

-- Install:
-- sudo apt install pgbadger

-- Generate report from stderr log:
-- pgbadger -p '%t [%p]: user=%u,db=%d,app=%a,client=%h ' \
--     /var/lib/postgresql/16/main/log/*.log \
--     -o /tmp/pgbadger_report.html

-- From csvlog:
-- pgbadger -f csv /var/lib/postgresql/16/main/log/*.csv \
--     -o /tmp/pgbadger_report.html

-- Incremental daily reports:
-- pgbadger -I -O /var/www/pgbadger/ \
--     /var/lib/postgresql/16/main/log/*.log

-- ============================================================
-- 7. LOG RETENTION CRON
-- ============================================================

-- /etc/cron.daily/pg-log-cleanup:
-- find /var/lib/postgresql/16/main/log/ \
--     -name 'postgresql-*.log' -mtime +30 -delete
-- find /var/lib/postgresql/16/main/log/ \
--     -name 'postgresql-*.csv' -mtime +30 -delete

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Check your current log_min_duration_statement.
--    If it's -1 (disabled), set it to 500ms.
-- 2. Run a slow query (e.g., pg_sleep(2)).
--    Find it in the log file.
-- 3. Enable auto_explain per-session.
--    Run a query > 500ms and check the log for the plan.
-- 4. If you have csvlog, load it into postgres_log table.
--    Find the top 5 slowest queries.
-- 5. Install pgBadger and generate a report from your logs.
--    What are the top queries by total time?
