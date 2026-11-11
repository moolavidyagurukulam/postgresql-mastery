# Procedures & DO Blocks
**Series:** PostgreSQL Mastery | **Phase:** Phase 14: PL/pgSQL Programming | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover procedures and DO blocks. Procedures were introduced in PostgreSQL 11 and are different from functions in one critical way — procedures can control transactions. They can COMMIT and ROLLBACK inside their body. Functions cannot do this. DO blocks are anonymous one-time code blocks — like a procedure you never save. Let us begin.

### Why Procedures Exist
Why do we need procedures when we already have functions? The answer is transaction control. Imagine you need to update one million rows. If you do it all in one transaction and it crashes at row 800,000, you lose everything. With a procedure, you can COMMIT every 1000 rows — if it crashes at 800,000, the first 800 batches are already saved. Functions cannot do this because they always run inside the caller's transaction.


---

## 2. Core Technical Concepts & Mechanisms

### Why Procedures Exist
Why do we need procedures when we already have functions? The answer is transaction control. Imagine you need to update one million rows. If you do it all in one transaction and it crashes at row 800,000, you lose everything. With a procedure, you can COMMIT every 1000 rows — if it crashes at 800,000, the first 800 batches are already saved. Functions cannot do this because they always run inside the caller's transaction.

| Term | Meaning / Explanation |
| :--- | :--- |
| **The Problem** | Functions run in caller's transaction — cannot COMMIT midway |
| **The Solution** | Procedures can COMMIT and ROLLBACK inside their body |
| **Use Case** | Batch processing, data migrations, multi-step operations |
| **Introduced** | PostgreSQL 11 (2018) — CREATE PROCEDURE + CALL |

**Notes:**
- Functions: calculations and queries
- Procedures: operations that need transaction control

### Function vs Procedure
Functions and procedures look similar but behave differently. A function returns a value and is called with SELECT. A procedure does not return a value and is called with CALL. The biggest difference: a procedure can COMMIT and ROLLBACK inside its body — it controls its own transactions. A function always runs inside the caller's transaction and cannot commit or rollback. Use functions for calculations and queries, procedures for multi-step operations that need transaction control.

| FUNCTION | PROCEDURE |
| :--- | :--- |
| RETURNS a value (or table) | No return value |
| Called with SELECT | Called with CALL |
| Cannot COMMIT/ROLLBACK | CAN COMMIT/ROLLBACK |
| Runs in caller's transaction | Controls own transactions |
| Can be used in expressions | Cannot be used in SELECT |
| CREATE FUNCTION ... RETURNS ... | CREATE PROCEDURE ... |

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Transaction Control Rules
There are important rules for transaction control in procedures. You cannot use COMMIT or ROLLBACK inside a procedure if it was called from within an existing transaction — only top-level CALL works. You cannot use COMMIT inside an EXCEPTION block. And after a COMMIT, any cursors that were open are closed. These restrictions exist because PostgreSQL needs to manage transaction boundaries cleanly.

| Rule | Details |
| :--- | :--- |
| Top-level CALL only | COMMIT/ROLLBACK work only when CALL is the outer statement |
| No BEGIN needed | CALL starts its own transaction automatically |
| No EXCEPTION block | Cannot COMMIT/ROLLBACK inside an EXCEPTION handler |
| Cursors close | Open cursors are closed after COMMIT |
| New transaction | After COMMIT, a new transaction starts automatically |

### When to Use What
Here is a decision framework for choosing between functions, procedures, and DO blocks. If you need a return value or want to use the result in a query, use a function. If you need COMMIT or ROLLBACK inside the code, use a procedure. If you need one-time code that you will not reuse, use a DO block. Most of your server-side code will be functions — procedures are specifically for batch operations and multi-step processes.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a decision framework for choosing between functions, procedures, and DO blocks |
| **Point 2** | If you need a return value or want to use the result in a query, use a function |
| **Point 3** | If you need COMMIT or ROLLBACK inside the code, use a procedure |
| **If you need one** | time code that you will not reuse, use a DO block |
| **Most of your server** | side code will be functions — procedures are specifically for batch operations and multi-step processes |

### Practice Exercises
Practice exercises: create a procedure that inserts sample data, create a batch processing procedure with COMMIT every N rows, use a DO block for a one-time data cleanup, create a procedure with OUT parameters, test what happens when you try COMMIT inside a function, and test CALL inside a BEGIN block.

- 1. Procedure: insert_sample_data(n INT) — inserts n test rows
- 2. Procedure with COMMIT: batch delete old records, commit every 10
- 3. DO block: set all accounts with bal < 100 to exactly 100
- 4. Procedure with OUT: calculate min, max, avg balance
- 5. Try COMMIT inside a FUNCTION → observe ERROR
- 6. Try CALL inside BEGIN/COMMIT → observe ERROR
- 7. DROP PROCEDURE IF EXISTS name(params);


