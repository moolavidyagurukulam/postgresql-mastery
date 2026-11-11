-- =============================================
-- PostgreSQL Mastery: PL/pgSQL Control Flow & RAISE
-- Phase 14: PL/pgSQL Programming | Classes 112-113
-- =============================================
-- IF/ELSIF/ELSE, CASE, RAISE levels, debugging,
-- USING HINT/ERRCODE, NULL handling.
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

-- === IF / ELSIF / ELSE ===

CREATE OR REPLACE FUNCTION account_tier(acct_id INT)
RETURNS VARCHAR AS $$
DECLARE
    acct_bal NUMERIC;
BEGIN
    SELECT bal INTO acct_bal FROM accounts WHERE id = acct_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % not found', acct_id;
    ELSIF acct_bal >= 10000 THEN
        RETURN 'Platinum';
    ELSIF acct_bal >= 5000 THEN
        RETURN 'Gold';
    ELSIF acct_bal >= 1000 THEN
        RETURN 'Silver';
    ELSE
        RETURN 'Bronze';
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- Test it:
SELECT name, bal, account_tier(id) AS tier FROM accounts;
-- Alice | 1000.00 | Silver
-- Bob   |  500.00 | Bronze
-- Carol |  300.00 | Bronze

-- === SIMPLE CASE ===

CREATE OR REPLACE FUNCTION status_label(code CHAR)
RETURNS VARCHAR AS $$
BEGIN
    CASE code
        WHEN 'A' THEN RETURN 'Active';
        WHEN 'S' THEN RETURN 'Suspended';
        WHEN 'C' THEN RETURN 'Closed';
        WHEN 'P' THEN RETURN 'Pending';
        ELSE RETURN 'Unknown: ' || code;
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT status_label('A');  -- Active
SELECT status_label('S');  -- Suspended
SELECT status_label('X');  -- Unknown: X

-- === SEARCHED CASE ===

CREATE OR REPLACE FUNCTION age_category(age INT)
RETURNS VARCHAR AS $$
BEGIN
    CASE
        WHEN age IS NULL THEN
            RETURN 'Unknown';
        WHEN age < 0 THEN
            RAISE EXCEPTION 'Age cannot be negative: %', age;
        WHEN age < 13 THEN
            RETURN 'Child';
        WHEN age < 18 THEN
            RETURN 'Teen';
        WHEN age < 65 THEN
            RETURN 'Adult';
        ELSE
            RETURN 'Senior';
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT age_category(8);    -- Child
SELECT age_category(16);   -- Teen
SELECT age_category(35);   -- Adult
SELECT age_category(70);   -- Senior
SELECT age_category(NULL); -- Unknown
-- SELECT age_category(-5);  -- ERROR: Age cannot be negative

-- === RAISE LEVELS ===

CREATE OR REPLACE FUNCTION raise_demo()
RETURNS VOID AS $$
BEGIN
    RAISE DEBUG   'This is DEBUG (hidden by default)';
    RAISE LOG     'This is LOG (server log only)';
    RAISE INFO    'This is INFO';
    RAISE NOTICE  'This is NOTICE (most common for debugging)';
    RAISE WARNING 'This is WARNING';
    -- RAISE EXCEPTION 'This stops execution!';
END;
$$ LANGUAGE plpgsql;

SELECT raise_demo();
-- INFO:  This is INFO
-- NOTICE:  This is NOTICE (most common for debugging)
-- WARNING: This is WARNING

-- To see DEBUG messages:
-- SET client_min_messages = 'debug';
-- SELECT raise_demo();
-- RESET client_min_messages;

-- === RAISE WITH PLACEHOLDERS ===

CREATE OR REPLACE FUNCTION raise_placeholders_demo()
RETURNS VOID AS $$
DECLARE
    user_name VARCHAR := 'Alice';
    user_bal  NUMERIC := 1000.00;
BEGIN
    -- % is replaced with the next argument
    RAISE NOTICE 'User: %, Balance: %', user_name, user_bal;
    RAISE NOTICE 'Tax: %', user_bal * 0.18;

    -- Multiple placeholders
    RAISE NOTICE '% has % which is % threshold',
        user_name, user_bal,
        CASE WHEN user_bal >= 500 THEN 'above' ELSE 'below' END;
END;
$$ LANGUAGE plpgsql;

SELECT raise_placeholders_demo();

-- === RAISE EXCEPTION WITH USING ===

CREATE OR REPLACE FUNCTION strict_withdraw(acct_id INT, amount NUMERIC)
RETURNS NUMERIC AS $$
DECLARE
    current_bal NUMERIC;
BEGIN
    IF amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be positive: %', amount
            USING HINT = 'Pass a positive number greater than zero',
                  ERRCODE = 'invalid_parameter_value';
    END IF;

    SELECT bal INTO current_bal FROM accounts WHERE id = acct_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % does not exist', acct_id
            USING HINT = 'Check account ID and try again',
                  ERRCODE = 'no_data_found';
    END IF;

    IF current_bal < amount THEN
        RAISE EXCEPTION 'Insufficient funds: have %, need %',
            current_bal, amount
            USING HINT = format('Maximum withdrawal: %s', current_bal),
                  ERRCODE = 'check_violation';
    END IF;

    RAISE NOTICE 'Withdrawing % from account %', amount, acct_id;

    UPDATE accounts SET bal = bal - amount WHERE id = acct_id;
    RETURN current_bal - amount;
