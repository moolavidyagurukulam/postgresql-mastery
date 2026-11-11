-- =============================================
-- PostgreSQL Mastery: Cursors & Dynamic SQL
-- Phase 14: PL/pgSQL Programming | Classes 118-119
-- =============================================
-- DECLARE CURSOR, OPEN, FETCH, CLOSE, parameterized
-- cursors, EXECUTE, format(%I, %L), USING, dynamic search.
-- =============================================

-- === SETUP ===

CREATE TABLE IF NOT EXISTS accounts (
    id   INT PRIMARY KEY,
    name VARCHAR(50),
    bal  NUMERIC(10,2)
);

DELETE FROM accounts;
INSERT INTO accounts VALUES
(1, 'Alice', 1000.00),
(2, 'Bob',    500.00),
(3, 'Carol',  300.00),
(4, 'Dave',   750.00),
(5, 'Eve',   2000.00);

-- === BOUND CURSOR (query defined at declaration) ===

CREATE OR REPLACE FUNCTION cursor_demo()
RETURNS TEXT AS $$
DECLARE
    cur CURSOR FOR SELECT name, bal FROM accounts ORDER BY bal DESC;
    rec RECORD;
    result TEXT := '';
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        result := result || rec.name || ': $' || rec.bal || E'\n';
    END LOOP;
    CLOSE cur;
    RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

SELECT cursor_demo();

-- === PARAMETERIZED CURSOR ===

CREATE OR REPLACE FUNCTION accounts_above(min_bal NUMERIC)
RETURNS TEXT AS $$
DECLARE
    cur CURSOR(threshold NUMERIC) FOR
        SELECT name, bal FROM accounts WHERE bal >= threshold ORDER BY bal DESC;
    rec RECORD;
    result TEXT := '';
BEGIN
    FOR rec IN cur(min_bal) LOOP
        result := result || rec.name || ' ($' || rec.bal || ') ';
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

SELECT accounts_above(500);
-- Eve ($2000.00) Alice ($1000.00) Dave ($750.00) Bob ($500.00)

-- === UNBOUND CURSOR (query assigned at OPEN) ===

CREATE OR REPLACE FUNCTION unbound_cursor_demo()
RETURNS TEXT AS $$
DECLARE
    cur REFCURSOR;
    rec RECORD;
    result TEXT := '';
BEGIN
    OPEN cur FOR SELECT name, bal FROM accounts WHERE bal > 500;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        result := result || rec.name || ' ';
    END LOOP;
    CLOSE cur;
    RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

SELECT unbound_cursor_demo();

-- === CURSOR FOR LOOP (Shorthand) ===

-- The FOR loop auto-opens, fetches, and closes the cursor
CREATE OR REPLACE FUNCTION cursor_for_demo()
RETURNS TEXT AS $$
DECLARE
    cur CURSOR FOR SELECT name, bal FROM accounts ORDER BY id;
    rec RECORD;
    result TEXT := '';
BEGIN
    FOR rec IN cur LOOP
        result := result || rec.name || ' ';
    END LOOP;
    -- No need to OPEN or CLOSE — FOR handles it
    RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

SELECT cursor_for_demo();

-- === FETCH directions (less commonly used) ===
-- FETCH NEXT FROM cur INTO rec;     -- next row (default)
-- FETCH PRIOR FROM cur INTO rec;    -- previous row
-- FETCH FIRST FROM cur INTO rec;    -- first row
-- FETCH LAST FROM cur INTO rec;     -- last row
-- FETCH ABSOLUTE 5 FROM cur INTO rec;  -- 5th row
-- FETCH RELATIVE 2 FROM cur INTO rec;  -- skip 2 forward
-- (Requires: DECLARE cur SCROLL CURSOR FOR ...)

-- === DYNAMIC SQL: EXECUTE ===

-- EXECUTE runs a string as SQL at runtime
CREATE OR REPLACE FUNCTION count_rows(tbl_name TEXT)
RETURNS BIGINT AS $$
DECLARE
    result BIGINT;
BEGIN
    -- %I = identifier (safely quoted table/column name)
    EXECUTE format('SELECT COUNT(*) FROM %I', tbl_name)
    INTO result;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

SELECT count_rows('accounts');   -- 5
-- SELECT count_rows('products');

-- === EXECUTE INTO ===

CREATE OR REPLACE FUNCTION get_max_value(tbl TEXT, col TEXT)
RETURNS NUMERIC AS $$
DECLARE
    result NUMERIC;
BEGIN
    EXECUTE format('SELECT MAX(%I) FROM %I', col, tbl)
    INTO result;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

SELECT get_max_value('accounts', 'bal');  -- 2000.00

-- === EXECUTE with USING ===

-- $1, $2 placeholders replaced by USING values (safe!)
CREATE OR REPLACE FUNCTION find_by_balance(
    tbl TEXT, min_bal NUMERIC
) RETURNS TABLE(acct_name VARCHAR, balance NUMERIC) AS $$
BEGIN
    RETURN QUERY EXECUTE
        format('SELECT name, bal FROM %I WHERE bal >= $1 ORDER BY bal DESC', tbl)
        USING min_bal;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM find_by_balance('accounts', 750);

