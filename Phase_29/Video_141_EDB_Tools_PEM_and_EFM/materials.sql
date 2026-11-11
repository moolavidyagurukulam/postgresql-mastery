-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- EDB Tools: PEM & EFM (Classes 262-263)
-- Phase 29: EDB & Distributions
-- ============================================================

-- ============================================================
-- 1. POSTGRES ENTERPRISE MANAGER (PEM) OVERVIEW
-- ============================================================

-- PEM = pgAdmin 4 + Enterprise Monitoring
-- Web-based dashboard for multiple PG/EPAS servers
-- Architecture: PEM Server (central) + PEM Agents (per node)

-- Key features:
-- - Multi-server dashboard (health, connections, TPS)
-- - 50+ built-in alert templates with email/SNMP notifications
-- - Scheduled probes for historical data collection
-- - SQL Profiler for query execution tracing
-- - Audit Log Manager (pgAudit integration)
-- - Capacity planning and trend analysis

-- ============================================================
-- 2. PEM vs OPEN SOURCE MONITORING STACK
-- ============================================================

-- PEM Feature         → Open Source Equivalent
-- Dashboard           → Grafana + custom dashboards
-- Metrics Collection  → Prometheus + postgres_exporter
-- Alerting            → Grafana Alerts or Alertmanager
-- SQL Profiling       → pg_stat_statements + auto_explain
-- Management          → pgAdmin 4 (free)
-- Audit               → pgAudit + log parsing tools
-- Setup               → PEM: ~1 day | OSS stack: ~3-5 days

-- ============================================================
-- 3. MONITORING QUERIES (Community PG Equivalent)
-- ============================================================

-- Active connections by state:
SELECT state, count(*)
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY state;

-- Transactions per second (snapshot):
SELECT xact_commit + xact_rollback AS total_txns,
  xact_commit, xact_rollback
FROM pg_stat_database
WHERE datname = current_database();

-- Replication lag:
SELECT client_addr, state,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- Top slow queries (requires pg_stat_statements):
SELECT calls, mean_exec_time::numeric(10,2) AS avg_ms,
  left(query, 80) AS query
FROM pg_stat_statements
ORDER BY mean_exec_time DESC LIMIT 10;

-- Table bloat estimate:
SELECT relname,
  pg_size_pretty(pg_total_relation_size(oid)) AS size,
  n_dead_tup,
  last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 10;

-- ============================================================
-- 4. EDB FAILOVER MANAGER (EFM) OVERVIEW
-- ============================================================

-- EFM = Automatic failover for PG/EPAS HA clusters
-- Architecture: EFM Agent on each node (primary + standby + witness)
-- Consensus: majority must agree primary is down before promotion
-- Actions on failover:
--   1. Promote healthiest standby to primary
--   2. Reconfigure other standbys to follow new primary
--   3. Update VIP (virtual IP) to new primary
--   4. Notify administrators

-- ============================================================
-- 5. EFM vs PATRONI COMPARISON
-- ============================================================

-- Feature          | EFM (EDB)          | Patroni (Open Source)
-- -----------------+--------------------+----------------------
-- License          | EDB subscription   | Free (MIT)
-- Consensus        | Built-in protocol  | etcd/Consul/ZooKeeper
-- Auto Failover    | Yes                | Yes
-- Switchover       | Yes                | Yes
-- VIP Management   | Built-in           | Callback scripts
-- Witness Node     | Supported          | Not needed (etcd quorum)
-- Config Format    | Properties file    | YAML
-- Community        | EDB customers      | Very widely adopted
-- Support          | EDB 24/7           | Community
-- Best For         | EDB/EPAS shops     | Community PG shops

-- ============================================================
-- 6. HA CLUSTER HEALTH CHECKS (Community PG)
-- ============================================================

-- Check if this server is primary or standby:
SELECT pg_is_in_recovery();
-- FALSE = primary, TRUE = standby

-- Check replication status (run on primary):
SELECT client_addr, state, sync_state,
  sent_lsn, write_lsn, flush_lsn, replay_lsn,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- Check WAL receiver status (run on standby):
SELECT status, sender_host, sender_port,
  received_lsn, latest_end_lsn
FROM pg_stat_wal_receiver;

-- ============================================================
-- 7. FAILOVER TESTING PROCEDURE
-- ============================================================

-- Monthly failover drill:
-- 1. Notify team of planned failover test
-- 2. Check replication lag = 0
-- 3. Stop primary PostgreSQL
-- 4. Verify EFM/Patroni promotes standby
-- 5. Test application connects to new primary
-- 6. Rebuild old primary as standby
-- 7. Document results and time taken

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Set up Grafana + Prometheus + postgres_exporter.
--    Create dashboard: connections, TPS, replication lag.

-- 2. Install Patroni + etcd on 3 nodes (primary + standby + etcd).
--    This is the free EFM equivalent.

-- 3. Simulate primary failure (stop PostgreSQL on primary).
--    Verify Patroni/EFM promotes standby automatically.
--    Measure time from failure to promotion.

-- 4. If you have EDB trial: install PEM and EFM.
--    Compare setup effort with Grafana + Patroni stack.