---

## 3. Hands-On Commands & psql Output

### Creating and Calling a Procedure
**Explanation:** Creating a procedure is like creating a function, but without RETURNS. Use CREATE PROCEDURE, define parameters, write the PL/pgSQL body, and call it with CALL. This simple procedure transfers money between accounts — it performs the debit and credit as one operation.

```sql
practice=# CREATE OR REPLACE PROCEDURE transfer_money(
    from_id INT, to_id INT, amount NUMERIC
) AS $$
DECLARE
    src_bal NUMERIC;
BEGIN
    SELECT bal INTO src_bal FROM accounts WHERE id = from_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source account % not found', from_id;
    END IF;
    IF src_bal < amount THEN
        RAISE EXCEPTION 'Insufficient funds';
    END IF;

    UPDATE accounts SET bal = bal - amount WHERE id = from_id;
    UPDATE accounts SET bal = bal + amount WHERE id = to_id;
    RAISE NOTICE 'Transferred % from account % to %',
        amount, from_id, to_id;
END;
$$ LANGUAGE plpgsql;
CREATE PROCEDURE

-- Call with CALL (not SELECT!)
practice=# CALL transfer_money(1, 2, 200);
NOTICE:  Transferred 200 from account 1 to 2
CALL

practice=# SELECT name, bal FROM accounts ORDER BY id;
 name  |  bal
-------+--------
 Alice | 800.00
 Bob   | 700.00
```

### Beginner Trap: SELECT vs CALL
**Explanation:** Beginner trap! If you try to use SELECT to call a procedure, or CALL to invoke a function, PostgreSQL gives an error. Procedures are CALL only. Functions are SELECT only. Also, you cannot use a procedure inside a WHERE clause, a JOIN, or any expression — procedures are standalone operations, not values.

```sql
-- WRONG: trying to SELECT a procedure
practice=# SELECT transfer_money(1, 2, 50);
ERROR:  transfer_money(integer, integer, numeric) is a procedure
HINT:  To call a procedure, use CALL.

-- CORRECT: use CALL
practice=# CALL transfer_money(1, 2, 50);
CALL

-- WRONG: trying to CALL a function
practice=# CALL add_tax(100);
ERROR:  add_tax(integer) is not a procedure
HINT:  To call a function, use SELECT.

-- WRONG: procedure in an expression
-- SELECT * FROM accounts WHERE bal > transfer_money(...)
-- ERROR: procedures cannot be used in expressions
```

### Transaction Control in Procedures
**Explanation:** The real power of procedures is transaction control. Inside a procedure, you can COMMIT to save progress and ROLLBACK to undo changes. This is essential for batch processing — if you are updating thousands of rows, you can commit every 100 rows instead of one giant transaction. If the process crashes at row 500, you have already saved the first 400.

```sql
practice=# CREATE OR REPLACE PROCEDURE batch_update_balances(
    bonus NUMERIC, batch_size INT DEFAULT 2
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

        IF counter % batch_size = 0 THEN
            COMMIT;  -- save progress every batch_size rows
            RAISE NOTICE 'Committed batch of %', batch_size;
        END IF;
    END LOOP;

    COMMIT;  -- commit any remaining rows
    RAISE NOTICE 'Done! Updated % accounts', counter;
END;
$$ LANGUAGE plpgsql;

practice=# CALL batch_update_balances(50);
NOTICE:  Updated Alice: +50
NOTICE:  Updated Bob: +50
NOTICE:  Committed batch of 2
NOTICE:  Updated Carol: +50
NOTICE:  Done! Updated 3 accounts
```

### Beginner Trap: COMMIT in a Function → ERROR
**Explanation:** Critical beginner trap: what happens if you try COMMIT inside a function? PostgreSQL rejects it immediately with the error — invalid transaction termination. Functions CANNOT control transactions. This is the number one reason procedures exist. If you need COMMIT or ROLLBACK in your code, it MUST be a procedure, not a function.

```sql
-- WRONG: COMMIT inside a function
practice=# CREATE OR REPLACE FUNCTION bad_func() RETURNS VOID AS $$
BEGIN
    INSERT INTO accounts VALUES (99, 'Test', 100);
    COMMIT;  -- This will FAIL!
END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION

practice=# SELECT bad_func();
ERROR:  invalid transaction termination
CONTEXT:  PL/pgSQL function bad_func() line 3 at COMMIT

-- The function is created successfully
-- but FAILS at runtime when COMMIT is reached
-- Solution: use CREATE PROCEDURE instead

practice=# DROP FUNCTION bad_func();
```

