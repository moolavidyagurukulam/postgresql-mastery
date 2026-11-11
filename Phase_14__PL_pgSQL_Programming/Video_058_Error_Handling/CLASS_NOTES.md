# PL/pgSQL Error Handling
**Series:** PostgreSQL Mastery | **Phase:** Phase 14: PL/pgSQL Programming | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover PL/pgSQL error handling. The EXCEPTION block lets you catch errors, log them, and decide what to do — retry, return a default, or re-raise. GET STACKED DIAGNOSTICS gives you error details like the SQLSTATE code and message. Robust functions handle failures gracefully instead of crashing. Let us begin.


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

### Common SQLSTATE Conditions
Here are the most common SQLSTATE condition names you will handle. unique_violation for duplicate keys, foreign_key_violation for broken references, not_null_violation for missing required values, check_violation for failed check constraints, and numeric_value_out_of_range for overflow. You can catch by name or by the five-character SQLSTATE code directly.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are the most common SQLSTATE condition names you will handle |
| **unique_violation for duplicate keys** | foreign_key_violation for broken references, not_null_violation for missing required values, check_violation for fail... |
| **You can catch by name or by the five** | character SQLSTATE code directly |

### EXCEPTION Block — Rollback Behavior
Important behavior: when an EXCEPTION block catches an error, all database changes inside that BEGIN block are rolled back. PostgreSQL uses an implicit savepoint. This means if your function inserted five rows and then failed on the sixth, all six are undone when the exception is caught. Only changes BEFORE that BEGIN block survive. Variables are NOT rolled back — only database changes.

| Rolled Back (Database) | NOT Rolled Back |
| :--- | :--- |
| All INSERTs inside the block | Variable assignments survive |
| All UPDATEs inside the block | Changes in outer blocks survive |
| All DELETEs inside the block | RAISE NOTICE already printed |
| DDL (CREATE, ALTER) in the block | Changes committed by PROCEDURE |
| Sequence advances ARE rolled back | Changes before the BEGIN block |

### Beginner Trap: EXCEPTION Performance Cost
Beginner trap: EXCEPTION blocks have a performance cost. PostgreSQL sets up an implicit savepoint for every BEGIN block that has an EXCEPTION clause, even if no error occurs. If you call a function with EXCEPTION in a tight loop — say a million times — you pay the savepoint cost a million times. Only use EXCEPTION where you actually expect errors. For validation, check conditions with IF before doing the operation.

| Slow: Catch Every Error | Fast: Check First |
| :--- | :--- |
| BEGIN | IF EXISTS (SELECT 1 FROM accounts |
|   INSERT INTO accounts ... |   WHERE id = p_id) THEN |
| EXCEPTION WHEN unique_violation |   RETURN 'exists'; |
|   RETURN 'exists'; | END IF; |
| END; | INSERT INTO accounts ... |
| Cost: savepoint on EVERY call | Cost: one SELECT, no savepoint |

### Error Handling Decision Framework
When should you use which error handling pattern? Here is the decision framework. For expected conditions like duplicates or missing rows, check with IF first — it is faster. For unexpected errors, use EXCEPTION with WHEN OTHERS. For business rule violations, raise custom errors with RAISE EXCEPTION. For critical operations, log errors and re-raise. For nested risky operations, use inner BEGIN blocks to isolate failures.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | When should you use which error handling pattern? |
| **Point 2** | For expected conditions like duplicates or missing rows, check with IF first — it is faster |
| **For unexpected errors** | use EXCEPTION with WHEN OTHERS |
| **For business rule violations** | raise custom errors with RAISE EXCEPTION |
| **For critical operations** | log errors and re-raise |
| **For nested risky operations** | use inner BEGIN blocks to isolate failures |

### Practice Exercises
Practice exercises: write a function that catches unique_violation and returns a friendly message, use GET STACKED DIAGNOSTICS to log error details, raise custom errors with RAISE EXCEPTION and ERRCODE, test the rollback behavior by inserting rows before an intentional error, use nested BEGIN blocks to isolate failures, and build an error log table with a logging function.

- 1. safe_insert: catch unique_violation, return message
- 2. GET STACKED DIAGNOSTICS: capture state, message, detail
- 3. RAISE EXCEPTION: custom error with ERRCODE and HINT
- 4. RAISE (bare): re-raise original error after logging
- 5. Nested BEGIN: inner error, outer continues
- 6. Test rollback: INSERT rows, fail, verify all undone
- 7. Performance: compare IF-check vs EXCEPTION approach
- 8. Error log: catch, log to table, then re-raise


---

## 3. Hands-On Commands & psql Output

