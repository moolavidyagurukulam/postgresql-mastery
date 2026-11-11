# Trigger Fundamentals
**Series:** PostgreSQL Mastery | **Phase:** Phase 15: Triggers & Rules | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn about triggers — automatic functions that PostgreSQL fires when something happens to your data. A trigger watches a table and runs your code before or after an INSERT, UPDATE, or DELETE. Think of it like a security camera that also takes action: it does not just watch, it responds. By the end of this class, you will know exactly how triggers work, when they fire, and how to write your first trigger function. Let us begin.

### The Problem: Application Logic Gets Bypassed
Here is the problem. Imagine you have an employees table and you need to automatically update a modified_at timestamp every time someone changes a row. Or you need to prevent salary from going below minimum wage. Or you need to log every deletion into an audit table. You could put this logic in your application code — but what if someone connects directly through psql and makes a change? Your application logic is bypassed entirely. You need the database itself to enforce these rules, regardless of how the data is changed.


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Application Logic Gets Bypassed
Here is the problem. Imagine you have an employees table and you need to automatically update a modified_at timestamp every time someone changes a row. Or you need to prevent salary from going below minimum wage. Or you need to log every deletion into an audit table. You could put this logic in your application code — but what if someone connects directly through psql and makes a change? Your application logic is bypassed entirely. You need the database itself to enforce these rules, regardless of how the data is changed.

| Application-Level Only | Database-Level Triggers |
| :--- | :--- |
| Validation in app code only | Runs for EVERY change |
| Direct psql changes skip it | Cannot be bypassed |
| Multiple apps = duplicate logic | One place, one rule |
| One missed check = bad data | Enforced regardless of client |

### What is a Trigger?
A trigger is a named database object that automatically calls a function when a specific event happens on a table. There are two parts: the trigger itself, which defines when and why it fires, and the trigger function, which defines what happens. The trigger is the alarm system. The trigger function is the response plan. You always create the function first, then create the trigger that calls it.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Trigger** | Named object that watches a table for INSERT, UPDATE, or DELETE events |
| **Trigger Function** | A special PL/pgSQL function that returns TRIGGER — contains the response logic |
| **Two-Step Creation** | Step 1: CREATE FUNCTION ... RETURNS TRIGGER — Step 2: CREATE TRIGGER ... EXECUTE FUNCTION |

**Notes:**
- Trigger functions MUST return TRIGGER type
- One function can be reused by many triggers

### BEFORE vs AFTER Triggers
Now let us understand the critical difference between BEFORE and AFTER triggers. A BEFORE trigger fires before the row is actually written. This means you can modify the NEW row — change values, add defaults, enforce rules — or even cancel the operation by returning NULL instead of NEW. An AFTER trigger fires after the row is already written. You cannot change the row anymore, but you can do follow-up work like logging, sending notifications, or updating related tables. Here is the key rule: use BEFORE when you need to modify or block the row. Use AFTER when you need to react to a confirmed change.

| BEFORE Trigger | AFTER Trigger |
| :--- | :--- |
| Fires BEFORE row is written | Fires AFTER row is written |
| Can MODIFY NEW values | Cannot change the row anymore |
| Can CANCEL by returning NULL | Good for follow-up actions |
| Use for: validation, defaults | Use for: logging, audit, notify |
| MUST return NEW (or NULL) | Return value is ignored |

### ROW vs STATEMENT Triggers
Now let us understand ROW-level versus STATEMENT-level triggers. A ROW trigger fires once for each affected row. If your UPDATE changes 5 rows, the trigger runs 5 times — once per row, with NEW and OLD set each time. A STATEMENT trigger fires once per SQL statement, regardless of how many rows it affects — even zero rows. STATEMENT triggers do NOT have access to NEW and OLD because they are not tied to a specific row. Most triggers you write will be ROW triggers. STATEMENT triggers are useful for things like counting total operations or logging that an event happened.

