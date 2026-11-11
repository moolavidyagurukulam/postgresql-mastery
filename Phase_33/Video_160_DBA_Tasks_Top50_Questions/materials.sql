-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- DBA Daily Tasks & Top 50 Interview Questions (Classes 286-287)
-- Phase 33: Interview & Career
-- ============================================================

-- ============================================================
-- SECTION 1: DBA DAILY MONITORING QUERIES
-- ============================================================

-- ============================================================
-- Morning Health Check Script
-- Run this every morning in 5 minutes
-- ============================================================

-- 1. Check database sizes and growth:
SELECT datname,
    pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE datname NOT IN ('template0', 'template1')
ORDER BY pg_database_size(datname) DESC;

-- 2. Check replication status (run on PRIMARY):
SELECT client_addr, state, sent_lsn, replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_pretty
FROM pg_stat_replication;

-- 3. Connection count by state:
SELECT state, count(*)
FROM pg_stat_activity
GROUP BY state ORDER BY count DESC;

-- Total vs max:
SELECT count(*) AS current,
    (SELECT setting::int FROM pg_settings
     WHERE name = 'max_connections') AS max
FROM pg_stat_activity;

-- 4. Long-running queries (> 1 minute):
SELECT pid, now() - query_start AS duration,
    state, left(query, 80) AS query
FROM pg_stat_activity
WHERE state = 'active'
    AND now() - query_start > interval '1 minute'
ORDER BY duration DESC;

-- 5. Idle-in-transaction connections (leaked transactions):
SELECT pid, usename,
    now() - state_change AS idle_duration,
    left(query, 60) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY idle_duration DESC;

-- 6. Table bloat check (top 10 bloated):
SELECT schemaname, relname,
    n_live_tup, n_dead_tup,
    CASE WHEN n_live_tup + n_dead_tup > 0
        THEN round(100.0 * n_dead_tup /
            (n_live_tup + n_dead_tup), 1)
    END AS dead_pct,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC LIMIT 10;

-- 7. Unused indexes (wasting disk space):
SELECT schemaname, relname, indexrelname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS idx_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND pg_relation_size(indexrelid) > 1048576
ORDER BY pg_relation_size(indexrelid) DESC;

-- 8. Tables with high sequential scans (may need indexes):
SELECT schemaname, relname,
    seq_scan, idx_scan,
    CASE WHEN seq_scan + idx_scan > 0
        THEN round(100.0 * idx_scan /
            (seq_scan + idx_scan), 1)
    END AS idx_usage_pct
FROM pg_stat_user_tables
WHERE seq_scan > 1000
ORDER BY seq_scan DESC LIMIT 10;

-- 9. Autovacuum health check:
SELECT schemaname, relname,
    last_autovacuum, last_autoanalyze,
    autovacuum_count, autoanalyze_count
FROM pg_stat_user_tables
ORDER BY last_autovacuum DESC NULLS LAST LIMIT 10;

-- 10. Checksum failures (if checksums enabled):
SELECT datname, checksum_failures, checksum_last_failure
FROM pg_stat_database
WHERE checksum_failures > 0;

-- ============================================================
-- SECTION 2: TOP 50 INTERVIEW QUESTIONS & ANSWERS
-- ============================================================

-- ============================================================
-- FUNDAMENTALS (1-10)
-- ============================================================

-- Q1: What is PostgreSQL?
-- Open-source object-relational DBMS. ACID-compliant. Extensible.
-- Supports SQL, JSON, full-text, GIS. 35+ years of development.

-- Q2: What is MVCC?
-- Multi-Version Concurrency Control. Each transaction sees a snapshot.
-- Readers never block writers. Old versions cleaned by VACUUM.

-- Q3: CHAR vs VARCHAR vs TEXT?
-- CHAR(n): fixed-length, padded. VARCHAR(n): max length. TEXT: unlimited.
-- In PostgreSQL, all three have identical performance. Use VARCHAR or TEXT.

