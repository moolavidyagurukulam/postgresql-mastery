-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Self-Managed vs Cloud & Cost Comparison (Classes 284-285)
-- Phase 31: Cloud PostgreSQL
-- ============================================================

-- ============================================================
-- 1. SELF-MANAGED — KEY SETUP STEPS
-- ============================================================

-- Install PostgreSQL 16 (Ubuntu/Debian):
-- sudo apt install -y postgresql-16 postgresql-client-16

-- Key config files:
-- /etc/postgresql/16/main/postgresql.conf
-- /etc/postgresql/16/main/pg_hba.conf

-- Essential tuning parameters:
-- shared_buffers = '4GB'          # 25% of RAM
-- effective_cache_size = '12GB'   # 75% of RAM
-- work_mem = '32MB'               # per-operation memory
-- maintenance_work_mem = '1GB'    # for VACUUM, CREATE INDEX
-- max_connections = 200
-- wal_level = replica
-- max_wal_senders = 10

-- ============================================================
-- 2. SELF-MANAGED — BACKUP WITH PGBACKREST
-- ============================================================

-- Install pgBackRest:
-- sudo apt install pgbackrest

-- /etc/pgbackrest/pgbackrest.conf:
-- [myapp]
-- pg1-path=/var/lib/postgresql/16/main
-- pg1-port=5432
--
-- [global]
-- repo1-path=/var/lib/pgbackrest
-- repo1-retention-full=4
-- repo1-retention-diff=14
-- process-max=4
-- log-level-console=info

-- Create stanza:
-- sudo -u postgres pgbackrest --stanza=myapp stanza-create

-- Full backup:
-- sudo -u postgres pgbackrest --stanza=myapp --type=full backup

-- Differential backup (daily):
-- sudo -u postgres pgbackrest --stanza=myapp --type=diff backup

-- List backups:
-- sudo -u postgres pgbackrest --stanza=myapp info

-- Restore:
-- sudo systemctl stop postgresql
-- sudo -u postgres pgbackrest --stanza=myapp restore
-- sudo systemctl start postgresql

-- ============================================================
-- 3. SELF-MANAGED — HA WITH PATRONI
-- ============================================================

-- Install Patroni:
-- pip install patroni[etcd]

-- /etc/patroni/patroni.yml (minimal):
-- scope: myapp-cluster
-- name: pg-node1
-- restapi:
--   listen: 0.0.0.0:8008
-- etcd:
--   host: 10.0.0.10:2379
-- bootstrap:
--   dcs:
--     postgresql:
--       parameters:
--         shared_buffers: 4GB
--         wal_level: replica
-- postgresql:
--   listen: 0.0.0.0:5432
--   data_dir: /var/lib/postgresql/16/main
--   authentication:
--     superuser:
--       password: secret
--     replication:
--       password: secret

-- Start Patroni:
-- patroni /etc/patroni/patroni.yml

-- Check cluster status:
-- patronictl -c /etc/patroni/patroni.yml list

-- ============================================================
-- 4. SELF-MANAGED — MONITORING
-- ============================================================

-- Install postgres_exporter (for Prometheus):
-- DATA_SOURCE_NAME="postgresql://monitor:password@localhost:5432/postgres?sslmode=disable"
-- ./postgres_exporter

-- Create monitoring user:
CREATE ROLE monitor WITH LOGIN PASSWORD 'monitor_pass';
GRANT pg_monitor TO monitor;

-- Key monitoring queries:

-- Database size:
SELECT pg_database.datname,
  pg_size_pretty(pg_database_size(pg_database.datname))
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;

-- Active connections:
SELECT count(*), state
FROM pg_stat_activity
GROUP BY state;

-- Long-running queries:
SELECT pid, now() - pg_stat_activity.query_start AS duration,
  query, state
FROM pg_stat_activity
WHERE state != 'idle'
  AND (now() - pg_stat_activity.query_start) > interval '5 minutes';

-- Table bloat estimate:
SELECT schemaname, tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;

-- Replication lag:
SELECT client_addr, state,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
  pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_pretty
FROM pg_stat_replication;

-- ============================================================
-- 5. CLOUD — RESERVED INSTANCE SAVINGS
-- ============================================================

-- AWS Reserved Instances:
-- 1-year: ~30% savings
-- 3-year: ~50-60% savings
-- aws rds purchase-reserved-db-instances-offering \
--   --reserved-db-instances-offering-id <offering-id> \
--   --db-instance-count 1

