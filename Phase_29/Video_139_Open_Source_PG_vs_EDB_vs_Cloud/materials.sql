-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Open Source PG vs EDB vs Cloud-Managed (Classes 258-259)
-- Phase 29: EDB & Distributions
-- ============================================================

-- ============================================================
-- 1. COMMUNITY OPEN SOURCE POSTGRESQL
-- ============================================================

-- License: PostgreSQL License (permissive, free forever)
-- Website: https://www.postgresql.org
-- Source: https://git.postgresql.org

-- Check your version:
SELECT version();
SHOW server_version;

-- List installed extensions (all available on community PG):
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- List all AVAILABLE extensions:
SELECT name, default_version, comment
FROM pg_available_extensions
ORDER BY name;

-- ============================================================
-- 2. ENTERPRISEDB (EDB)
-- ============================================================

-- Product: EDB Postgres Advanced Server (EPAS)
-- Website: https://www.enterprisedb.com
-- Oracle Compatibility: PL/SQL, packages, synonyms, Oracle types
-- Tools: PEM, EFM, BART, Migration Toolkit, pgd

-- EPAS-specific features (not available in community PG):
-- - Oracle-compatible PL/SQL (packages, DBMS_OUTPUT, UTL_FILE)
-- - Oracle-compatible data types (NUMBER, VARCHAR2)
-- - Database links (Oracle-style)
-- - Public and private synonyms
-- - Profiles (password policies, resource limits)
-- - EDB*Loader (SQL*Loader compatible)
-- - Redwood mode (Oracle-compatible date handling)

-- ============================================================
-- 3. CLOUD-MANAGED SERVICES
-- ============================================================

-- AWS RDS PostgreSQL:
-- - Standard managed PostgreSQL
-- - Multi-AZ for HA (synchronous replication)
-- - Automated backups with PITR (up to 35 days)
-- - Read replicas (up to 15)
-- - Extensions: ~70 supported

-- AWS Aurora PostgreSQL:
-- - Custom storage engine (shared distributed storage)
-- - Up to 5x write throughput vs standard PG
-- - Up to 15 read replicas with <10ms lag
-- - Serverless v2 option (auto-scaling)
-- - Higher cost per hour than standard RDS

-- Azure Database for PostgreSQL Flexible Server:
-- - Zone-redundant HA
-- - Built-in PgBouncer connection pooling
-- - Intelligent tuning recommendations
-- - Extensions: ~50 supported

-- Google Cloud SQL for PostgreSQL:
-- - Automatic backups and PITR
-- - High availability with regional instances
-- - Extensions: ~40 supported

-- Google AlloyDB:
-- - Columnar engine for analytics
-- - PostgreSQL compatible
-- - AI/ML integrations
-- - Highest cost among Google options

-- ============================================================
-- 4. FEATURE COMPARISON
-- ============================================================

-- Feature          | Community PG  | EDB EPAS       | Cloud Managed
-- -----------------+---------------+----------------+--------------
-- License Cost     | Free          | Per-core sub   | Pay-per-hour
-- Oracle Compat    | No            | Yes            | No
-- Install/Patching | You do it     | You do it      | Provider
-- Backup           | You configure | BART included  | Automatic+PITR
-- HA / Failover    | You build     | EFM included   | Built-in
-- Monitoring       | You set up    | PEM included   | Built-in
-- Extensions       | All           | All + extras   | Limited set
-- Support          | Community     | 24/7 SLA       | Cloud support
-- Max Control      | Full          | Full           | Limited

-- ============================================================
-- 5. COST COMPARISON (16-core, 64GB, 1TB — Annual Estimate)
-- ============================================================

-- Item              | Community PG    | EDB EPAS       | AWS RDS
-- ------------------+-----------------+----------------+---------
-- License/Sub       | $0              | ~$20K-50K      | $0
-- Compute           | ~$5K-15K        | ~$5K-15K       | ~$25K-40K
-- Storage (1TB)     | ~$1K-3K         | ~$1K-3K        | ~$3K-6K
-- DBA Salary share  | ~$30K-50K       | ~$20K-40K      | ~$10K-20K
-- Backup Infra      | ~$2K-5K         | Included       | ~$1K-3K
-- TOTAL             | ~$38K-73K       | ~$46K-108K     | ~$39K-69K

-- ============================================================
-- 6. VENDOR LOCK-IN ASSESSMENT
-- ============================================================

-- Community PG:     Zero lock-in (runs anywhere)
-- EDB EPAS:         Low (Oracle compat features are EDB-specific,
--                   but standard PG code works on community PG)
-- Cloud RDS/SQL:    Medium (standard PG, but tooling is cloud-specific)
-- Aurora/AlloyDB:   High (custom storage engine, can't run outside cloud)

-- Mitigation: Use standard SQL and extensions.
-- Avoid provider-specific features unless committed to that platform.

-- ============================================================
-- 7. EXTENSION AVAILABILITY CHECK
-- ============================================================

-- Check which extensions your app needs:
-- Run on your current PG installation:
SELECT name, default_version
FROM pg_available_extensions
WHERE name IN (
  'postgis', 'pg_stat_statements', 'pgcrypto',
  'uuid-ossp', 'hstore', 'pg_trgm', 'btree_gin',
  'citext', 'tablefunc', 'pgaudit'
)
ORDER BY name;

-- Then check each cloud provider's extension list:
-- AWS RDS:   docs.aws.amazon.com/AmazonRDS/latest/PostgreSQLReleaseNotes
-- Azure:     learn.microsoft.com/azure/postgresql/flexible-server/concepts-extensions
-- GCP:       cloud.google.com/sql/docs/postgres/extensions

-- ============================================================
-- 8. DECISION FRAMEWORK
-- ============================================================

-- Migrating from Oracle?          → EDB EPAS
-- No DBA on team?                 → Cloud Managed
-- Need vendor SLA for compliance? → EDB or Cloud
-- Maximum control needed?         → Community PG
-- Cost-sensitive?                 → Community PG
-- Fast setup, minimal ops?        → Cloud Managed
-- Large team with DBA expertise?  → Community PG
-- Startup / small team?           → Cloud Managed or Supabase/Neon

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Calculate 3-year TCO for community PG, EDB EPAS, and
--    AWS RDS for a 8-core/32GB workload. Include compute,
--    storage, backup, and DBA salary costs.

-- 2. List all extensions your application uses. Check which
--    are available on: community PG, AWS RDS, Azure Flexible,
--    and Google Cloud SQL.

-- 3. Install community PG on a test VM. Provision an AWS RDS
--    instance. Compare: setup time, available parameters,
--    extension support, backup options.

-- 4. Read EDB's EPAS feature comparison page. List which
--    Oracle compatibility features you would actually use.
--    Calculate: is the subscription cost justified?
