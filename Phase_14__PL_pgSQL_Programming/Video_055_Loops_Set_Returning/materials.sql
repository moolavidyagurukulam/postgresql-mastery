-- =============================================
-- PostgreSQL Mastery: PL/pgSQL Loops & Set-Returning Functions
-- Phase 14: PL/pgSQL Programming | Classes 114-115
-- =============================================
-- LOOP, WHILE, FOR, FOREACH, RETURN NEXT,
-- RETURN QUERY, EXIT, CONTINUE, loop labels.
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

-- === BASIC LOOP with EXIT ===

CREATE OR REPLACE FUNCTION countdown(n INT)
RETURNS TEXT AS $$
DECLARE
    result TEXT := '';
    i INT := n;
BEGIN
    LOOP
        EXIT WHEN i <= 0;
        result := result || i || ' ';
        i := i - 1;
    END LOOP;
    RETURN result || 'Go!';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT countdown(5);
-- 5 4 3 2 1 Go!

-- === WHILE LOOP ===

CREATE OR REPLACE FUNCTION factorial(n INT)
RETURNS BIGINT AS $$
DECLARE
    result BIGINT := 1;
    i INT := n;
BEGIN
    WHILE i > 1 LOOP
        result := result * i;
        i := i - 1;
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT factorial(5);   -- 120
SELECT factorial(10);  -- 3628800

-- Power of 2 finder
CREATE OR REPLACE FUNCTION next_power_of_2(n INT)
RETURNS INT AS $$
DECLARE
    result INT := 1;
BEGIN
    WHILE result <= n LOOP
        result := result * 2;
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT next_power_of_2(100);  -- 128
SELECT next_power_of_2(1000); -- 1024

-- === FOR INTEGER RANGE ===

CREATE OR REPLACE FUNCTION multiplication_table(n INT)
RETURNS TEXT AS $$
DECLARE
    result TEXT := '';
BEGIN
    FOR i IN 1..10 LOOP
        result := result || format('%s x %s = %s', n, i, n * i) || E'\n';
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT multiplication_table(7);

-- FOR with step (BY)
-- FOR i IN 1..20 BY 2 LOOP  -- 1, 3, 5, 7, ...
-- FOR i IN REVERSE 10..1 LOOP  -- 10, 9, 8, ..., 1

-- === FOR OVER QUERY RESULTS ===

CREATE OR REPLACE FUNCTION account_report()
RETURNS TEXT AS $$
DECLARE
    rec    RECORD;
    report TEXT := 'Account Report:' || E'\n';
    total  NUMERIC := 0;
BEGIN
    FOR rec IN SELECT name, bal FROM accounts ORDER BY bal DESC
    LOOP
        report := report || format('  %s: $%s', rec.name, rec.bal);
        IF rec.bal >= 1000 THEN
            report := report || ' (Premium)';
        END IF;
        report := report || E'\n';
        total := total + rec.bal;
    END LOOP;

    report := report || format('Total: $%s', total);
    RETURN report;
END;
$$ LANGUAGE plpgsql STABLE;

SELECT account_report();

-- === FOR with EXECUTE (dynamic query) ===

-- FOR rec IN EXECUTE 'SELECT * FROM ' || table_name LOOP
--     -- process rec
-- END LOOP;
-- (Covered more in Cursors & Dynamic SQL class)

-- === FOREACH (Array Loop) ===

CREATE OR REPLACE FUNCTION sum_array(arr INT[])
RETURNS INT AS $$
DECLARE
    total INT := 0;
    elem  INT;
BEGIN
    FOREACH elem IN ARRAY arr LOOP
        total := total + elem;
    END LOOP;
    RETURN total;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT sum_array(ARRAY[10, 20, 30, 40]);  -- 100
SELECT sum_array('{5,15,25}');             -- 45

-- Process array of account IDs
CREATE OR REPLACE FUNCTION total_balance(acct_ids INT[])
RETURNS NUMERIC AS $$
DECLARE
    total NUMERIC := 0;
    acct_id INT;
    acct_bal NUMERIC;
BEGIN
    FOREACH acct_id IN ARRAY acct_ids LOOP
        SELECT bal INTO acct_bal FROM accounts WHERE id = acct_id;
        IF FOUND THEN
            total := total + acct_bal;
        ELSE
            RAISE NOTICE 'Account % not found, skipping', acct_id;
        END IF;
    END LOOP;
    RETURN total;
END;
$$ LANGUAGE plpgsql STABLE;

SELECT total_balance(ARRAY[1, 2, 3]);   -- 1800.00
SELECT total_balance(ARRAY[1, 99, 3]);  -- 1300.00 (notice for 99)

-- === EXIT and CONTINUE ===

-- EXIT: leave the loop immediately
-- EXIT WHEN condition: conditional exit
-- CONTINUE: skip to next iteration
-- CONTINUE WHEN condition: conditional skip

CREATE OR REPLACE FUNCTION odd_sum(n INT)
RETURNS INT AS $$
DECLARE
    total INT := 0;
