-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Migrating MySQL to PostgreSQL — pgLoader (Classes 252-253)
-- Phase 28: Upgrade & Migration
-- ============================================================

-- ============================================================
-- 1. INSTALL PGLOADER
-- ============================================================

-- Debian/Ubuntu:
-- sudo apt install pgloader

-- RHEL/Rocky (from EPEL):
-- sudo dnf install epel-release
-- sudo dnf install pgloader

-- macOS:
-- brew install pgloader

-- Verify:
-- pgloader --version

-- ============================================================
-- 2. ONE-COMMAND MIGRATION
-- ============================================================

-- Simplest migration — single command:
-- pgloader mysql://root:password@mysql-server/app_db \
--          postgresql://postgres:pgpass@pg-server/app_db

-- ============================================================
-- 3. COMMAND FILE — PRODUCTION MIGRATION
-- ============================================================

-- Save as migration.load:
--
-- LOAD DATABASE
--   FROM mysql://root:password@mysql-server/app_db
--   INTO postgresql://postgres:pgpass@pg-server/app_db
--
-- WITH
--   include drop,
--   create tables,
--   create indexes,
--   reset sequences,
--   workers = 4,
--   concurrency = 2
--
-- SET
--   maintenance_work_mem to '512MB',
--   work_mem to '64MB'
--
-- CAST
--   type tinyint to boolean using tinyint-to-boolean,
--   type varchar to text when (= precision 65535)
--
-- INCLUDING ONLY TABLE NAMES MATCHING
--   'employees', 'departments', 'orders', 'products'
--
-- BEFORE LOAD DO
--   $$ CREATE SCHEMA IF NOT EXISTS app; $$
--
-- AFTER LOAD DO
--   $$ VACUUM ANALYZE; $$
-- ;

-- Run with:
-- pgloader migration.load

-- ============================================================
-- 4. DATA TYPE MAPPING REFERENCE
-- ============================================================

-- MySQL Type         → PostgreSQL Type
-- TINYINT(1)         → boolean
-- TINYINT            → smallint
-- INT / INTEGER      → integer
-- BIGINT             → bigint
-- FLOAT              → real
-- DOUBLE             → double precision
-- DECIMAL(p,s)       → numeric(p,s)
-- VARCHAR(n)         → varchar(n)
-- TEXT / LONGTEXT     → text
-- DATETIME           → timestamp
-- TIMESTAMP          → timestamptz
-- DATE               → date
-- BLOB / LONGBLOB    → bytea
-- ENUM('a','b')      → CREATE TYPE ... AS ENUM
-- JSON               → json (convert to jsonb manually)

-- ============================================================
-- 5. CUSTOM CAST RULES
-- ============================================================

-- CAST
--   type tinyint to boolean
--        using tinyint-to-boolean
--        when (= precision 1),
--
--   type tinyint to smallint
--        when (<> precision 1),
--
--   type varchar to text
--        when (= precision 65535),
--
--   type datetime to timestamptz,
--
--   column orders.status to text
--        using remove-null-characters,
--
--   type int when unsigned to bigint

-- ============================================================
-- 6. TABLE FILTERING
-- ============================================================

-- Include specific tables:
-- INCLUDING ONLY TABLE NAMES MATCHING
--   'employees', 'departments',
--   ~/^audit_/

-- Exclude specific tables:
-- EXCLUDING TABLE NAMES MATCHING
--   'temp_import', 'debug_log',
--   ~/^_backup_/

-- Include from specific schema:
-- INCLUDING ONLY TABLE NAMES MATCHING
--   'employees' IN SCHEMA 'hr'

-- Rename schema:
-- ALTER SCHEMA 'app_db' RENAME TO 'public'

-- ============================================================
-- 7. TWO-PASS MIGRATION
-- ============================================================

-- Pass 1: Schema only
-- pgloader --with 'schema only' migration.load

-- Review schema in psql:
-- \dt
-- \d employees

-- Make manual adjustments...

-- Pass 2: Data only
-- pgloader --with 'data only' migration.load

-- ============================================================
-- 8. MYSQL-SPECIFIC FEATURE HANDLING
-- ============================================================

-- AUTO_INCREMENT → GENERATED ALWAYS AS IDENTITY (automatic)
-- UNSIGNED INT   → bigint (automatic upcast)
-- UNSIGNED BIGINT → numeric(20,0) (automatic)
-- ENUM           → PostgreSQL ENUM type (automatic)
-- SET            → text[] or junction table (manual)
-- ON UPDATE CURRENT_TIMESTAMP → trigger (manual, see below)
-- FULLTEXT INDEX → tsvector + GIN (manual)
-- Spatial        → PostGIS geometry (manual)

