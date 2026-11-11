-- =============================================
-- PostgreSQL Mastery: SQL Functions & Introduction to PL/pgSQL
-- Phase 14: PL/pgSQL Programming | Classes 110-111
-- =============================================
-- CREATE FUNCTION (SQL and PL/pgSQL), variables,
-- SELECT INTO, RAISE, volatility, SECURITY DEFINER.
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
(3, 'Carol',  300.00);

CREATE TABLE IF NOT EXISTS products (
    id      INT PRIMARY KEY,
    name    VARCHAR(100),
    price   NUMERIC(10,2)
);

DELETE FROM products;
INSERT INTO products VALUES
(1, 'Widget', 29.99),
(2, 'Gadget', 49.99),
(3, 'Doohickey', 9.99);

-- === SQL FUNCTIONS (LANGUAGE sql) ===

-- Simple SQL function: add tax
CREATE OR REPLACE FUNCTION add_tax(price NUMERIC)
RETURNS NUMERIC AS $$
    SELECT ROUND(price * 1.18, 2);
$$ LANGUAGE sql IMMUTABLE;

SELECT add_tax(100);
-- 118.00

SELECT add_tax(29.99);
-- 35.39

-- Use with table data
SELECT name, price, add_tax(price) AS with_tax
FROM products;

-- === MULTIPLE PARAMETERS WITH DEFAULTS ===

CREATE OR REPLACE FUNCTION add_tax_rate(
    price NUMERIC,
    rate  NUMERIC DEFAULT 0.18
)
RETURNS NUMERIC AS $$
    SELECT ROUND(price * (1 + rate), 2);
$$ LANGUAGE sql IMMUTABLE;

SELECT add_tax_rate(100);        -- 118.00 (default 18%)
SELECT add_tax_rate(100, 0.05);  -- 105.00 (custom 5%)
SELECT add_tax_rate(100, 0.28);  -- 128.00 (custom 28%)

-- === RETURNS TABLE (Set-Returning SQL Function) ===

CREATE OR REPLACE FUNCTION get_rich_accounts(min_bal NUMERIC)
RETURNS TABLE(acct_id INT, acct_name VARCHAR, balance NUMERIC) AS $$
    SELECT id, name, bal
    FROM accounts
    WHERE bal >= min_bal
    ORDER BY bal DESC;
$$ LANGUAGE sql STABLE;

-- Use like a table:
SELECT * FROM get_rich_accounts(500);
SELECT * FROM get_rich_accounts(100);

-- === RETURNS SETOF (alternative syntax) ===

CREATE OR REPLACE FUNCTION all_accounts()
RETURNS SETOF accounts AS $$
    SELECT * FROM accounts ORDER BY id;
$$ LANGUAGE sql STABLE;

SELECT * FROM all_accounts();

-- === PL/pgSQL BASICS ===

