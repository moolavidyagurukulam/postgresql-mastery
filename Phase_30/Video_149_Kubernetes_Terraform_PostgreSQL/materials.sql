-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Kubernetes & Terraform with PostgreSQL (Classes 278-279)
-- Phase 30: Integration with Other Technologies
-- ============================================================

-- ============================================================
-- 1. CLOUDNATIVEPG — INSTALL OPERATOR
-- ============================================================

-- Install CloudNativePG operator:
-- kubectl apply --server-side -f \
--   https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.23/releases/cnpg-1.23.0.yaml

-- Verify operator running:
-- kubectl get deployment -n cnpg-system cnpg-controller-manager

-- Install kubectl plugin (optional):
-- curl -sSfL https://github.com/cloudnative-pg/cloudnative-pg/raw/main/hack/install-cnpg-plugin.sh | sh

-- ============================================================
-- 2. CLOUDNATIVEPG — CLUSTER DEFINITION
-- ============================================================

-- cluster.yaml:
-- apiVersion: postgresql.cnpg.io/v1
-- kind: Cluster
-- metadata:
--   name: myapp-db
-- spec:
--   instances: 3
--   imageName: ghcr.io/cloudnative-pg/postgresql:16.4
--
--   postgresql:
--     parameters:
--       shared_buffers: "256MB"
--       max_connections: "100"
--       work_mem: "16MB"
--       log_statement: "ddl"
--
--   storage:
--     size: 50Gi
--     storageClass: gp3
--
--   bootstrap:
--     initdb:
--       database: myapp
--       owner: app_user
--
--   backup:
--     barmanObjectStore:
--       destinationPath: s3://my-backups/pg
--       s3Credentials:
--         accessKeyId:
--           name: aws-creds
--           key: ACCESS_KEY_ID
--         secretAccessKey:
--           name: aws-creds
--           key: SECRET_ACCESS_KEY

-- Deploy:
-- kubectl apply -f cluster.yaml

-- ============================================================
-- 3. CLOUDNATIVEPG — OPERATIONS
-- ============================================================

-- Check cluster status:
-- kubectl cnpg status myapp-db

-- List pods:
-- kubectl get pods -l cnpg.io/cluster=myapp-db

-- Connect to primary:
-- kubectl cnpg psql myapp-db

-- Trigger failover (switchover):
-- kubectl cnpg promote myapp-db myapp-db-2

-- On-demand backup:
-- kubectl cnpg backup myapp-db

-- Scale up (add replica):
-- kubectl patch cluster myapp-db -p '{"spec":{"instances":4}}' --type=merge

-- ============================================================
-- 4. KUBERNETES SERVICES (Auto-created by Operator)
-- ============================================================

-- myapp-db-rw     → Routes to primary (read-write)
-- myapp-db-ro     → Routes to replicas (read-only)
-- myapp-db-r      → Routes to any instance

-- Application connection string:
-- postgresql://app_user:PASSWORD@myapp-db-rw:5432/myapp  (writes)
-- postgresql://app_user:PASSWORD@myapp-db-ro:5432/myapp  (reads)

-- Get password from secret:
-- kubectl get secret myapp-db-app -o jsonpath='{.data.password}' | base64 -d

-- ============================================================
-- 5. K8s OPERATORS COMPARED
-- ============================================================

-- CloudNativePG  | CNCF sandbox. Barman backup. Newest, fast-growing.
-- Crunchy PGO    | Most mature. pgBackRest. PgBouncer sidecar.
-- Percona Op.    | Multi-DB shops. PMM monitoring. Patroni HA.

-- All provide: auto-failover, backup, declarative YAML, self-healing

-- ============================================================
-- 6. TERRAFORM — AWS RDS POSTGRESQL
-- ============================================================

-- main.tf:
-- provider "aws" {
--   region = "us-east-1"
-- }
--
-- resource "aws_db_instance" "myapp" {
--   identifier        = "myapp-pg"
--   engine            = "postgres"
--   engine_version    = "16.4"
--   instance_class    = "db.t3.medium"
--   allocated_storage = 50
--   storage_type      = "gp3"
--
--   db_name  = "myapp"
--   username = "app_user"
--   password = var.db_password
--
--   vpc_security_group_ids = [aws_security_group.pg.id]
--   db_subnet_group_name   = aws_db_subnet_group.pg.name
--
--   backup_retention_period = 7
--   multi_az               = true
--   skip_final_snapshot    = false
--   final_snapshot_identifier = "myapp-pg-final"
-- }

-- variables.tf:
-- variable "db_password" {
--   type      = string
--   sensitive = true
-- }

-- ============================================================
-- 7. TERRAFORM — POSTGRESQL PROVIDER
-- ============================================================

-- provider "postgresql" {
--   host     = aws_db_instance.myapp.address
--   port     = 5432
--   username = "app_user"
--   password = var.db_password
--   database = "myapp"
--   sslmode  = "require"
-- }
--
-- resource "postgresql_role" "readonly" {
--   name     = "readonly_user"
--   login    = true
--   password = var.ro_password
-- }
--
-- resource "postgresql_database" "analytics" {
--   name  = "analytics"
--   owner = "app_user"
-- }
--
-- resource "postgresql_grant" "ro_tables" {
--   database    = "myapp"
--   role        = postgresql_role.readonly.name
--   schema      = "public"
--   object_type = "table"
--   privileges  = ["SELECT"]
-- }

-- ============================================================
-- 8. TERRAFORM — COMMANDS
-- ============================================================

-- terraform init      → Download providers
-- terraform plan      → Preview changes (ALWAYS do this!)
-- terraform apply     → Create/update resources
-- terraform destroy   → Delete all resources
-- terraform output    → Show output values
-- terraform state list → List managed resources

-- Remote state (S3 backend):
-- terraform {
--   backend "s3" {
--     bucket         = "myapp-tf-state"
--     key            = "postgres/terraform.tfstate"
--     region         = "us-east-1"
--     dynamodb_table = "tf-state-lock"
--     encrypt        = true
--   }
-- }

-- ============================================================
-- 9. MONITORING KUBERNETES PG
-- ============================================================

-- Check cluster health:
-- kubectl cnpg status myapp-db

-- Check replication lag:
SELECT client_addr, state,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- Check if primary or standby:
SELECT pg_is_in_recovery();
-- FALSE = primary, TRUE = standby

-- Pod resource usage:
-- kubectl top pods -l cnpg.io/cluster=myapp-db

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Minikube: install CloudNativePG, create 3-instance cluster.
--    Delete primary pod. Watch automatic failover.

-- 2. Terraform: write RDS PostgreSQL config.
--    Plan → Apply → Connect with psql → Destroy.

-- 3. Terraform PG provider: create readonly role + analytics DB.
--    Apply. Verify with psql.

-- 4. Compare deployment time: CloudNativePG vs Docker Compose.
--    Document features each approach provides.

-- 5. CloudNativePG: configure backup to MinIO (local S3).
--    Take backup. Restore to new cluster.
