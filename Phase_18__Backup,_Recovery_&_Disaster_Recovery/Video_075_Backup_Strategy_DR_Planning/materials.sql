-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Backup Strategy, DR Planning & Drills (Classes 153-155)
-- Phase 18: Backup, Recovery & Disaster Recovery
-- ============================================================

-- ============================================================
-- 1. BACKUP MONITORING QUERIES
-- ============================================================

-- WAL archiving health:
SELECT
    archived_count,
    failed_count,
    last_archived_time,
    CASE WHEN last_archived_time < now() - '10 min'::interval
         THEN 'ALERT: archiving stale!'
         ELSE 'OK' END AS status
FROM pg_stat_archiver;

-- Inactive replication slots (WAL leak!):
SELECT slot_name, active,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS retained_wal
FROM pg_replication_slots
WHERE NOT active;

-- Database sizes for capacity:
SELECT datname,
       pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;

-- WAL directory size:
SELECT count(*) AS wal_files,
       pg_size_pretty(sum(size)) AS wal_total
FROM pg_ls_waldir();

-- Temp file usage:
SELECT datname, temp_files,
       pg_size_pretty(temp_bytes) AS temp_size
FROM pg_stat_database
WHERE temp_bytes > 0;

-- ============================================================
-- 2. BACKUP STRATEGY: 3-2-1 RULE
-- ============================================================

-- 3 copies of your data
-- 2 different media types (local disk + cloud)
-- 1 offsite (different region/provider)

-- ============================================================
-- 3. GRANDFATHER-FATHER-SON RETENTION
-- ============================================================

-- Son (daily):        keep 7 days
-- Father (weekly):    keep 4 weeks
-- Grandfather (monthly): keep 12 months
-- Archive (yearly):   keep 3-7 years (compliance)

-- pgBackRest retention config:
-- repo1-retention-full=2      (full backups)
-- repo1-retention-diff=7      (diff backups)

-- ============================================================
-- 4. PRODUCTION CRON SCHEDULE
-- ============================================================

-- # Monthly full - 1st of month, 1AM
-- 0 1 1 * * pgbackrest --stanza=prod --type=full backup
--
-- # Weekly full - Sundays 1AM
-- 0 1 * * 0 pgbackrest --stanza=prod --type=full backup
--
-- # Daily diff - Mon-Sat 1AM
-- 0 1 * * 1-6 pgbackrest --stanza=prod --type=diff backup
--
-- # Hourly incremental
-- 0 * * * * pgbackrest --stanza=prod --type=incr backup
--
-- # Weekly verify - Sundays 6AM
-- 0 6 * * 0 pgbackrest --stanza=prod verify
--
-- # Daily logical backup of critical tables
-- 30 1 * * * pg_dump -Fc -t orders -t payments -d prod -f /backups/critical.dump

-- ============================================================
-- 5. DR DRILL PROCEDURE
-- ============================================================

-- 1. Record start time
-- 2. Stop test PostgreSQL instance
-- 3. Restore from backup:
--    pgbackrest --stanza=prod --delta \
--      --type=time --target='TIMESTAMP' \
--      --target-action=promote \
--      --pg1-path=/var/lib/postgresql/16/test restore
-- 4. Start test instance
-- 5. Verify data integrity:
--    - Check table existence
--    - Compare row counts
--    - Spot-check critical data
-- 6. Record end time
-- 7. Calculate actual RTO
-- 8. Write DR drill report

-- ============================================================
-- 6. DR DRILL REPORT TEMPLATE
-- ============================================================

-- Date:              2026-11-04
-- Scenario:          Full PITR to 30 minutes ago
-- Backup Tool:       pgBackRest
-- Backup Used:       20261104-020000F + diff + WAL
-- Target Time:       2026-11-04 10:30:00+05:30
-- Actual RTO:        47 minutes
-- Target RTO:        60 minutes
-- RTO Met?:          YES
-- Data Verified?:    YES
-- Issues Found:      (describe any problems)
-- Action Items:      (list fixes needed)
-- Performed By:      (name)

-- ============================================================
-- 7. DISASTER SCENARIOS REFERENCE
-- ============================================================

-- | Disaster           | Recovery Method                    |
-- |--------------------|------------------------------------|
-- | Accidental DROP    | PITR to before the DROP            |
-- | Disk failure       | Standby failover + rebuild         |
-- | Server failure     | Restore base + replay WAL          |
-- | Data corruption    | Restore from clean backup          |
-- | Ransomware         | Restore from OFFSITE backup        |
-- | Datacenter fire    | Failover to DR site                |
-- | Bad migration      | PITR to named restore point        |

-- ============================================================
-- 8. NAMED RESTORE POINTS (use before risky ops)
-- ============================================================

-- Before migration:
SELECT pg_create_restore_point('before_v2_migration');

-- Before bulk delete:
SELECT pg_create_restore_point('before_cleanup_20261104');

-- If something goes wrong, PITR to the named point:
-- recovery_target_name = 'before_v2_migration'

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Write a backup policy for an e-commerce DB (RTO=1h, RPO=5min)
-- 2. Create a cron schedule: full + diff + incr + verify
-- 3. Perform a full DR drill on a test server, measure RTO
-- 4. Write a DR drill report
-- 5. Set up monitoring queries with alert thresholds
