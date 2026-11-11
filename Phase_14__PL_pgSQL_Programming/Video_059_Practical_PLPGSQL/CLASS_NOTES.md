# Practical PL/pgSQL Projects
**Series:** PostgreSQL Mastery | **Phase:** Phase 14: PL/pgSQL Programming | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we bring together everything from the PL/pgSQL phase. We will build three real-world projects: an audit logging system that tracks all changes to a table, a data validation function that enforces business rules and collects all errors at once, and a batch processing procedure that handles large datasets safely with intermediate commits. These are patterns you will use in production. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### PL/pgSQL Phase — Complete Pattern Reference
Here is a summary of all PL/pgSQL patterns from the entire phase — when to use each one, with the key command. Bookmark this reference. You now have a complete toolkit for server-side programming in PostgreSQL.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a summary of all PL/pgSQL patterns from the entire phase — when to use each one, with the key command |
| **Point 2** | Bookmark this reference |
| **Point 3** | You now have a complete toolkit for server-side programming in PostgreSQL |

### Practice Exercises
Practice exercises: extend the audit log to track DELETE operations, add more validation rules, create a batch processing procedure for another table, combine audit logging with error handling, and build a complete CRUD layer for a new table using all the patterns.

- 1. Audit: add audited_delete_account() function
- 2. Validation: add email format check (must contain @)
- 3. Batch: process 1000 test rows with COMMIT every 100
- 4. Combine: audit + error handling in one function
- 5. Safe transfer: try edge cases (0 amount, same account)
- 6. Review: which functions should be IMMUTABLE/STABLE?
- 7. Challenge: build complete CRUD layer for a new table


---

## 3. Hands-On Commands & psql Output

### Project 1: Audit Log — Table Setup
**Explanation:** Project one: audit logging. Every production database needs an audit trail. When a row is inserted, updated, or deleted, you want to know: what table, what operation, what was the old data, what is the new data, who did it, and when. We store all of this in a single audit_log table using JSONB for the old and new data — JSONB is perfect because it can store any row from any table.

```sql
practice=# CREATE TABLE audit_log (
    id         SERIAL PRIMARY KEY,
    table_name VARCHAR(50)   NOT NULL,
    operation  VARCHAR(10)   NOT NULL,
    row_id     INT,
    old_data   JSONB,
    new_data   JSONB,
    changed_by VARCHAR(50)   DEFAULT current_user,
    changed_at TIMESTAMP     DEFAULT NOW()
);
CREATE TABLE

-- Stores: WHAT changed (table, operation, row ID)
--         BEFORE/AFTER data as JSONB
--         WHO (current_user) and WHEN (NOW())
```

### Core Audit Function
**Explanation:** The core audit function takes the table name, operation type, row ID, and old and new data. For an INSERT, old data is NULL. For a DELETE, new data is NULL. For an UPDATE, both are provided. We use to_jsonb to convert a table row into JSONB. The function returns VOID since it just logs — call it with PERFORM, not SELECT.

```sql
practice=# CREATE OR REPLACE FUNCTION log_audit(
    p_table VARCHAR, p_op VARCHAR,
    p_row_id INT,
    p_old JSONB DEFAULT NULL,
    p_new JSONB DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO audit_log(table_name, operation, row_id,
                          old_data, new_data)
    VALUES (p_table, p_op, p_row_id, p_old, p_new);
END;
$$ LANGUAGE plpgsql;

-- RETURNS VOID → call with PERFORM, not SELECT
-- PERFORM log_audit('accounts', 'UPDATE', 1, old, new);
-- INSERT: old=NULL, new=row data
-- DELETE: old=row data, new=NULL
-- UPDATE: old=before, new=after
```

### Audited UPDATE Function
**Explanation:** Now let us build the audited INSERT, UPDATE, and DELETE functions. Each one performs the operation AND logs it to the audit table. The UPDATE function captures the row before and after the change. The INSERT logs the new row. The DELETE logs the old row. Each also handles the case where the target row does not exist.

