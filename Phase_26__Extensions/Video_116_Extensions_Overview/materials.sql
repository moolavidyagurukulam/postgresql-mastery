-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Extensions — Install, Manage & Explore (Class 222)
-- Phase 26: Extensions
-- ============================================================

-- ============================================================
-- 1. LIST AVAILABLE EXTENSIONS
-- ============================================================

-- All extensions on the system:
SELECT name, default_version, comment
FROM pg_available_extensions
ORDER BY name;

-- Count:
SELECT count(*) FROM pg_available_extensions;

-- ============================================================
-- 2. INSTALL EXTENSIONS
-- ============================================================

-- Basic install:
CREATE EXTENSION pg_trgm;

-- Safe install (no error if already exists):
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Install into specific schema:
CREATE EXTENSION hstore SCHEMA public;

-- ============================================================
-- 3. LIST INSTALLED EXTENSIONS
-- ============================================================

-- SQL query:
SELECT extname, extversion, n.nspname AS schema
FROM pg_extension e
JOIN pg_namespace n ON e.extnamespace = n.oid
ORDER BY extname;

-- psql shortcut:
-- \dx          (list installed)
-- \dx+         (detailed with owned objects)
-- \dx+ pgcrypto  (objects in pgcrypto)

-- ============================================================
-- 4. MANAGE EXTENSIONS
-- ============================================================

-- Check for available upgrades:
SELECT name, installed_version, default_version
FROM pg_available_extensions
WHERE installed_version IS NOT NULL
  AND installed_version <> default_version;

-- Upgrade:
ALTER EXTENSION pg_trgm UPDATE;

-- Upgrade to specific version:
-- ALTER EXTENSION pg_trgm UPDATE TO '1.6';

-- Move to another schema:
-- ALTER EXTENSION hstore SET SCHEMA extensions;

-- Drop:
DROP EXTENSION hstore;

-- Drop with dependencies:
-- DROP EXTENSION hstore CASCADE;
-- WARNING: also drops columns/tables using hstore type!

-- ============================================================
-- 5. SHARED_PRELOAD_LIBRARIES
-- ============================================================

-- Check current setting:
SHOW shared_preload_libraries;

-- Extensions that need preloading:
-- pg_stat_statements, pg_cron, auto_explain,
-- pg_prewarm, pgaudit

-- In postgresql.conf:
-- shared_preload_libraries = 'pg_stat_statements,pg_cron'
-- Then restart PostgreSQL

-- ============================================================
-- 6. TRUSTED EXTENSIONS
-- ============================================================

-- List trusted extensions (non-superuser can install):
SELECT name, trusted, comment
FROM pg_available_extensions
WHERE trusted = true
ORDER BY name;

-- Grant CREATE to a user:
-- GRANT CREATE ON DATABASE mydb TO app_user;
-- Then as app_user: CREATE EXTENSION citext;

-- ============================================================
-- 7. EXTENSION DEPENDENCIES
-- ============================================================

-- Check what depends on an extension:
SELECT
    classid::regclass,
    objid,
    deptype
FROM pg_depend
WHERE refobjid = (
    SELECT oid FROM pg_extension WHERE extname = 'pgcrypto'
);

-- ============================================================
-- 8. EXTENSION FILE LOCATIONS
-- ============================================================

-- Find extension directory:
-- pg_config --sharedir
-- Extensions are in: <sharedir>/extension/

-- Control file: extension_name.control
-- SQL files: extension_name--version.sql
-- Upgrade: extension_name--old--new.sql

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. List all available extensions on your system.
--    How many are there?

-- 2. Install pg_trgm, pgcrypto, and uuid-ossp.
--    Use \dx to verify.

-- 3. Check \dx+ pgcrypto to see all functions it provides.

-- 4. Find which extensions are trusted on your system.

-- 5. Try installing an extension that needs
--    shared_preload_libraries (like pg_stat_statements).
--    What error do you get without preloading?

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP EXTENSION IF EXISTS pg_trgm;
-- DROP EXTENSION IF EXISTS pgcrypto;
-- DROP EXTENSION IF EXISTS hstore;
-- DROP EXTENSION IF EXISTS "uuid-ossp";
