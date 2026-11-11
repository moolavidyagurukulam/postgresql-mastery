-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Migrating SQL Server to PostgreSQL (Classes 254-255)
-- Phase 28: Upgrade & Migration
-- ============================================================

-- ============================================================
-- 1. INSTALL FREETDS + PGLOADER
-- ============================================================

-- Step 1: Install FreeTDS
-- sudo apt install freetds-dev freetds-bin tdsodbc

-- Step 2: Test connection
-- tsql -H sql-server-host -p 1433 -U sa -P 'YourPassword'

-- Step 3: Install pgLoader
-- sudo apt install pgloader

-- ============================================================
-- 2. CONFIGURE FREETDS
-- ============================================================

-- Edit /etc/freetds/freetds.conf:
--
-- [global]
-- tds version = 7.4
-- client charset = UTF-8
--
-- [myserver]
-- host = sql-server-host.example.com
-- port = 1433
-- tds version = 7.4
-- database = app_db

-- ============================================================
-- 3. PGLOADER COMMAND FILE
-- ============================================================

-- Save as mssql_migration.load:
--
-- LOAD DATABASE
--   FROM mssql://sa:YourPassword@myserver/app_db
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
--   maintenance_work_mem to '512MB'
--
-- INCLUDING ONLY TABLE NAMES MATCHING
--   'Employees', 'Departments', 'Orders', 'Products'
--   IN SCHEMA 'dbo'
--
-- CAST
--   type nvarchar to text,
--   type nchar to char,
--   type datetime to timestamptz,
--   type datetime2 to timestamptz,
--   type uniqueidentifier to uuid,
--   type bit to boolean,
--   type money to numeric,
--   type image to bytea
--
-- ALTER SCHEMA 'dbo' RENAME TO 'public'
-- ;

-- Run with:
-- pgloader mssql_migration.load

-- ============================================================
-- 4. DATA TYPE MAPPING REFERENCE
-- ============================================================

-- SQL Server Type        → PostgreSQL Type
-- INT                    → integer
-- BIGINT                 → bigint
-- SMALLINT               → smallint
-- BIT                    → boolean
-- MONEY / SMALLMONEY     → numeric
-- FLOAT                  → double precision
-- DECIMAL(p,s)           → numeric(p,s)
-- NVARCHAR(n)            → varchar(n) or text
-- NCHAR(n)               → char(n)
-- VARCHAR(MAX)           → text
-- DATETIME               → timestamp
-- DATETIME2              → timestamp
-- DATETIMEOFFSET         → timestamptz
-- UNIQUEIDENTIFIER       → uuid
-- IMAGE / VARBINARY      → bytea
-- XML                    → xml

-- ============================================================
-- 5. T-SQL → PL/PGSQL CONVERSION REFERENCE
-- ============================================================

-- @variable             → variable (no prefix)
-- GETDATE()             → CURRENT_TIMESTAMP
-- TOP 10                → LIMIT 10
-- ISNULL(a, b)          → COALESCE(a, b)
-- PRINT 'msg'           → RAISE NOTICE 'msg'
-- CONVERT(type, val)    → val::type or CAST()
-- EXEC sp_name          → CALL proc_name()
-- IDENTITY(1,1)         → GENERATED ALWAYS AS IDENTITY
-- NEWID()               → gen_random_uuid()
-- RAISERROR             → RAISE EXCEPTION
-- TRY...CATCH           → BEGIN...EXCEPTION
-- WITH (NOLOCK)         → Not needed (MVCC)
-- CROSS APPLY           → LATERAL JOIN
-- 'a' + 'b'            → 'a' || 'b'

-- ============================================================
-- 6. STORED PROCEDURE CONVERSION EXAMPLE
-- ============================================================

-- SQL Server (T-SQL):
-- CREATE PROCEDURE dbo.GetEmployeeSalary
--   @emp_id INT,
--   @salary MONEY OUTPUT
-- AS
-- BEGIN
--   SET @salary = (
--     SELECT ISNULL(salary, 0)
--     FROM Employees WHERE emp_id = @emp_id
--   );
--   IF @salary = 0
--     RAISERROR('Employee not found', 16, 1);
-- END;

