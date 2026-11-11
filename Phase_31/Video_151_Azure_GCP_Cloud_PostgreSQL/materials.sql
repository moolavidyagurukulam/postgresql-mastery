-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Azure & GCP Cloud PostgreSQL (Classes 282-283)
-- Phase 31: Cloud PostgreSQL
-- ============================================================

-- ============================================================
-- 1. AZURE — CREATE FLEXIBLE SERVER
-- ============================================================

-- Create resource group:
-- az group create --name myapp-rg --location eastus

-- Create Flexible Server:
-- az postgres flexible-server create \
--   --resource-group myapp-rg \
--   --name myapp-pg \
--   --location eastus \
--   --version 16 \
--   --sku-name Standard_D2ds_v5 \
--   --storage-size 128 \
--   --admin-user app_admin \
--   --admin-password 'SecurePass123!'

-- Burstable (low cost for dev/test):
-- az postgres flexible-server create \
--   --resource-group myapp-rg \
--   --name myapp-dev \
--   --location eastus \
--   --version 16 \
--   --sku-name Standard_B1ms \
--   --storage-size 32 \
--   --admin-user app_admin \
--   --admin-password 'SecurePass123!'

-- ============================================================
-- 2. AZURE — FIREWALL & CONNECTIVITY
-- ============================================================

-- Add firewall rule for your IP:
-- az postgres flexible-server firewall-rule create \
--   --resource-group myapp-rg \
--   --name myapp-pg \
--   --rule-name allow-myip \
--   --start-ip-address 203.0.113.10 \
--   --end-ip-address 203.0.113.10

-- Connect with psql:
-- psql "host=myapp-pg.postgres.database.azure.com \
--   dbname=postgres user=app_admin sslmode=require"

-- ============================================================
-- 3. AZURE — COMMON OPERATIONS
-- ============================================================

-- List servers:
-- az postgres flexible-server list --resource-group myapp-rg -o table

-- Show server details:
-- az postgres flexible-server show \
--   --resource-group myapp-rg --name myapp-pg

-- Update server parameter:
-- az postgres flexible-server parameter set \
--   --resource-group myapp-rg \
--   --server-name myapp-pg \
--   --name shared_buffers \
--   --value 524288

-- List all parameters:
-- az postgres flexible-server parameter list \
--   --resource-group myapp-rg \
--   --server-name myapp-pg -o table

-- Enable HA:
-- az postgres flexible-server update \
--   --resource-group myapp-rg \
--   --name myapp-pg \
--   --high-availability ZoneRedundant

-- Point-in-time restore:
-- az postgres flexible-server restore \
--   --resource-group myapp-rg \
--   --name myapp-restored \
--   --source-server myapp-pg \
--   --restore-time 2026-11-05T10:00:00Z

-- Create read replica:
-- az postgres flexible-server replica create \
--   --resource-group myapp-rg \
--   --replica-name myapp-replica \
--   --source-server myapp-pg

-- ============================================================
-- 4. AZURE — ENTRA ID (Azure AD) AUTHENTICATION
-- ============================================================

-- Enable Entra ID admin:
-- az postgres flexible-server ad-admin create \
--   --resource-group myapp-rg \
--   --server-name myapp-pg \
--   --display-name "DBA Team" \
--   --object-id <entra-group-object-id>

-- Connect with Entra token:
-- export PGPASSWORD=$(az account get-access-token \
--   --resource-type oss-rdbms --query accessToken -o tsv)
-- psql "host=myapp-pg.postgres.database.azure.com \
--   dbname=postgres user=dba@myapp-pg sslmode=require"

-- ============================================================
-- 5. GCP — CREATE CLOUD SQL INSTANCE
-- ============================================================

-- Create instance:
-- gcloud sql instances create myapp-pg \
--   --database-version=POSTGRES_16 \
--   --tier=db-custom-2-8192 \
--   --storage-size=50GB \
--   --storage-type=SSD \
--   --storage-auto-increase \
--   --region=us-central1 \
--   --availability-type=REGIONAL \
--   --backup-start-time=03:00 \
--   --database-flags=shared_buffers=2048MB

-- Set root password:
-- gcloud sql users set-password postgres \
--   --instance=myapp-pg \
--   --password='SecurePass123!'

-- Create database:
-- gcloud sql databases create myapp --instance=myapp-pg

-- Create app user:
-- gcloud sql users create app_user \
--   --instance=myapp-pg \
--   --password='AppPass123!'

-- ============================================================
-- 6. GCP — CLOUD SQL AUTH PROXY
-- ============================================================

-- Download proxy:
-- curl -o cloud-sql-proxy \
--   https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.1/cloud-sql-proxy.linux.amd64
-- chmod +x cloud-sql-proxy