-- Azure Reserved Capacity:
-- 1-year: ~30% savings
-- 3-year: ~50% savings
-- Purchase through Azure Portal → Reservations

-- GCP Committed Use Discounts:
-- 1-year: ~25% savings
-- 3-year: ~52% savings
-- Purchase through Cloud Console → Billing → Commitments

-- ============================================================
-- 6. COST COMPARISON — MEDIUM WORKLOAD
-- ============================================================

-- Workload: 4 vCPU, 16 GB RAM, 500 GB SSD, HA, daily backups

-- Self-Managed (dedicated server):
--   Compute: $200/month (2 servers for HA)
--   Storage: $50/month (SSD)
--   Backup storage: $30/month (S3/offsite)
--   Monitoring: $50/month (Grafana Cloud)
--   DBA time (20%): $2,000/month
--   Total: ~$2,530/month

-- AWS RDS (db.r6g.xlarge, Multi-AZ):
--   Compute: $800/month (with Multi-AZ)
--   Storage (gp3, 500GB): $40/month
--   Backup: $20/month (beyond free tier)
--   Total: ~$860/month (on-demand)
--   With 1-year RI: ~$600/month

-- AWS Aurora (db.r6g.xlarge):
--   Compute: $920/month (with HA)
--   Storage: $50/month
--   I/O: $100-500/month (varies)
--   Total: ~$1,100-1,500/month

-- Azure Flexible (D4ds_v5, Zone-Redundant):
--   Compute: $700/month (with HA)
--   Storage (128 GB): $15/month
--   Backup: $10/month
--   Total: ~$725/month
--   With 1-year RI: ~$500/month

-- GCP Cloud SQL (db-custom-4-16384, Regional):
--   Compute: $750/month (with HA)
--   Storage (500 GB SSD): $85/month
--   Total: ~$835/month
--   With 1-year CUD: ~$600/month

-- ============================================================
-- 7. MIGRATION TOOLS
-- ============================================================

-- pg_dump / pg_restore (< 100 GB):
-- pg_dump -Fc -h source-host -U user dbname > backup.dump
-- pg_restore -h target-host -U user -d dbname backup.dump

-- AWS DMS (Database Migration Service):
-- Supports full load + CDC (change data capture)
-- Minimal downtime migration
-- Console: aws.amazon.com → DMS → Create task

-- Azure DMS:
-- az dms create --resource-group myapp-rg \
--   --name myapp-dms --sku-name Premium_4vCores \
--   --location eastus

-- Google DMS:
-- Console: console.cloud.google.com → Database Migration

-- ============================================================
-- 8. EXTENSION AVAILABILITY CHECK
-- ============================================================

-- List your current extensions:
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- Common extensions on cloud:
-- pg_stat_statements  → Available on ALL (AWS, Azure, GCP)
-- pgcrypto            → Available on ALL
-- postgis             → Available on ALL
-- pg_trgm             → Available on ALL
-- hstore              → Available on ALL
-- uuid-ossp           → Available on ALL
-- pg_partman          → AWS, Azure (not GCP Cloud SQL)
-- pglogical           → AWS, Azure (not GCP Cloud SQL)
-- Custom C extensions → Self-managed ONLY

-- Check available extensions on cloud:
SELECT * FROM pg_available_extensions ORDER BY name;

-- ============================================================
-- 9. DECISION FRAMEWORK
-- ============================================================

-- Question 1: Do you have DBA or deep PG expertise?
--   NO  → Cloud-managed (operational simplicity)
--   YES → Continue to Question 2

-- Question 2: Need custom extensions or bare-metal performance?
--   YES → Self-managed (full control)
--   NO  → Continue to Question 3

-- Question 3: Running 50+ database instances?
--   YES → Evaluate cost (self-managed often cheaper at scale)
--   NO  → Cloud-managed (simpler operations)

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Use pricing calculators (AWS, Azure, GCP).
--    Enter your workload specs. Compare monthly costs.

-- 2. Estimate self-managed total cost for same workload:
--    Server + storage + DBA time (% of salary) + tooling + on-call.

-- 3. List all extensions in your database:
SELECT extname, extversion FROM pg_extension;
--    Check availability on AWS RDS, Azure, GCP.

-- 4. Draft migration plan:
--    Source (self-managed or cloud), Target (which cloud?),
--    Method (pg_dump or DMS), Cutover strategy, Rollback plan.

-- 5. Find 3 cost optimizations in your current setup:
--    Right-sizing, reserved instances, unused replicas,
--    storage type, dev instance scheduling.
