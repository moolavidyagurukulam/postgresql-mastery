-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- AWS RDS & Aurora PostgreSQL (Classes 280-281)
-- Phase 31: Cloud PostgreSQL
-- ============================================================

-- ============================================================
-- 1. CREATE RDS POSTGRESQL INSTANCE
-- ============================================================

-- aws rds create-db-instance \
--   --db-instance-identifier myapp-pg \
--   --engine postgres \
--   --engine-version 16.4 \
--   --db-instance-class db.t3.medium \
--   --allocated-storage 50 \
--   --storage-type gp3 \
--   --master-username app_admin \
--   --master-user-password 'SecurePass123!' \
--   --multi-az \
--   --backup-retention-period 7 \
--   --db-name myapp

-- Free tier (750 hours/month):
-- aws rds create-db-instance \
--   --db-instance-identifier myapp-free \
--   --engine postgres \
--   --engine-version 16.4 \
--   --db-instance-class db.t3.micro \
--   --allocated-storage 20 \
--   --storage-type gp2 \
--   --master-username app_admin \
--   --master-user-password 'SecurePass123!' \
--   --db-name myapp

-- ============================================================
-- 2. RDS COMMON OPERATIONS
-- ============================================================

-- Check instance status:
-- aws rds describe-db-instances \
--   --db-instance-identifier myapp-pg \
--   --query 'DBInstances[0].DBInstanceStatus'

-- Get connection endpoint:
-- aws rds describe-db-instances \
--   --db-instance-identifier myapp-pg \
--   --query 'DBInstances[0].Endpoint.Address'

-- Connect with psql:
-- psql -h myapp-pg.xxxx.us-east-1.rds.amazonaws.com \
--   -U app_admin -d myapp

-- Create manual snapshot:
-- aws rds create-db-snapshot \
--   --db-instance-identifier myapp-pg \
--   --db-snapshot-identifier myapp-pre-upgrade

-- Point-in-time restore:
-- aws rds restore-db-instance-to-point-in-time \
--   --source-db-instance-identifier myapp-pg \
--   --target-db-instance-identifier myapp-restored \
--   --restore-time 2026-11-05T10:00:00Z

-- Create read replica:
-- aws rds create-db-instance-read-replica \
--   --db-instance-identifier myapp-read1 \
--   --source-db-instance-identifier myapp-pg

-- Scale up (modify instance class):
-- aws rds modify-db-instance \
--   --db-instance-identifier myapp-pg \
--   --db-instance-class db.r6g.large \
--   --apply-immediately

-- ============================================================
-- 3. CUSTOM PARAMETER GROUP
-- ============================================================

-- Create parameter group:
-- aws rds create-db-parameter-group \
--   --db-parameter-group-name myapp-pg16 \
--   --db-parameter-group-family postgres16 \
--   --description 'Custom PG 16 settings'

-- Modify parameters:
-- aws rds modify-db-parameter-group \
--   --db-parameter-group-name myapp-pg16 \
--   --parameters \
--   'ParameterName=shared_buffers,ParameterValue={DBInstanceClassMemory/4},ApplyMethod=pending-reboot' \
--   'ParameterName=work_mem,ParameterValue=16384,ApplyMethod=immediate' \
--   'ParameterName=log_statement,ParameterValue=ddl,ApplyMethod=immediate' \
--   'ParameterName=log_min_duration_statement,ParameterValue=1000,ApplyMethod=immediate'

-- Attach to instance:
-- aws rds modify-db-instance \
--   --db-instance-identifier myapp-pg \
--   --db-parameter-group-name myapp-pg16 \
--   --apply-immediately

-- ============================================================
-- 4. AURORA POSTGRESQL — CREATE CLUSTER
-- ============================================================

-- Create Aurora cluster:
-- aws rds create-db-cluster \
--   --db-cluster-identifier myapp-aurora \
--   --engine aurora-postgresql \
--   --engine-version 16.4 \
--   --master-username app_admin \
--   --master-user-password 'SecurePass123!' \
--   --database-name myapp \
--   --backup-retention-period 7

-- Add writer instance:
-- aws rds create-db-instance \
--   --db-instance-identifier myapp-writer \
--   --db-cluster-identifier myapp-aurora \
--   --engine aurora-postgresql \
--   --db-instance-class db.r6g.large

-- Add reader instance:
-- aws rds create-db-instance \
--   --db-instance-identifier myapp-reader1 \
--   --db-cluster-identifier myapp-aurora \
--   --engine aurora-postgresql \
--   --db-instance-class db.r6g.large

-- ============================================================
-- 5. AURORA — ENDPOINTS
-- ============================================================

-- Cluster endpoint (writer — always points to primary):
-- aws rds describe-db-clusters \
--   --db-cluster-identifier myapp-aurora \
--   --query 'DBClusters[0].Endpoint'

-- Reader endpoint (load-balances across readers):
-- aws rds describe-db-clusters \
--   --db-cluster-identifier myapp-aurora \
--   --query 'DBClusters[0].ReaderEndpoint'

-- Connect to writer:
-- psql -h myapp-aurora.cluster-xxxx.us-east-1.rds.amazonaws.com \
--   -U app_admin -d myapp

-- Connect to reader (read-only):
-- psql -h myapp-aurora.cluster-ro-xxxx.us-east-1.rds.amazonaws.com \
--   -U app_admin -d myapp