- 1 -- Fires once per affected row. Has NEW/OLD. UPDATE 5 rows = fires 5 times.
- 2 -- Fires once per SQL statement. No NEW/OLD. UPDATE 5 rows = fires 1 time.
- 3 -- ROW trigger: does NOT fire. STATEMENT trigger: STILL fires once.
- 4 -- If you omit FOR EACH, PostgreSQL defaults to FOR EACH STATEMENT.

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too. Now let us continue with our decision framework.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Trigger Decision Framework
Here is your decision framework for triggers. When should you use BEFORE versus AFTER? When should you use ROW versus STATEMENT? Use this table as a quick reference. BEFORE ROW is the most common — you use it to validate, modify, or block individual rows. AFTER ROW is for audit logging and cascading changes after the row is confirmed. STATEMENT triggers are rare but useful for per-statement logging or enforcing whole-statement constraints.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Here** | your decision framework for triggers |
| **When should you** | BEFORE versus AFTER? When should you use ROW versus STATEMENT? Use this table as a quick reference |
| **BEFORE ROW** | the most common — you use it to validate, modify, or block individual rows |
| **AFTER ROW** | for audit logging and cascading changes after the row is confirmed |
| **STATEMENT triggers** | rare but useful for per-statement logging or enforcing whole-statement constraints |

### Trigger Function Patterns — Quick Reference
Here is a pattern reference for trigger functions. These are the building blocks you will combine in the next class on Practical Triggers.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a pattern reference for trigger functions |
| **Point 2** | These are the building blocks you will combine in the next class on Practical Triggers |

### Practice Exercises
Time to practice. Open psql and try these exercises. First, create a trigger that automatically converts employee names to title case on INSERT. Second, create a BEFORE DELETE trigger that prevents deleting employees from the Engineering department — return NULL to block it. Third, create a trigger that fires only when salary increases by more than 20 percent — use a WHEN clause with OLD and NEW. Fourth, list all triggers on your employees table using information_schema.triggers.

- 1 -- CREATE TRIGGER on INSERT, set NEW.name = initcap(NEW.name), RETURN NEW
- 2 -- BEFORE DELETE trigger, check OLD.department = 'Engineering', RETURN NULL to block
- 3 -- WHEN (NEW.salary > OLD.salary * 1.20) — fire AFTER UPDATE, RAISE NOTICE
- 4 -- SELECT trigger_name, event_manipulation, action_timing FROM information_schema.triggers


---

## 3. Hands-On Commands & psql Output

### Setup: Practice Table
**Explanation:** Let us set up our practice environment. We will create a simple employees table to experiment with triggers throughout this class.

```sql
postgres=# CREATE DATABASE trigger_lab;
CREATE DATABASE
postgres=# \c trigger_lab
You are now connected to database "trigger_lab" as user "postgres".
trigger_lab=# CREATE TABLE employees (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    department  VARCHAR(50),
    salary      NUMERIC(10,2),
    created_at  TIMESTAMPTZ DEFAULT now(),
    modified_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE
trigger_lab=# INSERT INTO employees (name, department, salary) VALUES
  ('Alice', 'Engineering', 85000),
  ('Bob', 'Marketing', 65000),
  ('Carol', 'Engineering', 92000);
INSERT 0 3
```

### Trigger Function Anatomy
**Explanation:** Here is the anatomy of a trigger function. It looks like a regular PL/pgSQL function, but with two key differences. First, it returns TRIGGER — not void, not integer, TRIGGER. Second, inside the function you have access to special variables that PostgreSQL provides automatically: NEW is the row being inserted or the new version of the row being updated. OLD is the row being deleted or the old version being updated. TG_OP tells you the operation: INSERT, UPDATE, or DELETE. TG_TABLE_NAME gives you the name of the table that fired the trigger.