### EXCEPTION Block Structure
**Explanation:** The EXCEPTION block sits at the end of a BEGIN END block. When an error occurs inside BEGIN, PostgreSQL jumps to the EXCEPTION section and matches the error against WHEN conditions. If a match is found, that handler runs. If no match, the error propagates to the caller. The EXCEPTION block is like try-catch in other languages. An important detail: when an EXCEPTION block catches an error, all changes inside that BEGIN block are automatically rolled back — it uses a savepoint internally.

```sql
BEGIN
    -- your code here
    -- if an error occurs, jump to EXCEPTION

EXCEPTION
    WHEN division_by_zero THEN
        -- handle divide by zero
        RAISE NOTICE 'Cannot divide by zero!';
        RETURN 0;

    WHEN no_data_found THEN
        -- handle missing data
        RAISE NOTICE 'No rows found';
        RETURN NULL;

    WHEN OTHERS THEN
        -- catch-all for any other error
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
        RETURN NULL;
END;

-- Key: changes inside BEGIN are ROLLED BACK
-- when EXCEPTION catches an error (uses savepoint)
```

### EXCEPTION in Action — Division Safety
**Explanation:** Let us see EXCEPTION in action. This function divides two numbers but catches division by zero. Instead of crashing, it returns zero and logs a notice. The SQLERRM variable contains the error message, and SQLSTATE contains the five-character error code. These are automatically available inside any EXCEPTION handler.

```sql
practice=# CREATE OR REPLACE FUNCTION safe_divide(a NUMERIC, b NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
    RETURN a / b;
EXCEPTION
    WHEN division_by_zero THEN
        RAISE NOTICE 'Division by zero! Returning 0';
        RETURN 0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

practice=# SELECT safe_divide(100, 4);
 25.0000000000000000

practice=# SELECT safe_divide(100, 0);
NOTICE:  Division by zero! Returning 0
 safe_divide
-------------
           0
```

### WHEN OTHERS & Multiple Handlers
**Explanation:** WHEN OTHERS catches any error not handled by a specific WHEN clause. Inside any handler, SQLERRM gives the error message and SQLSTATE gives the five-character code. You can catch by condition name or by SQLSTATE code directly. Always put specific handlers before WHEN OTHERS — PostgreSQL checks them in order and uses the first match.

```sql
practice=# CREATE OR REPLACE FUNCTION safe_insert(
    acct_id INT, acct_name VARCHAR, balance NUMERIC
) RETURNS TEXT AS $$
BEGIN
    INSERT INTO accounts VALUES (acct_id, acct_name, balance);
    RETURN 'Inserted ' || acct_name;
EXCEPTION
    WHEN unique_violation THEN
        RETURN 'Account ' || acct_id || ' already exists';
    WHEN check_violation THEN
        RETURN 'Check constraint failed';
    WHEN OTHERS THEN
        RETURN 'Error [' || SQLSTATE || ']: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

practice=# SELECT safe_insert(10, 'Frank', 600);
 Inserted Frank
practice=# SELECT safe_insert(10, 'Frank', 600);
 Account 10 already exists
practice=# SELECT safe_insert(1, 'Duplicate', 100);
 Account 1 already exists
```

### GET STACKED DIAGNOSTICS — Error Details
**Explanation:** GET STACKED DIAGNOSTICS captures detailed error information into variables. You can get the SQLSTATE code, the error message, the message detail, the hint, and the context — which shows the call stack. This is essential for error logging — you can write all these details to a log table so you can debug problems later.

```sql
practice=# CREATE OR REPLACE FUNCTION detailed_error_demo()
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

    RETURN format('State: %s | Msg: %s | Detail: %s',
                  v_state, v_msg, v_detail);
END; $$ LANGUAGE plpgsql;

practice=# SELECT detailed_error_demo();
 State: 23505 | Msg: duplicate key value violates
 unique constraint "accounts_pkey" | Detail: Key (id)=(1)
 already exists.
```

### RAISE EXCEPTION — Custom Errors
**Explanation:** You can raise your own custom errors with RAISE EXCEPTION. This is how you enforce business rules — check a condition, and if it fails, raise an error with a custom SQLSTATE code and message. Use the P0001 code for application errors, or define your own codes in the P range. RAISE EXCEPTION stops execution immediately and propagates to the caller's EXCEPTION handler.