BEGIN
    FOR i IN 1..n LOOP
        CONTINUE WHEN i % 2 = 0;  -- skip even numbers
        total := total + i;
    END LOOP;
    RETURN total;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT odd_sum(10);  -- 1+3+5+7+9 = 25

-- === LOOP LABELS ===

-- Label a loop to EXIT or CONTINUE it from an inner loop
CREATE OR REPLACE FUNCTION find_pair(target INT)
RETURNS TEXT AS $$
BEGIN
    <<outer_loop>>
    FOR i IN 1..target LOOP
        FOR j IN i..target LOOP
            IF i + j = target THEN
                RETURN format('%s + %s = %s', i, j, target);
            END IF;
        END LOOP;
    END LOOP outer_loop;
    RETURN 'No pair found';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT find_pair(15);  -- 1 + 14 = 15

-- === RETURN NEXT (Set-Returning Function) ===

CREATE OR REPLACE FUNCTION generate_series_custom(
    start_val INT, end_val INT
) RETURNS TABLE(num INT, squared INT) AS $$
BEGIN
    FOR i IN start_val..end_val LOOP
        num := i;
        squared := i * i;
        RETURN NEXT;  -- adds current row to result
    END LOOP;
    -- implicit RETURN at end of function
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT * FROM generate_series_custom(1, 5);

-- Fibonacci set-returning function
CREATE OR REPLACE FUNCTION fibonacci(n INT)
RETURNS TABLE(position INT, value BIGINT) AS $$
DECLARE
    a BIGINT := 0;
    b BIGINT := 1;
    temp BIGINT;
BEGIN
    FOR i IN 1..n LOOP
        position := i;
        value := a;
        RETURN NEXT;
        temp := a + b;
        a := b;
        b := temp;
    END LOOP;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT * FROM fibonacci(10);

-- === RETURN QUERY ===

CREATE OR REPLACE FUNCTION accounts_by_tier(tier VARCHAR)
RETURNS TABLE(acct_name VARCHAR, balance NUMERIC) AS $$
BEGIN
    CASE tier
        WHEN 'high' THEN
            RETURN QUERY SELECT name, bal FROM accounts
                         WHERE bal >= 1000 ORDER BY bal DESC;
        WHEN 'medium' THEN
            RETURN QUERY SELECT name, bal FROM accounts
                         WHERE bal >= 400 AND bal < 1000 ORDER BY bal DESC;
        WHEN 'low' THEN
            RETURN QUERY SELECT name, bal FROM accounts
                         WHERE bal < 400 ORDER BY bal DESC;
        ELSE
            RAISE EXCEPTION 'Unknown tier: %', tier;
    END CASE;
END;
$$ LANGUAGE plpgsql STABLE;

SELECT * FROM accounts_by_tier('high');
SELECT * FROM accounts_by_tier('medium');
SELECT * FROM accounts_by_tier('low');

-- Multiple RETURN QUERY in one function
CREATE OR REPLACE FUNCTION accounts_extremes()
RETURNS TABLE(category TEXT, acct_name VARCHAR, balance NUMERIC) AS $$
BEGIN
    -- Highest balance
    RETURN QUERY
        SELECT 'Richest'::TEXT, name, bal FROM accounts
        ORDER BY bal DESC LIMIT 1;

    -- Lowest balance
    RETURN QUERY
        SELECT 'Poorest'::TEXT, name, bal FROM accounts
        ORDER BY bal ASC LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

SELECT * FROM accounts_extremes();

-- === PRACTICE EXERCISES ===

-- Exercise 1: WHILE loop
-- Write power_of_2_above(n) that returns smallest 2^k > n

-- Exercise 2: FOR integer range
-- Write sum_range(a, b) that sums all integers from a to b

-- Exercise 3: FOR over query
-- Loop over accounts, return names of those with bal > 500

-- Exercise 4: FOREACH
-- Write avg_array(arr NUMERIC[]) that returns the average

-- Exercise 5: RETURN NEXT
-- Write prime_numbers(n INT) RETURNS TABLE(prime INT)
-- that returns all primes up to n

-- Exercise 6: RETURN QUERY
-- Write search_accounts(term TEXT)
-- that returns accounts where name ILIKE '%' || term || '%'

-- Exercise 7: CONTINUE WHEN
-- Write sum_positive(arr INT[]) that skips negative values

-- === CLEANUP ===
DROP FUNCTION IF EXISTS countdown(INT);
DROP FUNCTION IF EXISTS next_power_of_2(INT);
DROP FUNCTION IF EXISTS multiplication_table(INT);
DROP FUNCTION IF EXISTS odd_sum(INT);
DROP FUNCTION IF EXISTS find_pair(INT);
DROP FUNCTION IF EXISTS generate_series_custom(INT, INT);
-- Keep: factorial, account_report, sum_array, total_balance,
--       fibonacci, accounts_by_tier, accounts_extremes

-- =============================================
-- Next Class: Procedures & DO Blocks
-- =============================================
