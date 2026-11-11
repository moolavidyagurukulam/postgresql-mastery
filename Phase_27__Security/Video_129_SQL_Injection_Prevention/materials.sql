-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- SQL Injection Prevention (Classes 238-239)
-- Phase 27: Security
-- ============================================================

-- ============================================================
-- SETUP: Create a test database and tables
-- ============================================================

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    name TEXT,
    email TEXT,
    password_hash TEXT,
    role TEXT DEFAULT 'user'
);

INSERT INTO users (username, name, email, password_hash, role) VALUES
('alice', 'Alice Johnson', 'alice@example.com', 'scram_hash_here', 'user'),
('bob', 'Bob Smith', 'bob@example.com', 'scram_hash_here', 'user'),
('admin', 'Admin User', 'admin@example.com', 'scram_hash_here', 'admin');

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT,
    price NUMERIC(10,2),
    status TEXT DEFAULT 'active'
);

INSERT INTO products (name, price) VALUES
('Widget', 29.99), ('Gadget', 49.99), ('Thingamajig', 9.99);

-- ============================================================
-- 1. VULNERABLE FUNCTION (DO NOT USE IN PRODUCTION)
-- ============================================================

-- This function is INTENTIONALLY vulnerable for demonstration:
CREATE OR REPLACE FUNCTION vulnerable_search(search TEXT)
RETURNS TABLE(id INT, username TEXT, name TEXT, email TEXT) AS $$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT id, username, name, email FROM users WHERE name = ''' || search || '''';
END;
$$ LANGUAGE plpgsql;

-- Normal use:
SELECT * FROM vulnerable_search('Alice Johnson');