-- Q4: ACID properties?
-- Atomicity: all or nothing. Consistency: valid state after transaction.
-- Isolation: transactions don't interfere. Durability: committed = permanent.

-- Q5: Primary Key vs Unique constraint?
-- PK: NOT NULL + UNIQUE, only one per table, creates index.
-- Unique: allows NULL, multiple per table, creates index.

-- Q6: What is a Foreign Key?
-- Column referencing PK of another table. Prevents orphan rows.
-- ON DELETE CASCADE/RESTRICT/SET NULL. Always index FK columns.

-- Q7: DELETE vs TRUNCATE vs DROP?
-- DELETE: row by row, logged, rollback OK, triggers fire, slow.
-- TRUNCATE: instant, minimal logging, rollback OK in PG, no triggers.
-- DROP: destroys table + data + indexes. Gone.

-- Q8: What are indexes?
-- Sorted data structures for fast lookups. B-tree is default.
-- Speed reads, slow writes. Don't over-index.

-- Q9: What is a transaction?
-- BEGIN → SQL → COMMIT/ROLLBACK. All-or-nothing unit of work.
-- Supports SAVEPOINTs for partial rollback.

-- Q10: What is a schema?
-- Namespace within a database. Default is 'public'.
-- search_path controls resolution: SET search_path TO myapp, public;

-- ============================================================
-- PERFORMANCE (11-20)
-- ============================================================

-- Q11: Finding slow queries?
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT left(query, 60) AS query, calls,
    round(mean_exec_time::numeric, 1) AS mean_ms,
    round(total_exec_time::numeric, 1) AS total_ms
FROM pg_stat_statements
WHERE calls > 100
ORDER BY mean_exec_time DESC LIMIT 10;

-- Q12: EXPLAIN ANALYZE?
-- Shows execution plan with actual timing.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders WHERE user_id = 42;
-- Look for: Seq Scan (needs index), high Rows Removed, disk reads.

-- Q13: Index types in PostgreSQL?
-- B-tree: default. Equality (=) and range (<, >, BETWEEN).
-- GIN: full-text search, arrays, JSONB containment (@>).
-- GiST: geometric, range types, nearest-neighbor.
-- BRIN: large tables with natural ordering (timestamp). Tiny index.
-- Hash: exact equality only. Rarely needed over B-tree.

-- Q14: Partial index?
CREATE INDEX idx_active_orders ON orders(created_at)
    WHERE status = 'active';
-- Only indexes active orders. Smaller, faster, very useful.

-- Q15: Covering index?
CREATE INDEX idx_users_email ON users(email) INCLUDE (name);
-- Index-only scan: returns name without reading the table heap.

-- Q16: Connection pooling?
-- PgBouncer in transaction mode:
-- max_client_conn = 1000, default_pool_size = 25.
-- 1000 app connections share 25 real DB connections.

-- Q17: shared_buffers?
SHOW shared_buffers;
-- Set to 25% of RAM. PostgreSQL's own data page cache.

-- Q18: work_mem?
SHOW work_mem;
-- Memory per sort/hash per query. Default 4MB.
-- Increase for complex analytical queries. Careful: per-operation.

-- Q19: effective_cache_size?
SHOW effective_cache_size;
-- Hint to planner. Set to 50-75% of RAM. No actual allocation.

-- Q20: VACUUM explained?
-- Standard VACUUM: marks dead rows reusable. No lock. File doesn't shrink.
-- VACUUM FULL: rewrites table. File shrinks. LOCKS table.
-- Autovacuum: runs automatically based on dead row threshold.
-- pg_repack: online rebuild without locks (extension).

-- ============================================================
-- REPLICATION & HA (21-25)
-- ============================================================

-- Q21: Streaming replication?
-- Primary streams WAL to standby in real-time.
-- Standby replays. Hot standby allows read queries.
-- Check: SELECT * FROM pg_stat_replication;

