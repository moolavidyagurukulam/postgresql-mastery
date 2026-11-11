-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Migration Planning & Testing Checklist (Classes 256-257)
-- Phase 28: Upgrade & Migration
-- ============================================================

-- ============================================================
-- 1. ASSESSMENT — INVENTORY QUERIES
-- ============================================================

-- Count objects by type:
SELECT
  (SELECT count(*) FROM pg_class WHERE relkind='r'
   AND relnamespace = 'public'::regnamespace) AS tables,
  (SELECT count(*) FROM pg_class WHERE relkind='v'
   AND relnamespace = 'public'::regnamespace) AS views,
  (SELECT count(*) FROM pg_class WHERE relkind='i'
   AND relnamespace = 'public'::regnamespace) AS indexes,
  (SELECT count(*) FROM pg_class WHERE relkind='S'
   AND relnamespace = 'public'::regnamespace) AS sequences,
  (SELECT count(*) FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace) AS functions;

-- Total database size:
SELECT pg_size_pretty(pg_database_size(current_database()));

-- Top 10 largest tables:
SELECT relname,
  pg_size_pretty(pg_total_relation_size(oid)) AS total_size,
  n_live_tup AS row_count
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;

-- List all extensions:
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- ============================================================
-- 2. DATA VALIDATION QUERIES
-- ============================================================

-- Row count per table:
SELECT relname AS table_name, n_live_tup AS row_count
FROM pg_stat_user_tables
ORDER BY relname;

-- Exact count (for critical tables):
-- SELECT 'employees' AS tbl, count(*) FROM employees
-- UNION ALL
-- SELECT 'orders', count(*) FROM orders
-- UNION ALL
-- SELECT 'products', count(*) FROM products;

-- Checksum on critical columns:
-- SELECT md5(string_agg(
--   emp_id::text || name || salary::text,
--   ',' ORDER BY emp_id
-- )) AS employees_checksum
-- FROM employees;

-- Check for NULL where NOT NULL expected:
-- SELECT count(*) AS null_names
-- FROM employees WHERE name IS NULL;

-- Sequence sync verification:
SELECT sequencename, last_value
FROM pg_sequences
WHERE schemaname = 'public';

-- ============================================================
-- 3. SEQUENCE SYNC — Generate setval commands
-- ============================================================

-- Generate setval for every sequence:
SELECT format(
  'SELECT setval(%L, COALESCE((SELECT max(%I) FROM %I.%I), 1));',
  seq.relname,
  col.attname,
  tab_ns.nspname,
  tab.relname
)
FROM pg_class seq
JOIN pg_namespace seq_ns ON seq.relnamespace = seq_ns.oid
JOIN pg_depend d ON d.objid = seq.oid
JOIN pg_class tab ON d.refobjid = tab.oid
JOIN pg_namespace tab_ns ON tab.relnamespace = tab_ns.oid
JOIN pg_attribute col ON col.attrelid = tab.oid
  AND col.attnum = d.refobjsubid
WHERE seq.relkind = 'S'
  AND d.deptype = 'a'
ORDER BY seq.relname;

-- ============================================================
-- 4. POST-CUTOVER MONITORING CONFIGURATION
-- ============================================================

-- postgresql.conf settings for monitoring:
-- shared_preload_libraries = 'pg_stat_statements'
-- pg_stat_statements.track = all
-- log_min_duration_statement = 500  (log queries > 500ms)
-- log_checkpoints = on
-- log_connections = on
-- log_disconnections = on
-- log_lock_waits = on
-- log_temp_files = 0

-- After restart, enable the extension:
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- ============================================================
-- 5. POST-CUTOVER MONITORING QUERIES
-- ============================================================

-- Top 10 slowest queries:
SELECT calls, mean_exec_time::numeric(10,2) AS avg_ms,
  total_exec_time::numeric(10,2) AS total_ms,
  left(query, 80) AS query
FROM pg_stat_statements
ORDER BY mean_exec_time DESC LIMIT 10;

-- Active connections by state:
SELECT state, count(*)
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY state;

-- Lock contention:
SELECT blocked.pid,
  blocked_activity.query AS blocked_query,
  blocking.pid AS blocking_pid
FROM pg_locks blocked
JOIN pg_stat_activity blocked_activity
  ON blocked.pid = blocked_activity.pid
JOIN pg_locks blocking
  ON blocked.locktype = blocking.locktype
  AND blocked.pid != blocking.pid
WHERE NOT blocked.granted;

-- Database size:
SELECT pg_size_pretty(pg_database_size(current_database()));

-- ============================================================
-- 6. PERFORMANCE TESTING
-- ============================================================

-- Enable timing:
-- \timing on

