# SQL Functions & Introduction to PL/pgSQL
**Series:** PostgreSQL Mastery | **Phase:** Phase 14: PL/pgSQL Programming | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we start a new phase — PL/pgSQL Programming. PL/pgSQL is PostgreSQL's built-in procedural language that lets you write functions and procedures with variables, control flow, loops, and error handling. We start with simple SQL functions, then move into PL/pgSQL structure. By the end of this phase, you will be able to write complex server-side logic. Let us begin.

### Why Write Functions in PostgreSQL?
Why write functions in the database? Three reasons. First, performance — a function runs inside the database, close to the data, avoiding network round trips. Second, reuse — write a calculation once, call it from any query. Third, security — grant users access to a function without giving them direct table access. Functions encapsulate logic on the server side.


---

## 2. Core Technical Concepts & Mechanisms

### Why Write Functions in PostgreSQL?
Why write functions in the database? Three reasons. First, performance — a function runs inside the database, close to the data, avoiding network round trips. Second, reuse — write a calculation once, call it from any query. Third, security — grant users access to a function without giving them direct table access. Functions encapsulate logic on the server side.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Performance** | Runs inside the database, no network round trips |
| **Reuse** | Write once, call from any query or application |
| **Security** | Grant EXECUTE without direct table access |
| **Consistency** | Same logic for all applications using this database |
| **Two languages** | SQL (simple) and PL/pgSQL (procedural) |

**Notes:**
- SQL functions: pure SQL, no variables or control flow
- PL/pgSQL: variables, IF/ELSE, loops, error handling

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Function Volatility — Optimization Hints
Function volatility tells PostgreSQL how to optimize calls. IMMUTABLE means the function always returns the same result for the same inputs — like a math formula. PostgreSQL can cache these results. STABLE means the function returns the same result within a single query — like reading a config table. VOLATILE — the default — means the function might return different results every time, like NOW or RANDOM.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Function volatility tells PostgreSQL how to optimize calls |
| **Point 2** | IMMUTABLE means the function always returns the same result for the same inputs — like a math formula |
| **Point 3** | PostgreSQL can cache these results |
| **Point 4** | STABLE means the function returns the same result within a single query — like reading a config table |
| **VOLATILE** | the default — means the function might return different results every time, like NOW or RANDOM |

### SQL Function vs PL/pgSQL — When to Use Which
When should you use a SQL function versus PL/pgSQL? Here is the decision framework. If the function is a simple expression, transformation, or lookup with no control flow, use a SQL function — it is faster because PostgreSQL can inline it. If you need variables, IF/ELSE, loops, error handling, or RAISE, use PL/pgSQL. If the function is IMMUTABLE and has no side effects, SQL is almost always the right choice.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | When should you use a SQL function versus PL/pgSQL? |
| **If the function is a simple expression** | transformation, or lookup with no control flow, use a SQL function — it is faster because PostgreSQL can inline it |
| **If you need variables** | IF/ELSE, loops, error handling, or RAISE, use PL/pgSQL |
| **Point 4** | If the function is IMMUTABLE and has no side effects, SQL is almost always the right choice |

### Practice Exercises
Practice exercises: create a SQL function that calculates a discount, create a PL/pgSQL function with variables and SELECT INTO, use percent-TYPE to match column types, create a RETURNS TABLE function, use CREATE OR REPLACE to update a function, test dollar-quoting with nested quotes, and test RAISE EXCEPTION for input validation.

- 1. SQL function: calc_discount(price, percent) → discounted price
- 2. PL/pgSQL: get_balance(acct_id) with SELECT INTO
- 3. Use accounts.bal%TYPE for the variable
- 4. RETURNS TABLE: find_accounts_by_name(pattern VARCHAR)
- 5. CREATE OR REPLACE to update add_tax
- 6. Add RAISE EXCEPTION if account not found (FOUND variable)
- 7. Test: \df to list, \df+ to see source code


---

## 3. Hands-On Commands & psql Output