-- Start proxy:
-- ./cloud-sql-proxy --port 5432 \
--   PROJECT_ID:us-central1:myapp-pg &

-- Connect through proxy:
-- psql -h 127.0.0.1 -U postgres -d myapp

-- On GKE (sidecar container):
-- Add cloud-sql-proxy as sidecar in pod spec:
-- containers:
--   - name: cloud-sql-proxy
--     image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.14.1
--     args:
--       - "--structured-logs"
--       - "PROJECT_ID:us-central1:myapp-pg"
--     securityContext:
--       runAsNonRoot: true

-- ============================================================
-- 7. GCP — COMMON OPERATIONS
-- ============================================================

-- List instances:
-- gcloud sql instances list

-- Describe instance:
-- gcloud sql instances describe myapp-pg

-- Update database flags:
-- gcloud sql instances patch myapp-pg \
--   --database-flags=shared_buffers=4096MB,work_mem=32MB

-- Create backup:
-- gcloud sql backups create --instance=myapp-pg

-- List backups:
-- gcloud sql backups list --instance=myapp-pg

-- Restore from backup:
-- gcloud sql backups restore BACKUP_ID \
--   --restore-instance=myapp-pg

-- Create read replica:
-- gcloud sql instances create myapp-read1 \
--   --master-instance-name=myapp-pg \
--   --region=us-central1

-- ============================================================
-- 8. ALLOYDB — CREATE CLUSTER
-- ============================================================

-- Create AlloyDB cluster:
-- gcloud alloydb clusters create myapp-alloy \
--   --region=us-central1 \
--   --password='SecurePass123!' \
--   --network=default

-- Create primary instance:
-- gcloud alloydb instances create myapp-primary \
--   --cluster=myapp-alloy \
--   --region=us-central1 \
--   --instance-type=PRIMARY \
--   --cpu-count=4

-- Create read pool (2 nodes):
-- gcloud alloydb instances create myapp-readers \
--   --cluster=myapp-alloy \
--   --region=us-central1 \
--   --instance-type=READ_POOL \
--   --cpu-count=4 \
--   --read-pool-node-count=2

-- Connect via AlloyDB Auth Proxy:
-- Download from: https://cloud.google.com/alloydb/docs/auth-proxy/connect
-- ./alloydb-auth-proxy \
--   /projects/PROJECT_ID/locations/us-central1/clusters/myapp-alloy/instances/myapp-primary

-- ============================================================
-- 9. ALLOYDB — COLUMNAR ENGINE
-- ============================================================

-- Enable columnar engine (flag on instance):
-- gcloud alloydb instances update myapp-primary \
--   --cluster=myapp-alloy \
--   --region=us-central1 \
--   --database-flags=google_columnar_engine.enabled=on

-- Check columnar engine status:
SELECT google_columnar_engine_status();

-- Manually recommend columns to cache:
SELECT google_columnar_engine_recommend();

-- Check what is cached:
SELECT * FROM g_columnar_recommended_columns;

-- ============================================================
-- 10. USEFUL SQL ON MANAGED SERVICES
-- ============================================================

-- Check PostgreSQL version:
SELECT version();

-- Check if primary or standby:
SELECT pg_is_in_recovery();

-- Check replication status (on primary):
SELECT client_addr, state, sent_lsn, replay_lsn,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- Check available extensions:
SELECT * FROM pg_available_extensions ORDER BY name;

-- Enable extensions:
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Check current settings:
SHOW shared_buffers;
SHOW work_mem;
SHOW max_connections;

-- ============================================================
-- 11. CLEANUP
-- ============================================================

-- Azure — delete server:
-- az postgres flexible-server delete \
--   --resource-group myapp-rg --name myapp-pg --yes

-- Azure — delete resource group (deletes everything):
-- az group delete --name myapp-rg --yes

-- GCP — delete Cloud SQL:
-- gcloud sql instances delete myapp-pg

-- GCP — delete AlloyDB:
-- gcloud alloydb instances delete myapp-primary \
--   --cluster=myapp-alloy --region=us-central1
-- gcloud alloydb instances delete myapp-readers \
--   --cluster=myapp-alloy --region=us-central1
-- gcloud alloydb clusters delete myapp-alloy \
--   --region=us-central1

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Azure: Create Flexible Server (Burstable tier).
--    Add firewall rule. Connect with psql. Create test table.

-- 2. GCP: Create Cloud SQL instance. Set up Auth Proxy.
--    Connect through localhost:5432. Create test table.

-- 3. Compare server parameters on Azure vs GCP.
--    Modify shared_buffers on both. Note format differences.

-- 4. Enable HA on both providers. Trigger failover.
--    Measure downtime during failover.

-- 5. Optional: Create AlloyDB cluster. Enable columnar engine.
--    Run analytical query. Compare performance with Cloud SQL.