-- ============================================================
-- 9. REPLACING ON UPDATE CURRENT_TIMESTAMP
-- ============================================================

CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach to each table that needs auto-updated timestamps:
-- CREATE TRIGGER set_updated_at
--   BEFORE UPDATE ON employees
--   FOR EACH ROW
--   EXECUTE FUNCTION update_modified_column();

-- CREATE TRIGGER set_updated_at
--   BEFORE UPDATE ON orders
--   FOR EACH ROW
--   EXECUTE FUNCTION update_modified_column();

-- ============================================================
-- 10. CHARACTER SET HANDLING
-- ============================================================

-- MySQL: per-column character sets (latin1, utf8, utf8mb4)
-- PostgreSQL: single database encoding (always use UTF-8)

-- Check for bad encoding in MySQL before migrating:
-- SELECT id, col FROM tbl
-- WHERE col != CONVERT(col USING utf8mb4);

-- Fix bad data:
-- UPDATE tbl SET col = CONVERT(col USING utf8mb4)
-- WHERE col != CONVERT(col USING utf8mb4);

-- ============================================================
-- 11. POST-MIGRATION VALIDATION
-- ============================================================

-- Row counts:
SELECT relname, n_live_tup
FROM pg_stat_user_tables
ORDER BY relname;

-- Check indexes:
SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public';

-- Check foreign keys:
SELECT conname, conrelid::regclass, confrelid::regclass
FROM pg_constraint
WHERE contype = 'f';

-- Check sequences reset correctly:
-- SELECT sequencename, last_value
-- FROM pg_sequences WHERE schemaname = 'public';

-- Rebuild statistics:
-- vacuumdb -U postgres -d app_db --analyze-in-stages

-- ============================================================
-- 12. FIXING MYSQL ZERO DATES
-- ============================================================

-- MySQL allows 0000-00-00 dates — PostgreSQL rejects them.
-- Fix in MySQL BEFORE migrating:

-- Find zero dates:
-- SELECT COUNT(*) FROM orders WHERE order_date = '0000-00-00';

-- Fix by setting to NULL:
-- UPDATE orders SET order_date = NULL WHERE order_date = '0000-00-00';

-- Or set a default:
-- UPDATE orders SET order_date = '1970-01-01'
-- WHERE order_date = '0000-00-00';

-- ============================================================
-- 13. MYSQL vs POSTGRESQL QUERY DIFFERENCES
-- ============================================================

-- GROUP BY: MySQL is lenient, PostgreSQL is strict
-- MySQL:  SELECT name, dept, COUNT(*) FROM emp GROUP BY dept;  -- works
-- PG:     SELECT name, dept, COUNT(*) FROM emp GROUP BY dept;  -- ERROR
-- Fix:    SELECT name, dept, COUNT(*) FROM emp GROUP BY name, dept;

-- Case sensitivity:
-- MySQL:  SELECT * FROM emp WHERE name = 'john';  -- finds 'John'
-- PG:     SELECT * FROM emp WHERE name = 'john';  -- no match
-- Fix:    SELECT * FROM emp WHERE name ILIKE 'john';
-- Or:     CREATE EXTENSION citext; ALTER TABLE emp ALTER name TYPE citext;

-- String quoting:
-- MySQL:  SELECT * FROM emp WHERE name = "John";  -- works
-- PG:     SELECT * FROM emp WHERE name = 'John';  -- single quotes only

-- LIMIT syntax:
-- MySQL:  SELECT * FROM emp LIMIT 5, 10;  (offset, count)
-- PG:     SELECT * FROM emp LIMIT 10 OFFSET 5;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install pgLoader. Run a one-command migration from a
--    MySQL test database to PG 16. Compare row counts.

-- 2. Write a migration.load command file with custom CAST rules.
--    Migrate only 3 specific tables using INCLUDING.

-- 3. Insert zero dates (0000-00-00) in MySQL test data.
--    Attempt migration. See the error. Fix data and re-migrate.

-- 4. Create the update_modified_column() trigger function.
--    Attach to a migrated table. Verify UPDATE sets timestamp.

-- 5. Migrate a MySQL database with ENUM columns.
--    Run \dT in psql to verify PostgreSQL enum types were created.