### Beginner Trap: CALL Inside BEGIN → ERROR
**Explanation:** Another trap: calling a procedure inside an explicit transaction block. If you wrap CALL in your own BEGIN and COMMIT, the procedure cannot use its own transaction control. PostgreSQL raises an error — cannot commit while a subtransaction is active. The procedure's COMMIT only works when CALL is the outermost statement — not nested inside another transaction.

```sql
-- WRONG: CALL inside an explicit transaction
practice=# BEGIN;
practice=*# CALL batch_update_balances(10);
ERROR:  invalid transaction termination
CONTEXT:  PL/pgSQL function batch_update_balances(numeric,integer)
          line 12 at COMMIT
practice=!# ROLLBACK;

-- CORRECT: CALL as top-level statement (no outer BEGIN)
practice=# CALL batch_update_balances(10);
NOTICE:  Updated Alice: +10
NOTICE:  Updated Bob: +10
NOTICE:  Committed batch of 2
...

-- Rule: COMMIT/ROLLBACK only work in top-level CALL
-- If you don't use COMMIT in the procedure,
-- then CALL inside BEGIN is fine
```

### DO Blocks — Anonymous Code
**Explanation:** DO blocks are anonymous code blocks — PL/pgSQL code that runs immediately without creating a stored function or procedure. Use DO for one-time operations: data migrations, bulk updates, quick experiments, or admin scripts. A DO block has no name, no parameters, and no return value. It uses the same DECLARE, BEGIN, END structure as functions.

```sql
-- Simple DO block: calculate and report
practice=# DO $$
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
NOTICE:  Accounts: 3, Total: $1950.00
NOTICE:  Normal total balance
```

### DO Block — Data Migration Example
**Explanation:** DO blocks are perfect for data migrations and one-time cleanups. This DO block loops through accounts, finds those below a threshold, and tops them up. Use RAISE NOTICE to report what changed. Since DO blocks are anonymous, they are not stored — you run them once and they are gone. If you need to reuse the logic, convert it to a function or procedure.

```sql
-- Top up all accounts below $400
practice=# DO $$
DECLARE
    rec RECORD;
    updated INT := 0;
BEGIN
    FOR rec IN SELECT id, name, bal FROM accounts WHERE bal < 400
    LOOP
        UPDATE accounts SET bal = 400 WHERE id = rec.id;
        RAISE NOTICE 'Topped up %: $% → $400', rec.name, rec.bal;
        updated := updated + 1;
    END LOOP;

    RAISE NOTICE 'Migration complete: % accounts updated', updated;
END;
$$;
NOTICE:  Topped up Carol: $300.00 → $400
NOTICE:  Migration complete: 1 accounts updated

-- DO blocks: no name, no parameters, no return value
-- Run once, not stored in the database
-- Perfect for: migrations, cleanup, one-time fixes
```

### OUT and INOUT Parameters
**Explanation:** Procedures support OUT and INOUT parameters for returning values to the caller. OUT parameters are set inside the procedure and read by the caller. INOUT parameters pass a value in and get a modified value back. This is how procedures communicate results — since they cannot use RETURN to send back a value. When calling a procedure with OUT parameters, you must pass NULL for each OUT placeholder.

```sql
-- OUT parameter: returns values to the caller
practice=# CREATE OR REPLACE PROCEDURE get_stats(
    OUT total_accounts INT,
    OUT total_balance NUMERIC,
    OUT avg_balance NUMERIC
) AS $$
BEGIN
    SELECT COUNT(*), SUM(bal), ROUND(AVG(bal), 2)
    INTO total_accounts, total_balance, avg_balance
    FROM accounts;
END;
$$ LANGUAGE plpgsql;

-- Pass NULL for each OUT parameter
practice=# CALL get_stats(NULL, NULL, NULL);
 total_accounts | total_balance | avg_balance
----------------+---------------+-------------
              3 |       2150.00 |      716.67

-- INOUT: pass a value in, get modified value back
practice=# CREATE OR REPLACE PROCEDURE double_it(INOUT val INT) AS $$
BEGIN
    val := val * 2;
END;
$$ LANGUAGE plpgsql;

practice=# CALL double_it(21);
 val
-----
  42
```

### Managing Procedures
**Explanation:** Managing procedures is similar to managing functions. Use backslash-df to list all routines. Use the information_schema to filter for procedures specifically. DROP PROCEDURE requires matching parameter types — if you have two procedures with the same name but different parameters, you must specify which one. Use CREATE OR REPLACE to update an existing procedure without dropping it.