-- Injection: return ALL users
SELECT * FROM vulnerable_search(''' OR 1=1 --');

-- Injection: UNION to read other data
-- SELECT * FROM vulnerable_search(''' UNION SELECT 1, rolname, rolpassword, '''' FROM pg_authid --');

-- ============================================================
-- 2. SAFE FUNCTION — format() with %L
-- ============================================================

CREATE OR REPLACE FUNCTION safe_search_format(search TEXT)
RETURNS TABLE(id INT, username TEXT, name TEXT, email TEXT) AS $$
BEGIN
    RETURN QUERY EXECUTE
        format('SELECT id, username, name, email FROM users WHERE name = %L', search);
END;
$$ LANGUAGE plpgsql;

-- Same injection attempt — fails safely:
SELECT * FROM safe_search_format(''' OR 1=1 --');
-- Returns 0 rows (no user named: ' OR 1=1 --)

-- ============================================================
-- 3. SAFE FUNCTION — EXECUTE ... USING
-- ============================================================

CREATE OR REPLACE FUNCTION safe_search_using(search TEXT)
RETURNS TABLE(id INT, username TEXT, name TEXT, email TEXT) AS $$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT id, username, name, email FROM users WHERE name = $1'
        USING search;
END;
$$ LANGUAGE plpgsql;

-- Injection attempt — fails safely:
SELECT * FROM safe_search_using(''' OR 1=1 --');

-- ============================================================
-- 4. SAFE DYNAMIC TABLE/COLUMN QUERIES
-- ============================================================

CREATE OR REPLACE FUNCTION safe_dynamic_search(
    p_table TEXT,
    p_column TEXT,
    p_value TEXT
) RETURNS SETOF RECORD AS $$
DECLARE
    allowed_tables TEXT[] := ARRAY['users', 'products'];
    allowed_columns TEXT[] := ARRAY['name', 'email', 'status', 'username'];
BEGIN
    -- Whitelist validation
    IF NOT (p_table = ANY(allowed_tables)) THEN
        RAISE EXCEPTION 'Table not allowed: %', p_table;
    END IF;
    IF NOT (p_column = ANY(allowed_columns)) THEN
        RAISE EXCEPTION 'Column not allowed: %', p_column;
    END IF;

    -- %I for identifiers (table/column names), $1 USING for values
    RETURN QUERY EXECUTE
        format('SELECT * FROM %I WHERE %I = $1', p_table, p_column)
        USING p_value;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public;

-- Safe usage:
SELECT * FROM safe_dynamic_search('users', 'name', 'Alice Johnson')
    AS t(id INT, username TEXT, name TEXT, email TEXT, password_hash TEXT, role TEXT);

-- Blocked: unauthorized table
-- SELECT * FROM safe_dynamic_search('pg_authid', 'rolname', 'postgres');
-- ERROR: Table not allowed: pg_authid

-- ============================================================
-- 5. PREPARED STATEMENTS
-- ============================================================

PREPARE user_lookup (text) AS
    SELECT id, name, email FROM users WHERE username = $1;

-- Normal use:
EXECUTE user_lookup('alice');

-- Injection attempt treated as literal data:
EXECUTE user_lookup('admin'' OR 1=1 --');
-- Returns 0 rows

-- Cleanup:
DEALLOCATE user_lookup;

-- ============================================================
-- 6. LEAST PRIVILEGE — Application Role
-- ============================================================

-- Create restricted app role:
CREATE ROLE web_app WITH LOGIN PASSWORD 'app_pass_2026';

-- Grant only what the app needs:
GRANT CONNECT ON DATABASE postgres TO web_app;
GRANT USAGE ON SCHEMA public TO web_app;
GRANT SELECT, INSERT, UPDATE ON users, products TO web_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO web_app;

-- web_app CANNOT:
-- DROP TABLE, CREATE TABLE, DELETE (unless granted)
-- Access pg_authid, COPY to files, CREATE ROLE

-- Test (connect as web_app):
-- SET ROLE web_app;
-- DROP TABLE users;  -- ERROR: permission denied
-- SELECT * FROM pg_authid;  -- ERROR: permission denied

-- ============================================================
-- 7. SECURITY DEFINER — Safe Pattern
-- ============================================================

-- DANGEROUS: SECURITY DEFINER with concatenation
-- CREATE FUNCTION bad_admin(tbl TEXT) RETURNS SETOF RECORD AS $$
-- BEGIN
--     RETURN QUERY EXECUTE 'SELECT * FROM ' || tbl;
-- END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- SAFE: SECURITY DEFINER with format + search_path
CREATE OR REPLACE FUNCTION safe_admin_lookup(tbl TEXT)
RETURNS SETOF RECORD AS $$
DECLARE
    allowed TEXT[] := ARRAY['users', 'products'];
BEGIN
    IF NOT (tbl = ANY(allowed)) THEN
        RAISE EXCEPTION 'Not allowed: %', tbl;
    END IF;
    RETURN QUERY EXECUTE format('SELECT * FROM %I', tbl);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;

-- ============================================================
-- 8. LIKE PATTERN ESCAPING
-- ============================================================

-- Unsafe LIKE (user can inject wildcards):
-- SELECT * FROM users WHERE name LIKE '%' || user_input || '%';
-- Input: %admin% → matches differently than expected

-- Safe LIKE (escape wildcards):
-- In SQL:
SELECT * FROM users
WHERE name LIKE '%' || replace(replace('test%input', '%', '\%'), '_', '\_') || '%';

-- In application code (Python psycopg2):
-- search = search.replace('%', r'\%').replace('_', r'\_')
-- cursor.execute("SELECT * FROM users WHERE name LIKE %s", ['%' + search + '%'])

-- ============================================================
-- FORMAT() REFERENCE
-- ============================================================

-- %s  : simple string substitution (no quoting — AVOID for user input)
-- %I  : identifier (quotes if needed: table names, column names)
-- %L  : literal (properly quoted and escaped: values)

-- Examples:
SELECT format('SELECT * FROM %I WHERE %I = %L', 'users', 'name', 'Alice');
-- Result: SELECT * FROM users WHERE name = 'Alice'

SELECT format('SELECT * FROM %I WHERE %I = %L', 'my table', 'col name', 'O''Brien');
-- Result: SELECT * FROM "my table" WHERE "col name" = 'O''Brien'

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Call vulnerable_search with injection payloads:
--    ' OR 1=1 --
--    ' UNION SELECT 1,'a','b','c' --
--    Then call safe_search_format with the same payloads.

-- 2. Connect as web_app role. Try to DROP TABLE, read pg_authid,
--    and COPY to a file. All should fail.

-- 3. Modify safe_dynamic_search to add 'orders' to the whitelist
--    and test it.

-- 4. Create a SECURITY DEFINER function that is safe against
--    injection and schema hijacking.

-- 5. Write a LIKE query that properly escapes % and _ from
--    user input.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP FUNCTION IF EXISTS vulnerable_search;
-- DROP FUNCTION IF EXISTS safe_search_format;
-- DROP FUNCTION IF EXISTS safe_search_using;
-- DROP FUNCTION IF EXISTS safe_dynamic_search;
-- DROP FUNCTION IF EXISTS safe_admin_lookup;
-- REVOKE ALL ON ALL TABLES IN SCHEMA public FROM web_app;
-- DROP ROLE IF EXISTS web_app;
-- DROP TABLE IF EXISTS products;
-- DROP TABLE IF EXISTS users;