### Creating a SQL Function
**Explanation:** A SQL function is the simplest kind. It contains pure SQL — no variables, no control flow, just SQL statements. You define input parameters, a return type, and the SQL body. PostgreSQL inlines simple SQL functions into the calling query, making them very fast. Use SQL functions for calculations, transformations, and simple lookups.

```sql
-- Simple SQL function: add tax to a price
practice=# CREATE FUNCTION add_tax(price NUMERIC)
RETURNS NUMERIC AS $$
  SELECT price * 1.18;
$$ LANGUAGE sql;
CREATE FUNCTION

-- Use it in a query
practice=# SELECT add_tax(100);
 add_tax
---------
  118.00

-- Use it with table data
practice=# SELECT name, price, add_tax(price) AS price_with_tax
FROM products;
  name   | price |  price_with_tax
---------+-------+-----------------
 Widget  | 29.99 |          35.39
```

### SQL Functions — Multiple Parameters & RETURNS TABLE
**Explanation:** SQL functions can take multiple parameters and return different types. They can also return rows from tables. A function with RETURNS TABLE defines a set-returning function — it returns multiple rows and columns, like a virtual table you can query with SELECT FROM.

```sql
-- Multiple parameters with default value
practice=# CREATE FUNCTION add_tax_rate(price NUMERIC, rate NUMERIC DEFAULT 0.18)
RETURNS NUMERIC AS $$
  SELECT price * (1 + rate);
$$ LANGUAGE sql;

practice=# SELECT add_tax_rate(100);
 118.00  -- uses default 0.18
practice=# SELECT add_tax_rate(100, 0.05);
 105.00  -- uses 0.05

-- RETURNS TABLE: return multiple rows and columns
practice=# CREATE FUNCTION get_rich_accounts(min_bal NUMERIC)
RETURNS TABLE(acct_id INT, acct_name VARCHAR, balance NUMERIC) AS $$
  SELECT id, name, bal FROM accounts WHERE bal >= min_bal;
$$ LANGUAGE sql;

practice=# SELECT * FROM get_rich_accounts(500);
 acct_id | acct_name | balance
---------+-----------+---------
       1 | Alice     | 1000.00
       2 | Bob       |  500.00
```

### PL/pgSQL Block Structure
**Explanation:** Now let us move to PL/pgSQL — PostgreSQL's procedural language. Unlike SQL functions, PL/pgSQL gives you variables, IF/ELSE, loops, and error handling. The structure is a block: DECLARE for variables, BEGIN for code, END to close. Every PL/pgSQL function follows this pattern. The dollar-dollar notation — double dollar signs — marks the function body so you do not have to escape single quotes inside.

```sql
CREATE FUNCTION function_name(param1 TYPE, param2 TYPE)
RETURNS return_type AS $$
DECLARE
    -- variable declarations
    my_var  INTEGER;
    my_text VARCHAR(100) := 'hello';
    my_row  accounts%ROWTYPE;
BEGIN
    -- your code here
    -- assignments, queries, control flow
    my_var := 42;

    RETURN my_var;
END;
$$ LANGUAGE plpgsql;

-- Key parts:
-- DECLARE:  declare variables (optional)
-- BEGIN:    start of code
-- END:      end of code
-- $$:       dollar-quoting (avoids escaping quotes)
-- LANGUAGE plpgsql:  tells PG this is PL/pgSQL
```

### First PL/pgSQL Function — Withdraw
**Explanation:** Let us create our first PL/pgSQL function. This function takes an account ID and an amount, checks if the account has sufficient balance, and performs the withdrawal. If the balance is too low, it raises an error. This shows variables, SELECT INTO to capture a value, IF/THEN/ELSE, UPDATE, and RETURN — all in one function.

```sql
practice=# CREATE FUNCTION withdraw(acct_id INT, amount NUMERIC)
RETURNS NUMERIC AS $$
DECLARE
    current_bal NUMERIC;
BEGIN
    -- Get current balance
    SELECT bal INTO current_bal
    FROM accounts WHERE id = acct_id;

    -- Check sufficient funds
    IF current_bal < amount THEN
        RAISE EXCEPTION 'Insufficient funds: have %, need %',
            current_bal, amount;
    END IF;

    -- Perform withdrawal
    UPDATE accounts SET bal = bal - amount WHERE id = acct_id;

    RETURN current_bal - amount;
END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION
```

