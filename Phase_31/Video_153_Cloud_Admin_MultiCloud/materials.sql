-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Cloud Administration & Multi-Cloud (Classes 286-287)
-- Phase 31: Cloud PostgreSQL
-- ============================================================

-- ============================================================
-- 1. SECURITY — IAM AUTHENTICATION
-- ============================================================

-- AWS — IAM DB Authentication:
-- 1. Enable IAM auth on instance:
-- aws rds modify-db-instance --db-instance-identifier myapp-pg \
--   --enable-iam-database-authentication --apply-immediately

-- 2. Create IAM-authenticated user:
CREATE USER iam_user WITH LOGIN;
GRANT rds_iam TO iam_user;

-- 3. Generate auth token and connect:
-- TOKEN=$(aws rds generate-db-auth-token \
--   --hostname myapp.xxxx.rds.amazonaws.com \
--   --port 5432 --username iam_user)
-- psql "host=myapp.xxxx.rds.amazonaws.com user=iam_user \
--   password=$TOKEN dbname=myapp sslmode=require"

-- Azure — Entra ID Authentication:
-- 1. Enable Entra admin:
-- az postgres flexible-server ad-admin create \
--   --resource-group myapp-rg --server-name myapp-pg \
--   --display-name "DBA Team" --object-id <group-object-id>

-- 2. Get access token:
-- TOKEN=$(az account get-access-token \
--   --resource-type oss-rdbms --query accessToken -o tsv)
-- PGPASSWORD=$TOKEN psql "host=myapp-pg.postgres.database.azure.com \
--   user=dba@myapp-pg dbname=postgres sslmode=require"

-- GCP — Auth Proxy (handles IAM automatically):
-- ./cloud-sql-proxy --port 5432 PROJECT:region:instance &
-- psql -h 127.0.0.1 -U postgres -d myapp

-- ============================================================
-- 2. SECURITY — AUDIT LOGGING
-- ============================================================

-- Enable pgAudit extension:
-- AWS: add pgaudit to shared_preload_libraries (parameter group)
-- Azure: enable pgaudit server parameter
-- GCP: set cloudsql.enable_pgaudit=on

CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Configure audit logging:
-- pgaudit.log = 'ddl, role'         -- Log DDL + role changes
-- pgaudit.log_catalog = off          -- Skip system catalog queries
-- pgaudit.log_statement_once = on    -- Log statement once, not per row

-- Check audit settings:
SHOW pgaudit.log;

-- ============================================================
-- 3. SECURITY — LEAST PRIVILEGE ROLES
-- ============================================================

-- Application role (read-write on specific tables):
CREATE ROLE app_role NOLOGIN;
GRANT CONNECT ON DATABASE myapp TO app_role;
GRANT USAGE ON SCHEMA public TO app_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_role;

-- Application user:
CREATE USER app_user WITH PASSWORD 'secure_password';
GRANT app_role TO app_user;

-- Read-only role:
CREATE ROLE readonly_role NOLOGIN;
GRANT CONNECT ON DATABASE myapp TO readonly_role;
GRANT USAGE ON SCHEMA public TO readonly_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO readonly_role;

-- Reporting user:
CREATE USER report_user WITH PASSWORD 'report_password';
GRANT readonly_role TO report_user;

-- ============================================================
-- 4. MONITORING — KEY QUERIES
-- ============================================================

-- Active connections by state:
SELECT state, count(*)
FROM pg_stat_activity
GROUP BY state
ORDER BY count DESC;

-- Long-running queries (> 5 minutes):
SELECT pid, now() - query_start AS duration,
  state, left(query, 100) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND now() - query_start > interval '5 minutes'
ORDER BY duration DESC;

-- Top tables by size:
SELECT schemaname || '.' || tablename AS table_name,
  pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size,
  pg_size_pretty(pg_relation_size(schemaname || '.' || tablename)) AS data_size,
  pg_size_pretty(pg_indexes_size(schemaname || '.' || tablename)) AS index_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC
LIMIT 20;

-- Cache hit ratio (should be > 99%):
SELECT
  sum(heap_blks_hit) * 100.0 / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0) AS cache_hit_ratio
FROM pg_statio_user_tables;

-- Index usage ratio:
SELECT schemaname, tablename,
  idx_scan AS index_scans,
  seq_scan AS sequential_scans,
  CASE WHEN idx_scan + seq_scan > 0
    THEN round(100.0 * idx_scan / (idx_scan + seq_scan), 1)
    ELSE 0
  END AS index_usage_pct
FROM pg_stat_user_tables
ORDER BY seq_scan DESC
LIMIT 20;

-- Replication lag:
SELECT client_addr, state,
  sent_lsn, replay_lsn,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
  pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_pretty
FROM pg_stat_replication;

-- ============================================================
-- 5. MONITORING — CLOUD CLI ALERTS
-- ============================================================

-- AWS CloudWatch alert (CPU > 80%):
-- aws cloudwatch put-metric-alarm \
--   --alarm-name "RDS-CPU-High" \
--   --metric-name CPUUtilization \
--   --namespace AWS/RDS \
--   --statistic Average \
--   --period 300 \
--   --threshold 80 \
--   --comparison-operator GreaterThanThreshold \
--   --evaluation-periods 2 \
--   --alarm-actions arn:aws:sns:us-east-1:ACCOUNT:DBATeam \
--   --dimensions Name=DBInstanceIdentifier,Value=myapp-pg