```sql
CREATE OR REPLACE FUNCTION my_trigger_fn()
RETURNS TRIGGER AS $$
BEGIN
    -- Special variables available:
    -- NEW  = new row (INSERT/UPDATE)
    -- OLD  = old row (DELETE/UPDATE)
    -- TG_OP = 'INSERT','UPDATE','DELETE'
    -- TG_TABLE_NAME = table name
    -- TG_WHEN = 'BEFORE' or 'AFTER'
    -- TG_LEVEL = 'ROW' or 'STATEMENT'

    -- Your logic here...

    RETURN NEW;  -- for BEFORE triggers
END;
$$ LANGUAGE plpgsql;
```

### CREATE TRIGGER Syntax
**Explanation:** Now the trigger itself. The CREATE TRIGGER statement tells PostgreSQL: on this table, for these events, at this timing, call this function. Let us break down each keyword. BEFORE or AFTER is the timing — when does the function run relative to the actual data change? FOR EACH ROW means the function runs once per affected row. FOR EACH STATEMENT means it runs once per SQL statement, regardless of how many rows are affected. EXECUTE FUNCTION names the trigger function to call.

```sql
CREATE TRIGGER trigger_name
    { BEFORE | AFTER | INSTEAD OF }
    { INSERT | UPDATE | DELETE | TRUNCATE }
    ON table_name
    [ FOR EACH { ROW | STATEMENT } ]
    [ WHEN ( condition ) ]
    EXECUTE FUNCTION function_name();
```

### First Trigger: Auto-Update modified_at
**Explanation:** Let us build our first trigger. We want to automatically update modified_at whenever someone changes an employee row. First, we create the trigger function. It sets NEW dot modified_at to now and returns NEW. Then we create the trigger that calls it — BEFORE UPDATE, FOR EACH ROW. We use BEFORE because we want to modify the row before PostgreSQL writes it to the table.

```sql
trigger_lab=# CREATE OR REPLACE FUNCTION update_modified_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.modified_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE TRIGGER trg_employees_modified
    BEFORE UPDATE ON employees
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER
```

### Testing the Trigger
**Explanation:** Let us test it. We will check Alice's modified_at timestamp, then update her salary, and check again. Watch how modified_at changes automatically without us touching it.

```sql
trigger_lab=# SELECT name, salary, modified_at FROM employees WHERE name = 'Alice';
 name  |  salary  |         modified_at
-------+----------+-------------------------------
 Alice | 85000.00 | 2026-11-03 10:00:00.123456+05:30
(1 row)
trigger_lab=# UPDATE employees SET salary = 90000 WHERE name = 'Alice';
UPDATE 1
trigger_lab=# SELECT name, salary, modified_at FROM employees WHERE name = 'Alice';
 name  |  salary  |         modified_at
-------+----------+-------------------------------
 Alice | 90000.00 | 2026-11-03 10:05:32.789012+05:30
(1 row)
```

### BEFORE Trigger: Blocking an Operation
**Explanation:** Let us see BEFORE trigger cancellation in action. We will create a trigger that prevents anyone from setting a salary below 30,000. If someone tries, the trigger returns NULL which cancels the operation — the row is not updated. We use RAISE NOTICE to tell the user what happened.

```sql
trigger_lab=# CREATE OR REPLACE FUNCTION enforce_min_salary()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.salary < 30000 THEN
        RAISE NOTICE 'Salary % is below minimum 30000. Update blocked.', NEW.salary;
        RETURN NULL;  -- cancels the operation
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE TRIGGER trg_min_salary
    BEFORE UPDATE ON employees
    FOR EACH ROW
    EXECUTE FUNCTION enforce_min_salary();
CREATE TRIGGER
trigger_lab=# UPDATE employees SET salary = 20000 WHERE name = 'Bob';
NOTICE:  Salary 20000 is below minimum 30000. Update blocked.
UPDATE 0
trigger_lab=# SELECT name, salary FROM employees WHERE name = 'Bob';
 name | salary
------+----------
 Bob  | 65000.00
(1 row)
```

