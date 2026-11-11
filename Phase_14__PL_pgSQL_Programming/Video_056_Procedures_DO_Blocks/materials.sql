-- =============================================
-- PostgreSQL Mastery: Procedures & DO Blocks
-- Phase 14: PL/pgSQL Programming | Classes 116-117
-- =============================================
-- CREATE PROCEDURE, CALL, transaction control,
-- OUT/INOUT parameters, DO blocks, batch processing.
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

-- === BASIC PROCEDURE ===

CREATE OR REPLACE PROCEDURE transfer_money(
    from_id INT, to_id INT, amount NUMERIC
) AS $$
DECLARE
    src_bal NUMERIC;
BEGIN
    -- Validate
    SELECT bal INTO src_bal FROM accounts WHERE id = from_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source account % not found', from_id;
    END IF;
    IF src_bal < amount THEN
        RAISE EXCEPTION 'Insufficient funds: have %, need %', src_bal, amount;
    END IF;

    -- Transfer
    UPDATE accounts SET bal = bal - amount WHERE id = from_id;
    UPDATE accounts SET bal = bal + amount WHERE id = to_id;
    RAISE NOTICE 'Transferred % from account % to %', amount, from_id, to_id;
END;
$$ LANGUAGE plpgsql;

-- Call with CALL (not SELECT!)
CALL transfer_money(1, 2, 200);

SELECT name, bal FROM accounts ORDER BY id;
-- Alice: 800, Bob: 700

-- Reset
UPDATE accounts SET bal = 1000 WHERE id = 1;
UPDATE accounts SET bal = 500 WHERE id = 2;

-- === TRANSACTION CONTROL IN PROCEDURES ===

-- Procedures can COMMIT and ROLLBACK!
-- Functions CANNOT do this.

CREATE OR REPLACE PROCEDURE batch_add_bonus(
    bonus NUMERIC,
    batch_size INT DEFAULT 2
) AS $$
DECLARE
    rec RECORD;
    counter INT := 0;
BEGIN
    FOR rec IN SELECT id, name FROM accounts ORDER BY id
    LOOP
        UPDATE accounts SET bal = bal + bonus WHERE id = rec.id;
        counter := counter + 1;
        RAISE NOTICE 'Updated %: +%', rec.name, bonus;

        -- Commit every batch_size rows
        IF counter % batch_size = 0 THEN
            COMMIT;
            RAISE NOTICE '--- Committed batch of % ---', batch_size;
        END IF;
    END LOOP;

    -- Commit any remaining rows
    COMMIT;
    RAISE NOTICE 'Done! Updated % accounts total', counter;
END;
$$ LANGUAGE plpgsql;

CALL batch_add_bonus(50);
SELECT name, bal FROM accounts ORDER BY id;

-- Reset
UPDATE accounts SET bal = 1000 WHERE id = 1;
UPDATE accounts SET bal = 500 WHERE id = 2;
UPDATE accounts SET bal = 300 WHERE id = 3;

-- === PROCEDURE WITH ROLLBACK ===

CREATE OR REPLACE PROCEDURE safe_batch_insert() AS $$
DECLARE
    i INT;
BEGIN
    FOR i IN 100..105 LOOP
        BEGIN
            INSERT INTO accounts VALUES (i, 'Temp_' || i, i * 10);
            RAISE NOTICE 'Inserted account %', i;

            -- Commit each insert separately
            IF i <= 102 THEN
                COMMIT;
            ELSE
                -- Simulate a problem: rollback the rest
                RAISE NOTICE 'Problem at %! Rolling back...', i;
                ROLLBACK;
                RETURN;
            END IF;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- CALL safe_batch_insert();
-- Accounts 100-102 are committed
-- Accounts 103+ are rolled back

-- === OUT PARAMETERS ===

CREATE OR REPLACE PROCEDURE get_stats(
    OUT total_accounts INT,
    OUT total_balance  NUMERIC,
    OUT avg_balance    NUMERIC
) AS $$
BEGIN
    SELECT COUNT(*), SUM(bal), ROUND(AVG(bal), 2)
    INTO total_accounts, total_balance, avg_balance
    FROM accounts;
END;
$$ LANGUAGE plpgsql;

-- Pass NULL for OUT parameters
CALL get_stats(NULL, NULL, NULL);

-- === INOUT PARAMETERS ===

CREATE OR REPLACE PROCEDURE double_it(INOUT val INT) AS $$
BEGIN
    val := val * 2;
END;
$$ LANGUAGE plpgsql;

CALL double_it(21);
-- Returns: 42

