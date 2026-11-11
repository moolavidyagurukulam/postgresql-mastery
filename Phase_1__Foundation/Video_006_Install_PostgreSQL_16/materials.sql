-- =============================================
-- PostgreSQL Mastery: Install PostgreSQL 16
-- Phase 1: Foundation | Class 06
-- =============================================
-- Step-by-step installation on Linux (Debian/Ubuntu) and Windows.
-- Follow along and have a working PG 16 by the end!
-- =============================================

-- === LINUX INSTALLATION (Debian/Ubuntu) ===

-- Step 1: Add official PostgreSQL repository
-- sudo apt install -y gnupg2 wget lsb-release
-- sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
-- wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
-- sudo apt update

-- Step 2: Install PostgreSQL 16
-- sudo apt install -y postgresql-16

-- Step 3: Verify installation
-- sudo systemctl status postgresql
-- psql --version
-- sudo -u postgres psql -c 'SELECT version();'

-- Step 4: Connect for the first time
-- sudo -u postgres psql

-- Step 5: Create practice database
-- CREATE DATABASE practice;
-- \c practice
-- \conninfo

-- === WINDOWS INSTALLATION ===

-- Step 1: Download from https://www.postgresql.org/download/windows/
-- Step 2: Run installer, set password for postgres user
-- Step 3: Keep defaults: port 5432, default locale
-- Step 4: Connect: psql -U postgres (enter password)
-- Step 5: CREATE DATABASE practice;

-- === VERIFICATION COMMANDS (run inside psql) ===

-- Check version
SELECT version();

-- List all databases
-- \l

-- Check connection info
-- \conninfo

-- Create practice database
CREATE DATABASE practice;

-- Connect to practice database
-- \c practice

-- === SERVICE MANAGEMENT ===

-- Linux:
-- sudo systemctl start postgresql
-- sudo systemctl stop postgresql
-- sudo systemctl restart postgresql    -- drops all connections!
-- sudo systemctl reload postgresql     -- keeps connections alive
-- sudo systemctl status postgresql
-- sudo systemctl is-active postgresql

-- Windows (Command Prompt as Administrator):
-- net stop postgresql-x64-16
-- net start postgresql-x64-16

-- === IMPORTANT FILE PATHS ===

-- Linux (Debian/Ubuntu):
-- Config:    /etc/postgresql/16/main/postgresql.conf
-- Auth:      /etc/postgresql/16/main/pg_hba.conf
-- Data:      /var/lib/postgresql/16/main/
-- WAL:       /var/lib/postgresql/16/main/pg_wal/
-- Logs:      /var/log/postgresql/postgresql-16-main.log
-- Binaries:  /usr/lib/postgresql/16/bin/

-- Windows:
-- Install:   C:\Program Files\PostgreSQL\16\
-- Data:      C:\Program Files\PostgreSQL\16\data\
-- Config:    C:\Program Files\PostgreSQL\16\data\postgresql.conf
-- Auth:      C:\Program Files\PostgreSQL\16\data\pg_hba.conf
-- Logs:      C:\Program Files\PostgreSQL\16\data\log\
-- Binaries:  C:\Program Files\PostgreSQL\16\bin\

-- === COMMON ERRORS & FIXES ===

-- ERROR: psql: command not found
-- FIX:   sudo apt install postgresql-client-16 (Linux)
-- FIX:   Add C:\Program Files\PostgreSQL\16\bin\ to PATH (Windows)

-- ERROR: connection refused / No such file or directory
-- FIX:   sudo systemctl start postgresql

-- ERROR: FATAL: role "yourname" does not exist
-- FIX:   sudo -u postgres psql (Linux) or psql -U postgres (Windows)

-- ERROR: password authentication failed
-- FIX:   Edit pg_hba.conf → set method to 'trust' → reload → change password → restore auth

-- === PRACTICE EXERCISES ===

-- Exercise 1:
-- Install PostgreSQL 16. Verify with: SELECT version();

-- Exercise 2:
-- CREATE DATABASE practice;
-- \c practice
-- \conninfo

-- Exercise 3:
-- Find postgresql.conf on your system. Open and read the first 20 lines.

-- Exercise 4:
-- Stop PostgreSQL, then start it again. Verify with status command.

-- Exercise 5:
-- Try connecting without -U postgres. See the error. Then connect correctly.

-- =============================================
-- Next Class: psql Command-Line Tool
-- =============================================
