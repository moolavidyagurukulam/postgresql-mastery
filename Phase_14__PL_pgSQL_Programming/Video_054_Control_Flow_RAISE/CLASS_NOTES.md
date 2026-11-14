# Class 054: PL/pgSQL Control Flow & RAISE Statements
## PostgreSQL 16 Admin & Developer Mastery Series

---

### Executive Overview
In PostgreSQL server-side programming, robust business logic demands predictable execution flow and precise diagnostic reporting. PL/pgSQL provides powerful procedural branching constructs—`IF-THEN-ELSIF-ELSE` and both Simple and Searched `CASE` statements—alongside the `RAISE` statement for runtime diagnostics and transactional enforcement. 

This guide details the internal mechanics of branch evaluation, explores the critical distinctions between SQL expressions and procedural control flow, explains how `RAISE EXCEPTION` enforces transactional atomicity by triggering immediate rollbacks, and demonstrates how to structure enterprise-grade error reporting using standard SQLSTATE codes, `DETAIL`, and `HINT` attributes.

---

### 1. Branching Constructs in PL/pgSQL

#### The IF Statement Family
PL/pgSQL evaluates conditional branches sequentially. As soon as a condition evaluates to `TRUE`, its block executes and control jumps past `END IF;`.
- **Three-Valued Logic Caution:** In SQL and PL/pgSQL, a boolean condition that yields `NULL` is treated as **NOT TRUE**. Consequently, neither `IF (condition)` nor `ELSIF (condition)` will fire if the condition evaluates to `NULL`; execution will fall through to the `ELSE` block or exit.

```sql
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
```

---

### 2. The CASE Statement: Simple vs Searched

PL/pgSQL supports two distinct forms of the `CASE` statement. Note that a procedural `CASE` statement ends with `END CASE;`, whereas a SQL `CASE` expression ends with `END`.

#### A. Simple CASE (Value Matching)
Compares a single test expression against target values:
```sql
CASE order_status
    WHEN 'PENDING' THEN
        -- perform pending validation
    WHEN 'SHIPPED', 'DELIVERED' THEN
        -- archive or log
    ELSE
        -- default fallback
END CASE;
```

#### B. Searched CASE (Boolean Condition Evaluation)
Evaluates multiple independent boolean conditions in order:
```sql
CASE
    WHEN credit_score >= 800 THEN discount_pct := 0.20;
    WHEN credit_score >= 700 THEN discount_pct := 0.10;
    WHEN credit_score IS NULL THEN discount_pct := 0.00;
    ELSE discount_pct := 0.05;
END CASE;
```

> [!WARNING] The Critical CASE_NOT_FOUND Trap
> If no condition evaluates to `TRUE` and the `ELSE` clause is omitted in a procedural `CASE` statement, PostgreSQL immediately raises a runtime exception with SQLSTATE `20000` (`case_not_found`). Always include an explicit `ELSE` block unless you deliberately intend an unhandled condition to abort the transaction.

---

### 3. The RAISE Statement: Diagnostics & Exceptions

The `RAISE` statement outputs status messages to client sessions, writes diagnostics to the server log, or halts execution and aborts the current transaction.

#### Severity Levels
- `DEBUG` / `LOG`: Emitted to the PostgreSQL engine log depending on `log_min_messages`.
- `INFO`: Always transmitted to the client, unaffected by `client_min_messages`.
- `NOTICE`: Informational message transmitted to the client session (default `client_min_messages` is `NOTICE`). Does **not** halt transaction.
- `WARNING`: Alerts client of a potential issue without terminating the transaction.
- `EXCEPTION`: Triggers an immediate fatal error, aborting execution and rolling back uncommitted changes within the current transaction block.

#### Formatting & Parameter Injection
Use `%` as a placeholder for variable interpolation:
```sql
RAISE NOTICE 'Processing user ID: %, attempts remaining: %', v_user_id, v_retries;
```

#### Structured Error Metadata
Enterprise applications should supply standardized metadata using `USING`:
```sql
RAISE EXCEPTION 'Invalid tax identification number: %', p_tax_id
    USING ERRCODE = 'invalid_parameter_value',
          DETAIL = 'The tax identifier must contain exactly 9 numeric digits.',
          HINT = 'Verify the input format with the billing department.',
          COLUMN = 'tax_id';
```

---

### 4. Hands-On Practice Challenges

#### Challenge 1: Tiered VIP Discount Calculation
Write a function `calc_tier_discount(p_total_spent NUMERIC)` that returns a numeric discount rate:
- Over $10,000 -> 25% (0.25)
- $5,000 to $9,999.99 -> 15% (0.15)
- $1,000 to $4,999.99 -> 10% (0.10)
- Below $1,000 -> 0% (0.00)
- If `p_total_spent` is negative, raise an `EXCEPTION` with code `check_violation`.

#### Challenge 2: Order Status Machine with Simple CASE
Write a function `next_order_stage(p_current_status TEXT)` returning the next permissible status:
- `DRAFT` -> `PENDING`
- `PENDING` -> `PROCESSING`
- `PROCESSING` -> `SHIPPED`
- `SHIPPED` -> `DELIVERED`
- `DELIVERED` -> `ARCHIVED`
- Any unrecognized status must raise an exception: `'Invalid order stage transition from %'`.

#### Challenge 3: Guard Clause Validation
Write a function `register_system_user(p_username TEXT, p_email TEXT, p_role TEXT)`:
- Validates that `p_username` is at least 3 characters.
- Validates that `p_email` contains `@`.
- Uses `CASE` to ensure `p_role` is strictly `'admin'`, `'analyst'`, or `'operator'`.
- Emits a `RAISE NOTICE` welcoming the user, and returns their generated ID.

#### Challenge 4: Safe Division with Warning
Write a function `safe_metric_ratio(p_numerator NUMERIC, p_denominator NUMERIC)` returning `NUMERIC`:
- If `p_denominator = 0`, emit a `RAISE WARNING 'Division by zero attempted. Defaulting ratio to 0.00'` and return `0.00`.
- Otherwise return `ROUND(p_numerator / p_denominator, 4)`.

#### Challenge 5: Structured Error Handling with Error Codes & Hint
Write a function `transfer_funds_secure(p_from_acct INT, p_to_acct INT, p_amount NUMERIC)`:
- Rejects transfer if `p_from_acct = p_to_acct` with `ERRCODE = 'cardinality_violation'` and a helpful `HINT`.
- Verifies both accounts exist; raises `no_data_found` if missing.
- Verifies sufficient balance before deducting and adding; raises `check_violation` if balance is deficient.

---

### 5. Verified Answer Key & Solutions
```sql
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
```
