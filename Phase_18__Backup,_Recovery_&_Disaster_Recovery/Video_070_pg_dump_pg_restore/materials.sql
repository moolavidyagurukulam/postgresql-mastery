-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- pg_dump & pg_restore (Classes 145-146)
-- Phase 18: Backup, Recovery & Disaster Recovery
-- ============================================================

-- ============================================================
-- 1. pg_dump — OUTPUT FORMATS
-- ============================================================

-- Plain SQL (default):
-- pg_dump -U postgres -d trigger_lab > backup.sql

-- Custom format (PRODUCTION STANDARD):
-- pg_dump -U postgres -Fc -d trigger_lab -f backup.dump

-- Directory format (parallel dump):
-- pg_dump -U postgres -Fd -j 4 -d trigger_lab -f backup_dir/

-- Tar format:
-- pg_dump -U postgres -Ft -d trigger_lab -f backup.tar

-- ============================================================
-- 2. pg_dump — SELECTIVE OPTIONS
-- ============================================================

-- Single table:
-- pg_dump -U postgres -Fc -t big_orders -d trigger_lab -f orders.dump

-- Exclude table:
-- pg_dump -U postgres -Fc -T audit_log -d trigger_lab -f no_audit.dump

-- Schema only (no data):
-- pg_dump -U postgres -s -d trigger_lab > schema.sql

-- Data only (no schema):
-- pg_dump -U postgres -a -Fc -d trigger_lab -f data_only.dump

-- Specific schema:
-- pg_dump -U postgres -Fc -n public -d trigger_lab -f public.dump

-- With DROP+CREATE (clean refresh):
-- pg_dump -U postgres -Fc --clean --if-exists -d trigger_lab -f clean.dump

-- Skip ownership (for restoring as different user):
-- pg_dump -U postgres -Fc -O -d trigger_lab -f no_owner.dump

-- ============================================================
-- 3. pg_dumpall — GLOBAL OBJECTS
-- ============================================================

-- Globals only (roles, tablespaces):
-- pg_dumpall -U postgres --globals-only > globals.sql

-- All databases (one giant file):
-- pg_dumpall -U postgres > full_cluster.sql

-- IMPORTANT: pg_dump misses roles/tablespaces!
-- Always run pg_dumpall --globals-only alongside per-DB dumps.

-- ============================================================
-- 4. pg_restore — BASIC RESTORE
-- ============================================================

-- Create target database:
-- createdb -U postgres restored_db

-- Restore custom format:
-- pg_restore -U postgres -d restored_db backup.dump

-- Parallel restore (4 workers):
-- pg_restore -U postgres -d restored_db -j 4 backup.dump

-- Restore with CREATE DATABASE (-C):
-- pg_restore -U postgres -C -d postgres backup.dump

-- ============================================================
-- 5. pg_restore — SELECTIVE RESTORE
-- ============================================================

-- List Table of Contents:
-- pg_restore -l backup.dump > toc.list

-- Selective restore from TOC:
-- pg_restore -U postgres -d restored_db -L toc.list backup.dump

-- Restore single table:
-- pg_restore -U postgres -d restored_db -t employees backup.dump

-- Restore single table data only:
-- pg_restore -U postgres -d restored_db -t employees --data-only backup.dump

-- Restore with clean (drop + create):
-- pg_restore -U postgres -d restored_db --clean --if-exists backup.dump

-- ============================================================
-- 6. VERIFY BACKUP
-- ============================================================

-- Verify custom/directory/tar dump is readable:
-- pg_restore -l backup.dump > /dev/null && echo "OK" || echo "CORRUPT"

-- ============================================================
-- 7. PRODUCTION BACKUP SCRIPT
-- ============================================================

-- #!/bin/bash
-- DB_NAME="myapp"
-- BACKUP_DIR="/backups/pg_dumps"
-- RETENTION_DAYS=7
-- TIMESTAMP=$(date +%Y%m%d_%H%M%S)
-- FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"
--
-- mkdir -p "$BACKUP_DIR"
-- pg_dump -U postgres -Fc -d "$DB_NAME" -f "$FILE"
--
-- if pg_restore -l "$FILE" > /dev/null 2>&1; then
--     echo "Backup OK: $FILE"
-- else
--     echo "ERROR: Backup failed!" >&2; exit 1
-- fi
--
-- find "$BACKUP_DIR" -name '*.dump' -mtime +$RETENTION_DAYS -delete

-- Schedule with cron:
-- 0 2 * * * /opt/scripts/pg_backup.sh >> /var/log/pg_backup.log 2>&1

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. pg_dump -Fc -d trigger_lab -f trigger_lab.dump
-- 2. pg_restore -l trigger_lab.dump | head -20
-- 3. createdb restored; pg_restore -d restored trigger_lab.dump
-- 4. pg_restore -d restored -t employees --clean --if-exists trigger_lab.dump
-- 5. Write a backup script with timestamp and retention