-- Block structure: DECLARE → BEGIN → END
CREATE OR REPLACE FUNCTION greet(person_name VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    greeting VARCHAR;
BEGIN
    greeting := 'Hello, ' || person_name || '! Welcome to PostgreSQL.';
    RETURN greeting;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT greet('Alice');
-- Hello, Alice! Welcome to PostgreSQL.

-- === VARIABLES & ASSIGNMENT ===

CREATE OR REPLACE FUNCTION demo_variables()
RETURNS TEXT AS $$
DECLARE
    counter    INTEGER := 0;
    user_name  VARCHAR(100);
    is_active  BOOLEAN := TRUE;
    created    TIMESTAMP := NOW();
    tax_rate   CONSTANT NUMERIC := 0.18;
BEGIN
    counter := counter + 1;
    user_name := 'Test User';

    RETURN format('counter=%s, name=%s, active=%s, tax=%s',
                  counter, user_name, is_active, tax_rate);
END;
$$ LANGUAGE plpgsql;

SELECT demo_variables();

-- === %TYPE and %ROWTYPE ===

CREATE OR REPLACE FUNCTION get_account_info(acct_id INT)
RETURNS TEXT AS $$
DECLARE
    acct_name  accounts.name%TYPE;   -- matches column type
    acct_bal   accounts.bal%TYPE;    -- matches column type
    acct_row   accounts%ROWTYPE;     -- matches entire row
BEGIN
    -- SELECT INTO individual variables
    SELECT name, bal INTO acct_name, acct_bal
    FROM accounts WHERE id = acct_id;

    -- Or SELECT INTO a row variable
    SELECT * INTO acct_row
    FROM accounts WHERE id = acct_id;

    -- Access row fields with dot notation
    RETURN format('Name: %s, Balance: %s (row.bal: %s)',
                  acct_name, acct_bal, acct_row.bal);
END;
$$ LANGUAGE plpgsql STABLE;

SELECT get_account_info(1);
SELECT get_account_info(2);

-- === FOUND Variable ===

-- After SELECT INTO, the FOUND variable tells you if a row was returned

CREATE OR REPLACE FUNCTION safe_get_balance(acct_id INT)
RETURNS NUMERIC AS $$
DECLARE
    result NUMERIC;
BEGIN
    SELECT bal INTO result
    FROM accounts WHERE id = acct_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % does not exist', acct_id;
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

SELECT safe_get_balance(1);   -- 1000.00
SELECT safe_get_balance(999); -- ERROR: Account 999 does not exist

-- === WITHDRAW FUNCTION (Full Example) ===

CREATE OR REPLACE FUNCTION withdraw(acct_id INT, amount NUMERIC)
RETURNS NUMERIC AS $$
DECLARE
    current_bal NUMERIC;
BEGIN
    -- Get current balance
    SELECT bal INTO current_bal
    FROM accounts WHERE id = acct_id;

    -- Check account exists
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % does not exist', acct_id;
    END IF;

    -- Check sufficient funds
    IF current_bal < amount THEN
        RAISE EXCEPTION 'Insufficient funds: have %, need %',
            current_bal, amount;
    END IF;

    -- Perform withdrawal
    UPDATE accounts SET bal = bal - amount WHERE id = acct_id;

    RETURN current_bal - amount;
END;
$$ LANGUAGE plpgsql;

-- Test it:
SELECT withdraw(1, 200);   -- 800.00
SELECT * FROM accounts WHERE id = 1;

-- SELECT withdraw(1, 5000);  -- ERROR: Insufficient funds
-- SELECT withdraw(999, 50);  -- ERROR: Account 999 does not exist

-- Reset Alice's balance
UPDATE accounts SET bal = 1000 WHERE id = 1;

-- === MANAGING FUNCTIONS ===

-- List functions
-- \df                      -- all functions
-- \df public.*             -- functions in public schema
-- \df+ withdraw            -- full details with source

-- From SQL:
SELECT routine_name, routine_type, data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_name;

-- Drop a function
DROP FUNCTION IF EXISTS greet(VARCHAR);

-- Drop with cascade (if other objects depend on it)
-- DROP FUNCTION add_tax(NUMERIC) CASCADE;

-- === VOLATILITY CATEGORIES ===

-- IMMUTABLE: always same result for same inputs
-- Good for: math, string manipulation, type conversion
-- PG can cache/fold results at plan time
CREATE OR REPLACE FUNCTION double_it(n INT)
RETURNS INT AS $$
    SELECT n * 2;
$$ LANGUAGE sql IMMUTABLE;

-- STABLE: same result within one query execution
-- Good for: table lookups, config reads
-- PG can cache within a single query
CREATE OR REPLACE FUNCTION get_tax_rate()
RETURNS NUMERIC AS $$
    SELECT 0.18;  -- would normally read from config table
$$ LANGUAGE sql STABLE;

-- VOLATILE (default): may return different results each call
-- Good for: NOW(), RANDOM(), INSERT/UPDATE/DELETE
-- PG cannot cache at all
-- (functions with side effects MUST be VOLATILE)

-- === SECURITY DEFINER ===

-- Normal function: runs with caller's permissions (INVOKER)
-- SECURITY DEFINER: runs with owner's permissions

-- Example: let users check their own salary only
-- CREATE FUNCTION my_salary()
-- RETURNS NUMERIC AS $$
-- BEGIN
--     RETURN (SELECT salary FROM employees
--             WHERE username = current_user);
-- END;
-- $$ LANGUAGE plpgsql SECURITY DEFINER
--    SET search_path = public;
--
-- GRANT EXECUTE ON FUNCTION my_salary() TO all_employees;
-- REVOKE ALL ON TABLE employees FROM all_employees;

-- IMPORTANT: Always SET search_path with SECURITY DEFINER
-- to prevent schema injection attacks!

-- === DOLLAR QUOTING (named tags) ===

-- You can use named dollar-quote tags to nest functions:
-- $function$ ... $function$
-- $body$ ... $body$
-- $outer$ ... $inner$ ... $inner$ ... $outer$

CREATE OR REPLACE FUNCTION named_quote_demo()
RETURNS TEXT AS $function$
BEGIN
    RETURN 'This uses $function$ tags instead of $$';
END;
$function$ LANGUAGE plpgsql;

SELECT named_quote_demo();

-- === PRACTICE EXERCISES ===

-- Exercise 1: SQL function for discount
CREATE OR REPLACE FUNCTION calc_discount(price NUMERIC, pct NUMERIC)
RETURNS NUMERIC AS $$
    SELECT ROUND(price * (1 - pct / 100), 2);
$$ LANGUAGE sql IMMUTABLE;

SELECT calc_discount(100, 20);  -- 80.00
SELECT calc_discount(49.99, 10); -- 44.99

-- Exercise 2: PL/pgSQL function with SELECT INTO
-- Write a function that returns an account's name given its ID

-- Exercise 3: Use %TYPE
-- Declare variables matching accounts.name and accounts.bal

-- Exercise 4: RETURNS TABLE
-- Create find_accounts(pattern VARCHAR) that returns
-- accounts where name ILIKE the pattern

-- Exercise 5: FOUND check
-- Modify your function to RAISE EXCEPTION if no account found

-- Exercise 6: List your functions
-- \df
-- \df+ add_tax

-- Exercise 7: Create OR Replace
-- Update add_tax to use 20% instead of 18%

-- === CLEANUP ===
DROP FUNCTION IF EXISTS demo_variables();
DROP FUNCTION IF EXISTS named_quote_demo();
DROP FUNCTION IF EXISTS double_it(INT);
DROP FUNCTION IF EXISTS get_tax_rate();
DROP FUNCTION IF EXISTS all_accounts();
-- Keep: add_tax, get_rich_accounts, withdraw, get_account_info,
--        safe_get_balance, calc_discount (used in later classes)

-- =============================================
-- Next Class: PL/pgSQL Control Flow & RAISE
-- =============================================
