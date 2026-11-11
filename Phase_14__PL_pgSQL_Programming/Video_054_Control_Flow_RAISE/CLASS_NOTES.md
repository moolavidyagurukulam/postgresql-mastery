# PL/pgSQL Control Flow & RAISE
**Series:** PostgreSQL Mastery | **Phase:** Phase 14: PL/pgSQL Programming | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we dive into PL/pgSQL control flow — IF, ELSIF, ELSE, CASE, and the RAISE command for debugging and error messages. Control flow lets your functions make decisions. RAISE lets you print debug messages, warnings, and throw custom errors. These are essential tools for writing real-world PL/pgSQL. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### RAISE — Debugging & Error Messages
RAISE is your debugging and error tool. It has five levels: DEBUG, LOG, INFO, NOTICE, and WARNING print messages but let execution continue. EXCEPTION stops execution and rolls back the transaction. Use percent signs as placeholders — they are replaced with your values in order. RAISE NOTICE is the most common for debugging — it prints to the client.

| Term | Meaning / Explanation |
| :--- | :--- |
| **RAISE DEBUG** | Lowest level, hidden by default (set client_min_messages) |
| **RAISE LOG** | Written to server log only |
| **RAISE INFO** | Informational, shown to client |
| **RAISE NOTICE** | Most common for debugging — shown to client |
| **RAISE WARNING** | Warning — shown to client, execution continues |
| **RAISE EXCEPTION** | ERROR — stops execution, rolls back transaction |

**Notes:**
- Use % as placeholder: RAISE NOTICE 'bal = %', my_var;
- EXCEPTION is the only level that stops execution

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Beginner Trap: NULL in Conditionals
The NULL check is a common beginner trap. In PL/pgSQL, NULL is not equal to anything — not even itself. Use IS NULL and IS NOT NULL, never equals-NULL. Also, IF with a NULL condition falls through to ELSE — it does not match THEN. COALESCE replaces NULL with a default value.

| Wrong (Common Mistakes) | Correct |
| :--- | :--- |
| IF x = NULL THEN  -- NEVER true! | IF x IS NULL THEN |
| IF x != NULL THEN -- NEVER true! | IF x IS NOT NULL THEN |
| IF NULL THEN      -- goes to ELSE | IF COALESCE(x, 0) > 0 THEN |
| x := y + NULL;    -- result is NULL | x := COALESCE(y, 0) + 1; |
| SELECT INTO x ... (no rows → x is NULL) | Check FOUND after SELECT INTO |

### Decision Framework: IF vs CASE vs RAISE
When should you use IF versus CASE versus RAISE? Here is the decision framework. Use IF ELSIF for sequential condition checks with different actions. Use simple CASE when comparing one variable against fixed values. Use searched CASE for assigning one variable from multiple conditions. Use RAISE NOTICE for debugging. Use RAISE EXCEPTION for business rule violations. Use ASSERT for development-time invariants.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | When should you use IF versus CASE versus RAISE? |
| **Point 2** | Use IF ELSIF for sequential condition checks with different actions |
| **Point 3** | Use simple CASE when comparing one variable against fixed values |
| **Point 4** | Use searched CASE for assigning one variable from multiple conditions |
| **Point 5** | Use RAISE NOTICE for debugging |
| **Point 6** | Use RAISE EXCEPTION for business rule violations |
| **Use ASSERT for development** | time invariants |

### Practice Exercises
Practice exercises: create a function with IF/ELSIF that categorizes ages, use CASE to convert status codes to labels, add RAISE NOTICE debugging to an existing function, write a validation function that checks multiple conditions and raises specific errors, test NULL handling in conditionals, and use ASSERT to guard function inputs.

- 1. age_category(age INT): child/teen/adult/senior IF/ELSIF
- 2. status_label(code CHAR): CASE 'A'→Active, 'S'→Suspended
- 3. Add RAISE NOTICE to trace the transfer function
- 4. validate_email(email TEXT): check @ and . present
- 5. Test: IF NULL THEN → which branch runs?
- 6. Test: PL/pgSQL CASE without ELSE → what happens?
- 7. ASSERT: guard a function with assertions
- 8. Disable ASSERTs: SET plpgsql.check_asserts = off


---

## 3. Hands-On Commands & psql Output

### IF / ELSIF / ELSE Structure
**Explanation:** IF THEN is the simplest conditional. If the condition is true, the code runs. Add ELSE for an alternative path. Add ELSIF for multiple conditions — PostgreSQL checks them top to bottom and runs the first match. Always close with END IF and a semicolon. You can nest IF blocks inside each other, but ELSIF is usually cleaner.

```sql
-- Simple IF
IF balance < 0 THEN
    status := 'overdrawn';
END IF;

-- IF / ELSE
IF balance >= 100 THEN
    status := 'sufficient';
ELSE
    status := 'low';
END IF;

-- IF / ELSIF / ELSE (multiple conditions)
IF balance >= 10000 THEN
    tier := 'platinum';
ELSIF balance >= 5000 THEN
    tier := 'gold';
ELSIF balance >= 1000 THEN
    tier := 'silver';
ELSE
    tier := 'bronze';
END IF;

-- Note: ELSIF (not ELSEIF, not ELSE IF)
```