### Testing the Withdraw Function
**Explanation:** Let us test the withdraw function. First, a normal withdrawal that succeeds. Then, a withdrawal that exceeds the balance — it raises an exception with a clear error message. This is much better than doing these checks in application code — the database enforces the rules no matter which application calls it.

```sql
-- Check Alice's balance
practice=# SELECT * FROM accounts WHERE id = 1;
 id | name  |   bal
----+-------+---------
  1 | Alice | 1000.00

-- Withdraw 200 → success
practice=# SELECT withdraw(1, 200);
 withdraw
----------
   800.00

-- Try to withdraw too much → error!
practice=# SELECT withdraw(1, 5000);
ERROR:  Insufficient funds: have 800.00, need 5000
CONTEXT:  PL/pgSQL function withdraw(integer,numeric)
          line 10 at RAISE

-- Balance unchanged after failed attempt
practice=# SELECT bal FROM accounts WHERE id = 1;
 800.00
```

### PL/pgSQL Variables & Assignment
**Explanation:** PL/pgSQL variables have specific types. You can declare them explicitly, or use the percent-TYPE shorthand to match a column's type — if the column type changes, your variable changes too. The percent-ROWTYPE matches an entire row. Use SELECT INTO to assign query results to variables. Use the colon-equals operator for direct assignment.

```sql
DECLARE
    -- Explicit types
    counter    INTEGER := 0;
    user_name  VARCHAR(100);
    is_active  BOOLEAN := TRUE;
    created    TIMESTAMP := NOW();

    -- Match a column's type (recommended!)
    acct_bal   accounts.bal%TYPE;

    -- Match an entire row
    acct_row   accounts%ROWTYPE;

    -- Constant (cannot be changed)
    tax_rate   CONSTANT NUMERIC := 0.18;

BEGIN
    -- Direct assignment
    counter := counter + 1;
    user_name := 'Alice';

    -- SELECT INTO: assign query result to variable
    SELECT bal INTO acct_bal
    FROM accounts WHERE id = 1;

    -- SELECT INTO a row variable
    SELECT * INTO acct_row
    FROM accounts WHERE id = 1;
    -- Access fields: acct_row.name, acct_row.bal
END;
```

### Managing Functions
**Explanation:** You can manage functions with several commands. CREATE OR REPLACE updates a function without dropping it first — callers do not notice the change. DROP FUNCTION removes it. You can list your functions from the information_schema or use the psql slash-df command. ALTER FUNCTION changes properties like the owner or security context.

```sql
-- Replace existing function (no DROP needed)
practice=# CREATE OR REPLACE FUNCTION add_tax(price NUMERIC)
RETURNS NUMERIC AS $$
  SELECT ROUND(price * 1.18, 2);
$$ LANGUAGE sql;

-- Drop a function
practice=# DROP FUNCTION IF EXISTS add_tax_rate(NUMERIC, NUMERIC);
DROP FUNCTION

-- List functions in psql
practice=# \df
                        List of functions
 Schema |      Name       | Result  | Argument types
--------+-----------------+---------+---------------
 public | add_tax         | numeric | price numeric
 public | get_rich_accounts| SETOF record | min_bal numeric
 public | withdraw        | numeric | acct_id int...

-- Function details
practice=# \df+ withdraw
-- Shows full source code, volatility, etc.
```

### SECURITY DEFINER — Controlled Access
**Explanation:** SECURITY DEFINER is a powerful feature. Normally, a function runs with the permissions of the caller. With SECURITY DEFINER, it runs with the permissions of the function owner — like sudo in Linux. This lets you create functions that access restricted tables, then grant users only EXECUTE on the function. They can use the function but cannot access the table directly.

