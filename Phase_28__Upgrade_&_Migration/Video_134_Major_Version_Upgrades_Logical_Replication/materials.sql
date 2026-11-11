-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Major Version Upgrades with Logical Replication (Classes 248-249)
-- Phase 28: Upgrade & Migration
-- ============================================================

-- ============================================================
-- 1. PREPARE OLD SERVER (PG 15)
-- ============================================================

-- Enable logical replication:
ALTER SYSTEM SET wal_level = logical;
ALTER SYSTEM SET max_replication_slots = 10;
ALTER SYSTEM SET max_wal_senders = 10;
-- Requires restart:
-- sudo systemctl restart postgresql-15

-- Verify:
SHOW wal_level;

-- Create replication user:
CREATE ROLE repl_upgrade WITH LOGIN REPLICATION PASSWORD 'repl_pass_2026';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO repl_upgrade;

-- Add to pg_hba.conf:
-- hostssl all repl_upgrade <new-server-ip>/32 scram-sha-256

SELECT pg_reload_conf();

-- ============================================================
-- 2. PREPARE NEW SERVER (PG 16)
-- ============================================================

-- Install PG 16:
-- sudo apt install postgresql-16

-- Export schema from old server:
-- pg_dump -h old-server -U postgres --schema-only app_db > schema.sql

-- Export globals:
-- pg_dumpall -h old-server -U postgres --globals-only > globals.sql

-- Import on new server:
-- psql -U postgres -f globals.sql
-- psql -U postgres -d app_db -f schema.sql

-- ============================================================
-- 3. CHECK TABLES FOR PRIMARY KEYS
-- ============================================================

-- Find tables WITHOUT a primary key:
SELECT c.relname
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relkind = 'r' AND n.nspname = 'public'
AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.oid AND i.indisprimary
);

-- Fix: Add primary key
-- ALTER TABLE audit_log ADD COLUMN id BIGSERIAL PRIMARY KEY;

-- Or: Set REPLICA IDENTITY FULL (slower)
-- ALTER TABLE audit_log REPLICA IDENTITY FULL;

-- Check REPLICA IDENTITY for all tables:
SELECT relname,
  CASE relreplident
    WHEN 'd' THEN 'default (PK)'
    WHEN 'f' THEN 'full'
    WHEN 'n' THEN 'nothing'
    WHEN 'i' THEN 'index'
  END AS replica_identity
FROM pg_class
WHERE relkind = 'r'
  AND relnamespace = 'public'::regnamespace;

-- ============================================================
-- 4. CREATE PUBLICATION (Old Server)
-- ============================================================

-- Publish all tables:
CREATE PUBLICATION upgrade_pub FOR ALL TABLES;

-- Or specific tables:
-- CREATE PUBLICATION upgrade_pub FOR TABLE users, orders, products;

-- Verify:
SELECT * FROM pg_publication;
SELECT * FROM pg_publication_tables;

-- ============================================================
-- 5. CREATE SUBSCRIPTION (New Server)
-- ============================================================

CREATE SUBSCRIPTION upgrade_sub
CONNECTION 'host=old-server dbname=app_db user=repl_upgrade password=repl_pass_2026'
PUBLICATION upgrade_pub
WITH (copy_data = true);

-- Monitor initial sync:
SELECT srsubid::regsubscription, srrelid::regclass, srsubstate
FROM pg_subscription_rel;
-- States: i = initialize, d = data copy, s = sync, r = ready

-- ============================================================
-- 6. MONITOR REPLICATION LAG
-- ============================================================

-- On OLD server:
SELECT slot_name, active,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS lag
FROM pg_replication_slots
WHERE slot_name = 'upgrade_sub';

-- On NEW server:
SELECT srrelid::regclass, srsubstate FROM pg_subscription_rel;
-- All 'r' = sync complete

-- ============================================================
-- 7. SEQUENCE SYNC QUERY
-- ============================================================

-- Generate setval commands for ALL sequences:
SELECT format(
  'SELECT setval(%L, COALESCE((SELECT max(%I) FROM %I.%I), 1));',
  seq.relname,
  col.attname,
  tab_ns.nspname,
  tab.relname
)
FROM pg_class seq
JOIN pg_namespace seq_ns ON seq.relnamespace = seq_ns.oid
JOIN pg_depend d ON d.objid = seq.oid
JOIN pg_class tab ON d.refobjid = tab.oid
JOIN pg_namespace tab_ns ON tab.relnamespace = tab_ns.oid
JOIN pg_attribute col ON col.attrelid = tab.oid
  AND col.attnum = d.refobjsubid
WHERE seq.relkind = 'S'
  AND d.deptype = 'a'
ORDER BY seq.relname;

-- ============================================================
-- 8. CUTOVER PROCEDURE
-- ============================================================

-- 1. Stop writes to old server
-- 2. Wait for lag = 0 bytes
-- 3. Run setval for every sequence (from query above)
-- 4. Disable and drop subscription:
ALTER SUBSCRIPTION upgrade_sub DISABLE;
DROP SUBSCRIPTION upgrade_sub;
-- 5. Update application connection string to new server
-- 6. Verify application works on new server

-- ============================================================
-- 9. ROLLBACK (if needed)
-- ============================================================

-- Old server is still running — point app back to it
-- Data written to new server post-cutover is lost
-- Keep old server running 24+ hours after cutover
-- For critical systems: set up reverse replication (new → old)

-- ============================================================
-- 10. CLEANUP AFTER SUCCESSFUL MIGRATION
-- ============================================================

-- On old server: drop publication and replication slot
-- DROP PUBLICATION upgrade_pub;
-- SELECT pg_drop_replication_slot('upgrade_sub');  -- if not auto-dropped

-- Decommission old server after 24-hour verification period

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Set up publication/subscription between PG 15 and 16.
--    Verify initial sync completes (all tables show 'r').

-- 2. Insert, update, delete on old server. Verify on new server.

-- 3. Practice the cutover: stop writes, sync sequences, switch.

-- 4. Intentionally insert on new server before setval.
--    Observe the duplicate key error.

-- 5. Full zero-downtime upgrade workflow from start to finish.