### IF/ELSIF Function — Account Tier
**Explanation:** Let us build a real function using IF ELSIF. This function takes an account ID and returns its tier based on balance. It also checks if the account exists using the FOUND variable. Notice how each branch assigns a different value and we return the result at the end.

```sql
practice=# CREATE OR REPLACE FUNCTION account_tier(acct_id INT)
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

practice=# SELECT name, bal, account_tier(id) FROM accounts;
 name  |   bal   | account_tier
-------+---------+-------------
 Alice | 1000.00 | Silver
 Bob   |  500.00 | Bronze
 Carol |  300.00 | Bronze
```

### CASE — Simple and Searched Forms
**Explanation:** CASE is another way to handle multiple conditions. PL/pgSQL has two forms. The simple CASE compares one expression against multiple values — like a switch statement. The searched CASE evaluates separate boolean conditions — like IF ELSIF but often cleaner when assigning a single variable. Both end with END CASE.

```sql
-- Simple CASE: compare one expression
CASE status
    WHEN 'active' THEN
        result := 'Account is active';
    WHEN 'suspended' THEN
        result := 'Account is suspended';
    WHEN 'closed' THEN
        result := 'Account is closed';
    ELSE
        result := 'Unknown status: ' || status;
END CASE;

-- Searched CASE: separate conditions
CASE
    WHEN age < 13 THEN
        category := 'child';
    WHEN age < 18 THEN
        category := 'teen';
    WHEN age < 65 THEN
        category := 'adult';
    ELSE
        category := 'senior';
END CASE;
```

### Beginner Trap: CASE Without ELSE
**Explanation:** Beginner trap: PL/pgSQL CASE without ELSE raises an error if no branch matches! This is different from SQL CASE expression, which returns NULL when no match. Always include ELSE in PL/pgSQL CASE statements to avoid this surprise error.

```sql
practice=# DO $$ DECLARE x INT := 5; result TEXT; BEGIN
  CASE x
    WHEN 1 THEN result := 'one';
    WHEN 2 THEN result := 'two';
    -- No ELSE, and x is 5 → no match!
  END CASE;
END $$;
ERROR:  case not found
HINT:  CASE statement is missing ELSE part.

-- Fix: always add ELSE
practice=# DO $$ DECLARE x INT := 5; result TEXT; BEGIN
  CASE x
    WHEN 1 THEN result := 'one';
    WHEN 2 THEN result := 'two';
    ELSE result := 'other';  -- always safe!
  END CASE;
  RAISE NOTICE 'result: %', result;
END $$;
NOTICE:  result: other
```

### RAISE in Action
**Explanation:** Let us see RAISE in action. RAISE NOTICE prints messages while the function runs — perfect for debugging. You can include multiple placeholders. RAISE EXCEPTION stops the function and returns an error to the caller. You can also add USING HINT to suggest a fix, and USING ERRCODE to set a specific error code.

```sql
practice=# CREATE OR REPLACE FUNCTION debug_demo(n INT)
RETURNS TEXT AS $$
BEGIN
    RAISE NOTICE 'Function called with n = %', n;
    RAISE NOTICE 'Doubling: % * 2 = %', n, n * 2;

    IF n < 0 THEN
        RAISE EXCEPTION 'n must be positive, got %', n
            USING HINT = 'Pass a positive integer',
                  ERRCODE = 'invalid_parameter_value';
    END IF;

    RAISE NOTICE 'Returning result';
    RETURN format('Result: %s', n * 2);
END; $$ LANGUAGE plpgsql;

practice=# SELECT debug_demo(5);
NOTICE:  Function called with n = 5
NOTICE:  Doubling: 5 * 2 = 10
NOTICE:  Returning result
 Result: 10

practice=# SELECT debug_demo(-3);
NOTICE:  Function called with n = -3
ERROR:  n must be positive, got -3
HINT:  Pass a positive integer
```

### Practical: Transfer with Validation & Debug
**Explanation:** Let us build a practical function that validates and processes a money transfer. It uses IF checks for every possible problem — missing accounts, negative amounts, insufficient funds — and RAISE NOTICE to log each step. This is how real-world PL/pgSQL functions look: validate everything, log everything, raise clear errors.

```sql
practice=# CREATE OR REPLACE FUNCTION transfer(
    from_id INT, to_id INT, amount NUMERIC
) RETURNS TEXT AS $$
DECLARE
    from_bal NUMERIC; from_name VARCHAR; to_name VARCHAR;
BEGIN
    IF amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be positive';
    END IF;
    IF from_id = to_id THEN
        RAISE EXCEPTION 'Cannot transfer to same account';
    END IF;
    SELECT name, bal INTO from_name, from_bal
      FROM accounts WHERE id = from_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source account % not found', from_id;
    END IF;
    SELECT name INTO to_name FROM accounts WHERE id = to_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dest account % not found', to_id;
    END IF;
    IF from_bal < amount THEN
        RAISE EXCEPTION '% has only %, need %',
            from_name, from_bal, amount;
    END IF;
    UPDATE accounts SET bal = bal - amount WHERE id = from_id;
    UPDATE accounts SET bal = bal + amount WHERE id = to_id;
    RAISE NOTICE 'Transfer complete: % → %', from_name, to_name;
    RETURN format('Transferred %s from %s to %s',
                  amount, from_name, to_name);
END; $$ LANGUAGE plpgsql;
```