END;
$$ LANGUAGE plpgsql;

-- Test:
SELECT strict_withdraw(1, 100);  -- Success
-- SELECT strict_withdraw(1, -50);  -- ERROR + HINT
-- SELECT strict_withdraw(999, 50); -- ERROR + HINT
-- SELECT strict_withdraw(1, 99999); -- ERROR + HINT

-- Reset
UPDATE accounts SET bal = 1000 WHERE id = 1;

-- === TRANSFER FUNCTION (Full Validation) ===

CREATE OR REPLACE FUNCTION transfer(
    from_id INT, to_id INT, amount NUMERIC
) RETURNS TEXT AS $$
DECLARE
    from_bal  NUMERIC;
    from_name VARCHAR;
    to_name   VARCHAR;
BEGIN
    -- Validate amount
    IF amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be positive';
    END IF;

    -- Validate different accounts
    IF from_id = to_id THEN
        RAISE EXCEPTION 'Cannot transfer to same account';
    END IF;

    -- Validate source account
    SELECT name, bal INTO from_name, from_bal
    FROM accounts WHERE id = from_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source account % not found', from_id;
    END IF;

    -- Validate destination account
    SELECT name INTO to_name FROM accounts WHERE id = to_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Destination account % not found', to_id;
    END IF;

    -- Validate sufficient funds
    IF from_bal < amount THEN
        RAISE EXCEPTION '% has only %, need %',
            from_name, from_bal, amount;
    END IF;

    -- Perform transfer
    RAISE NOTICE 'Transferring % from % to %', amount, from_name, to_name;
    UPDATE accounts SET bal = bal - amount WHERE id = from_id;
    UPDATE accounts SET bal = bal + amount WHERE id = to_id;

    RETURN format('Transferred %s from %s to %s', amount, from_name, to_name);
END;
$$ LANGUAGE plpgsql;

-- Test:
SELECT transfer(1, 2, 100);
SELECT name, bal FROM accounts ORDER BY id;

-- Reset
UPDATE accounts SET bal = 1000 WHERE id = 1;
UPDATE accounts SET bal = 500 WHERE id = 2;

-- === NULL HANDLING ===

-- NULL is tricky in PL/pgSQL!

CREATE OR REPLACE FUNCTION null_demo()
RETURNS VOID AS $$
DECLARE
    x INTEGER := NULL;
    y INTEGER := 5;
BEGIN
    -- These are all FALSE (not true, not false — NULL!)
    IF x = NULL THEN
        RAISE NOTICE 'x = NULL (WRONG — never reaches here)';
    END IF;

    IF x != NULL THEN
        RAISE NOTICE 'x != NULL (WRONG — never reaches here)';
    END IF;

    -- Correct way:
    IF x IS NULL THEN
        RAISE NOTICE 'x IS NULL — correct!';
    END IF;

    -- NULL arithmetic produces NULL
    RAISE NOTICE 'y + NULL = %', y + x;         -- NULL
    RAISE NOTICE 'COALESCE(x, 0) = %', COALESCE(x, 0);  -- 0
    RAISE NOTICE 'COALESCE(x, 0) + y = %', COALESCE(x, 0) + y;  -- 5
END;
$$ LANGUAGE plpgsql;

SELECT null_demo();

-- === PRACTICE EXERCISES ===

-- Exercise 1: Grading function
-- grade(score INT) → 'A' (90+), 'B' (80+), 'C' (70+), 'D' (60+), 'F'

-- Exercise 2: Simple CASE
-- day_type(day VARCHAR) → 'Weekday' or 'Weekend'

-- Exercise 3: RAISE debugging
-- Add RAISE NOTICE to transfer() to trace each validation step

-- Exercise 4: USING HINT and ERRCODE
-- Create a function that validates an email:
--   must contain @, must contain ., must be > 5 chars
--   Each violation raises with a specific HINT

-- Exercise 5: NULL traps
-- What does this return?
-- SELECT CASE WHEN NULL = NULL THEN 'equal' ELSE 'not equal' END;
-- Answer: 'not equal' (NULL = NULL is NULL, not true)

-- Exercise 6: CASE without ELSE
-- What happens when no WHEN matches and there's no ELSE?
-- Answer: ERROR: case not found

-- === CLEANUP ===
DROP FUNCTION IF EXISTS raise_demo();
DROP FUNCTION IF EXISTS raise_placeholders_demo();
DROP FUNCTION IF EXISTS null_demo();
DROP FUNCTION IF EXISTS debug_demo(INT);
-- Keep: account_tier, status_label, age_category,
--       strict_withdraw, transfer

-- =============================================
-- Next Class: PL/pgSQL Loops & Set-Returning Functions
-- =============================================
