-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Streaming Replication — Primary Server Setup (Class 200 Part 1)
-- Phase 24: Replication & High Availability
-- ============================================================

-- ============================================================
-- 1. CHECK CURRENT WAL SETTINGS
-- ============================================================

SHOW wal_level;          -- Should be: replica (PG 16 default)
SHOW max_wal_senders;    -- Should be: 10
SHOW wal_keep_size;      -- Default: 0 (we will change this)
SHOW max_replication_slots;  -- Should be: 10

-- ============================================================
-- 2. CONFIGURE WAL SETTINGS (run as postgres superuser)
-- ============================================================

-- wal_level must be at least 'replica' for streaming replication
-- PG 16 default is already 'replica', but verify:
ALTER SYSTEM SET wal_level = 'replica';

-- Allow up to 10 standbys to connect simultaneously
ALTER SYSTEM SET max_wal_senders = 10;

-- Keep 1GB of WAL for standby reconnection
ALTER SYSTEM SET wal_keep_size = '1GB';

-- Allow up to 10 replication slots
ALTER SYSTEM SET max_replication_slots = 10;

-- Listen on all interfaces (not just localhost)
ALTER SYSTEM SET listen_addresses = '*';

-- Allow read queries on standby servers
ALTER SYSTEM SET hot_standby = 'on';

-- ============================================================
-- 3. CHECK WHICH PARAMETERS NEED RESTART
-- ============================================================

SELECT name, setting, pending_restart
FROM pg_settings
WHERE name IN (
    'wal_level',
    'max_wal_senders',
    'wal_keep_size',
    'max_replication_slots',
    'listen_addresses',
    'hot_standby'
)
ORDER BY name;

-- pending_restart = true means a RESTART is needed
-- pending_restart = false means current or reload is enough

-- ============================================================
-- 4. pg_hba.conf REPLICATION LINE
-- ============================================================

-- Find pg_hba.conf location:
SHOW hba_file;

-- Add this line to pg_hba.conf:
-- (Replace 10.0.1.0/24 with your standby's subnet)
--
-- TYPE   DATABASE      USER          ADDRESS          METHOD
-- host   replication   replicator    10.0.1.0/24      scram-sha-256

-- IMPORTANT:
-- 'replication' is a KEYWORD, not a database name
-- Do NOT use 'all' or your database name here
-- Using 'all' does NOT include replication connections

-- For a single standby IP (more secure):
-- host   replication   replicator    10.0.1.10/32     scram-sha-256

-- For testing on same machine (localhost):
-- host   replication   replicator    127.0.0.1/32     scram-sha-256

-- ============================================================
-- 5. CREATE REPLICATION USER
-- ============================================================

CREATE ROLE replicator
    WITH REPLICATION LOGIN PASSWORD 'SecurePass123!';

-- Verify the role:
SELECT rolname, rolreplication, rolcanlogin, rolsuper
FROM pg_roles
WHERE rolname = 'replicator';

-- rolreplication = true: can stream WAL
-- rolcanlogin = true: can connect
-- rolsuper = false: not a superuser (least privilege)

-- ============================================================
-- 6. RESTART POSTGRESQL
-- ============================================================

-- Linux:
-- sudo systemctl restart postgresql

-- Windows:
-- net stop postgresql-x64-16
-- net start postgresql-x64-16

-- Or from psql (if only reload is needed):
-- SELECT pg_reload_conf();

-- REMEMBER: wal_level, max_wal_senders, max_replication_slots
-- require a FULL RESTART, not just reload!

-- ============================================================
-- 7. VERIFY AFTER RESTART
-- ============================================================

SHOW wal_level;          -- Must be: replica
SHOW max_wal_senders;    -- Must be: 10
SHOW wal_keep_size;      -- Must be: 1GB
SHOW max_replication_slots;  -- Must be: 10

-- Verify no pending restarts:
SELECT name, setting, pending_restart
FROM pg_settings
WHERE pending_restart = true;
-- Should return 0 rows

-- ============================================================
-- 8. OPTIONAL: CREATE REPLICATION SLOT
-- ============================================================

-- Create a physical replication slot for the standby:
SELECT pg_create_physical_replication_slot('standby1_slot');

-- Verify:
SELECT slot_name, slot_type, active
FROM pg_replication_slots;

-- active = false until standby connects

-- ============================================================
-- 9. TEST REPLICATION CONNECTIVITY
-- ============================================================

-- From the standby machine, test that the replicator can connect:
-- psql -h <primary_ip> -U replicator -d postgres
-- Should prompt for password and connect successfully

-- If connection fails, check:
-- 1. Is listen_addresses = '*'?
-- 2. Is the pg_hba.conf line correct?
-- 3. Did you reload/restart after pg_hba.conf change?
-- 4. Is the firewall allowing port 5432?

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Run SHOW wal_level; on your server.
--    If it is 'minimal', change it to 'replica'.

-- 2. Set wal_keep_size to 1GB using ALTER SYSTEM.
--    Check pg_settings.pending_restart to see if restart is needed.

-- 3. Add a replication line to pg_hba.conf for localhost.
--    Restart PostgreSQL.

-- 4. Create the replicator role with REPLICATION LOGIN.
--    Verify with pg_roles.

-- 5. Test connecting as replicator:
--    psql -h 127.0.0.1 -U replicator -d postgres