-- Multiple INOUT
CREATE OR REPLACE PROCEDURE swap_values(INOUT a INT, INOUT b INT) AS $$
DECLARE
    temp INT;
BEGIN
    temp := a;
    a := b;
    b := temp;
END;
$$ LANGUAGE plpgsql;

CALL swap_values(10, 20);
-- Returns: a=20, b=10

-- === DO BLOCKS — Anonymous Code ===

-- Simple DO block: print account stats
DO $$
DECLARE
    total NUMERIC;
    cnt   INT;
BEGIN
    SELECT COUNT(*), SUM(bal) INTO cnt, total FROM accounts;
    RAISE NOTICE 'Accounts: %, Total: $%', cnt, total;

    IF total > 5000 THEN
        RAISE NOTICE 'High total balance!';
    ELSE
        RAISE NOTICE 'Normal total balance';
    END IF;
END;
$$;

-- DO block for data migration
DO $$
DECLARE
    rec RECORD;
    updated INT := 0;
BEGIN
    FOR rec IN SELECT id, name, bal FROM accounts WHERE bal < 400
    LOOP
        UPDATE accounts SET bal = 400 WHERE id = rec.id;
        RAISE NOTICE 'Topped up %: % → 400', rec.name, rec.bal;
        updated := updated + 1;
    END LOOP;

    IF updated = 0 THEN
        RAISE NOTICE 'No accounts needed topping up';
    ELSE
        RAISE NOTICE 'Topped up % accounts', updated;
    END IF;
END;
$$;

-- Reset Carol
UPDATE accounts SET bal = 300 WHERE id = 3;

-- DO block with dynamic table creation
DO $$
BEGIN
    -- Create a temp table for processing
    CREATE TEMP TABLE IF NOT EXISTS processing_log (
        id    SERIAL,
        msg   TEXT,
        ts    TIMESTAMP DEFAULT NOW()
    );

    INSERT INTO processing_log (msg) VALUES ('Batch started');
    INSERT INTO processing_log (msg) VALUES ('Processing accounts...');
    INSERT INTO processing_log (msg) VALUES ('Batch complete');

    RAISE NOTICE 'Processing log created with 3 entries';
END;
$$;

SELECT * FROM processing_log;
DROP TABLE IF EXISTS processing_log;

-- === TRANSACTION CONTROL RULES ===

-- Rule 1: COMMIT/ROLLBACK only in procedures, NOT functions
-- This will FAIL:
-- CREATE FUNCTION bad_func() RETURNS VOID AS $$
-- BEGIN
--     COMMIT;  -- ERROR: invalid transaction termination
-- END;
-- $$ LANGUAGE plpgsql;

-- Rule 2: Top-level CALL only
-- This will FAIL (CALL inside explicit transaction):
-- BEGIN;
-- CALL batch_add_bonus(10);  -- ERROR: cannot commit in active txn
-- COMMIT;

-- Rule 3: No COMMIT inside EXCEPTION blocks
-- COMMIT/ROLLBACK cannot appear inside BEGIN...EXCEPTION...END

-- === MANAGING PROCEDURES ===

-- List procedures
-- \dp  -- (not available in all psql versions)
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_type = 'PROCEDURE'
ORDER BY routine_name;

-- Drop procedure (must include parameter types!)
-- DROP PROCEDURE IF EXISTS transfer_money(INT, INT, NUMERIC);
-- DROP PROCEDURE IF EXISTS double_it(INT);

-- === PRACTICE EXERCISES ===

-- Exercise 1: Basic procedure
-- Create insert_account(id, name, bal) procedure

-- Exercise 2: Transaction control
-- Create a procedure that inserts 10 test accounts,
-- committing every 3 rows

-- Exercise 3: DO block
-- Write a DO block that finds and prints
-- the account with the highest balance

-- Exercise 4: OUT parameters
-- Create get_account_range(OUT min_bal, OUT max_bal, OUT range)

-- Exercise 5: INOUT
-- Create increment(INOUT val INT, step INT DEFAULT 1)

-- Exercise 6: Test the restriction
-- Try COMMIT inside a function → observe the error

-- Exercise 7: Clean up test data
DO $$
BEGIN
    DELETE FROM accounts WHERE id >= 100;
    RAISE NOTICE 'Cleaned up test accounts';
END;
$$;

-- === CLEANUP ===
DROP PROCEDURE IF EXISTS safe_batch_insert();
DROP PROCEDURE IF EXISTS double_it(INT);
DROP PROCEDURE IF EXISTS swap_values(INT, INT);
-- Keep: transfer_money, batch_add_bonus, get_stats

-- =============================================
-- Next Class: Cursors & Dynamic SQL
-- =============================================
