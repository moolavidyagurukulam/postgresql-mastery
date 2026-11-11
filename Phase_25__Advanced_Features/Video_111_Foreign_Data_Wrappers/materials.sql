-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Foreign Data Wrappers — Query External Data (Class 217)
-- Phase 25: Advanced Features
-- ============================================================

-- ============================================================
-- 1. file_fdw — SETUP
-- ============================================================

-- Enable the extension:
CREATE EXTENSION file_fdw;

-- Create a foreign server:
CREATE SERVER csv_files
    FOREIGN DATA WRAPPER file_fdw;

-- ============================================================
-- 2. file_fdw — CREATE FOREIGN TABLE
-- ============================================================

-- Sample CSV file: /tmp/countries.csv
-- code,name,population,continent
-- US,United States,331000000,North America
-- IN,India,1380000000,Asia
-- BR,Brazil,212000000,South America
-- DE,Germany,83000000,Europe

CREATE FOREIGN TABLE countries_csv (
    code text,
    name text,
    population bigint,
    continent text
)
SERVER csv_files
OPTIONS (
    filename '/tmp/countries.csv',
    format 'csv',
    header 'true'
);

-- Query it:
SELECT name, population FROM countries_csv
WHERE continent = 'Asia';

-- ============================================================
-- 3. JOIN FOREIGN TABLE WITH LOCAL TABLE
-- ============================================================

CREATE TABLE offices (
    id serial PRIMARY KEY,
    city text NOT NULL,
    country_code text NOT NULL
);
INSERT INTO offices (city, country_code) VALUES
('New York', 'US'), ('Mumbai', 'IN'), ('Berlin', 'DE');

SELECT o.city, c.name AS country, c.continent
FROM offices o
JOIN countries_csv c ON c.code = o.country_code;

-- ============================================================
-- 4. file_fdw WITH PROGRAM OPTION
-- ============================================================

-- Read from gzipped CSV (requires superuser):
CREATE FOREIGN TABLE logs_gz (
    timestamp text,
    level text,
    message text
)
SERVER csv_files
OPTIONS (
    program 'gunzip -c /var/log/app/app.csv.gz',
    format 'csv',
    header 'true'
);

-- ============================================================
-- 5. IMPORT FOREIGN SCHEMA
-- ============================================================

-- Import all tables from a remote schema:
-- IMPORT FOREIGN SCHEMA public
--     FROM SERVER remote_pg INTO local_schema;

-- Import only specific tables:
-- IMPORT FOREIGN SCHEMA public
--     LIMIT TO (users, orders)
--     FROM SERVER remote_pg INTO local_schema;

-- Exclude specific tables:
-- IMPORT FOREIGN SCHEMA public
--     EXCEPT (temp_data, logs)
--     FROM SERVER remote_pg INTO local_schema;

-- ============================================================
-- 6. CHECKING PUSHDOWN
-- ============================================================

-- See what gets pushed to the remote server:
-- EXPLAIN VERBOSE
-- SELECT name, email FROM remote_users
-- WHERE active = true ORDER BY name LIMIT 10;
-- Look for "Remote SQL:" in the output

-- ============================================================
-- 7. LISTING FDW OBJECTS
-- ============================================================

-- List foreign servers:
SELECT srvname, fdwname FROM pg_foreign_server
JOIN pg_foreign_data_wrapper
  ON pg_foreign_server.srvfdw = pg_foreign_data_wrapper.oid;

-- List foreign tables:
-- \dE+

-- List user mappings:
SELECT * FROM pg_user_mappings;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a CSV file with sample data (countries, products, etc.)
--    Set up file_fdw and create a foreign table for it.
--    Query it with SELECT, WHERE, and ORDER BY.

-- 2. Create a local table and JOIN it with the foreign CSV table.

-- 3. Try aggregation on the foreign table:
--    SELECT continent, sum(population) FROM countries_csv
--    GROUP BY continent;

-- 4. Explore pg_foreign_server and pg_user_mappings
--    system catalogs to see your FDW configuration.

-- 5. (Bonus) If you have two PostgreSQL instances,
--    set up postgres_fdw (covered in next class).

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP FOREIGN TABLE IF EXISTS countries_csv;
-- DROP FOREIGN TABLE IF EXISTS logs_gz;
-- DROP TABLE IF EXISTS offices;
-- DROP SERVER IF EXISTS csv_files;
-- DROP EXTENSION IF EXISTS file_fdw;
