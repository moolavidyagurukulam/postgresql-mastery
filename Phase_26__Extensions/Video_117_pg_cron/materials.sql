-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- pg_cron — Scheduled Jobs Inside PostgreSQL (Class 223)
-- Phase 26: Extensions
-- ============================================================

-- ============================================================
-- INSTALLATION (run as superuser)
-- ============================================================

-- 1. Install OS package:
--    Debian/Ubuntu: sudo apt install postgresql-16-cron
--    RHEL/Rocky:    sudo dnf install pg_cron_16

-- 2. Edit postgresql.conf:
--    shared_preload_libraries = 'pg_cron'
--    cron.database_name = 'postgres'

-- 3. Restart PostgreSQL:
--    sudo systemctl restart postgresql-16

-- 4. Create extension:
CREATE EXTENSION pg_cron;

-- ============================================================
-- 1. CREATING JOBS
-- ============================================================

-- VACUUM every night at 3 AM:
SELECT cron.schedule(
    'nightly-vacuum',
    '0 3 * * *',
    'VACUUM ANALYZE public.orders'
);

-- Refresh materialized view every hour:
SELECT cron.schedule(
    'hourly-refresh',
    '0 * * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY dashboard_stats'
);

-- Delete old logs every Sunday at midnight:
SELECT cron.schedule(
    'weekly-log-cleanup',
    '0 0 * * 0',
    $$DELETE FROM app_logs WHERE created_at < now() - interval '90 days'$$
);

-- Every 5 minutes:
SELECT cron.schedule(
    'frequent-check',
    '*/5 * * * *',
    'SELECT process_pending_queue()'
);

-- ============================================================
-- 2. VIEWING JOBS
-- ============================================================

-- List all jobs:
SELECT jobid, jobname, schedule, command, active
FROM cron.job ORDER BY jobid;

-- View execution history:
SELECT jobid, jobname, status, start_time, end_time,
       return_message
FROM cron.job_run_details
ORDER BY start_time DESC LIMIT 10;

-- ============================================================
-- 3. MANAGING JOBS
-- ============================================================

-- Change schedule:
SELECT cron.alter_job(
    job_id := 1,
    schedule := '0 4 * * *'
);

-- Pause a job:
UPDATE cron.job SET active = false
WHERE jobname = 'frequent-check';

-- Resume:
UPDATE cron.job SET active = true
WHERE jobname = 'frequent-check';

-- Delete:
SELECT cron.unschedule('nightly-vacuum');

-- ============================================================
-- 4. CROSS-DATABASE JOBS
-- ============================================================

SELECT cron.schedule_in_database(
    'vacuum-app-db',
    '0 3 * * *',
    'VACUUM ANALYZE orders',
    'app_db'
);

-- ============================================================
-- 5. NIGHTLY AGGREGATION EXAMPLE
-- ============================================================

CREATE TABLE daily_order_stats (
    stat_date date PRIMARY KEY,
    order_count int,
    total_revenue numeric(12,2),
    avg_order_value numeric(10,2),
    computed_at timestamptz DEFAULT now()
);

SELECT cron.schedule(
    'nightly-order-stats',
    '5 1 * * *',
    $$INSERT INTO daily_order_stats
        (stat_date, order_count, total_revenue, avg_order_value)
    SELECT current_date - 1, count(*), sum(amount), avg(amount)
    FROM orders
    WHERE created_at >= current_date - 1
      AND created_at < current_date
    ON CONFLICT (stat_date) DO UPDATE SET
        order_count = EXCLUDED.order_count,
        total_revenue = EXCLUDED.total_revenue,
        avg_order_value = EXCLUDED.avg_order_value,
        computed_at = now()$$
);

-- ============================================================
-- 6. MONITORING FAILED JOBS
-- ============================================================

SELECT jobname, status, return_message, start_time
FROM cron.job_run_details
WHERE status = 'failed'
ORDER BY start_time DESC;

-- ============================================================
-- 7. HISTORY CLEANUP
-- ============================================================

-- Clean old history:
DELETE FROM cron.job_run_details
WHERE end_time < now() - interval '30 days';

-- Schedule automatic cleanup:
SELECT cron.schedule(
    'cleanup-cron-history',
    '0 4 * * 0',
    $$DELETE FROM cron.job_run_details
      WHERE end_time < now() - interval '30 days'$$
);

-- ============================================================
-- 8. NON-SUPERUSER ACCESS
-- ============================================================

GRANT USAGE ON SCHEMA cron TO app_user;
GRANT SELECT ON cron.job TO app_user;
GRANT SELECT ON cron.job_run_details TO app_user;

-- ============================================================
-- CRON SCHEDULE REFERENCE
-- ============================================================

-- ┌───────── minute (0-59)
-- │ ┌─────── hour (0-23)
-- │ │ ┌───── day of month (1-31)
-- │ │ │ ┌─── month (1-12)
-- │ │ │ │ ┌─ day of week (0-6, 0=Sunday)
-- │ │ │ │ │
-- * * * * *

-- Examples:
-- '0 3 * * *'     = daily at 3:00 AM
-- '*/10 * * * *'  = every 10 minutes
-- '0 * * * *'     = every hour at :00
-- '0 0 * * 0'     = every Sunday at midnight
-- '0 0 1 * *'     = first of every month at midnight
-- '30 9 * * 1-5'  = weekdays at 9:30 AM

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install pg_cron (or simulate by reading the cron.job table).

-- 2. Schedule a job that runs VACUUM ANALYZE on a table
--    every night at 2 AM.

-- 3. Schedule a job that deletes rows older than 60 days
--    every Sunday.

-- 4. Query cron.job_run_details to see execution history.

-- 5. Create a history cleanup job that runs weekly.

-- ============================================================
-- CLEANUP
-- ============================================================
-- SELECT cron.unschedule('nightly-vacuum');
-- SELECT cron.unschedule('hourly-refresh');
-- SELECT cron.unschedule('weekly-log-cleanup');
-- SELECT cron.unschedule('frequent-check');
-- SELECT cron.unschedule('nightly-order-stats');
-- SELECT cron.unschedule('cleanup-cron-history');
-- DROP TABLE IF EXISTS daily_order_stats;
-- DROP EXTENSION IF EXISTS pg_cron;