-- Multiple USING parameters
CREATE OR REPLACE FUNCTION find_in_range(
    tbl TEXT, low NUMERIC, high NUMERIC
) RETURNS TABLE(acct_name VARCHAR, balance NUMERIC) AS $$
BEGIN
    RETURN QUERY EXECUTE
        format('SELECT name, bal FROM %I WHERE bal BETWEEN $1 AND $2', tbl)
        USING low, high;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM find_in_range('accounts', 300, 800);

-- === format() PLACEHOLDERS ===

-- %I = identifier (table/column name) → adds quotes if needed
-- %L = literal (string/number value) → adds quotes + escaping
-- %s = simple string substitution → NO escaping (UNSAFE for user input!)

-- Examples:
-- format('%I', 'my table')  → "my table"  (quoted because space)
-- format('%I', 'accounts')  → accounts    (no quoting needed)
-- format('%L', 'O''Brien')  → 'O''Brien'  (escaped single quote)
-- format('%L', 42)          → '42'
-- format('%s', 'hello')     → hello       (no escaping!)

-- === DYNAMIC SEARCH BUILDER ===

CREATE OR REPLACE FUNCTION search_accounts(
    p_name    TEXT DEFAULT NULL,
    p_min_bal NUMERIC DEFAULT NULL,
    p_max_bal NUMERIC DEFAULT NULL
) RETURNS TABLE(id INT, name VARCHAR, bal NUMERIC) AS $$
DECLARE
    sql TEXT := 'SELECT id, name, bal FROM accounts WHERE 1=1';
BEGIN
    IF p_name IS NOT NULL THEN
        sql := sql || format(' AND name ILIKE %L', '%' || p_name || '%');
    END IF;
    IF p_min_bal IS NOT NULL THEN
        sql := sql || format(' AND bal >= %L', p_min_bal);
    END IF;
    IF p_max_bal IS NOT NULL THEN
        sql := sql || format(' AND bal <= %L', p_max_bal);
    END IF;
    sql := sql || ' ORDER BY bal DESC';

    RAISE NOTICE 'Executing: %', sql;
    RETURN QUERY EXECUTE sql;
END;
$$ LANGUAGE plpgsql;

-- Test various combinations:
SELECT * FROM search_accounts(p_name := 'a');
-- Alice, Carol, Dave (names containing 'a')

SELECT * FROM search_accounts(p_min_bal := 500, p_max_bal := 1000);
-- Alice (1000), Dave (750), Bob (500)

SELECT * FROM search_accounts(p_name := 'e', p_min_bal := 1000);
-- Eve (2000)

-- === DYNAMIC DDL ===

CREATE OR REPLACE FUNCTION create_archive_table(src_table TEXT)
RETURNS VOID AS $$
BEGIN
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I (LIKE %I INCLUDING ALL)',
        src_table || '_archive',
        src_table
    );
    RAISE NOTICE 'Created table %_archive', src_table;
END;
$$ LANGUAGE plpgsql;

-- SELECT create_archive_table('accounts');
-- Creates: accounts_archive with same structure

-- === SQL INJECTION PREVENTION ===

-- DANGEROUS (never do this!):
-- EXECUTE 'SELECT * FROM ' || user_input;
-- If user_input = 'accounts; DROP TABLE accounts; --'
-- It would run: SELECT * FROM accounts; DROP TABLE accounts; --

-- SAFE (always do this):
-- EXECUTE format('SELECT * FROM %I', user_input);
-- format(%I) quotes the identifier: "accounts; DROP TABLE accounts; --"
-- PostgreSQL treats the whole thing as a table name (which doesn't exist)

-- === PRACTICE EXERCISES ===

-- Exercise 1: Basic cursor
-- Write a function using OPEN/FETCH/CLOSE

-- Exercise 2: Parameterized cursor
-- Cursor that takes (min_bal, max_bal) and returns matches

-- Exercise 3: count_rows for any table
SELECT count_rows('accounts');

-- Exercise 4: Dynamic search
SELECT * FROM search_accounts(p_name := 'bob');

-- Exercise 5: EXECUTE with USING
-- Write a function: get_nth_account(tbl TEXT, n INT)
-- that returns the nth account by balance

-- Exercise 6: SQL injection test
-- SELECT count_rows('accounts; DROP TABLE accounts; --');
-- With format(%I): safely returns an error (table not found)
-- Without format(%I): would be catastrophic!

-- Exercise 7: Dynamic INSERT
-- Write insert_into(tbl TEXT, name TEXT, bal NUMERIC)
-- using EXECUTE with USING

-- === CLEANUP ===
DROP FUNCTION IF EXISTS cursor_demo();
DROP FUNCTION IF EXISTS unbound_cursor_demo();
DROP FUNCTION IF EXISTS cursor_for_demo();
DROP FUNCTION IF EXISTS get_max_value(TEXT, TEXT);
DROP FUNCTION IF EXISTS find_in_range(TEXT, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS create_archive_table(TEXT);
-- Keep: accounts_above, count_rows, find_by_balance, search_accounts

-- =============================================
-- Next Class: PL/pgSQL Error Handling
-- =============================================
