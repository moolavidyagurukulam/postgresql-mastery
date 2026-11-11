-- =============================================
-- PostgreSQL Mastery: PL/pgSQL Error Handling
-- Phase 14: PL/pgSQL Programming | Classes 120-121
-- =============================================
-- EXCEPTION blocks, SQLSTATE codes, GET STACKED
-- DIAGNOSTICS, error logging, rollback behavior.
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

-- === BASIC EXCEPTION HANDLING ===

CREATE OR REPLACE FUNCTION safe_divide(a NUMERIC, b NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
    RETURN a / b;
EXCEPTION
    WHEN division_by_zero THEN
        RAISE NOTICE 'Division by zero! Returning 0';
        RETURN 0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT safe_divide(100, 4);  -- 25
SELECT safe_divide(100, 0);  -- 0 (with NOTICE)

-- === CATCHING SPECIFIC CONDITIONS ===

CREATE OR REPLACE FUNCTION safe_insert(
    acct_id INT, acct_name VARCHAR, balance NUMERIC
) RETURNS TEXT AS $$
BEGIN
    INSERT INTO accounts VALUES (acct_id, acct_name, balance);
    RETURN 'Inserted ' || acct_name;
EXCEPTION
    WHEN unique_violation THEN
        RETURN 'Account ' || acct_id || ' already exists';
    WHEN not_null_violation THEN
        RETURN 'Name and balance are required';
    WHEN check_violation THEN
        RETURN 'Check constraint failed';
    WHEN OTHERS THEN
        RETURN 'Error [' || SQLSTATE || ']: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Test:
SELECT safe_insert(10, 'Frank', 600);     -- Inserted Frank
SELECT safe_insert(10, 'Frank', 600);     -- Account 10 already exists
SELECT safe_insert(1, 'Duplicate', 100);  -- Account 1 already exists

-- Clean up
DELETE FROM accounts WHERE id = 10;

-- === CATCHING BY SQLSTATE CODE ===

-- You can use SQLSTATE code directly:
CREATE OR REPLACE FUNCTION catch_by_code_demo()
RETURNS TEXT AS $$
BEGIN
    INSERT INTO accounts VALUES (1, 'Duplicate', 0);
    RETURN 'OK';
EXCEPTION
    WHEN SQLSTATE '23505' THEN  -- unique_violation
        RETURN 'Duplicate key (caught by SQLSTATE code)';
END;
$$ LANGUAGE plpgsql;

SELECT catch_by_code_demo();

-- === SQLERRM and SQLSTATE ===

-- Available inside any EXCEPTION handler:
-- SQLERRM:  the error message text
-- SQLSTATE: the 5-character error code

CREATE OR REPLACE FUNCTION error_info_demo()
RETURNS TEXT AS $$
BEGIN
    -- Force a unique violation
    INSERT INTO accounts VALUES (1, 'X', 0);
    RETURN 'OK';
EXCEPTION WHEN OTHERS THEN
    RETURN format('SQLSTATE=%s  SQLERRM=%s', SQLSTATE, SQLERRM);
END;
$$ LANGUAGE plpgsql;

SELECT error_info_demo();
-- SQLSTATE=23505  SQLERRM=duplicate key value violates ...

-- === GET STACKED DIAGNOSTICS ===

CREATE OR REPLACE FUNCTION detailed_error_demo()
RETURNS TEXT AS $$
DECLARE
    v_state   TEXT;
    v_msg     TEXT;
    v_detail  TEXT;
    v_hint    TEXT;
    v_context TEXT;
BEGIN
    INSERT INTO accounts VALUES (1, 'Duplicate', 0);
    RETURN 'OK';
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
        v_state   = RETURNED_SQLSTATE,
        v_msg     = MESSAGE_TEXT,
        v_detail  = PG_EXCEPTION_DETAIL,
        v_hint    = PG_EXCEPTION_HINT,
        v_context = PG_EXCEPTION_CONTEXT;

    RETURN format(E'State: %s\nMsg: %s\nDetail: %s\nHint: %s\nContext: %s',
                  v_state, v_msg, v_detail, v_hint, v_context);
END;
$$ LANGUAGE plpgsql;

SELECT detailed_error_demo();

-- Available diagnostics items:
-- RETURNED_SQLSTATE:    5-char error code
-- MESSAGE_TEXT:         error message
-- PG_EXCEPTION_DETAIL: additional detail
-- PG_EXCEPTION_HINT:   hint for fixing
-- PG_EXCEPTION_CONTEXT: call stack
-- COLUMN_NAME:          column that caused the error
-- CONSTRAINT_NAME:      constraint that was violated
-- TABLE_NAME:           table involved
-- SCHEMA_NAME:          schema involved

-- === ERROR LOGGING ===

CREATE TABLE IF NOT EXISTS error_log (
    id       SERIAL PRIMARY KEY,
    func     TEXT,
    sqlstate TEXT,
    message  TEXT,
    detail   TEXT,
    context  TEXT,
    logged   TIMESTAMP DEFAULT NOW()
);

-- Function that logs errors to a table, then re-raises
CREATE OR REPLACE FUNCTION log_and_raise(
    func_name TEXT,
    v_state TEXT,
    v_msg TEXT,
    v_detail TEXT,
    v_context TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO error_log(func, sqlstate, message, detail, context)
    VALUES (func_name, v_state, v_msg, v_detail, v_context);
END;
$$ LANGUAGE plpgsql;

-- Example: withdrawal with error logging
CREATE OR REPLACE FUNCTION logged_withdraw(acct INT, amt NUMERIC)
RETURNS NUMERIC AS $$
DECLARE
    current_bal NUMERIC;
    v_state TEXT; v_msg TEXT; v_detail TEXT; v_context TEXT;
BEGIN
    SELECT bal INTO current_bal FROM accounts WHERE id = acct;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % not found', acct;
    END IF;

    IF current_bal < amt THEN
        RAISE EXCEPTION 'Insufficient funds: % < %', current_bal, amt;
    END IF;

    UPDATE accounts SET bal = bal - amt WHERE id = acct;
    RETURN current_bal - amt;

EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
        v_state = RETURNED_SQLSTATE,
        v_msg = MESSAGE_TEXT,
        v_detail = PG_EXCEPTION_DETAIL,
        v_context = PG_EXCEPTION_CONTEXT;

    -- Log the error
    PERFORM log_and_raise('logged_withdraw', v_state, v_msg, v_detail, v_context);

    -- Re-raise the original error
    RAISE;
END;
$$ LANGUAGE plpgsql;

-- Test:
-- SELECT logged_withdraw(999, 100);  -- logs + re-raises
-- SELECT * FROM error_log;

-- === ROLLBACK BEHAVIOR ===

-- Changes inside a BEGIN/EXCEPTION block are ROLLED BACK
-- when an exception is caught. This uses implicit savepoints.

CREATE OR REPLACE FUNCTION rollback_demo()
RETURNS TEXT AS $$
BEGIN
    -- This INSERT will be rolled back when exception is caught
    INSERT INTO accounts VALUES (99, 'Temp', 999);
    RAISE NOTICE 'Inserted account 99';

    -- This will fail (duplicate key)
    INSERT INTO accounts VALUES (1, 'Duplicate', 0);

    RETURN 'Should not reach here';
EXCEPTION WHEN unique_violation THEN
    -- At this point, account 99 INSERT is ROLLED BACK!
    RETURN 'Caught duplicate. Account 99 was NOT inserted.';
END;
$$ LANGUAGE plpgsql;

SELECT rollback_demo();
-- Returns: Caught duplicate. Account 99 was NOT inserted.

SELECT * FROM accounts WHERE id = 99;
-- No rows! The INSERT was rolled back.

-- === NESTED EXCEPTION BLOCKS ===

-- Inner block catches its own errors; outer block continues
CREATE OR REPLACE FUNCTION nested_exception_demo()
RETURNS TEXT AS $$
DECLARE
    result TEXT := '';
BEGIN
    -- Block 1: may fail, but we handle it
    BEGIN
        INSERT INTO accounts VALUES (1, 'Dup', 0);
        result := result || 'Block 1: OK. ';
    EXCEPTION WHEN unique_violation THEN
        result := result || 'Block 1: Caught duplicate. ';
    END;

    -- Block 2: continues even if Block 1 failed
    BEGIN
        INSERT INTO accounts VALUES (20, 'New', 100);
        result := result || 'Block 2: Inserted 20. ';
    EXCEPTION WHEN unique_violation THEN
        result := result || 'Block 2: Caught duplicate. ';
    END;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

SELECT nested_exception_demo();
-- Block 1: Caught duplicate. Block 2: Inserted 20.

SELECT * FROM accounts WHERE id = 20;
-- id=20 exists!

DELETE FROM accounts WHERE id = 20;

-- === COMMON CONDITION NAMES ===

-- Class 23: Integrity Constraint Violation
-- 23000  integrity_constraint_violation
-- 23502  not_null_violation
-- 23503  foreign_key_violation
-- 23505  unique_violation
-- 23514  check_violation

-- Class 22: Data Exception
-- 22012  division_by_zero
-- 22003  numeric_value_out_of_range
-- 22007  invalid_datetime_format
-- 22P02  invalid_text_representation

-- Class P0: PL/pgSQL Error
-- P0001  raise_exception (your RAISE EXCEPTION)
-- P0002  no_data_found (SELECT INTO STRICT, no rows)
-- P0003  too_many_rows (SELECT INTO STRICT, multiple rows)

-- Class 40: Transaction Rollback
-- 40001  serialization_failure
-- 40P01  deadlock_detected

-- === STRICT SELECT INTO ===

-- SELECT INTO normally sets FOUND=false if no rows
-- With STRICT, it raises an exception instead

CREATE OR REPLACE FUNCTION strict_lookup(acct_id INT)
RETURNS accounts.name%TYPE AS $$
DECLARE
    result accounts.name%TYPE;
BEGIN
    SELECT name INTO STRICT result
    FROM accounts WHERE id = acct_id;
    RETURN result;
EXCEPTION
    WHEN no_data_found THEN
        RETURN 'Account ' || acct_id || ' not found';
    WHEN too_many_rows THEN
        RETURN 'Multiple accounts match!';
END;
$$ LANGUAGE plpgsql STABLE;

SELECT strict_lookup(1);    -- Alice
SELECT strict_lookup(999);  -- Account 999 not found

-- === PRACTICE EXERCISES ===

-- Exercise 1: safe_insert with multiple error types
-- Catch unique_violation, not_null_violation

-- Exercise 2: GET STACKED DIAGNOSTICS
-- Capture and display all error fields

-- Exercise 3: Error logging
-- Create error_log table and a logging function

-- Exercise 4: RAISE (bare) to re-raise after logging

-- Exercise 5: Rollback demo
-- Insert a row, then cause an error, verify INSERT was undone

-- Exercise 6: Nested BEGIN blocks
-- Inner handles error, outer continues processing

-- Exercise 7: STRICT SELECT INTO
-- Use STRICT and handle no_data_found / too_many_rows

-- === CLEANUP ===
DROP FUNCTION IF EXISTS safe_divide(NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS catch_by_code_demo();
DROP FUNCTION IF EXISTS error_info_demo();
DROP FUNCTION IF EXISTS detailed_error_demo();
DROP FUNCTION IF EXISTS rollback_demo();
DROP FUNCTION IF EXISTS nested_exception_demo();
DROP FUNCTION IF EXISTS strict_lookup(INT);
DROP TABLE IF EXISTS error_log;
-- Keep: safe_insert, logged_withdraw, log_and_raise

-- =============================================
-- Next Class: Practical PL/pgSQL Projects
-- =============================================