-- Azure Monitor alert (connections > 80%):
-- az monitor metrics alert create \
--   --name "PG-Connections-High" \
--   --resource-group myapp-rg \
--   --scopes /subscriptions/SUB/resourceGroups/myapp-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/myapp-pg \
--   --condition "avg active_connections > 160" \
--   --action DBATeam

-- ============================================================
-- 6. BACKUP & DR TESTING
-- ============================================================

-- Monthly PITR test procedure:

-- AWS:
-- aws rds restore-db-instance-to-point-in-time \
--   --source-db-instance-identifier myapp-pg \
--   --target-db-instance-identifier myapp-dr-test \
--   --restore-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
-- # Wait for available, connect, verify, delete

-- Azure:
-- az postgres flexible-server restore \
--   --resource-group myapp-rg \
--   --name myapp-dr-test \
--   --source-server myapp-pg \
--   --restore-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)

-- GCP:
-- gcloud sql instances clone myapp-pg myapp-dr-test \
--   --point-in-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)

-- Portable backup (works across clouds):
-- pg_dump -Fc -h source-host -U admin dbname > backup.dump
-- pg_restore -h target-host -U admin -d dbname backup.dump

-- ============================================================
-- 7. MAJOR VERSION UPGRADE — SAFE PROCEDURE
-- ============================================================

-- 1. Create snapshot
-- 2. Restore to test instance
-- 3. Upgrade test instance to new version
-- 4. Run application test suite against upgraded instance
-- 5. Check pg_stat_statements for query regressions
-- 6. If all pass: schedule production upgrade in maintenance window
-- 7. Monitor for 24 hours after upgrade

-- Check for incompatible objects before upgrade:
SELECT * FROM pg_catalog.pg_extension;
-- Verify all extensions available on new version

-- Check for deprecated features:
-- Read PG release notes for your target version

-- ============================================================
-- 8. CONNECTION POOLING
-- ============================================================

-- Azure Flexible Server — built-in PgBouncer:
-- az postgres flexible-server parameter set \
--   --resource-group myapp-rg --server-name myapp-pg \
--   --name pgbouncer.enabled --value true

-- PgBouncer config (self-deployed):
-- [databases]
-- myapp = host=myapp.xxxx.rds.amazonaws.com port=5432 dbname=myapp
--
-- [pgbouncer]
-- listen_addr = 0.0.0.0
-- listen_port = 6432
-- auth_type = scram-sha-256
-- pool_mode = transaction
-- max_client_conn = 1000
-- default_pool_size = 25
-- min_pool_size = 5

-- ============================================================
-- 9. CROSS-CLOUD LOGICAL REPLICATION
-- ============================================================

-- Prerequisites:
-- wal_level = logical (set in parameter group)
-- max_replication_slots >= 4
-- max_wal_senders >= 4

-- On SOURCE (e.g., AWS RDS):
CREATE PUBLICATION cross_cloud_pub
  FOR TABLE users, orders, products;

-- Create replication user:
CREATE USER repl_user WITH REPLICATION LOGIN PASSWORD 'repl_password';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO repl_user;

-- On TARGET (e.g., Azure Flexible Server):
-- Create identical tables first (same schema)
-- Then create subscription:
CREATE SUBSCRIPTION cross_cloud_sub
  CONNECTION 'host=myapp.xxxx.rds.amazonaws.com
    port=5432 dbname=myapp
    user=repl_user password=repl_password
    sslmode=require'
  PUBLICATION cross_cloud_pub;

-- Monitor replication status:
SELECT subname, received_lsn, latest_end_lsn,
  latest_end_time
FROM pg_stat_subscription;

-- ============================================================
-- 10. MULTI-CLOUD PORTABILITY CHECKLIST
-- ============================================================

-- [ ] Use standard PostgreSQL features only
-- [ ] No Aurora/AlloyDB-specific extensions
-- [ ] Weekly pg_dump stored outside any single cloud
-- [ ] Schema migrations in Flyway/Liquibase (portable)
-- [ ] Connection string from environment variable
-- [ ] Terraform modules per cloud provider
-- [ ] Quarterly DR test: restore to different cloud
-- [ ] Document cloud-specific parameter mappings
-- [ ] Test application against both clouds
-- [ ] Monitor cross-cloud replication lag

-- ============================================================
-- 11. COST MANAGEMENT
-- ============================================================

-- Tagging best practices:
-- All resources tagged with:
--   env = prod | staging | dev
--   team = backend | data | platform
--   app = myapp | analytics | reporting
--   cost-center = engineering | marketing

-- Dev/test scheduling (stop at night, save ~65%):
-- AWS:
-- aws rds stop-db-instance --db-instance-identifier myapp-dev
-- aws rds start-db-instance --db-instance-identifier myapp-dev

-- Azure:
-- az postgres flexible-server stop \
--   --resource-group myapp-rg --name myapp-dev
-- az postgres flexible-server start \
--   --resource-group myapp-rg --name myapp-dev

-- GCP (cannot stop, but can reduce to minimum tier):
-- gcloud sql instances patch myapp-dev --tier=db-f1-micro

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Enable pgAudit. Perform DDL (CREATE TABLE, ALTER).
--    Review audit logs. Verify operations are logged.

-- 2. Set up IAM authentication on your cloud provider.
--    Connect using token/proxy instead of password.

-- 3. Create a monitoring alert for CPU > 80%.
--    Generate load. Verify alert fires.

-- 4. Perform monthly DR test: PITR to new instance.
--    Connect. Run SELECT queries. Verify data. Delete instance.

-- 5. Set up logical replication between two PG instances
--    (different regions or different cloud providers).
--    Insert data on source. Verify appears on target.
