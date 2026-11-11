-- =============================================
-- PostgreSQL Mastery: Practical PL/pgSQL Projects
-- Phase 14: PL/pgSQL Programming | Classes 122-123
-- =============================================
-- Audit logging, data validation, batch processing.
-- Combining all PL/pgSQL techniques into real projects.
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

-- =========================================
-- PROJECT 1: AUDIT LOGGING SYSTEM
-- =========================================

-- Audit log table: stores all changes as JSONB
CREATE TABLE IF NOT EXISTS audit_log (
    id         SERIAL PRIMARY KEY,
    table_name VARCHAR(50)   NOT NULL,
    operation  VARCHAR(10)   NOT NULL,
    row_id     INT,
    old_data   JSONB,
    new_data   JSONB,
    changed_by VARCHAR(50)   DEFAULT current_user,
    changed_at TIMESTAMP     DEFAULT NOW()
);

-- Core audit function
CREATE OR REPLACE FUNCTION log_audit(
    p_table VARCHAR,
    p_op    VARCHAR,
    p_row_id INT,
    p_old   JSONB DEFAULT NULL,
    p_new   JSONB DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO audit_log(table_name, operation, row_id, old_data, new_data)
    VALUES (p_table, p_op, p_row_id, p_old, p_new);
END;
$$ LANGUAGE plpgsql;

-- Audited INSERT
CREATE OR REPLACE FUNCTION audited_insert_account(
    p_id INT, p_name VARCHAR, p_bal NUMERIC
) RETURNS TEXT AS $$
DECLARE
    new_row JSONB;
BEGIN
    INSERT INTO accounts VALUES (p_id, p_name, p_bal);
    SELECT to_jsonb(a) INTO new_row FROM accounts a WHERE id = p_id;
    PERFORM log_audit('accounts', 'INSERT', p_id, NULL, new_row);
    RETURN 'Inserted and logged: ' || p_name;
EXCEPTION WHEN unique_violation THEN
    RETURN 'Account ' || p_id || ' already exists';
END;
$$ LANGUAGE plpgsql;

-- Audited UPDATE
CREATE OR REPLACE FUNCTION audited_update_balance(
    acct_id INT, new_bal NUMERIC
) RETURNS TEXT AS $$
DECLARE
    old_row JSONB;
    new_row JSONB;
BEGIN
    SELECT to_jsonb(a) INTO old_row FROM accounts a WHERE id = acct_id;
    IF old_row IS NULL THEN
        RETURN 'Account ' || acct_id || ' not found';
    END IF;

    UPDATE accounts SET bal = new_bal WHERE id = acct_id;
    SELECT to_jsonb(a) INTO new_row FROM accounts a WHERE id = acct_id;
    PERFORM log_audit('accounts', 'UPDATE', acct_id, old_row, new_row);
    RETURN 'Updated and logged';
END;
$$ LANGUAGE plpgsql;

-- Audited DELETE
CREATE OR REPLACE FUNCTION audited_delete_account(acct_id INT)
RETURNS TEXT AS $$
DECLARE
    old_row JSONB;
BEGIN
    SELECT to_jsonb(a) INTO old_row FROM accounts a WHERE id = acct_id;
    IF old_row IS NULL THEN
        RETURN 'Account ' || acct_id || ' not found';
    END IF;

    DELETE FROM accounts WHERE id = acct_id;
    PERFORM log_audit('accounts', 'DELETE', acct_id, old_row, NULL);
    RETURN 'Deleted and logged';
END;
$$ LANGUAGE plpgsql;

-- Test the audit system:
SELECT audited_insert_account(10, 'Frank', 600);
SELECT audited_update_balance(10, 700);
SELECT audited_delete_account(10);

-- View audit log:
SELECT id, table_name, operation, row_id,
       old_data->>'bal' AS old_bal,
       new_data->>'bal' AS new_bal,
       changed_at
FROM audit_log ORDER BY id;

-- =========================================
-- PROJECT 2: DATA VALIDATION
-- =========================================

-- Validate all business rules, collect ALL errors
CREATE OR REPLACE FUNCTION validate_and_insert(
    p_id INT, p_name VARCHAR, p_bal NUMERIC
) RETURNS TEXT AS $$
DECLARE
    errors TEXT[] := '{}';
    existing INT;
BEGIN
    -- Rule 1: ID must be positive
    IF p_id IS NULL OR p_id <= 0 THEN
        errors := array_append(errors, 'ID must be a positive integer');
    END IF;

    -- Rule 2: Name not empty
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        errors := array_append(errors, 'Name cannot be empty');
    END IF;

    -- Rule 3: Name length
    IF p_name IS NOT NULL AND LENGTH(p_name) > 50 THEN
        errors := array_append(errors, 'Name too long (max 50 characters)');
    END IF;

    -- Rule 4: Name must start with a letter
    IF p_name IS NOT NULL AND p_name !~ '^[A-Za-z]' THEN
        errors := array_append(errors, 'Name must start with a letter');
    END IF;

    -- Rule 5: Balance not negative
    IF p_bal IS NULL THEN
        errors := array_append(errors, 'Balance is required');
    ELSIF p_bal < 0 THEN
        errors := array_append(errors, 'Balance cannot be negative');
    ELSIF p_bal > 1000000 THEN
        errors := array_append(errors, 'Balance exceeds maximum (1,000,000)');
    END IF;

    -- Rule 6: Unique name
    IF p_name IS NOT NULL THEN
        SELECT COUNT(*) INTO existing FROM accounts WHERE LOWER(name) = LOWER(p_name);
        IF existing > 0 THEN
            errors := array_append(errors, 'Name already exists (case-insensitive)');
        END IF;
    END IF;

    -- Rule 7: Unique ID
    SELECT COUNT(*) INTO existing FROM accounts WHERE id = p_id;
    IF existing > 0 THEN
        errors := array_append(errors, 'ID already taken');
    END IF;

    -- Return all errors or insert
    IF array_length(errors, 1) > 0 THEN
        RETURN 'ERRORS: ' || array_to_string(errors, '; ');
    END IF;

    INSERT INTO accounts VALUES (p_id, TRIM(p_name), p_bal);
    RETURN 'OK: Inserted ' || p_name;
END;
$$ LANGUAGE plpgsql;

-- Test validation:
SELECT validate_and_insert(10, 'Frank', 600);     -- OK
SELECT validate_and_insert(11, '', -100);          -- 2 errors
SELECT validate_and_insert(12, 'Alice', 500);      -- Name exists
SELECT validate_and_insert(13, '123Bad', -50);     -- 2 errors
SELECT validate_and_insert(1, 'NewPerson', 100);   -- ID taken

-- Clean up
DELETE FROM accounts WHERE id >= 10;

-- =========================================
-- PROJECT 3: BATCH PROCESSING
-- =========================================

-- Apply interest to all accounts with batch commits
CREATE OR REPLACE PROCEDURE apply_interest(
    rate NUMERIC,
    batch_size INT DEFAULT 2
) AS $$
DECLARE
    rec RECORD;
    counter INT := 0;
    total_added NUMERIC := 0;
    interest NUMERIC;
BEGIN
    RAISE NOTICE 'Starting interest application at %% rate', rate * 100;

    FOR rec IN SELECT id, name, bal FROM accounts ORDER BY id
    LOOP
        interest := ROUND(rec.bal * rate, 2);
        UPDATE accounts SET bal = bal + interest WHERE id = rec.id;
        total_added := total_added + interest;
        counter := counter + 1;

        RAISE NOTICE '  % (#%): $% + $% interest',
            rec.name, rec.id, rec.bal, interest;

        IF counter % batch_size = 0 THEN
            COMMIT;
            RAISE NOTICE '  --- Committed batch (% accounts so far) ---', counter;
        END IF;
    END LOOP;

    COMMIT;
    RAISE NOTICE 'Complete! % accounts, $% total interest added', counter, total_added;
END;
$$ LANGUAGE plpgsql;

-- Test:
CALL apply_interest(0.05);
SELECT name, bal FROM accounts ORDER BY id;

-- Reset
UPDATE accounts SET bal = 1000 WHERE id = 1;
UPDATE accounts SET bal = 500 WHERE id = 2;
UPDATE accounts SET bal = 300 WHERE id = 3;

-- Batch data cleanup procedure
CREATE OR REPLACE PROCEDURE cleanup_small_accounts(
    min_balance NUMERIC,
    batch_size INT DEFAULT 10
) AS $$
DECLARE
    rec RECORD;
    counter INT := 0;
    deleted INT := 0;
BEGIN
    FOR rec IN SELECT id, name, bal FROM accounts
               WHERE bal < min_balance ORDER BY id
    LOOP
        -- Log before deleting
        PERFORM log_audit('accounts', 'CLEANUP',
            rec.id,
            to_jsonb(rec),
            NULL);

        DELETE FROM accounts WHERE id = rec.id;
        deleted := deleted + 1;
        counter := counter + 1;

        IF counter % batch_size = 0 THEN
            COMMIT;
            RAISE NOTICE 'Committed batch: % deleted so far', deleted;
        END IF;
    END LOOP;

    COMMIT;
    RAISE NOTICE 'Cleanup complete: % accounts removed', deleted;
END;
$$ LANGUAGE plpgsql;

-- Test (careful — this deletes data!):
-- CALL cleanup_small_accounts(400);

-- =========================================
-- BONUS: COMBINED PATTERN — SAFE TRANSFER
-- =========================================

-- Combines: validation, audit logging, error handling
CREATE OR REPLACE FUNCTION safe_audited_transfer(
    from_id INT, to_id INT, amount NUMERIC
) RETURNS TEXT AS $$
DECLARE
    from_row JSONB;
    to_row   JSONB;
    from_bal NUMERIC;
    v_state TEXT; v_msg TEXT;
BEGIN
    -- Validate
    IF amount <= 0 THEN
        RETURN 'ERROR: Amount must be positive';
    END IF;
    IF from_id = to_id THEN
        RETURN 'ERROR: Cannot transfer to same account';
    END IF;

    -- Get source account
    SELECT to_jsonb(a), a.bal INTO from_row, from_bal
    FROM accounts a WHERE id = from_id;
    IF from_row IS NULL THEN
        RETURN 'ERROR: Source account not found';
    END IF;
    IF from_bal < amount THEN
        RETURN format('ERROR: Insufficient funds ($%s available)', from_bal);
    END IF;

    -- Get dest account
    SELECT to_jsonb(a) INTO to_row FROM accounts a WHERE id = to_id;
    IF to_row IS NULL THEN
        RETURN 'ERROR: Destination account not found';
    END IF;

    -- Perform transfer
    UPDATE accounts SET bal = bal - amount WHERE id = from_id;
    UPDATE accounts SET bal = bal + amount WHERE id = to_id;

    -- Audit both changes
    PERFORM log_audit('accounts', 'TRANSFER-OUT', from_id,
        from_row,
        to_jsonb(a) FROM accounts a WHERE id = from_id);
    PERFORM log_audit('accounts', 'TRANSFER-IN', to_id,
        to_row,
        to_jsonb(a) FROM accounts a WHERE id = to_id);

    RETURN format('OK: Transferred $%s from account %s to %s',
                  amount, from_id, to_id);

EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE,
                            v_msg = MESSAGE_TEXT;
    PERFORM log_audit('accounts', 'ERROR', from_id, NULL,
        jsonb_build_object('error', v_msg, 'sqlstate', v_state));
    RAISE;
END;
$$ LANGUAGE plpgsql;

-- Test:
SELECT safe_audited_transfer(1, 2, 100);
SELECT name, bal FROM accounts ORDER BY id;
SELECT operation, row_id, old_data->>'bal' AS old, new_data->>'bal' AS new
FROM audit_log WHERE operation LIKE 'TRANSFER%' ORDER BY id;

-- === PRACTICE EXERCISES ===

-- Exercise 1: Extend audit logging
-- Add an audited_update_name() function

-- Exercise 2: More validation rules
-- Add email validation to validate_and_insert

-- Exercise 3: Batch processing
-- Create a procedure that archives old audit_log entries
-- (move to audit_log_archive table, commit every 100)

-- Exercise 4: Dynamic audit function
-- Create audit_any_table(tbl TEXT, op TEXT, row_id INT)
-- using dynamic SQL

-- Exercise 5: Report function
-- Create audit_report(table_name TEXT, since TIMESTAMP)
-- that returns a summary of changes

-- Exercise 6: Full CRUD layer
-- Build audited_* functions for another table

-- === CLEANUP ===
-- TRUNCATE audit_log;
-- DROP TABLE IF EXISTS audit_log;
-- DROP FUNCTION IF EXISTS log_audit CASCADE;
-- (Keep everything for reference and Triggers phase)

-- =============================================
-- Next Phase: Triggers & Rules
-- =============================================