```sql
practice=# CREATE OR REPLACE FUNCTION audited_update_balance(
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

practice=# SELECT audited_update_balance(1, 1500);
 Updated and logged
```

### Audited INSERT with Error Handling
**Explanation:** The audited INSERT function with error handling. It catches unique_violation — if the account already exists, it returns a friendly message instead of crashing. On success, it logs the new row to the audit table. Notice the EXCEPTION block — if the INSERT fails, the log_audit call never happens because PL/pgSQL rolls back the block.

```sql
practice=# CREATE OR REPLACE FUNCTION audited_insert_account(
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

practice=# SELECT audited_insert_account(10, 'Frank', 600);
 Inserted and logged: Frank
practice=# SELECT audited_insert_account(10, 'Frank', 600);
 Account 10 already exists
```

### Querying the Audit Log
**Explanation:** Querying the audit log. The power of storing old and new data as JSONB is that you can extract specific fields with the arrow operator. This lets you see exactly what changed — old balance versus new balance — without storing separate columns for every field.

```sql
practice=# SELECT id, operation, row_id,
  old_data->>'bal' AS old_bal,
  new_data->>'bal' AS new_bal,
  changed_by, changed_at::TEXT
FROM audit_log ORDER BY id;
 id | operation | row_id | old_bal  | new_bal  | changed_by |     changed_at
----+-----------+--------+---------+---------+------------+--------------------
  1 | UPDATE    |      1 | 1000.00 | 1500.00 | postgres   | 2024-01-15 10:30:00
  2 | INSERT    |     10 |         |  600.00 | postgres   | 2024-01-15 10:31:00

-- JSONB ->> 'key' extracts as TEXT
-- JSONB -> 'key' extracts as JSONB
-- You can query: WHERE old_data->>'bal' != new_data->>'bal'
-- to find all balance changes
```

### Project 2: Multi-Rule Validation
**Explanation:** Project two: data validation. Instead of letting PostgreSQL throw individual constraint errors one at a time, we validate ALL business rules upfront and collect every error into an array. The caller sees all problems at once. This is a much better experience — fix everything in one go instead of playing whack-a-mole with errors.

```sql
practice=# CREATE OR REPLACE FUNCTION validate_and_insert(
    p_id INT, p_name VARCHAR, p_bal NUMERIC
) RETURNS TEXT AS $$
DECLARE
    errors TEXT[] := '{}';
    existing INT;
BEGIN
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        errors := array_append(errors, 'Name cannot be empty');
    END IF;
    IF p_name IS NOT NULL AND LENGTH(p_name) > 50 THEN
        errors := array_append(errors, 'Name too long');
    END IF;
    IF p_name IS NOT NULL AND p_name !~ '^[A-Za-z]' THEN
        errors := array_append(errors, 'Must start with letter');
    END IF;
    IF p_bal IS NULL OR p_bal < 0 THEN
        errors := array_append(errors, 'Balance invalid');
    END IF;
    SELECT COUNT(*) INTO existing FROM accounts
      WHERE LOWER(name) = LOWER(p_name);
    IF existing > 0 THEN
        errors := array_append(errors, 'Name exists');
    END IF;
    IF array_length(errors, 1) > 0 THEN
        RETURN 'ERRORS: ' || array_to_string(errors, '; ');
    END IF;
    INSERT INTO accounts VALUES (p_id, TRIM(p_name), p_bal);
    RETURN 'OK: Inserted ' || p_name;
END;
$$ LANGUAGE plpgsql;
```

### Testing Validation
**Explanation:** Let us test the validation. Valid input succeeds. Invalid inputs return ALL errors at once. Multiple rules can fail together — empty name with negative balance shows both errors. Duplicate name is caught too. This is the pattern used in production APIs.

