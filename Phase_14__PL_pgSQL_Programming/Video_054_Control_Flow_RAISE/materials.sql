-- ====================================================================
-- Class 054: PL/pgSQL Control Flow & RAISE Statements
-- PostgreSQL 16 Admin & Developer Mastery Series
-- MoolaVidya Gurukulam — 100% Free High-Impact Education
-- ====================================================================

-- Setup mock schema for tests
DROP TABLE IF EXISTS accounts CASCADE;
CREATE TABLE accounts (
    account_id INT PRIMARY KEY,
    owner_name TEXT NOT NULL,
    balance NUMERIC(12, 2) NOT NULL CHECK (balance >= 0)
);

INSERT INTO accounts (account_id, owner_name, balance) VALUES
(101, 'Alice Corp', 5000.00),
(102, 'Bob Logistics', 12500.00),
(103, 'Charlie Ventures', 750.00);

-- Demonstration 1: IF-THEN-ELSIF-ELSE with RAISE EXCEPTION
CREATE OR REPLACE FUNCTION process_withdrawal(
    p_account_id INT,
    p_amount NUMERIC
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance NUMERIC;
BEGIN
    SELECT balance INTO v_balance 
    FROM accounts 
    WHERE account_id = p_account_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % not found', p_account_id
            USING ERRCODE = 'no_data_found';
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Withdrawal amount must be strictly positive (requested: %)', p_amount
            USING ERRCODE = 'check_violation',
                  HINT = 'Pass a positive decimal value.';
    ELSIF p_amount > v_balance THEN
        RAISE EXCEPTION 'Insufficient funds: balance is %, attempted %', v_balance, p_amount
            USING ERRCODE = 'integrity_constraint_violation',
                  DETAIL = 'Account overdraft limits are disabled on standard retail accounts.';
    ELSE
        UPDATE accounts 
        SET balance = balance - p_amount 
        WHERE account_id = p_account_id;
        
        RETURN 'SUCCESS: New balance is ' || (v_balance - p_amount);
    END IF;
END;
$$;

-- Demonstration 2: Simple vs Searched CASE Statements
CREATE OR REPLACE FUNCTION evaluate_credit_tier(p_score INT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_tier TEXT;
BEGIN
    -- Searched CASE
    CASE
        WHEN p_score >= 800 THEN v_tier := 'PLATINUM';
        WHEN p_score >= 700 THEN v_tier := 'GOLD';
        WHEN p_score >= 600 THEN v_tier := 'SILVER';
        WHEN p_score IS NULL THEN v_tier := 'UNRATED';
        ELSE v_tier := 'SUBPRIME';
    END CASE;
    RETURN v_tier;
END;
$$;

-- Demonstration 3: Diagnostic RAISE Levels
CREATE OR REPLACE FUNCTION test_raise_levels()
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE DEBUG 'Debug info for engine logs';
    RAISE LOG 'Log written to postgresql server log file';
    RAISE INFO 'Informational message always pushed to client';
    RAISE NOTICE 'Notice: standard application progress ping';
    RAISE WARNING 'Warning: non-fatal warning condition detected';
    -- RAISE EXCEPTION 'Exception: this terminates transaction immediately!';
END;
$$;

-- ====================================================================
-- Hands-On Practice Solutions
-- ====================================================================

-- Challenge 1: calc_tier_discount
CREATE OR REPLACE FUNCTION calc_tier_discount(p_total_spent NUMERIC)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_total_spent < 0 THEN
        RAISE EXCEPTION 'Total spent cannot be negative: %', p_total_spent
            USING ERRCODE = 'check_violation',
                  HINT = 'Provide a non-negative purchase total.';
    ELSIF p_total_spent >= 10000 THEN
        RETURN 0.25;
    ELSIF p_total_spent >= 5000 THEN
        RETURN 0.15;
    ELSIF p_total_spent >= 1000 THEN
        RETURN 0.10;
    ELSE
        RETURN 0.00;
    END IF;
END;
$$;

-- Challenge 2: next_order_stage
CREATE OR REPLACE FUNCTION next_order_stage(p_current_status TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_next TEXT;
BEGIN
    CASE UPPER(TRIM(p_current_status))
        WHEN 'DRAFT' THEN v_next := 'PENDING';
        WHEN 'PENDING' THEN v_next := 'PROCESSING';
        WHEN 'PROCESSING' THEN v_next := 'SHIPPED';
        WHEN 'SHIPPED' THEN v_next := 'DELIVERED';
        WHEN 'DELIVERED' THEN v_next := 'ARCHIVED';
        ELSE
            RAISE EXCEPTION 'Invalid order stage transition from %', p_current_status
                USING ERRCODE = 'invalid_parameter_value',
                      HINT = 'Permissible states: DRAFT, PENDING, PROCESSING, SHIPPED, DELIVERED.';
    END CASE;
    RETURN v_next;
END;
$$;

-- Challenge 3: register_system_user
CREATE OR REPLACE FUNCTION register_system_user(
    p_username TEXT, 
    p_email TEXT, 
    p_role TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    IF LENGTH(TRIM(p_username)) < 3 THEN
        RAISE EXCEPTION 'Username "%" must be at least 3 characters long', p_username
            USING ERRCODE = 'string_data_length_mismatch';
    END IF;

    IF POSITION('@' IN p_email) = 0 THEN
        RAISE EXCEPTION 'Invalid email address provided: %', p_email
            USING ERRCODE = 'invalid_parameter_value',
                  HINT = 'Ensure email contains an @ symbol.';
    END IF;

    CASE LOWER(TRIM(p_role))
        WHEN 'admin', 'analyst', 'operator' THEN
            NULL; -- Valid role, continue
        ELSE
            RAISE EXCEPTION 'Unauthorized role assignment: %', p_role
                USING ERRCODE = 'invalid_parameter_value',
                      HINT = 'Role must be admin, analyst, or operator.';
    END CASE;

    RAISE NOTICE 'Provisioned account for % (Role: %)', p_username, p_role;
    RETURN 'SUCCESS: Account active';
END;
$$;

-- Challenge 4: safe_metric_ratio
CREATE OR REPLACE FUNCTION safe_metric_ratio(
    p_numerator NUMERIC, 
    p_denominator NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_denominator = 0 THEN
        RAISE WARNING 'Division by zero attempted for numerator %. Defaulting ratio to 0.00.', p_numerator;
        RETURN 0.00;
    END IF;
    RETURN ROUND(p_numerator / p_denominator, 4);
END;
$$;

-- Challenge 5: transfer_funds_secure
CREATE OR REPLACE FUNCTION transfer_funds_secure(
    p_from_acct INT, 
    p_to_acct INT, 
    p_amount NUMERIC
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_bal NUMERIC;
    v_to_bal NUMERIC;
BEGIN
    IF p_from_acct = p_to_acct THEN
        RAISE EXCEPTION 'Origin and destination accounts cannot be identical (ID: %)', p_from_acct
            USING ERRCODE = 'cardinality_violation',
                  HINT = 'Specify two different account IDs.';
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Transfer amount must be greater than zero (received %)', p_amount
            USING ERRCODE = 'check_violation';
    END IF;

    SELECT balance INTO v_from_bal FROM accounts WHERE account_id = p_from_acct;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source account % does not exist', p_from_acct
            USING ERRCODE = 'no_data_found';
    END IF;

    SELECT balance INTO v_to_bal FROM accounts WHERE account_id = p_to_acct;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Destination account % does not exist', p_to_acct
            USING ERRCODE = 'no_data_found';
    END IF;

    IF v_from_bal < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance: Account % has %, attempted transfer %', p_from_acct, v_from_bal, p_amount
            USING ERRCODE = 'check_violation',
                  DETAIL = 'Transfer rejected to prevent account negative balance.';
    END IF;

    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from_acct;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to_acct;

    RETURN format('SUCCESS: Transferred %s from %s to %s', p_amount, p_from_acct, p_to_acct);
END;
$$;
