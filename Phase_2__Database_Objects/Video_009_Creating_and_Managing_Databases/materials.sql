-- =============================================
-- PostgreSQL Mastery: Creating & Managing Databases
-- Phase 2: Database Objects | Class 09
-- =============================================
-- CREATE, ALTER, and DROP databases with all options.
-- =============================================

-- === DEFAULT DATABASES (created on install) ===

-- postgres   = default admin database (connect here by default)
-- template1  = template for new databases (modifiable)
-- template0  = clean template (read-only, for clean restores)

-- List all databases
-- \l

-- === CREATE DATABASE ===

-- Simple create
CREATE DATABASE myapp;

-- Create with full options
CREATE DATABASE shop
  OWNER = postgres
  ENCODING = 'UTF8'
  LC_COLLATE = 'en_US.UTF-8'
  LC_CTYPE = 'en_US.UTF-8'
  TEMPLATE = template0
  CONNECTION LIMIT = 100;

-- Create with a different owner
CREATE ROLE webapp LOGIN PASSWORD 'secure123';
CREATE DATABASE webapp_db OWNER webapp;

-- Options reference:
-- OWNER          = who owns the database (default: current user)
-- ENCODING       = character encoding (always use UTF8)
-- TEMPLATE       = base template (template1 default, template0 for clean)
-- LC_COLLATE     = sort order locale
-- LC_CTYPE       = character classification locale
-- CONNECTION LIMIT = max connections (-1 = unlimited)
-- IS_TEMPLATE    = allow as template for other DBs
-- ALLOW_CONNECTIONS = allow users to connect

-- === ALTER DATABASE ===

-- Rename
ALTER DATABASE myapp RENAME TO myapp_v2;

-- Change owner
ALTER DATABASE myapp_v2 OWNER TO webapp;

-- Set a config parameter (applies only to this database)
ALTER DATABASE myapp_v2 SET timezone TO 'Asia/Kolkata';

-- Change connection limit
ALTER DATABASE myapp_v2 CONNECTION LIMIT 50;

-- NOTE: CANNOT change ENCODING or LOCALE after creation!

-- === DROP DATABASE ===

-- Switch to a different database first!
-- \c postgres

-- Drop a database (PERMANENT — no undo!)
DROP DATABASE myapp_v2;

-- Safer: only drop if exists
DROP DATABASE IF EXISTS myapp_v2;

-- Force drop: terminates all connections first (PG 13+)
DROP DATABASE shop WITH (FORCE);

-- === TEMPLATES ===

-- template1: default template, can be modified
-- Add extensions to template1 → all new databases get them
-- \c template1
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- Now every new database will have uuid-ossp

-- template0: clean, read-only
-- Use for: different encoding, clean restores
-- CREATE DATABASE japanese ENCODING 'EUC_JP' TEMPLATE template0
--   LC_COLLATE 'ja_JP.eucJP' LC_CTYPE 'ja_JP.eucJP';

-- === USEFUL QUERIES ===

-- Database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;

-- Who is connected to which database?
SELECT datname, usename, client_addr, state
FROM pg_stat_activity
WHERE datname IS NOT NULL;

-- Connection count per database
SELECT datname, count(*) AS connections
FROM pg_stat_activity
WHERE datname IS NOT NULL
GROUP BY datname
ORDER BY connections DESC;

-- Database settings
SELECT d.datname, s.setconfig
FROM pg_db_role_setting s
JOIN pg_database d ON d.oid = s.setdatabase
WHERE s.setrole = 0;

-- === COMMON ERRORS ===

-- ERROR: database "myapp" already exists
-- FIX: choose a different name or drop the existing one

-- ERROR: cannot drop the currently open database
-- FIX: \c postgres  then DROP DATABASE ...

-- ERROR: database "practice" is being accessed by other users
-- FIX: Terminate connections first:
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'practice' AND pid <> pg_backend_pid();
-- Then DROP DATABASE practice;

-- === PRACTICE EXERCISES ===

-- Exercise 1:
CREATE DATABASE school;
-- \l
-- \c school

-- Exercise 2:
CREATE DATABASE inventory
  OWNER = postgres
  ENCODING = 'UTF8'
  CONNECTION LIMIT = 50;

-- Exercise 3:
ALTER DATABASE school RENAME TO school_v2;
ALTER DATABASE school_v2 CONNECTION LIMIT 20;

-- Exercise 4:
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database ORDER BY pg_database_size(datname) DESC;

-- Exercise 5:
-- \c postgres
DROP DATABASE IF EXISTS school_v2;
DROP DATABASE IF EXISTS inventory;
DROP DATABASE IF EXISTS webapp_db;
DROP ROLE IF EXISTS webapp;
-- \l

-- === ANSWER KEY ===

-- Answer 1:
-- CREATE DATABASE school; creates it; \l confirms it in the list; \c school connects to it.

-- Answer 2:
-- Creates inventory owned by postgres with UTF8 encoding and max 50 concurrent connections.

-- Answer 3:
-- ALTER DATABASE school RENAME TO school_v2; and ALTER DATABASE school_v2 CONNECTION LIMIT 20;
-- (Note: you cannot rename a database while connected to it ? run from postgres DB.)

-- Answer 4:
-- pg_database_size(datname) returns bytes; pg_size_pretty(...) formats into KB / MB / GB sorted largest first.

-- Answer 5:
-- Switch to \c postgres first (cannot drop the DB you are currently connected to), then DROP DATABASE IF EXISTS ...;

-- =============================================
-- Next Class: Schemas
-- =============================================