```sql
practice=# SELECT validate_and_insert(10, 'Frank', 600);
 OK: Inserted Frank

practice=# SELECT validate_and_insert(11, '', -100);
 ERRORS: Name cannot be empty; Balance invalid

practice=# SELECT validate_and_insert(12, '123Bad', -50);
 ERRORS: Must start with letter; Balance invalid

practice=# SELECT validate_and_insert(13, 'Alice', 500);
 ERRORS: Name exists

practice=# DELETE FROM accounts WHERE id >= 10;
```

### Project 3: Batch Interest Processing
**Explanation:** Project three: batch processing. A procedure that applies interest to all accounts with COMMIT after every batch. If the process crashes at row 500, the first 400 rows are already saved — you do not lose everything. The batch_size parameter controls how many rows to process before each COMMIT. This is how you handle millions of rows safely.

```sql
practice=# CREATE OR REPLACE PROCEDURE apply_interest(
    rate NUMERIC, batch_size INT DEFAULT 2
) AS $$
DECLARE
    rec RECORD; counter INT := 0;
    total_added NUMERIC := 0; interest NUMERIC;
BEGIN
    RAISE NOTICE 'Applying %% interest...', rate * 100;
    FOR rec IN SELECT id, name, bal FROM accounts ORDER BY id
    LOOP
        interest := ROUND(rec.bal * rate, 2);
        UPDATE accounts SET bal = bal + interest WHERE id = rec.id;
        total_added := total_added + interest;
        counter := counter + 1;
        IF counter % batch_size = 0 THEN
            COMMIT;
            RAISE NOTICE 'Committed batch (% done)', counter;
        END IF;
    END LOOP;
    COMMIT;
    RAISE NOTICE 'Done: % accounts, $% added', counter, total_added;
END;
$$ LANGUAGE plpgsql;

practice=# CALL apply_interest(0.05);
NOTICE:  Applying 5% interest...
NOTICE:  Committed batch (2 done)
NOTICE:  Done: 3 accounts, $90.00 added
```

### Combined Pattern: Safe Audited Transfer
**Explanation:** The ultimate pattern: combining validation, audit logging, and error handling in one function. This safe transfer function validates the inputs, checks balances, performs the transfer, logs both sides to the audit table, and catches any unexpected error with GET STACKED DIAGNOSTICS. This is production-quality code.

```sql
practice=# CREATE OR REPLACE FUNCTION safe_audited_transfer(
    from_id INT, to_id INT, amount NUMERIC
) RETURNS TEXT AS $$
DECLARE
    from_row JSONB; to_row JSONB; from_bal NUMERIC;
    v_state TEXT; v_msg TEXT;
BEGIN
    IF amount <= 0 THEN RETURN 'Amount must be positive'; END IF;
    IF from_id = to_id THEN RETURN 'Cannot self-transfer'; END IF;
    SELECT to_jsonb(a), a.bal INTO from_row, from_bal
      FROM accounts a WHERE id = from_id;
    IF from_row IS NULL THEN RETURN 'Source not found'; END IF;
    IF from_bal < amount THEN RETURN 'Insufficient funds'; END IF;
    SELECT to_jsonb(a) INTO to_row FROM accounts a WHERE id = to_id;
    IF to_row IS NULL THEN RETURN 'Dest not found'; END IF;

    UPDATE accounts SET bal = bal - amount WHERE id = from_id;
    UPDATE accounts SET bal = bal + amount WHERE id = to_id;
    PERFORM log_audit('accounts','XFER-OUT',from_id,from_row,NULL);
    PERFORM log_audit('accounts','XFER-IN',to_id,NULL,to_row);
    RETURN format('OK: $%s from %s to %s', amount, from_id, to_id);
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE,
                            v_msg = MESSAGE_TEXT;
    PERFORM log_audit('accounts','ERROR',from_id,NULL,
      jsonb_build_object('error',v_msg,'state',v_state));
    RAISE;
END; $$ LANGUAGE plpgsql;
```

### Testing Safe Audited Transfer
**Explanation:** Testing the safe transfer. A successful transfer returns OK and logs both sides. Validation failures return immediately. And if an unexpected error occurs, it is caught, logged to the audit table, and re-raised so the caller still gets the error.