### ROW vs STATEMENT — Live Demo
**Explanation:** Let us see this difference live. We will create two triggers on the same table — one ROW-level and one STATEMENT-level — and run an UPDATE that affects 3 rows. Watch the output to see how many times each fires.

```sql
trigger_lab=# CREATE OR REPLACE FUNCTION log_row_trigger()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'ROW trigger fired for: %', NEW.name;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE OR REPLACE FUNCTION log_stmt_trigger()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'STATEMENT trigger fired once for entire operation';
    RETURN NULL;
END; $$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE TRIGGER trg_row_demo BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION log_row_trigger();
CREATE TRIGGER
trigger_lab=# CREATE TRIGGER trg_stmt_demo BEFORE UPDATE ON employees
    FOR EACH STATEMENT EXECUTE FUNCTION log_stmt_trigger();
CREATE TRIGGER
trigger_lab=# UPDATE employees SET salary = salary * 1.05;
NOTICE:  STATEMENT trigger fired once for entire operation
NOTICE:  ROW trigger fired for: Alice
NOTICE:  ROW trigger fired for: Bob
NOTICE:  ROW trigger fired for: Carol
UPDATE 3
```

### Column-Specific Triggers
**Explanation:** Triggers can also fire on specific columns. If you only want your trigger to run when the salary column changes — not when name or department changes — you add an OF clause. This is a nice optimization: the trigger function does not even get called if the relevant column was not touched. You can list multiple columns separated by commas.

```sql
trigger_lab=# DROP TRIGGER trg_row_demo ON employees;
DROP TRIGGER
trigger_lab=# DROP TRIGGER trg_stmt_demo ON employees;
DROP TRIGGER
trigger_lab=# CREATE TRIGGER trg_salary_change
    AFTER UPDATE OF salary ON employees
    FOR EACH ROW
    EXECUTE FUNCTION log_row_trigger();
CREATE TRIGGER
trigger_lab=# UPDATE employees SET department = 'Sales' WHERE name = 'Bob';
UPDATE 1
-- -- No trigger notice! Only salary changes fire it.
trigger_lab=# UPDATE employees SET salary = 70000 WHERE name = 'Bob';
NOTICE:  ROW trigger fired for: Bob
UPDATE 1
```

### Conditional Triggers with WHEN
**Explanation:** You can also add a WHEN clause to a trigger. This is a condition evaluated by PostgreSQL before calling the trigger function. If the condition is false, the function is never called — saving the overhead of a function call entirely. For example, we can fire a trigger only when the salary actually changes to a different value, skipping no-op updates where someone sets salary to its current value.

```sql
trigger_lab=# DROP TRIGGER trg_salary_change ON employees;
DROP TRIGGER
trigger_lab=# CREATE TRIGGER trg_salary_actual_change
    AFTER UPDATE OF salary ON employees
    FOR EACH ROW
    WHEN (OLD.salary IS DISTINCT FROM NEW.salary)
    EXECUTE FUNCTION log_row_trigger();
CREATE TRIGGER
trigger_lab=# UPDATE employees SET salary = 70000 WHERE name = 'Bob';
UPDATE 1
-- -- No notice! Salary was already 70000.
trigger_lab=# UPDATE employees SET salary = 75000 WHERE name = 'Bob';
NOTICE:  ROW trigger fired for: Bob
UPDATE 1
```

### Trigger Firing Order: Alphabetical
**Explanation:** When a table has multiple triggers for the same event and timing, PostgreSQL fires them in alphabetical order by trigger name. This is important. If trigger A must run before trigger B, name them so A sorts first: for example, trg_01_validate and trg_02_audit. Let us see this ordering in action.