-- PostgreSQL (PL/pgSQL):
CREATE OR REPLACE FUNCTION get_employee_salary(
  p_emp_id integer
) RETURNS numeric AS $$
DECLARE
  v_salary numeric;
BEGIN
  SELECT COALESCE(salary, 0) INTO v_salary
  FROM employees WHERE emp_id = p_emp_id;

  IF v_salary = 0 THEN
    RAISE EXCEPTION 'Employee not found';
  END IF;

  RETURN v_salary;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. BCP EXPORT + COPY IMPORT (Large Tables)
-- ============================================================

-- Export from SQL Server:
-- bcp "SELECT * FROM app_db.dbo.Orders" queryout orders.csv \
--   -S sql-server -U sa -P pass -c -t '|' -r '\n'

-- Create table in PostgreSQL first (from converted schema)
-- psql -U postgres -d app_db -f orders_table.sql

-- Import with COPY:
-- \COPY orders FROM 'orders.csv'
--   WITH (FORMAT csv, DELIMITER '|', NULL '')

-- Rebuild indexes after bulk load:
-- psql -U postgres -d app_db -f orders_indexes.sql
-- vacuumdb -U postgres -d app_db --analyze-in-stages

-- ============================================================
-- 8. SCHEMA MAPPING
-- ============================================================

-- SQL Server default schema: dbo
-- PostgreSQL default schema: public

-- In pgLoader command file:
-- ALTER SCHEMA 'dbo' RENAME TO 'public'

-- For multiple schemas, set search_path:
-- ALTER DATABASE app_db SET search_path = public, sales, hr;

-- ============================================================
-- 9. SQL SERVER FEATURES → POSTGRESQL ALTERNATIVES
-- ============================================================

-- Linked Server      → postgres_fdw
-- SQL Agent Jobs     → pg_cron or OS cron
-- SSRS Reports       → Metabase / Grafana
-- SSIS Packages      → Airflow / custom scripts
-- Temporal Tables    → Trigger-based audit
-- CROSS APPLY        → LATERAL JOIN
-- MERGE              → INSERT ON CONFLICT
-- Service Broker     → LISTEN/NOTIFY

-- ============================================================
-- 10. CROSS APPLY → LATERAL JOIN EXAMPLE
-- ============================================================

-- SQL Server:
-- SELECT e.name, t.total
-- FROM Employees e
-- CROSS APPLY (
--   SELECT SUM(amount) AS total
--   FROM Orders o WHERE o.emp_id = e.emp_id
-- ) t;

-- PostgreSQL:
SELECT e.name, t.total
FROM employees e
CROSS JOIN LATERAL (
  SELECT SUM(amount) AS total
  FROM orders o WHERE o.emp_id = e.emp_id
) t;

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

-- Check constraints:
SELECT conname, contype, conrelid::regclass
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace;

-- Rebuild statistics:
-- vacuumdb -U postgres -d app_db --analyze-in-stages

-- ============================================================
-- 12. CASE SENSITIVITY HANDLING
-- ============================================================

-- SQL Server default: case-insensitive (CI collation)
-- PostgreSQL: case-sensitive always

-- Option 1: Use ILIKE for case-insensitive search
SELECT * FROM employees WHERE name ILIKE 'john%';

-- Option 2: Use citext extension
CREATE EXTENSION IF NOT EXISTS citext;
-- ALTER TABLE employees ALTER COLUMN name TYPE citext;
-- Now: SELECT * FROM employees WHERE name = 'john'; finds 'John'

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install FreeTDS + pgLoader. Run migration from SQL Server
--    to PG 16 using a command file. Compare row counts.

-- 2. Convert a T-SQL stored procedure (with @vars, ISNULL,
--    GETDATE) to PL/pgSQL. Test both produce same results.

-- 3. Export a large table with BCP to CSV. Import into PG
--    with COPY. Compare row counts and spot-check data.

-- 4. Convert a CROSS APPLY query to LATERAL JOIN.
--    Run both and verify identical results.

-- 5. Map dbo schema to public. Verify application queries
--    work without schema prefix in PostgreSQL.