-- Q22: Synchronous vs asynchronous?
-- synchronous_commit = on + synchronous_standby_names = 'standby1'
-- Sync: COMMIT waits for standby ACK. Zero data loss. Higher latency.
-- Async: COMMIT immediately. Risk losing recent txns on failover.

-- Q23: Replication slots?
SELECT pg_create_physical_replication_slot('standby_slot');
-- Retains WAL until standby confirms. Prevents data loss.
-- WARNING: if standby is offline, WAL accumulates on primary.

-- Q24: Logical replication?
-- Selective table replication. Cross-version. Cross-platform.
-- CREATE PUBLICATION pub FOR TABLE orders;
-- CREATE SUBSCRIPTION sub CONNECTION '...' PUBLICATION pub;

-- Q25: Patroni?
-- HA framework with auto-failover. Uses etcd/Consul for DCS.
-- Failover < 30 seconds. HAProxy for connection routing.
-- patronictl list — shows cluster status.

-- ============================================================
-- BACKUP & RECOVERY (26-30)
-- ============================================================

-- Q26: Point-in-Time Recovery (PITR)?
-- 1. Restore base backup
-- 2. Configure restore_command + recovery_target_time
-- 3. PostgreSQL replays WAL to that timestamp
-- Recovers from: accidental DROP TABLE, bad UPDATE, data corruption.

-- Q27: pg_basebackup?
-- pg_basebackup -h primary -U repl_user -D /backup -R -P -X stream
-- -R: creates standby.signal for replication
-- -P: shows progress. -X stream: includes WAL.

-- Q28: pgBackRest vs pg_dump?
-- pgBackRest: physical. Incremental. Parallel. Fast restore. Large DBs.
-- pg_dump: logical. Portable. Selective (tables/schemas). Slower.
-- Best practice: use both. pgBackRest for DR, pg_dump for portability.

-- Q29: WAL archiving?
-- archive_mode = on
-- archive_command = 'cp %p /archive/%f'
-- Required for PITR. Each 16MB WAL file archived when full.

-- Q30: Backup testing?
-- Monthly: restore to test server. Verify data. Time the restore.
-- A backup you never tested will fail when you need it most.

-- ============================================================
-- SECURITY (31-35)
-- ============================================================

-- Q31: pg_hba.conf?
-- TYPE  DATABASE  USER    ADDRESS        METHOD
-- host  all       all     10.0.0.0/24    scram-sha-256
-- First matching line wins. Reload: SELECT pg_reload_conf();

-- Q32: Authentication methods?
-- scram-sha-256: modern, secure (default in PG 16).
-- md5: legacy, weaker. cert: SSL certificates.
-- LDAP: directory integration. trust: no password (dev only!).

-- Q33: Row-Level Security?
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_orders ON orders
    USING (user_id = current_setting('app.user_id')::int);
-- Each user sees only their orders. Even SELECT * is filtered.

-- Q34: SSL/TLS?
-- ssl = on in postgresql.conf
-- ssl_cert_file = 'server.crt'
-- ssl_key_file = 'server.key'
-- Client: sslmode=verify-full for full verification.

-- Q35: GRANT and REVOKE?
-- GRANT SELECT, INSERT ON orders TO app_user;
-- REVOKE DELETE ON orders FROM app_user;
-- Principle of least privilege. Audit with \dp in psql.

-- ============================================================
-- ADVANCED (36-40)
-- ============================================================

-- Q36: CTEs (Common Table Expressions)?
WITH monthly_sales AS (
    SELECT date_trunc('month', created_at) AS month,
        sum(total) AS revenue
    FROM orders GROUP BY month
)
SELECT month, revenue,
    revenue - lag(revenue) OVER (ORDER BY month) AS growth
FROM monthly_sales;

-- Q37: Window functions?
SELECT name, department, salary,
    rank() OVER (PARTITION BY department ORDER BY salary DESC) AS rank,
    salary - avg(salary) OVER (PARTITION BY department) AS diff_from_avg