```sql
trigger_lab=# CREATE OR REPLACE FUNCTION trigger_a()
RETURNS TRIGGER AS $$
BEGIN RAISE NOTICE 'Trigger A fired'; RETURN NEW; END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE OR REPLACE FUNCTION trigger_b()
RETURNS TRIGGER AS $$
BEGIN RAISE NOTICE 'Trigger B fired'; RETURN NEW; END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE TRIGGER trg_zzz BEFORE INSERT ON employees
    FOR EACH ROW EXECUTE FUNCTION trigger_a();
CREATE TRIGGER
trigger_lab=# CREATE TRIGGER trg_aaa BEFORE INSERT ON employees
    FOR EACH ROW EXECUTE FUNCTION trigger_b();
CREATE TRIGGER
trigger_lab=# INSERT INTO employees (name, department, salary) VALUES ('Dave', 'HR', 55000);
NOTICE:  Trigger B fired
NOTICE:  Trigger A fired
INSERT 0 1
-- -- trg_aaa fires before trg_zzz (alphabetical order)
```

### Beginner Trap: Wrong Return Type & Missing Variables
**Explanation:** Here is a common beginner trap. You create a trigger function and forget to return TRIGGER type, or you create it returning void. PostgreSQL gives you this error: trigger function must return trigger. Another trap: you try to access NEW in a DELETE trigger or OLD in an INSERT trigger. NEW does not exist for DELETE because there is no new row — the row is being removed. OLD does not exist for INSERT because there is no old row — it is brand new. For UPDATE, both NEW and OLD are available.

```sql
trigger_lab=# CREATE FUNCTION bad_trigger() RETURNS void AS $$
BEGIN RAISE NOTICE 'hello'; END; $$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE TRIGGER trg_bad BEFORE INSERT ON employees
    FOR EACH ROW EXECUTE FUNCTION bad_trigger();
ERROR:  function bad_trigger() must return type trigger
-- 
-- -- NEW and OLD availability:
-- -- INSERT: NEW = yes, OLD = NULL
-- -- UPDATE: NEW = yes, OLD = yes
-- -- DELETE: NEW = NULL, OLD = yes
-- -- TRUNCATE: neither (STATEMENT only)
```

### Beginner Trap: Accidental NULL Return
**Explanation:** Another important trap: what happens if a BEFORE ROW trigger returns NULL? The entire operation for that row is silently cancelled. No error, no warning — the row just does not get inserted, updated, or deleted. The UPDATE or INSERT reports zero rows affected. This is by design — it is how you conditionally block operations. But if you accidentally return NULL instead of NEW, you will spend hours wondering why your INSERT silently does nothing. Always return NEW from BEFORE triggers unless you intentionally want to cancel the operation.

```sql
trigger_lab=# CREATE OR REPLACE FUNCTION accidental_null()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'Processing %', NEW.name;
    -- Forgot RETURN NEW!
    -- PL/pgSQL returns NULL by default
END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE TRIGGER trg_oops BEFORE INSERT ON employees
    FOR EACH ROW EXECUTE FUNCTION accidental_null();
CREATE TRIGGER
trigger_lab=# INSERT INTO employees (name, department, salary) VALUES ('Eve', 'Finance', 60000);
NOTICE:  Processing Eve
INSERT 0 0
-- -- INSERT 0 0 means zero rows inserted! Silent failure.
-- -- Fix: always end BEFORE triggers with RETURN NEW;
```

### Managing Triggers: List, Disable, Enable, Drop
**Explanation:** Let us look at how to manage triggers. You can list all triggers on a table, disable and enable them, and drop them. The backslash dS plus command in psql shows a table's triggers. ALTER TABLE lets you disable a trigger temporarily — useful during bulk loads when you want to skip trigger overhead. Always remember to re-enable after the load.