-- ============================================================
-- 6. AURORA SERVERLESS v2
-- ============================================================

-- Create Serverless v2 cluster:
-- aws rds create-db-cluster \
--   --db-cluster-identifier myapp-serverless \
--   --engine aurora-postgresql \
--   --engine-version 16.4 \
--   --master-username app_admin \
--   --master-user-password 'SecurePass123!' \
--   --database-name myapp \
--   --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=16

-- Add Serverless v2 instance:
-- aws rds create-db-instance \
--   --db-instance-identifier myapp-sv2 \
--   --db-cluster-identifier myapp-serverless \
--   --engine aurora-postgresql \
--   --db-instance-class db.serverless

-- ============================================================
-- 7. MONITORING — CLOUDWATCH & PERFORMANCE INSIGHTS
-- ============================================================

-- Enable Enhanced Monitoring:
-- aws rds modify-db-instance \
--   --db-instance-identifier myapp-pg \
--   --monitoring-interval 60 \
--   --monitoring-role-arn arn:aws:iam::ACCOUNT:role/rds-monitoring-role

-- Enable Performance Insights:
-- aws rds modify-db-instance \
--   --db-instance-identifier myapp-pg \
--   --enable-performance-insights \
--   --performance-insights-retention-period 7

-- Key CloudWatch metrics to monitor:
-- CPUUtilization          → Alert at 80%
-- FreeStorageSpace        → Alert at 20% remaining
-- DatabaseConnections     → Alert at 80% of max_connections
-- ReadIOPS / WriteIOPS    → Monitor I/O patterns
-- ReplicaLag              → Alert if > 10 seconds

-- ============================================================
-- 8. SECURITY — VPC & ENCRYPTION
-- ============================================================

-- Enable encryption at creation (CANNOT add later):
-- --storage-encrypted \
-- --kms-key-id arn:aws:kms:us-east-1:ACCOUNT:key/KEY-ID

-- Force SSL connections (parameter group):
-- aws rds modify-db-parameter-group \
--   --db-parameter-group-name myapp-pg16 \
--   --parameters \
--   'ParameterName=rds.force_ssl,ParameterValue=1,ApplyMethod=pending-reboot'

-- Security group — allow only your app's CIDR:
-- aws ec2 authorize-security-group-ingress \
--   --group-id sg-xxxx \
--   --protocol tcp \
--   --port 5432 \
--   --cidr 10.0.1.0/24

-- ============================================================
-- 9. RDS vs AURORA COMPARISON
-- ============================================================

-- RDS PostgreSQL:
--   Storage: EBS (gp3 or io2)
--   Write speed: Standard
--   Failover: < 60 seconds (Multi-AZ)
--   Read replicas: Up to 15 (async, replication lag)
--   Serverless: No
--   Cost: Lower
--   Best for: Cost-sensitive, moderate workloads

-- Aurora PostgreSQL:
--   Storage: Shared distributed, auto-scale to 128 TB
--   Write speed: Up to 3x faster
--   Failover: < 30 seconds
--   Read replicas: Up to 15 (shared storage, ms lag)
--   Serverless: v2 (auto-scale compute)
--   Cost: ~20% more + I/O charges
--   Best for: High throughput, fast failover

-- ============================================================
-- 10. USEFUL SQL ON RDS/AURORA
-- ============================================================

-- Check PostgreSQL version:
SELECT version();

-- Check available extensions:
SELECT * FROM pg_available_extensions ORDER BY name;

-- Enable extensions (rds_superuser can do this):
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Check replication status (on primary):
SELECT client_addr, state, sent_lsn, replay_lsn,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- Check if instance is primary or standby:
SELECT pg_is_in_recovery();
-- FALSE = primary, TRUE = standby/reader

-- Check current settings:
SHOW shared_buffers;
SHOW work_mem;
SHOW max_connections;

-- ============================================================
-- 11. CLEANUP — DELETE RESOURCES
-- ============================================================

-- Delete RDS instance (take final snapshot):
-- aws rds delete-db-instance \
--   --db-instance-identifier myapp-pg \
--   --final-db-snapshot-identifier myapp-final

-- Delete Aurora reader:
-- aws rds delete-db-instance \
--   --db-instance-identifier myapp-reader1 \
--   --skip-final-snapshot

-- Delete Aurora writer:
-- aws rds delete-db-instance \
--   --db-instance-identifier myapp-writer \
--   --skip-final-snapshot

-- Delete Aurora cluster:
-- aws rds delete-db-cluster \
--   --db-cluster-identifier myapp-aurora \
--   --final-db-snapshot-identifier myapp-aurora-final

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create RDS PostgreSQL (free tier: db.t3.micro, 20GB).
--    Connect with psql. Create a test table. Insert data.

-- 2. Create custom parameter group for postgres16.
--    Set shared_buffers, work_mem, log_statement. Apply to instance.

-- 3. Enable automated backups. Insert data.
--    Perform point-in-time restore to 5 minutes ago.
--    Connect to restored instance. Verify data.

-- 4. Create a read replica. Connect to it.
--    Verify data is replicated. Test that writes are rejected.

-- 5. Optional: Create Aurora cluster (writer + reader).
--    Compare failover time with RDS Multi-AZ.
--    Test Aurora reader endpoint load balancing.
