-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- EDB Tools: BART, Migration Toolkit & pgd (Classes 264-265)
-- Phase 29: EDB & Distributions
-- ============================================================

-- ============================================================
-- 1. EDB BART — BACKUP AND RECOVERY TOOL
-- ============================================================

-- BART = Centralized backup management for PG/EPAS clusters
-- Backup types: full, incremental (block-level), differential
-- Features: retention policies, catalog, verification, PITR
-- NOTE: EDB now recommends pgBackRest for new deployments

-- BART vs Community:
-- BART         → pgBackRest (recommended) or Barman
-- Full backup  → All three support
-- Incremental  → All three support
-- Parallel     → pgBackRest: yes, BART: no, Barman: yes
-- Encryption   → pgBackRest: AES-256, others: no
-- Cloud storage → pgBackRest: S3/Azure/GCS native

-- ============================================================
-- 2. PGBACKREST (Recommended for ALL PG Deployments)
-- ============================================================

-- Install:
-- sudo apt install pgbackrest  (Debian/Ubuntu)
-- sudo dnf install pgbackrest  (RHEL/Rocky)

-- Configure /etc/pgbackrest/pgbackrest.conf:
-- [global]
-- repo1-path=/var/lib/pgbackrest
-- repo1-retention-full=2
-- repo1-retention-diff=7
-- compress-type=lz4
--
-- [main]
-- pg1-path=/var/lib/postgresql/16/main

-- Full backup:
-- sudo -u postgres pgbackrest --stanza=main backup --type=full

-- Incremental backup:
-- sudo -u postgres pgbackrest --stanza=main backup --type=incr

-- List backups:
-- sudo -u postgres pgbackrest --stanza=main info

-- Restore:
-- sudo -u postgres pgbackrest --stanza=main restore

-- PITR:
-- sudo -u postgres pgbackrest --stanza=main restore \
--   --type=time --target="2026-11-05 10:00:00"

-- ============================================================
-- 3. EDB MIGRATION TOOLKIT
-- ============================================================

-- Type: Java-based CLI migration tool
-- Sources: Oracle, SQL Server, MySQL, Sybase → PostgreSQL/EPAS
-- Migrates: Schema, data, stored procedures, triggers, sequences
-- EPAS advantage: preserves Oracle packages and synonyms

-- Example usage:
-- runMTK.sh -sourcedbtype oracle \
--   -targetdbtype enterprisedb \
--   -host oracle-server -port 1521 -database ORCL \
--   -user system -password oracle_pass \
--   -targetHost pg-server -targetPort 5444 \
--   -targetDatabase app_db \
--   -targetUser enterprisedb \
--   -allSchemas

-- Migration Toolkit vs Community:
-- Oracle source  → Ora2Pg (excellent, free)
-- MySQL source   → pgLoader (excellent, free)
-- MSSQL source   → pgLoader (good, free)
-- Sybase source  → Migration Toolkit only
-- Oracle → EPAS  → Migration Toolkit (packages preserved)

-- ============================================================
-- 4. pgd — EDB POSTGRES DISTRIBUTED
-- ============================================================

-- Formerly: BDR (Bi-Directional Replication)
-- Type: Multi-master distributed PostgreSQL
-- All nodes are writable (active-active)
-- Logical replication between all nodes
-- Conflict resolution: last-writer-wins (default) or custom

-- Use cases:
-- - Multi-region active-active (US, EU, Asia)
-- - Always-on availability (no single point of failure)
-- - Local read AND write performance in each region

-- NOT for:
-- - Simple HA (use streaming replication + Patroni)
-- - Sharding large datasets (use Citus instead)
-- - Small/medium deployments (overkill)

-- pgd vs other solutions:
-- pgd            → Multi-master, all nodes writable
-- Citus          → Sharding (distributed tables, coordinator)
-- Streaming rep  → Single master + read replicas
-- Logical rep    → Selective replication, upgrade path

-- ============================================================
-- 5. CONFLICT RESOLUTION IN pgd
-- ============================================================

-- Default: last-writer-wins (based on commit timestamp)
-- Row-level: conflict detected per row, not per transaction
-- Column-level: can merge non-conflicting column changes

-- Example scenario:
-- Node 1: UPDATE users SET email='a@b.com' WHERE id=1;
-- Node 2: UPDATE users SET phone='555-1234' WHERE id=1;
-- Result: Both changes applied (different columns)

-- True conflict:
-- Node 1: UPDATE users SET name='Alice' WHERE id=1;
-- Node 2: UPDATE users SET name='Bob' WHERE id=1;
-- Result: Last commit timestamp wins

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install pgBackRest. Configure full + incremental backups
--    with 7-day retention. Take a backup and test restore.

-- 2. If you have EDB trial: run Migration Toolkit against
--    Oracle XE. Compare output with Ora2Pg for same schema.

-- 3. Research pgd architecture docs. Design a 3-region
--    deployment. Document your conflict resolution strategy.

-- 4. Compare pgBackRest vs Barman for your backup needs.
--    Install both, run the same backup, compare features.