FROM employees;

-- Q38: Table partitioning?
-- CREATE TABLE logs (id SERIAL, created_at DATE, message TEXT)
--     PARTITION BY RANGE (created_at);
-- CREATE TABLE logs_2026_01 PARTITION OF logs
--     FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

-- Q39: JSONB?
-- Store: INSERT INTO docs VALUES ('{"name": "test", "tags": ["a","b"]}');
-- Query: SELECT data->>'name' FROM docs WHERE data @> '{"tags": ["a"]}';
-- Index: CREATE INDEX idx_docs_data ON docs USING GIN(data);

-- Q40: Full-text search?
-- SELECT * FROM articles
-- WHERE to_tsvector('english', title || ' ' || body)
--     @@ to_tsquery('english', 'postgresql & performance');

-- ============================================================
-- OPERATIONS (41-45)
-- ============================================================

-- Q41: Autovacuum?
-- Runs automatically. Reclaims dead rows. Updates statistics.
-- Tune per table: autovacuum_vacuum_scale_factor = 0.01 for large tables.
-- Never disable globally. Monitor with pg_stat_user_tables.

-- Q42: Transaction ID wraparound?
-- 32-bit txid. Wraps at ~2 billion. Autovacuum freezes old rows.
-- Monitor: SELECT datname, age(datfrozenxid) FROM pg_database;
-- Alert at age > 500 million. Emergency at > 1 billion.

-- Q43: Major version upgrade?
-- pg_upgrade --old-datadir --new-datadir --old-bindir --new-bindir
-- Use --link for fast upgrade (hard links, seconds instead of hours).
-- Or: logical replication for zero-downtime upgrade.
-- Always: test on staging first. Read release notes.

-- Q44: pg_stat_statements?
-- shared_preload_libraries = 'pg_stat_statements'
-- CREATE EXTENSION pg_stat_statements;
-- Query: top 10 by total time (see Q11 above).

-- Q45: Tablespaces?
-- CREATE TABLESPACE fast_ssd LOCATION '/mnt/ssd/pgdata';
-- ALTER TABLE hot_data SET TABLESPACE fast_ssd;
-- Moves data to different physical storage.

-- ============================================================
-- FINAL (46-50)
-- ============================================================

-- Q46: Function vs Procedure?
-- Function: RETURNS value. Used in SELECT. No tx control inside.
-- Procedure: CALL proc(). Supports COMMIT/ROLLBACK inside. PG 11+.

-- Q47: Triggers?
-- CREATE TRIGGER audit_log AFTER UPDATE ON orders
--     FOR EACH ROW EXECUTE FUNCTION log_change();
-- Fires automatically. Useful for audit, validation, derived data.

-- Q48: pg_repack?
-- Extension. Rebuilds table online without locks.
-- pg_repack -d myapp -t bloated_table
-- Alternative to VACUUM FULL for production.

-- Q49: WAL (Write-Ahead Log)?
-- All changes written to WAL before data files.
-- Crash recovery: replay WAL to recover uncommitted state.
-- Enables: streaming replication, PITR, archiving.

-- Q50: PostgreSQL vs MySQL?
-- PG: true MVCC, richer SQL, JSONB, extensions, full-text, GIS.
-- PG: window functions, CTEs, partitioning, RLS, better ACID.
-- MySQL: simpler, more web hosting support, faster simple reads.
-- Choose PG for: complex queries, data integrity, enterprise.

-- ============================================================
-- PRACTICE
-- ============================================================

-- 1. Run the morning health check script above on your database.
-- 2. Pick 10 questions and answer them without looking. Time yourself.
-- 3. For each answer, include the actual SQL command, not just the concept.
-- 4. Practice explaining EXPLAIN ANALYZE output to a colleague.
-- 5. Write a 1-page DBA runbook for your most critical database.