### Testing the Transfer Function
**Explanation:** Let us test the transfer function. A successful transfer moves money and returns a confirmation. Each invalid input produces a clear, specific error. The function validates everything before performing any updates — if any check fails, nothing changes.

```sql
practice=# SELECT transfer(1, 2, 100);
NOTICE:  Transfer complete: Alice → Bob
 Transferred 100 from Alice to Bob

practice=# SELECT name, bal FROM accounts ORDER BY id;
 name  |  bal
-------+--------
 Alice | 900.00
 Bob   | 600.00
 Carol | 300.00

practice=# SELECT transfer(1, 2, -50);
ERROR:  Amount must be positive
practice=# SELECT transfer(3, 1, 999);
ERROR:  Carol has only 300.00, need 999
practice=# SELECT transfer(1, 1, 50);
ERROR:  Cannot transfer to same account
practice=# SELECT transfer(99, 1, 50);
ERROR:  Source account 99 not found
```

### ASSERT — Debug-Time Checks
**Explanation:** ASSERT is a debugging tool added in PostgreSQL 9.5. It checks a condition and raises an error if the condition is false. Unlike RAISE EXCEPTION, ASSERTs can be disabled in production with plpgsql.check_asserts set to off. Use them to verify assumptions during development — like checking that a count is never negative or a record was found.

```sql
practice=# CREATE OR REPLACE FUNCTION checked_withdraw(
    acct_id INT, amount NUMERIC
) RETURNS NUMERIC AS $$
DECLARE
    current_bal NUMERIC;
BEGIN
    ASSERT amount > 0, 'Amount must be positive';
    ASSERT acct_id IS NOT NULL, 'Account ID required';

    SELECT bal INTO current_bal FROM accounts WHERE id = acct_id;
    ASSERT FOUND, format('Account %s not found', acct_id);
    ASSERT current_bal >= amount, 'Insufficient funds';

    UPDATE accounts SET bal = bal - amount WHERE id = acct_id;
    RETURN current_bal - amount;
END; $$ LANGUAGE plpgsql;

practice=# SELECT checked_withdraw(1, -10);
ERROR:  Amount must be positive

-- Disable in production:
-- SET plpgsql.check_asserts = off;
-- ASSERT is skipped entirely when disabled
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: CASE Without ELSE
Beginner trap: PL/pgSQL CASE without ELSE raises an error if no branch matches! This is different from SQL CASE expression, which returns NULL when no match. Always include ELSE in PL/pgSQL CASE statements to avoid this surprise error.

```sql
DO $$ DECLARE x INT := 5; result TEXT; BEGIN
  CASE x
    WHEN 1 THEN result := 'one';
    WHEN 2 THEN result := 'two';
    -- No ELSE, and x is 5 → no match!
  END CASE;
END $$;
ERROR:  case not found
HINT:  CASE statement is missing ELSE part.

-- Fix: always add ELSE
DO $$ DECLARE x INT := 5; result TEXT; BEGIN
  CASE x
    WHEN 1 THEN result := 'one';
    WHEN 2 THEN result := 'two';
    ELSE result := 'other';  -- always safe!
  END CASE;
  RAISE NOTICE 'result: %', result;
END $$;
NOTICE:  result: other
```

### Beginner Trap: NULL in Conditionals
The NULL check is a common beginner trap. In PL/pgSQL, NULL is not equal to anything — not even itself. Use IS NULL and IS NOT NULL, never equals-NULL. Also, IF with a NULL condition falls through to ELSE — it does not match THEN. COALESCE replaces NULL with a default value.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. IF, ELSIF, ELSE let your functions make decisions — always close with END IF. CASE handles multiple values or conditions — always include ELSE or risk 'case not found' error. RAISE NOTICE is your debugging tool. RAISE EXCEPTION stops execution and rolls back. ASSERT checks invariants during development and can be disabled in production. NULL is tricky — always use IS NULL, never equals NULL. Validate ALL inputs before making changes. In the next class, we cover loops and set-returning functions.

- **IF / ELSIF / ELSE / END IF: conditional branches**
- **CASE value WHEN ... END CASE: always add ELSE!**
- **Searched CASE WHEN condition THEN ...**
- **RAISE NOTICE 'msg %', var: debug output**
- **RAISE EXCEPTION: stops, rolls back transaction**
- **ASSERT condition, 'msg': dev-time check**
- **NULL: use IS NULL, never = NULL**
- **FOUND: check after SELECT INTO**
- **Validate ALL inputs before any database change**


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
