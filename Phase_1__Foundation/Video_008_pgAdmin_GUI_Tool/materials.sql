-- =============================================
-- PostgreSQL Mastery: pgAdmin GUI Tool
-- Phase 1: Foundation | Class 08
-- =============================================
-- Learn to use pgAdmin 4 — the official graphical
-- administration tool for PostgreSQL.
-- =============================================

-- === INSTALLATION ===

-- Windows: Included with PostgreSQL installer
-- Start Menu → PostgreSQL 16 → pgAdmin 4

-- Linux (Debian/Ubuntu):
-- curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin.gpg
-- sudo apt update
-- sudo apt install pgadmin4-desktop    (desktop version)
-- sudo apt install pgadmin4-web        (web/server version)

-- macOS: Download .dmg from https://www.pgadmin.org/download/

-- === FIRST LAUNCH ===

-- 1. Set a MASTER PASSWORD (this is NOT your PostgreSQL password!)
--    pgAdmin uses it to encrypt saved server connections.

-- 2. Register a server:
--    Right-click Servers → Register → Server
--    General tab:  Name = "Local PG 16"
--    Connection tab:
--      Host:     localhost
--      Port:     5432
--      Database: postgres
--      Username: postgres
--      Password: (your password)
--      Check "Save Password"

-- === KEY INTERFACE AREAS ===

-- Browser (left)   = tree view: Servers → Databases → Schemas → Tables
-- Properties        = details of the selected object
-- Query Tool        = write and run SQL (Tools → Query Tool or Alt+Shift+Q)
-- Dashboard         = server activity monitoring
-- Messages (bottom) = query results, errors, notifications

-- === COMMON OPERATIONS ===

-- Browse data:
--   Right-click table → View/Edit Data → All Rows

-- Describe table:
--   Right-click table → Properties → see all tabs

-- Create database:
--   Right-click Databases → Create → Database

-- Create table:
--   Right-click Tables → Create → Table → fill form → check SQL tab → Save

-- Run a query:
--   Tools → Query Tool → type SQL → F5 (or click Execute)

-- Export results:
--   In Query Tool results → click download icon → CSV or JSON

-- View query plan:
--   In Query Tool → click Explain (or F7)

-- === psql vs pgAdmin — USE BOTH! ===

-- Use psql for:
--   Quick one-off queries
--   Scripting & automation (bash scripts)
--   Remote servers via SSH
--   Speed (faster for experienced users)

-- Use pgAdmin for:
--   Visual browsing of database structure
--   Writing complex queries with auto-complete
--   Viewing query execution plans graphically
--   Creating objects without memorizing syntax
--   Monitoring server activity (Dashboard)

-- === PRACTICE EXERCISES ===

-- Exercise 1:
-- Open pgAdmin. Register your local PostgreSQL 16 server.
-- Expand the tree and browse to the practice database.

-- Exercise 2:
-- Find the students table (from the psql class).
-- Right-click → View/Edit Data → All Rows.

-- Exercise 3:
-- Open Query Tool (Tools → Query Tool).
-- Run: SELECT * FROM students;  (press F5)

-- Exercise 4:
-- Create a new table using the GUI:
-- Right-click Tables → Create → Table
-- Name: courses
-- Columns:
--   id      SERIAL PRIMARY KEY
--   name    VARCHAR(100) NOT NULL
--   credits INTEGER CHECK (credits > 0)
-- Click SQL tab to see the generated statement.
-- Click Save.

-- Verify with SQL:
SELECT * FROM courses;
-- \d courses

-- Exercise 5:
-- Click your server name in Browser.
-- Open the Dashboard tab.
-- Check: How many active connections do you see?

-- === COMMON MISTAKES ===

-- 1. Forgot master password → may need to reset pgAdmin settings
--    (Delete ~/.pgadmin/ on Linux/macOS or %APPDATA%\pgAdmin\ on Windows)

-- 2. Running query on wrong database → check the database name in Query Tool title bar

-- 3. Not clicking Save → the object is NOT created until you Save

-- 4. Thinking pgAdmin replaces psql → they are complementary, learn BOTH

-- === ANSWER KEY ===

-- Answer 1:
-- Register Server -> General (Name: Local PG16) -> Connection (Host: localhost, Port: 5432, User: postgres).

-- Answer 2:
-- Databases -> practice -> Schemas -> public -> Tables -> students -> Right-click -> View/Edit Data -> All Rows.

-- Answer 3:
-- Tools -> Query Tool -> type SELECT * FROM students; -> press F5 (or Execute button) to see Data Output.

-- Answer 4:
-- Verify in Query Tool with: SELECT * FROM courses; and in psql with: \d courses.

-- Answer 5:
-- Server -> Dashboard tab -> "Sessions" / "Server Activity" shows active & idle client connections in real time.

-- =============================================
-- Phase 1: Foundation — COMPLETE!
-- Next Phase: Phase 2 — Database Basics
-- Next Class: Creating Databases
-- =============================================
