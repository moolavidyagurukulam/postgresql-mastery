-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Barman & WAL-G (Classes 151-152)
-- Phase 18: Backup, Recovery & Disaster Recovery
-- ============================================================

-- ============================================================
-- PART 1: BARMAN
-- ============================================================

-- ============================================================
-- 1. INSTALL BARMAN
-- ============================================================

-- On BACKUP SERVER:
-- sudo apt install barman         (Ubuntu/Debian)
-- sudo dnf install barman         (RHEL/CentOS)
-- barman --version

-- On POSTGRESQL SERVER:
-- sudo apt install barman-cli
-- Provides: barman-wal-archive, barman-wal-restore

-- ============================================================
-- 2. BARMAN CONFIGURATION
-- ============================================================

-- /etc/barman.d/myapp.conf:
--
-- [myapp]
-- description = "Production PostgreSQL 16"
-- conninfo = host=10.0.1.1 user=barman dbname=postgres
-- streaming_conninfo = host=10.0.1.1 user=streaming_barman
-- backup_method = postgres
-- streaming_archiver = on
-- slot_name = barman
-- create_slot = auto
-- backup_directory = /var/lib/barman/myapp
-- retention_policy = RECOVERY WINDOW OF 30 DAYS
-- parallel_jobs = 4
-- compression = gzip

-- ============================================================
-- 3. POSTGRESQL SETUP FOR BARMAN
-- ============================================================

CREATE ROLE barman WITH LOGIN SUPERUSER PASSWORD 'barman_pass';
CREATE ROLE streaming_barman WITH LOGIN REPLICATION PASSWORD 'stream_pass';

-- pg_hba.conf entries:
-- host  all          barman            10.0.2.1/32  scram-sha-256
-- host  replication  streaming_barman  10.0.2.1/32  scram-sha-256

ALTER SYSTEM SET archive_command = 'barman-wal-archive backup-server myapp %p';
-- Restart PostgreSQL

-- ============================================================
-- 4. BARMAN COMMANDS
-- ============================================================

-- Check setup:
-- barman check myapp

-- Force WAL switch:
-- barman switch-wal myapp

-- Take backup:
-- barman backup myapp --wait

-- List backups:
-- barman list-backup myapp

-- Backup details:
-- barman show-backup myapp 20261104T140000

-- Restore (to remote PG server):
-- barman recover myapp 20261104T140000 \
--   /var/lib/postgresql/16/main \
--   --remote-ssh-command 'ssh postgres@10.0.1.1'

-- PITR:
-- barman recover myapp latest \
--   /var/lib/postgresql/16/main \
--   --remote-ssh-command 'ssh postgres@10.0.1.1' \
--   --target-time '2026-11-04 10:30:00+05:30'

-- Maintenance (add to cron every minute):
-- * * * * * barman cron

-- Delete specific backup:
-- barman delete myapp 20261104T140000

-- ============================================================
-- PART 2: WAL-G
-- ============================================================

-- ============================================================
-- 5. INSTALL WAL-G
-- ============================================================

-- Download from GitHub releases:
-- wget https://github.com/wal-g/wal-g/releases/download/v3.0.0/\
--   wal-g-pg-ubuntu-20.04-amd64.tar.gz
-- tar xzf wal-g-pg-*.tar.gz
-- sudo mv wal-g-pg-ubuntu-20.04-amd64 /usr/local/bin/wal-g
-- sudo chmod +x /usr/local/bin/wal-g

-- ============================================================
-- 6. WAL-G CONFIGURATION (Environment Variables)
-- ============================================================

-- For S3:
-- WALG_S3_PREFIX=s3://mycompany-pg-backups/myapp
-- AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
-- AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
-- AWS_REGION=ap-south-1

-- For local filesystem:
-- WALG_FILE_PREFIX=/backups/wal-g

-- For Google Cloud Storage:
-- WALG_GS_PREFIX=gs://bucket-name/path
-- GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json

-- Common settings:
-- WALG_COMPRESSION_METHOD=lz4
-- WALG_DELTA_MAX_STEPS=7
-- PGDATA=/var/lib/postgresql/16/main

-- ============================================================
-- 7. POSTGRESQL SETUP FOR WAL-G
-- ============================================================

ALTER SYSTEM SET archive_command =
    'envdir /etc/wal-g/env.d wal-g wal-push %p';
ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM SET wal_level = 'replica';
-- Restart PostgreSQL

-- ============================================================
-- 8. WAL-G COMMANDS
-- ============================================================

-- Full backup:
-- sudo -u postgres envdir /etc/wal-g/env.d wal-g backup-push $PGDATA

-- Delta backup:
-- sudo -u postgres envdir /etc/wal-g/env.d wal-g backup-push --delta $PGDATA

-- List backups:
-- sudo -u postgres envdir /etc/wal-g/env.d wal-g backup-list

-- Restore latest:
-- sudo -u postgres envdir /etc/wal-g/env.d wal-g backup-fetch $PGDATA LATEST

-- Restore specific:
-- sudo -u postgres envdir /etc/wal-g/env.d wal-g backup-fetch $PGDATA backup_name

-- PITR setup after backup-fetch:
-- Add to postgresql.auto.conf:
--   restore_command = 'envdir /etc/wal-g/env.d wal-g wal-fetch %f %p'
--   recovery_target_time = '2026-11-04 10:30:00+05:30'
--   recovery_target_action = 'promote'
-- touch $PGDATA/recovery.signal

-- Retention (dry run):
-- sudo -u postgres envdir /etc/wal-g/env.d wal-g delete retain FULL 2

-- Retention (actually delete):
-- sudo -u postgres envdir /etc/wal-g/env.d wal-g delete retain FULL 2 --confirm

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install WAL-G, configure for local filesystem
-- 2. Set archive_command = wal-g wal-push, restart PG
-- 3. wal-g backup-push $PGDATA; wal-g backup-list
-- 4. INSERT data, wal-g backup-push --delta $PGDATA
-- 5. Restore: backup-fetch LATEST, configure recovery, start PG
