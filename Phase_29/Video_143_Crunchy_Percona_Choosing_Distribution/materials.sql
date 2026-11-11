-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Crunchy Data, Percona & Choosing a Distribution (Classes 266-267)
-- Phase 29: EDB & Distributions
-- ============================================================

-- ============================================================
-- 1. CRUNCHY DATA OVERVIEW
-- ============================================================

-- Crunchy Data = Kubernetes-native PostgreSQL company
-- Key products:
--   PGO        → Kubernetes operator for PG clusters
--   Crunchy Bridge → Managed PG cloud (AWS, Azure, GCP)
--   pgMonitor  → Open-source monitoring (Prometheus + Grafana)

-- Philosophy: 100% open source, community PostgreSQL
-- No proprietary extensions or forks

-- ============================================================
-- 2. CRUNCHY PGO — KUBERNETES OPERATOR
-- ============================================================

-- PGO automates PostgreSQL on Kubernetes:
--   - Cluster deployment from YAML spec
--   - High availability (Patroni-based failover)
--   - Automated backups (pgBackRest to S3/GCS/Azure)
--   - Connection pooling (PgBouncer sidecar)
--   - Monitoring (Prometheus exporter + Grafana)
--   - Rolling minor version upgrades

-- Example: Create a PG cluster with PGO (Kubernetes YAML)
-- apiVersion: postgres-operator.crunchydata.com/v1beta1
-- kind: PostgresCluster
-- metadata:
--   name: myapp-db
-- spec:
--   postgresVersion: 16
--   instances:
--     - name: instance1
--       replicas: 3
--       dataVolumeClaimSpec:
--         accessModes: ["ReadWriteOnce"]
--         resources:
--           requests:
--             storage: 50Gi
--   backups:
--     pgbackrest:
--       repos:
--         - name: repo1
--           schedules:
--             full: "0 1 * * 0"
--             incremental: "0 1 * * 1-6"
--           volume:
--             volumeClaimSpec:
--               accessModes: ["ReadWriteOnce"]
--               resources:
--                 requests:
--                   storage: 100Gi

-- Apply with:
-- kubectl apply -f myapp-db.yaml

-- Check cluster status:
-- kubectl get postgresclusters

-- ============================================================
-- 3. PERCONA DISTRIBUTION FOR POSTGRESQL
-- ============================================================

-- Percona = Community PG + curated extension bundle
-- Includes: pg_stat_monitor, pgAudit, pgBackRest,
--           Patroni, PgBouncer, HAProxy
-- Also: Percona Operator for Kubernetes

-- Install Percona Distribution (Debian/Ubuntu):
-- wget https://repo.percona.com/apt/percona-release_latest.generic_all.deb
-- sudo dpkg -i percona-release_latest.generic_all.deb
-- sudo percona-release setup ppg-16
-- sudo apt install percona-ppg-server-16

-- ============================================================
-- 4. PERCONA PMM — MONITORING AND MANAGEMENT
-- ============================================================

-- PMM = Free monitoring for PostgreSQL + MySQL + MongoDB
-- Uses: Prometheus, ClickHouse, Grafana
-- PG-specific: pg_stat_monitor (enhanced pg_stat_statements)

-- Install PMM Server (Docker):
-- docker pull percona/pmm-server:2
-- docker run -d --name pmm-server \
--   -p 443:443 -p 80:80 \
--   -v pmm-data:/srv \
--   percona/pmm-server:2

-- Access: https://localhost (admin/admin, change on first login)

-- Install PMM Client on PG server:
-- sudo percona-release setup pmm2-client
-- sudo apt install pmm2-client
-- pmm-admin config --server-url=https://admin:password@pmm-server:443

-- Register PostgreSQL:
-- pmm-admin add postgresql \
--   --username=pmm_user --password=pmm_pass \
--   --service-name=my-pg-16 \
--   --host=localhost --port=5432

-- ============================================================
-- 5. pg_stat_monitor (Works on Community PG Too)
-- ============================================================

-- pg_stat_monitor = enhanced pg_stat_statements
-- Extra features: query plans, histograms, per-client stats

-- Install on community PG:
-- sudo apt install percona-pg-stat-monitor16

-- Enable in postgresql.conf:
-- shared_preload_libraries = 'pg_stat_monitor'

-- After restart:
CREATE EXTENSION pg_stat_monitor;

-- Query top slow queries with plans:
SELECT bucket_start_time,
  calls,
  mean_exec_time::numeric(10,2) AS avg_ms,
  left(query, 60) AS query
FROM pg_stat_monitor
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Query stats by client:
SELECT client_ip,
  sum(calls) AS total_calls,
  avg(mean_exec_time)::numeric(10,2) AS avg_ms
FROM pg_stat_monitor
GROUP BY client_ip
ORDER BY total_calls DESC;

-- ============================================================
-- 6. COMPLETE DISTRIBUTION COMPARISON
-- ============================================================

-- Feature       | Community  | EDB        | Crunchy      | Percona
-- --------------|------------|------------|--------------|--------
-- License       | Free       | Subscr.    | Free+Support | Free+Support
-- Oracle Compat | No         | Yes (EPAS) | No           | No
-- K8s Operator  | No         | EDB PGD    | PGO (mature) | Operator
-- Monitoring    | DIY        | PEM        | pgMonitor    | PMM
-- HA Tool       | DIY        | EFM        | Patroni(PGO) | Patroni
-- Backup Tool   | DIY        | BART/pgBR  | pgBackRest   | pgBackRest
-- Managed Cloud | No         | BigAnimal  | Bridge       | No
-- Multi-DB Mon  | No         | No         | No           | Yes
-- Best For      | DIY expert | Oracle mig | K8s teams    | Multi-DB

-- ============================================================
-- 7. DECISION FRAMEWORK
-- ============================================================

-- Start with your primary need:
--
-- Oracle migration?         → EDB EPAS
-- Kubernetes deployment?    → Crunchy PGO or Percona Operator
-- Multi-DB monitoring?      → Percona PMM
-- Maximum control, $0 cost? → Community PostgreSQL
-- Managed cloud service?    → Crunchy Bridge or AWS RDS / Azure
-- Oracle-trained DBA team?  → EDB
--
-- DEFAULT RECOMMENDATION:
-- Community PG + pgBackRest + Patroni + Grafana
-- (This covers 90% of production needs at zero license cost)

-- ============================================================
-- 8. KEY FACTS
-- ============================================================

-- All distributions use the SAME PostgreSQL engine
-- Your data is NOT locked in — switching is straightforward
-- You can buy support for community PG from:
--   EDB, Crunchy Data, Percona, 2ndQuadrant, Command Prompt
-- Community PG powers: Instagram, Spotify, Apple, Twitch

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install pg_stat_monitor on community PG.
--    Compare output with pg_stat_statements for same workload.

-- 2. Deploy PG on Kubernetes using Crunchy PGO quickstart.
--    Create a 3-replica cluster. Simulate pod failure.

-- 3. Install PMM with Docker. Connect to your PG instance.
--    Explore the pre-built PostgreSQL dashboards.

-- 4. Write a 1-page recommendation for your team:
--    Which distribution? Why? Include cost, features, team skills.