```sql
-- List all routines (functions + procedures)
practice=# \df
                         List of functions
 Schema |         Name           | Result  | Arguments
--------+------------------------+---------+----------
 public | transfer_money         |         | from_id...
 public | batch_update_balances  |         | bonus...
 public | add_tax                | numeric | price...

-- Filter for procedures only (SQL query)
practice=# SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_type = 'PROCEDURE';
      routine_name       | routine_type
------------------------+--------------
 transfer_money         | PROCEDURE
 batch_update_balances  | PROCEDURE

-- Drop requires param types!
practice=# DROP PROCEDURE IF EXISTS double_it(INT);
DROP PROCEDURE

-- Update without dropping:
-- CREATE OR REPLACE PROCEDURE name(params) AS $$ ... $$;
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: SELECT vs CALL
Beginner trap! If you try to use SELECT to call a procedure, or CALL to invoke a function, PostgreSQL gives an error. Procedures are CALL only. Functions are SELECT only. Also, you cannot use a procedure inside a WHERE clause, a JOIN, or any expression — procedures are standalone operations, not values.

```sql
-- WRONG: trying to SELECT a procedure
SELECT transfer_money(1, 2, 50);
ERROR:  transfer_money(integer, integer, numeric) is a procedure
HINT:  To call a procedure, use CALL.

-- CORRECT: use CALL
CALL transfer_money(1, 2, 50);
CALL

-- WRONG: trying to CALL a function
CALL add_tax(100);
ERROR:  add_tax(integer) is not a procedure
HINT:  To call a function, use SELECT.

-- WRONG: procedure in an expression
-- SELECT * FROM accounts WHERE bal > transfer_money(...)
-- ERROR: procedures cannot be used in expressions
```

### Beginner Trap: COMMIT in a Function → ERROR
Critical beginner trap: what happens if you try COMMIT inside a function? PostgreSQL rejects it immediately with the error — invalid transaction termination. Functions CANNOT control transactions. This is the number one reason procedures exist. If you need COMMIT or ROLLBACK in your code, it MUST be a procedure, not a function.

```sql
-- WRONG: COMMIT inside a function
CREATE OR REPLACE FUNCTION bad_func() RETURNS VOID AS $$
BEGIN
    INSERT INTO accounts VALUES (99, 'Test', 100);
    COMMIT;  -- This will FAIL!
END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION

SELECT bad_func();
ERROR:  invalid transaction termination
CONTEXT:  PL/pgSQL function bad_func() line 3 at COMMIT

-- The function is created successfully
-- but FAILS at runtime when COMMIT is reached
-- Solution: use CREATE PROCEDURE instead

DROP FUNCTION bad_func();
```

### Beginner Trap: CALL Inside BEGIN → ERROR
Another trap: calling a procedure inside an explicit transaction block. If you wrap CALL in your own BEGIN and COMMIT, the procedure cannot use its own transaction control. PostgreSQL raises an error — cannot commit while a subtransaction is active. The procedure's COMMIT only works when CALL is the outermost statement — not nested inside another transaction.

```sql
-- WRONG: CALL inside an explicit transaction
BEGIN;
CALL batch_update_balances(10);
ERROR:  invalid transaction termination
CONTEXT:  PL/pgSQL function batch_update_balances(numeric,integer)
          line 12 at COMMIT
ROLLBACK;

-- CORRECT: CALL as top-level statement (no outer BEGIN)
CALL batch_update_balances(10);
NOTICE:  Updated Alice: +10
NOTICE:  Updated Bob: +10
NOTICE:  Committed batch of 2
...

-- Rule: COMMIT/ROLLBACK only work in top-level CALL
-- If you don't use COMMIT in the procedure,
-- then CALL inside BEGIN is fine
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. Procedures are created with CREATE PROCEDURE and called with CALL — not SELECT. The key difference from functions: procedures can COMMIT and ROLLBACK inside their body, enabling batch processing with intermediate saves. DO blocks are anonymous PL/pgSQL for one-time scripts. OUT and INOUT parameters let procedures return values. Transaction control only works in top-level CALL statements — not inside existing transactions, not inside functions. Beginner traps: never SELECT a procedure, never COMMIT in a function, and never CALL a batch procedure inside BEGIN. In the next class, we cover cursors and dynamic SQL. See you there!

- **CREATE PROCEDURE: no RETURNS, called with CALL**
- **COMMIT/ROLLBACK: works inside procedures (not functions!)**
- **Batch processing: COMMIT every N rows for safety**
- **Top-level CALL only: no txn control if called within BEGIN**
- **DO $$ BEGIN ... END; $$: anonymous one-time code**
- **OUT parameters: procedure returns values to caller**
- **INOUT parameters: pass in and get modified value back**
- **Trap: COMMIT in function → invalid transaction termination**


---

## 8. Downloadable SQL Script Instructions

Every command demonstrated in this video is compiled into the companion `materials.sql` file.

To execute it directly in PostgreSQL:

```bash
# From your command line:
psql -U postgres -d postgres -f materials.sql

# Or from inside psql prompt:
postgres=# \i materials.sql
```