```sql
practice=# CREATE OR REPLACE FUNCTION withdraw(acct INT, amt NUMERIC)
RETURNS NUMERIC AS $$
DECLARE
    current_bal NUMERIC;
BEGIN
    SELECT bal INTO STRICT current_bal FROM accounts WHERE id = acct;

    IF amt <= 0 THEN
        RAISE EXCEPTION 'Amount must be positive: %', amt
            USING ERRCODE = 'P0001';
    END IF;
    IF current_bal < amt THEN
        RAISE EXCEPTION 'Insufficient funds: have %, need %',
            current_bal, amt
            USING ERRCODE = 'P0002',
                  HINT = 'Check balance before withdrawing';
    END IF;

    UPDATE accounts SET bal = bal - amt WHERE id = acct;
    RETURN current_bal - amt;
END; $$ LANGUAGE plpgsql;

practice=# SELECT withdraw(1, 999999);
ERROR:  Insufficient funds: have 1000.00, need 999999
HINT:  Check balance before withdrawing
```

### Practical: Error Logging & Re-Raise
**Explanation:** A practical pattern: an error-logging function that catches exceptions, writes them to a log table, and re-raises the error. This way you get both — the error is logged for later debugging, AND the caller still receives the error. Use RAISE without arguments inside an EXCEPTION handler to re-raise the original error unchanged.

```sql
practice=# CREATE TABLE IF NOT EXISTS error_log (
    id       SERIAL PRIMARY KEY,
    func     TEXT,
    sqlstate TEXT,
    message  TEXT,
    detail   TEXT,
    logged   TIMESTAMP DEFAULT NOW()
);

practice=# CREATE OR REPLACE FUNCTION logged_withdraw(acct INT, amt NUMERIC)
RETURNS NUMERIC AS $$
DECLARE
    v_state TEXT; v_msg TEXT; v_detail TEXT;
BEGIN
    RETURN (SELECT withdraw(acct, amt));
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
        v_state = RETURNED_SQLSTATE,
        v_msg = MESSAGE_TEXT,
        v_detail = PG_EXCEPTION_DETAIL;
    INSERT INTO error_log(func, sqlstate, message, detail)
    VALUES ('logged_withdraw', v_state, v_msg, v_detail);
    RAISE;  -- re-raise the original error
END; $$ LANGUAGE plpgsql;
```

### Nested BEGIN Blocks — Local Error Handling
**Explanation:** Nested BEGIN blocks let you handle errors locally without losing outer work. The inner block has its own EXCEPTION handler — if it catches an error, only the inner block is rolled back. The outer block continues normally. This is how you isolate risky operations inside a larger function.

```sql
practice=# CREATE OR REPLACE FUNCTION nested_demo()
RETURNS TEXT AS $$
DECLARE result TEXT := '';
BEGIN
    -- Outer block: this work is safe
    result := 'Step 1 done. ';

    -- Inner block: risky operation isolated
    BEGIN
        INSERT INTO accounts VALUES (1, 'Dupe', 0);
        result := result || 'Step 2 done. ';
    EXCEPTION WHEN unique_violation THEN
        result := result || 'Step 2 skipped (duplicate). ';
    END;

    -- Outer block continues regardless
    result := result || 'Step 3 done.';
    RETURN result;
END; $$ LANGUAGE plpgsql;

practice=# SELECT nested_demo();
 Step 1 done. Step 2 skipped (duplicate). Step 3 done.

-- Inner error caught locally, outer block unaffected!
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: EXCEPTION Performance Cost
Beginner trap: EXCEPTION blocks have a performance cost. PostgreSQL sets up an implicit savepoint for every BEGIN block that has an EXCEPTION clause, even if no error occurs. If you call a function with EXCEPTION in a tight loop — say a million times — you pay the savepoint cost a million times. Only use EXCEPTION where you actually expect errors. For validation, check conditions with IF before doing the operation.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. EXCEPTION blocks catch errors inside BEGIN END. WHEN condition names match specific errors. WHEN OTHERS is the catch-all. SQLERRM and SQLSTATE give quick error info. GET STACKED DIAGNOSTICS captures full details. RAISE EXCEPTION creates custom errors with ERRCODE and HINT. Changes inside the caught block are rolled back. Nested BEGIN blocks isolate failures. EXCEPTION has a performance cost — check with IF first when possible. RAISE without arguments re-raises the original error. In the next class, we bring it all together with practical projects.

- **EXCEPTION: catch errors inside BEGIN/END block**
- **WHEN unique_violation / WHEN OTHERS: match errors**
- **SQLERRM + SQLSTATE: quick error info in handler**
- **GET STACKED DIAGNOSTICS: full error details**
- **RAISE EXCEPTION 'msg' USING ERRCODE: custom errors**
- **RAISE (bare): re-raise original in handler**
- **Rollback: all DB changes in block undone on catch**
- **Nested BEGIN: isolate risky sub-operations**
- **Performance: IF-check > EXCEPTION for expected cases**


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
