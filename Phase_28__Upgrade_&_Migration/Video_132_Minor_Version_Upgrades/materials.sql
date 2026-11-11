-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Minor Version Upgrades (Classes 244-245)
-- Phase 28: Upgrade & Migration
-- ============================================================

-- ============================================================
-- 1. CHECK CURRENT VERSION
-- ============================================================

SELECT version();
SHOW server_version;
SHOW server_version_num;

-- Version number breakdown:
-- 16.4 = Major version 16, Minor version 4
-- server_version_num: 160004

-- ============================================================
-- 2. PRE-UPGRADE: CHECK EXTENSIONS
-- ============================================================

-- List installed extensions:
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- Check if extensions need updating after upgrade:
SELECT e.extname, e.extversion AS installed,
       a.default_version AS available,
       e.extversion != a.default_version AS needs_update
FROM pg_extension e
JOIN pg_available_extensions a ON e.extname = a.name
ORDER BY needs_update DESC, e.extname;

-- ============================================================
-- 3. PRE-UPGRADE: FULL BACKUP
-- ============================================================

-- Option 1: pg_dumpall (logical backup of everything):
-- pg_dumpall -U postgres > /backups/pre_upgrade_$(date +%Y%m%d).sql

-- Option 2: pg_basebackup (physical backup):
-- pg_basebackup -U postgres -D /backups/base_pre_upgrade -Ft -z

-- Verify backup:
-- ls -lh /backups/pre_upgrade_*.sql

-- ============================================================
-- 4. UPGRADE — Debian/Ubuntu
-- ============================================================

-- Check available version:
-- apt-cache policy postgresql-16

-- Upgrade:
-- sudo apt update
-- sudo apt install postgresql-16

-- Restart:
-- sudo systemctl restart postgresql-16

-- ============================================================
-- 5. UPGRADE — RHEL/Rocky/Alma
-- ============================================================

-- Check available version:
-- sudo dnf check-update postgresql16*

-- Upgrade:
-- sudo dnf update postgresql16*

-- Restart:
-- sudo systemctl restart postgresql-16

-- ============================================================
-- 6. UPGRADE — Windows
-- ============================================================

-- 1. Download new installer from postgresql.org
-- 2. Stop service: net stop postgresql-x64-16
-- 3. Run installer (detects existing installation)
-- 4. Start service: net start postgresql-x64-16

-- ============================================================
-- 7. POST-UPGRADE VERIFICATION
-- ============================================================

-- Version:
SELECT version();

-- Databases accessible:
SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database WHERE NOT datistemplate;

-- Extensions need update?
SELECT e.extname, e.extversion AS installed,
       a.default_version AS available
FROM pg_extension e
JOIN pg_available_extensions a ON e.extname = a.name
WHERE e.extversion != a.default_version;

-- Update extensions if needed:
-- ALTER EXTENSION pgaudit UPDATE;
-- ALTER EXTENSION pgcrypto UPDATE;

-- Check logs for errors:
-- tail -50 /var/log/postgresql/postgresql-16-main.log

-- Check replication status (if applicable):
SELECT client_addr, state, sent_lsn, write_lsn, replay_lsn
FROM pg_stat_replication;

-- ============================================================
-- 8. REPLICA UPGRADE ORDER
-- ============================================================

-- CORRECT order:
-- 1. Upgrade Standby-1: apt install + restart
-- 2. Verify Standby-1: SELECT * FROM pg_stat_wal_receiver;
-- 3. Upgrade Standby-2: apt install + restart
-- 4. Verify Standby-2: SELECT * FROM pg_stat_wal_receiver;
-- 5. Upgrade Primary: apt install + restart
-- 6. Verify all standbys reconnected:
SELECT client_addr, state, sent_lsn, replay_lsn
FROM pg_stat_replication;

-- ============================================================
-- 9. AUTOMATED UPGRADE SCRIPT
-- ============================================================

-- Save as /usr/local/bin/pg_minor_upgrade.sh:
--
-- #!/bin/bash
-- set -e
-- DATE=$(date +%Y%m%d)
-- LOG="/var/log/pg_upgrade_${DATE}.log"
--
-- echo "[$(date)] Starting minor upgrade" >> $LOG
--
-- # Current version
-- CURRENT=$(psql -U postgres -t -c "SHOW server_version;" | xargs)
-- echo "Current: $CURRENT" >> $LOG
--
-- # Backup
-- pg_dumpall -U postgres > /backups/pre_upgrade_${DATE}.sql 2>> $LOG
--
-- # Upgrade
-- sudo apt update >> $LOG 2>&1
-- sudo apt install -y postgresql-16 >> $LOG 2>&1
--
-- # Restart
-- sudo systemctl restart postgresql-16
--
-- # Verify
-- NEW=$(psql -U postgres -t -c "SHOW server_version;" | xargs)
-- echo "Upgraded: $CURRENT -> $NEW" >> $LOG
-- echo "[$(date)] Complete" >> $LOG

-- ============================================================
-- 10. ROLLBACK (if needed)
-- ============================================================

-- Debian: install specific older version
-- sudo apt install postgresql-16=16.1-1.pgdg22.04+1

-- Or restore from backup:
-- sudo systemctl stop postgresql-16
-- sudo -u postgres pg_restore ... (depends on backup method)
-- sudo systemctl start postgresql-16

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Run SELECT version(); and note your current minor version.
--    Check what versions are available in your package repo.

-- 2. Take a full pg_dumpall backup. Perform a minor upgrade
--    on a test server. Verify with SELECT version().

-- 3. Write an automated upgrade script with logging and
--    error checking. Test it on a dev server.

-- 4. If you have replicas: upgrade a standby first, verify
--    replication, then upgrade the primary.

-- 5. Simulate a failed upgrade by removing an extension package
--    before upgrading. Troubleshoot the startup failure.