```sql
-- salary table: only HR can read directly
-- But any employee can check their OWN salary:

practice=# CREATE FUNCTION my_salary()
RETURNS NUMERIC AS $$
BEGIN
    RETURN (SELECT salary FROM employees
            WHERE username = current_user);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to all employees
-- GRANT EXECUTE ON FUNCTION my_salary() TO employees;

-- SECURITY INVOKER (default): runs as caller
-- SECURITY DEFINER: runs as function owner
-- Like sudo — gives function elevated privileges

-- IMPORTANT: always SET search_path with SECURITY DEFINER
-- to prevent schema injection attacks:
-- CREATE FUNCTION ... SECURITY DEFINER SET search_path = public;
```

### Beginner Trap: $$ Quoting vs Single Quotes
**Explanation:** Beginner trap: the dollar-dollar delimiters. Why not just use single quotes to wrap the function body? Because the SQL inside the function already uses single quotes — for string literals. If you use single quotes for both, you have to double every quote inside. Dollar-quoting avoids this entirely. You can also use named tags like dollar-body-dollar to nest dollar-quoted blocks inside each other.

```sql
-- WRONG: single-quote body (must escape inner quotes)
practice=# CREATE FUNCTION greet(name TEXT) RETURNS TEXT AS '
  SELECT ''Hello, '' || name || ''!'';
' LANGUAGE sql;
CREATE FUNCTION

-- CORRECT: $$ quoting (no escaping needed)
practice=# CREATE OR REPLACE FUNCTION greet(name TEXT) RETURNS TEXT AS $$
  SELECT 'Hello, ' || name || '!';
$$ LANGUAGE sql;
CREATE FUNCTION

-- Named tags for nesting: $body$ ... $body$
-- Useful when function body contains $$ itself
-- CREATE FUNCTION ... AS $body$ ... $body$ LANGUAGE plpgsql;

-- Rule: ALWAYS use $$ (or named tags), never single quotes
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: $$ Quoting vs Single Quotes
Beginner trap: the dollar-dollar delimiters. Why not just use single quotes to wrap the function body? Because the SQL inside the function already uses single quotes — for string literals. If you use single quotes for both, you have to double every quote inside. Dollar-quoting avoids this entirely. You can also use named tags like dollar-body-dollar to nest dollar-quoted blocks inside each other.

```sql
-- WRONG: single-quote body (must escape inner quotes)
CREATE FUNCTION greet(name TEXT) RETURNS TEXT AS '
  SELECT ''Hello, '' || name || ''!'';
' LANGUAGE sql;
CREATE FUNCTION

-- CORRECT: $$ quoting (no escaping needed)
CREATE OR REPLACE FUNCTION greet(name TEXT) RETURNS TEXT AS $$
  SELECT 'Hello, ' || name || '!';
$$ LANGUAGE sql;
CREATE FUNCTION

-- Named tags for nesting: $body$ ... $body$
-- Useful when function body contains $$ itself
-- CREATE FUNCTION ... AS $body$ ... $body$ LANGUAGE plpgsql;

-- Rule: ALWAYS use $$ (or named tags), never single quotes
```


---

## 6. Hands-On Practice Exercises & Verified Solutions

### Exercise 1: Pure SQL Immutable Tax Calculator
**Challenge:** Write a pure SQL function `calc_tax(price, rate)` returning `price * (rate / 100.0)` rounded to two decimals. Mark it `IMMUTABLE STRICT`.
```sql
CREATE OR REPLACE FUNCTION calc_tax(p NUMERIC, r NUMERIC) 
RETURNS NUMERIC AS $$ 
    SELECT ROUND(p * (r / 100.0), 2); 
$$ LANGUAGE sql IMMUTABLE STRICT;

SELECT calc_tax(199.99, 8.25); -- Returns 16.50
```
*Explanation:* `IMMUTABLE` guarantees deterministic output for identical arguments, allowing query inlining and expression indexing. `STRICT` returns `NULL` instantly if any input is `NULL`.

### Exercise 2: Table-Returning Inventory Filter
**Challenge:** Create a function `low_stock_products(min_stock INT)` returning a relational dataset of products below threshold.
```sql
CREATE OR REPLACE FUNCTION low_stock_products(min_stock INT) 
RETURNS TABLE(product_id INT, product_name TEXT, current_stock INT) AS $$ 
    SELECT id, name, stock 
    FROM products 
    WHERE stock < min_stock
    ORDER BY stock ASC; 
