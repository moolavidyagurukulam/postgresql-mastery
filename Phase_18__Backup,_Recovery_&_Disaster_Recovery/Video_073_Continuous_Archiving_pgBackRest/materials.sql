-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Continuous Archiving & pgBackRest (Classes 149-150)
-- Phase 18: Backup, Recovery & Disaster Recovery
-- ============================================================

-- ============================================================
-- 1. INSTALL PGBACKREST
-- ============================================================

-- Ubuntu/Debian:
-- sudo apt install pgbackrest

-- RHEL/CentOS:
-- sudo dnf install pgbackrest

-- Verify:
-- pgbackrest version

-- Create directories:
-- sudo mkdir -p /etc/pgbackrest
-- sudo mkdir -p /var/lib/pgbackrest
-- sudo chown postgres:postgres /var/lib/pgbackrest

-- ============================================================
-- 2. CONFIGURATION FILE
-- ============================================================

-- /etc/pgbackrest/pgbackrest.conf:
--
-- [global]
-- repo1-path=/var/lib/pgbackrest
-- repo1-retention-full=2
-- repo1-retention-diff=7
-- repo1-cipher-type=aes-256-cbc
-- repo1-cipher-pass=your-encryption-passphrase
-- compress-type=lz4
-- compress-level=6
-- process-max=4
-- log-level-console=info
-- log-level-file=detail
--
-- [myapp]
-- pg1-path=/var/lib/postgresql/16/main

-- ============================================================
-- 3. CONFIGURE POSTGRESQL FOR PGBACKREST
-- ============================================================

ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM SET archive_command = 'pgbackrest --stanza=myapp archive-push %p';
ALTER SYSTEM SET wal_level = 'replica';
-- Restart required

-- ============================================================
-- 4. STANZA SETUP
-- ============================================================

-- Create stanza (one-time):
-- sudo -u postgres pgbackrest --stanza=myapp stanza-create

-- Verify:
-- sudo -u postgres pgbackrest --stanza=myapp check

-- ============================================================
-- 5. BACKUP TYPES
-- ============================================================

-- Full backup (everything):
-- sudo -u postgres pgbackrest --stanza=myapp --type=full backup

-- Differential (since last full):
-- sudo -u postgres pgbackrest --stanza=myapp --type=diff backup

-- Incremental (since last backup):
-- sudo -u postgres pgbackrest --stanza=myapp --type=incr backup

-- ============================================================
-- 6. VIEW BACKUPS
-- ============================================================

-- List all backups:
-- sudo -u postgres pgbackrest --stanza=myapp info

-- JSON output (for scripting):
-- sudo -u postgres pgbackrest --stanza=myapp info --output=json

-- ============================================================
-- 7. RESTORE
-- ============================================================

-- Stop PostgreSQL first:
-- sudo systemctl stop postgresql

-- Full restore (latest):
-- sudo -u postgres pgbackrest --stanza=myapp --delta restore
-- sudo systemctl start postgresql

-- PITR to specific time:
-- sudo -u postgres pgbackrest --stanza=myapp --delta \
--   --type=time --target='2026-11-04 10:30:00+05:30' \
--   --target-action=promote restore

-- Selective database restore:
-- sudo -u postgres pgbackrest --stanza=myapp --delta \
--   --db-include=trigger_lab restore

-- ============================================================
-- 8. VERIFY AND EXPIRE
-- ============================================================

-- Verify backup integrity:
-- sudo -u postgres pgbackrest --stanza=myapp verify

-- Manual expire (usually automatic):
-- sudo -u postgres pgbackrest --stanza=myapp expire

-- ============================================================
-- 9. S3 CONFIGURATION EXAMPLE
-- ============================================================

-- [global]
-- repo1-type=s3
-- repo1-path=/pgbackrest
-- repo1-s3-bucket=mycompany-pg-backups
-- repo1-s3-region=ap-south-1
-- repo1-s3-endpoint=s3.ap-south-1.amazonaws.com
-- repo1-s3-key=AKIAIOSFODNN7EXAMPLE
-- repo1-s3-key-secret=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
-- repo1-retention-full=4

-- ============================================================
-- 10. PRODUCTION CRON SCHEDULE
-- ============================================================

-- # Weekly full - Sunday 2AM
-- 0 2 * * 0 pgbackrest --stanza=myapp --type=full backup
--
-- # Daily diff - Mon-Sat 2AM
-- 0 2 * * 1-6 pgbackrest --stanza=myapp --type=diff backup
--
-- # Hourly incremental
-- 0 * * * * pgbackrest --stanza=myapp --type=incr backup
--
-- # Weekly verify - Sunday 6AM
-- 0 6 * * 0 pgbackrest --stanza=myapp verify

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install pgBackRest, write config file
-- 2. stanza-create + check
-- 3. --type=full backup + info
-- 4. INSERT data, --type=diff backup, compare sizes
-- 5. Stop PG, --delta restore, start PG, verify data
