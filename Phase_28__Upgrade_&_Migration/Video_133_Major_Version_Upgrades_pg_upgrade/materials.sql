-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Major Version Upgrades with pg_upgrade (Classes 246-247)
-- Phase 28: Upgrade & Migration
-- ============================================================

-- ============================================================
-- 1. CHECK CURRENT VERSION
-- ============================================================

SELECT version();
SHOW server_version;

-- ============================================================
-- 2. PRE-UPGRADE CHECKS
-- ============================================================

-- Check for reg* data types in user tables (will block pg_upgrade):
SELECT n.nspname, c.relname, a.attname, t.typname
FROM pg_class c
JOIN pg_attribute a ON c.oid = a.attrelid
JOIN pg_type t ON a.atttypid = t.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE t.typname ~ '^reg'
  AND c.relkind = 'r'
  AND n.nspname NOT LIKE 'pg_%'
  AND n.nspname != 'information_schema';

-- Check for prepared transactions (must be resolved first):
SELECT * FROM pg_prepared_xacts;

-- Check for deprecated/removed data types:
SELECT n.nspname, c.relname, a.attname, t.typname
FROM pg_class c
JOIN pg_attribute a ON c.oid = a.attrelid
JOIN pg_type t ON a.atttypid = t.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE t.typname IN ('abstime', 'reltime', 'tinterval')
  AND c.relkind = 'r';

-- List installed extensions:
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- ============================================================
-- 3. TAKE BACKUP
-- ============================================================

-- Option 1: pg_dumpall
-- pg_dumpall -U postgres > /backups/pre_major_upgrade.sql

-- Option 2: pg_basebackup (better for large databases)
-- pg_basebackup -U postgres -D /backups/base_pre_upgrade -Ft -z -P

-- ============================================================
-- 4. INSTALL NEW VERSION (Debian/Ubuntu)
-- ============================================================

-- Install PG 16 alongside PG 15:
-- sudo apt install postgresql-16

-- Check both versions:
-- pg_lsclusters

-- ============================================================
-- 5. INSTALL NEW VERSION (RHEL/Rocky/Alma)
-- ============================================================

-- sudo dnf install postgresql16-server
-- sudo /usr/pgsql-16/bin/postgresql-16-setup initdb

-- ============================================================
-- 6. STOP BOTH CLUSTERS
-- ============================================================

-- Debian:
-- sudo systemctl stop postgresql@15-main
-- sudo systemctl stop postgresql@16-main

-- RHEL:
-- sudo systemctl stop postgresql-15
-- sudo systemctl stop postgresql-16

-- ============================================================
-- 7. RUN pg_upgrade — CHECK MODE
-- ============================================================

-- Debian paths:
-- sudo -u postgres /usr/lib/postgresql/16/bin/pg_upgrade \
--     --old-bindir=/usr/lib/postgresql/15/bin \
--     --new-bindir=/usr/lib/postgresql/16/bin \
--     --old-datadir=/var/lib/postgresql/15/main \
--     --new-datadir=/var/lib/postgresql/16/main \
--     --check

-- RHEL paths:
-- sudo -u postgres /usr/pgsql-16/bin/pg_upgrade \
--     --old-bindir=/usr/pgsql-15/bin \
--     --new-bindir=/usr/pgsql-16/bin \
--     --old-datadir=/var/lib/pgsql/15/data \
--     --new-datadir=/var/lib/pgsql/16/data \
--     --check

-- ============================================================
-- 8. RUN pg_upgrade — COPY MODE
-- ============================================================

-- Same as above, remove --check:
-- sudo -u postgres /usr/lib/postgresql/16/bin/pg_upgrade \
--     --old-bindir=/usr/lib/postgresql/15/bin \
--     --new-bindir=/usr/lib/postgresql/16/bin \
--     --old-datadir=/var/lib/postgresql/15/main \
--     --new-datadir=/var/lib/postgresql/16/main

-- ============================================================
-- 9. RUN pg_upgrade — LINK MODE (faster)
-- ============================================================

-- Add --link for hard links (instant but old cluster unusable):
-- sudo -u postgres /usr/lib/postgresql/16/bin/pg_upgrade \
--     --old-bindir=/usr/lib/postgresql/15/bin \
--     --new-bindir=/usr/lib/postgresql/16/bin \
--     --old-datadir=/var/lib/postgresql/15/main \
--     --new-datadir=/var/lib/postgresql/16/main \
--     --link

-- ============================================================
-- 10. POST-UPGRADE TASKS
-- ============================================================

-- Compare and migrate config files:
-- diff /etc/postgresql/15/main/postgresql.conf \
--      /etc/postgresql/16/main/postgresql.conf

-- diff /etc/postgresql/15/main/pg_hba.conf \
--      /etc/postgresql/16/main/pg_hba.conf

-- Start new cluster:
-- sudo systemctl start postgresql@16-main

-- Rebuild optimizer statistics:
-- /usr/lib/postgresql/16/bin/vacuumdb --all --analyze-in-stages

-- Update extensions:
SELECT e.extname, e.extversion AS installed, a.default_version AS available
FROM pg_extension e
JOIN pg_available_extensions a ON e.extname = a.name
WHERE e.extversion != a.default_version;

-- ALTER EXTENSION pgaudit UPDATE;

-- ============================================================
-- 11. VERIFY UPGRADE
-- ============================================================

SELECT version();

SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database WHERE NOT datistemplate;

-- Quick test on important tables:
-- SELECT count(*) FROM your_important_table;

-- Check for errors in log:
-- tail -50 /var/log/postgresql/postgresql-16-main.log

-- ============================================================
-- 12. CLEANUP
-- ============================================================

-- Run the generated cleanup scripts:
-- ./analyze_new_cluster.sh
-- ./delete_old_cluster.sh

-- Remove old PostgreSQL version:
-- sudo apt remove postgresql-15  (Debian)
-- sudo dnf remove postgresql15*  (RHEL)

-- Update port if needed:
-- Edit postgresql.conf: port = 5432

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install PG 15 and 16 on a test server. Create a database
--    with tables and data in PG 15. Run pg_upgrade --check.

-- 2. Perform pg_upgrade in copy mode. Verify all data is present
--    in the new cluster.

-- 3. Repeat with --link mode. Compare upgrade time.

-- 4. Add a regclass column to a table, run --check (should fail),
--    fix the column, re-run --check (should pass).

-- 5. Full workflow: upgrade, migrate config, update extensions,
--    rebuild stats, verify, cleanup.