$$ LANGUAGE sql STABLE;

SELECT * FROM low_stock_products(10) WHERE current_stock > 0;
```
*Explanation:* `RETURNS TABLE(...)` outputs a structured tuple stream queryable directly in `FROM` clauses.

### Exercise 3: Dynamic Type Anchoring with %TYPE
**Challenge:** Author a PL/pgSQL function `get_customer_tier(p_id)` using `customers.balance%TYPE` variables to classify spending tiers.
```sql
CREATE OR REPLACE FUNCTION get_customer_tier(p_customer_id INT) 
RETURNS TEXT AS $$ 
DECLARE 
    v_balance customers.balance%TYPE; 
BEGIN 
    SELECT balance INTO v_balance FROM customers WHERE id = p_customer_id; 
    IF NOT FOUND THEN
        RETURN 'Unknown Customer';
    ELSIF v_balance > 5000.00 THEN 
        RETURN 'Gold Tier'; 
    ELSIF v_balance > 1000.00 THEN 
        RETURN 'Silver Tier'; 
    ELSE 
        RETURN 'Standard Tier'; 
    END IF; 
END; 
$$ LANGUAGE plpgsql STABLE;
```
*Explanation:* `%TYPE` automatically tracks schema changes if `balance` is altered from `INTEGER` to `NUMERIC(12,2)`.

### Exercise 4: Verifying Row Existence via FOUND
**Challenge:** Demonstrate how `SELECT INTO` populates the automatic `FOUND` boolean variable to handle non-existent rows gracefully.
```sql
DO $$
DECLARE
    v_email users.email%TYPE;
BEGIN
    SELECT email INTO v_email FROM users WHERE id = 99999;
    IF NOT FOUND THEN
        RAISE NOTICE 'Target row does not exist!';
    END IF;
END $$;
```
*Explanation:* `FOUND` evaluates to `true` if `SELECT INTO` returns >= 1 row, and `false` if 0 rows match.

### Exercise 5: Auditing Custom Functions in pg_proc
**Challenge:** Query the PostgreSQL system catalog to inspect custom functions, volatility codes, and implementation languages.
```sql
SELECT 
    pg_proc.proname AS function_name,
    pg_proc.provolatile AS volatility,
    pg_language.lanname AS language,
    pg_proc.prosrc AS source_code
FROM pg_proc 
JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid 
JOIN pg_language ON pg_proc.prolang = pg_language.oid
WHERE pg_namespace.nspname = 'public'
ORDER BY function_name;
```
*Explanation:* Allows DBAs to audit function code, verify volatility optimizations, and check security flags across the cluster.


## 7. Key Takeaways & Cheat Sheet

Let us recap. SQL functions contain pure SQL and are inlined into queries for maximum speed. PL/pgSQL adds variables, control flow, and error handling. The DECLARE block holds variables, BEGIN and END wrap the code. SELECT INTO assigns query results. RAISE EXCEPTION stops execution with an error message. CREATE OR REPLACE updates functions seamlessly. Volatility — IMMUTABLE, STABLE, VOLATILE — controls optimization. SECURITY DEFINER gives functions elevated permissions. Always use dollar-quoting, never single quotes for function bodies. In the next class, we dive deeper into PL/pgSQL control flow — IF, ELSIF, CASE, and RAISE for debugging. See you there!

- **SQL function: pure SQL, fast, can be inlined**
- **PL/pgSQL: DECLARE → BEGIN → END block**
- **Variables: explicit type, %TYPE, %ROWTYPE**
- **SELECT INTO: capture query result into variable**
- **RAISE EXCEPTION: stop with error message**
- **CREATE OR REPLACE: update without DROP**
- **IMMUTABLE / STABLE / VOLATILE: optimization hints**
- **SECURITY DEFINER: function runs as owner (like sudo)**
- **Always $$ or $tag$ — never single-quote function bodies**


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