```sql
practice=# SELECT safe_audited_transfer(1, 2, 100);
 OK: $100 from 1 to 2

practice=# SELECT name, bal FROM accounts ORDER BY id;
 name  |  bal
-------+--------
 Alice | 1400.00
 Bob   |  600.00
 Carol |  300.00

-- Validation catches bad inputs immediately:
practice=# SELECT safe_audited_transfer(1, 2, -50);
 Amount must be positive
practice=# SELECT safe_audited_transfer(1, 1, 100);
 Cannot self-transfer
practice=# SELECT safe_audited_transfer(1, 2, 999999);
 Insufficient funds
```

### Beginner Trap: PERFORM vs SELECT
**Explanation:** Beginner trap: PERFORM versus SELECT for void functions. When calling a function that returns VOID, use PERFORM — not SELECT. SELECT would try to return a result row, but VOID has nothing to return. PERFORM discards the result. This is specific to PL/pgSQL — in plain SQL at the psql prompt, you still use SELECT to call any function.

```sql
-- Inside PL/pgSQL: use PERFORM for void functions
-- CORRECT:
-- PERFORM log_audit('accounts', 'UPDATE', 1, old, new);

-- WRONG (inside PL/pgSQL):
-- SELECT log_audit(...);  ← tries to return a result

-- At the psql prompt: SELECT works fine
-- SELECT safe_audited_transfer(1, 2, 100);  ← OK

-- Rule of thumb:
-- PERFORM = call function, discard result
-- SELECT ... INTO = call function, capture result
-- SELECT (bare) = only at psql prompt, not in PL/pgSQL
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: PERFORM vs SELECT
Beginner trap: PERFORM versus SELECT for void functions. When calling a function that returns VOID, use PERFORM — not SELECT. SELECT would try to return a result row, but VOID has nothing to return. PERFORM discards the result. This is specific to PL/pgSQL — in plain SQL at the psql prompt, you still use SELECT to call any function.

```sql
-- Inside PL/pgSQL: use PERFORM for void functions
-- CORRECT:
-- PERFORM log_audit('accounts', 'UPDATE', 1, old, new);

-- WRONG (inside PL/pgSQL):
-- SELECT log_audit(...);  ← tries to return a result

-- At the psql prompt: SELECT works fine
-- SELECT safe_audited_transfer(1, 2, 100);  ← OK

-- Rule of thumb:
-- PERFORM = call function, discard result
-- SELECT ... INTO = call function, capture result
-- SELECT (bare) = only at psql prompt, not in PL/pgSQL
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap the entire PL/pgSQL phase. We started with SQL functions and PL/pgSQL basics — DECLARE, BEGIN, END, variables, percent-TYPE. Added control flow with IF, ELSIF, CASE, and RAISE for debugging. Learned loops — FOR, WHILE, FOREACH — and set-returning functions with RETURN NEXT. Created procedures with transaction control using COMMIT and ROLLBACK. Used cursors for row-by-row processing and dynamic SQL with EXECUTE and format. Built robust error handling with EXCEPTION blocks and GET STACKED DIAGNOSTICS. And today, we combined everything into production patterns — audit logging with JSONB, multi-rule validation with error arrays, batch processing with intermediate commits, and a safe transfer function that validates, audits, and handles errors. This completes the PL/pgSQL phase!

- **SQL functions: pure SQL, fast, inlinable**
- **PL/pgSQL: DECLARE/BEGIN/END, variables, %TYPE**
- **Control flow: IF/ELSIF/CASE, RAISE NOTICE/EXCEPTION**
- **Loops: FOR, WHILE, FOREACH, RETURN NEXT/QUERY**
- **Procedures: CALL, COMMIT/ROLLBACK inside body**
- **Cursors & dynamic SQL: EXECUTE format(%I, %L)**
- **Error handling: EXCEPTION, GET STACKED DIAGNOSTICS**
- **Projects: audit log, validation, batch, safe transfer**


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