```sql
trigger_lab=# \dS employees
-- -- Shows table definition including triggers at the bottom
-- 
trigger_lab=# SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers WHERE event_object_table = 'employees';
       trigger_name       | event_manipulation | action_timing
--------------------------+--------------------+--------------
 trg_employees_modified   | UPDATE             | BEFORE
 trg_min_salary           | UPDATE             | BEFORE
(2 rows)
-- 
trigger_lab=# ALTER TABLE employees DISABLE TRIGGER trg_min_salary;
ALTER TABLE
trigger_lab=# ALTER TABLE employees ENABLE TRIGGER trg_min_salary;
ALTER TABLE
trigger_lab=# DROP TRIGGER trg_min_salary ON employees;
DROP TRIGGER
-- -- Note: DROP TRIGGER does NOT drop the function
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Wrong Return Type & Missing Variables
Here is a common beginner trap. You create a trigger function and forget to return TRIGGER type, or you create it returning void. PostgreSQL gives you this error: trigger function must return trigger. Another trap: you try to access NEW in a DELETE trigger or OLD in an INSERT trigger. NEW does not exist for DELETE because there is no new row — the row is being removed. OLD does not exist for INSERT because there is no old row — it is brand new. For UPDATE, both NEW and OLD are available.

```sql
CREATE FUNCTION bad_trigger() RETURNS void AS $$
BEGIN RAISE NOTICE 'hello'; END; $$ LANGUAGE plpgsql;
CREATE FUNCTION
CREATE TRIGGER trg_bad BEFORE INSERT ON employees
    FOR EACH ROW EXECUTE FUNCTION bad_trigger();
ERROR:  function bad_trigger() must return type trigger

-- NEW and OLD availability:
-- INSERT: NEW = yes, OLD = NULL
-- UPDATE: NEW = yes, OLD = yes
-- DELETE: NEW = NULL, OLD = yes
-- TRUNCATE: neither (STATEMENT only)
```

### Beginner Trap: Accidental NULL Return
Another important trap: what happens if a BEFORE ROW trigger returns NULL? The entire operation for that row is silently cancelled. No error, no warning — the row just does not get inserted, updated, or deleted. The UPDATE or INSERT reports zero rows affected. This is by design — it is how you conditionally block operations. But if you accidentally return NULL instead of NEW, you will spend hours wondering why your INSERT silently does nothing. Always return NEW from BEFORE triggers unless you intentionally want to cancel the operation.

```sql
CREATE OR REPLACE FUNCTION accidental_null()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'Processing %', NEW.name;
    -- Forgot RETURN NEW!
    -- PL/pgSQL returns NULL by default
END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION
CREATE TRIGGER trg_oops BEFORE INSERT ON employees
    FOR EACH ROW EXECUTE FUNCTION accidental_null();
CREATE TRIGGER
INSERT INTO employees (name, department, salary) VALUES ('Eve', 'Finance', 60000);
NOTICE:  Processing Eve
INSERT 0 0
-- INSERT 0 0 means zero rows inserted! Silent failure.
-- Fix: always end BEFORE triggers with RETURN NEW;
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review what we covered. You learned that triggers are automatic functions fired on table events. A trigger function returns TRIGGER and has access to NEW, OLD, and TG variables. BEFORE triggers can modify or cancel rows. AFTER triggers react to confirmed changes. ROW triggers fire per row, STATEMENT triggers fire once per statement. Multiple triggers on the same event fire in alphabetical order. And you should always return NEW from BEFORE triggers unless you intentionally want to cancel.

- **Trigger = watches table + calls function on INSERT/UPDATE/DELETE**
- **Two-step: CREATE FUNCTION (RETURNS TRIGGER) then CREATE TRIGGER**
- **BEFORE: can modify NEW or cancel (RETURN NULL)**
- **AFTER: row confirmed, good for logging/audit**
- **ROW: fires per row, has NEW/OLD. STATEMENT: fires once, no NEW/OLD**
- **Multiple triggers: alphabetical order by trigger name**
- **Column-specific: UPDATE OF col1, col2**
- **WHEN clause: skip trigger without function call overhead**
- **Trap: missing RETURN NEW silently cancels operations**


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