-- Run key application queries with EXPLAIN ANALYZE:
-- EXPLAIN (ANALYZE, BUFFERS) SELECT ...;

-- Compare execution time with source database
-- Document results in a comparison table

-- ============================================================
-- 7. MIGRATION PHASES CHECKLIST
-- ============================================================

-- PHASE 1: ASSESSMENT
-- [ ] Object inventory complete (tables, views, indexes, etc.)
-- [ ] Data volume measured (total size, largest tables)
-- [ ] Complexity score / person-day estimate
-- [ ] Application connection patterns documented
-- [ ] Downtime tolerance defined

-- PHASE 2: SCHEMA CONVERSION
-- [ ] Data type mapping documented
-- [ ] DDL loads without errors on empty PG database
-- [ ] All stored procedures converted (PL/SQL or T-SQL → PL/pgSQL)
-- [ ] All triggers converted
-- [ ] All views converted and tested

-- PHASE 3: DATA MIGRATION
-- [ ] Migration method chosen (pgLoader / BCP+COPY / logical rep)
-- [ ] Load order defined (tables → sequences → data → indexes → FKs)
-- [ ] Row counts match on ALL tables
-- [ ] Checksums match on critical tables
-- [ ] All sequences synced to max(id)+1
-- [ ] VACUUM ANALYZE completed
-- [ ] Encoding validated (no garbled characters)

-- PHASE 4: APPLICATION CONVERSION
-- [ ] Connection strings updated
-- [ ] ORM configuration updated
-- [ ] SQL syntax fixed (TOP→LIMIT, ISNULL→COALESCE, etc.)
-- [ ] Case sensitivity handled (ILIKE or citext)
-- [ ] GROUP BY strictness fixed
-- [ ] Full regression test suite passes
-- [ ] Performance benchmarks pass

-- PHASE 5: CUTOVER
-- [ ] Rehearsal #1 completed (timing measured)
-- [ ] Rehearsal #2 completed (issues from #1 fixed)
-- [ ] Rollback plan documented and tested
-- [ ] Stakeholders notified of maintenance window
-- [ ] Final backup of source taken
-- [ ] Writes stopped on source
-- [ ] Final data sync completed
-- [ ] Connection strings switched to PostgreSQL
-- [ ] Smoke tests pass on production
-- [ ] 24-hour monitoring active
-- [ ] Source database kept running for rollback

-- ============================================================
-- 8. ROLLBACK PROCEDURE
-- ============================================================

-- 1. Stop application
-- 2. Switch connection strings back to source database
-- 3. Restart application
-- 4. Verify application works on source
-- 5. Investigate what went wrong
-- 6. Data written to PG after cutover is lost (unless reverse replication)

-- Rollback trigger criteria (define BEFORE cutover):
-- - Error rate > 1%
-- - Response time > 2x baseline
-- - Data corruption detected
-- - Critical feature not working

-- ============================================================
-- 9. MIGRATION TIMELINE TEMPLATE
-- ============================================================

-- Phase 1: Assessment       — 1-2 weeks
-- Phase 2: Schema Conversion — 2-4 weeks
-- Phase 3: Data Migration Dev — 1-2 weeks
-- Phase 4: App Conversion    — 2-6 weeks (parallel with Phase 2-3)
-- Phase 5: Integration Test  — 1-2 weeks
-- Phase 6: Rehearsal (2x)    — 1 week
-- Phase 7: Cutover           — 4-24 hours
-- Phase 8: Post-Cutover      — 1-2 weeks monitoring
-- TOTAL: 6-14 weeks (medium complexity)

-- ============================================================
-- 10. MIGRATION STRATEGY DECISION FRAMEWORK
-- ============================================================

-- Small DB + downtime OK    → dump + convert + restore
-- Medium DB + short window  → pgLoader direct streaming
-- Large DB + no downtime    → Logical replication cutover
-- Oracle + packages         → Ora2Pg + manual PL/SQL
-- MySQL + simple schema     → One-command pgLoader
-- SQL Server + many procs   → pgLoader + manual T-SQL conversion
-- PG major version upgrade  → pg_upgrade (link mode)
-- PG upgrade + no downtime  → Logical replication

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a migration assessment for a test database.
--    Count all objects, measure total size, score complexity.

-- 2. Build a migration timeline using the 8-phase template.
--    Assign realistic dates and owners to each phase.

-- 3. Full rehearsal: migrate a test database end-to-end.
--    Schema + data + validation + app test. Time everything.

-- 4. Practice rollback: switch to PG, insert test data,
--    rollback to source. Measure total rollback time.

-- 5. Set up post-cutover monitoring (pg_stat_statements +
--    slow query log). Run queries under load. Review reports.
