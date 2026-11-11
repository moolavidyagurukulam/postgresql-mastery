-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- pg_basebackup (Class 147)
-- Phase 18: Backup, Recovery & Disaster Recovery
-- ============================================================

-- ============================================================
-- 1. PREREQUISITES
-- ============================================================

-- Create replication user:
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'repl_pass_123';

-- Check wal_level (must be replica or logical):
SHOW wal_level;

-- If minimal, change and restart:
-- ALTER SYSTEM SET wal_level = 'replica';
-- Restart PostgreSQL required

-- Add to pg_hba.conf:
-- host  replication  replicator  127.0.0.1/32  scram-sha-256
-- host  replication  replicator  10.0.0.0/8    scram-sha-256
-- Then: SELECT pg_reload_conf();

-- ============================================================
-- 2. TAKING A BASE BACKUP
-- ============================================================

-- Plain format (raw directory):
-- pg_basebackup -U replicator -D /backups/base_plain -P --checkpoint=fast

-- Tar format with compression (PRODUCTION):
-- pg_basebackup -U replicator -D /backups/base_tar -Ft -z -P --checkpoint=fast

-- With max rate limit (kind to production I/O):
-- pg_basebackup -U replicator -D /backups/base_gentle -Ft -z -P --max-rate=100M

-- With standby configuration for replica:
-- pg_basebackup -U replicator -D /backups/standby -Fp -R -P --checkpoint=fast

-- ============================================================
-- 3. BACKUP OPTIONS REFERENCE
-- ============================================================

-- -D directory     : destination (required)
-- -Fp / -Ft        : plain directory or tar archives
-- -z               : compress with gzip
-- --compress=lz4   : compress with lz4 (PG 15+)
-- -P               : show progress
-- --checkpoint=fast: immediate checkpoint (quicker start, I/O spike)
-- --checkpoint=spread: gradual checkpoint (default, gentler)
-- -R               : write standby.signal + primary_conninfo
-- -X stream        : stream WAL during backup (default, self-contained)
-- -X fetch         : fetch WAL at end (needs wal_keep_size)
-- --max-rate=100M  : throttle backup I/O to 100MB/s

-- ============================================================
-- 4. RESTORING FROM PLAIN BACKUP
-- ============================================================

-- Step 1: Stop PostgreSQL
-- sudo systemctl stop postgresql

-- Step 2: Move old data directory
-- sudo mv /var/lib/postgresql/16/main /var/lib/postgresql/16/main_old

-- Step 3: Copy backup
-- sudo cp -r /backups/base_plain /var/lib/postgresql/16/main

-- Step 4: Fix ownership
-- sudo chown -R postgres:postgres /var/lib/postgresql/16/main

-- Step 5: Start PostgreSQL
-- sudo systemctl start postgresql

-- ============================================================
-- 5. RESTORING FROM TAR BACKUP
-- ============================================================

-- sudo systemctl stop postgresql
-- sudo mv /var/lib/postgresql/16/main /var/lib/postgresql/16/main_old
-- sudo mkdir /var/lib/postgresql/16/main
-- sudo tar xzf /backups/base_tar/base.tar.gz -C /var/lib/postgresql/16/main
-- sudo tar xzf /backups/base_tar/pg_wal.tar.gz -C /var/lib/postgresql/16/main/pg_wal
-- sudo chown -R postgres:postgres /var/lib/postgresql/16/main
-- sudo systemctl start postgresql

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. CREATE ROLE replicator REPLICATION LOGIN PASSWORD 'pass';
--    Update pg_hba.conf for replication
-- 2. pg_basebackup -U replicator -D /backups/test -P --checkpoint=fast
-- 3. pg_basebackup -U replicator -D /backups/tar -Ft -z -P
-- 4. Restore from tar backup to test location
-- 5. pg_basebackup -R to create standby-ready backup
