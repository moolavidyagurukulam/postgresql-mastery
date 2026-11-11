# Practical Triggers
**Series:** PostgreSQL Mastery | **Phase:** Phase 15: Triggers & Rules | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we build real-world trigger systems. We will create a complete audit logging system that tracks every INSERT, UPDATE, and DELETE with full old and new data stored as JSONB. We will build data validation triggers that enforce complex business rules the database itself. We will see trigger cascading — triggers that fire other triggers. And we will learn the complete firing order when multiple triggers exist on the same table. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Project 1: Universal Audit Log
Every production database needs an audit trail. When a row changes, you want to know: what table was affected, what operation happened, what was the old data, what is the new data, who made the change, and when. We will build a universal audit trigger that works on any table without modification. The trick is using JSONB and the to_jsonb function — it converts any row to JSON, so one trigger function handles every table structure.

| Term | Meaning / Explanation |
| :--- | :--- |
| **audit_log table** | Central table storing all changes across all audited tables |
| **to_jsonb(NEW)** | Converts any row to JSONB — works for any table structure |
| **TG_TABLE_NAME** | Trigger variable giving the source table name automatically |
| **session_user** | Built-in variable for who is connected — cannot be faked |

**Notes:**
- One function, attach to any table
- JSONB stores full row snapshots

### Project 2: Multi-Rule Validation Trigger
Project two: data validation triggers. CHECK constraints are simple — they test one condition. But real business rules are complex. What if a salary change requires that the new salary is within the department's budget range and the employee has been with the company for at least 90 days and the raise does not exceed 25 percent of the current salary? You cannot do all of that in a CHECK constraint. A BEFORE UPDATE trigger can enforce all of these rules together.

- 1 -- Engineering: 60k-150k, Marketing: 45k-120k, HR: 40k-100k
- 2 -- No single raise can exceed 25% of current salary
- 3 -- Employee must be hired at least 90 days ago for a raise
- 4 -- Trigger collects ALL violations, raises them together

### Complete Trigger Firing Order
Here is the complete trigger firing order for a single UPDATE statement that affects multiple rows. First, BEFORE STATEMENT triggers fire once. Then, for each affected row: BEFORE ROW triggers fire, the row is actually written, and AFTER ROW triggers fire. After all rows are processed, AFTER STATEMENT triggers fire once. For BEFORE triggers, they fire in alphabetical order by name. Same for AFTER triggers. This order matters when you have validation triggers that must run before logging triggers.

- 1 -- Fire once, alphabetical order. No NEW/OLD.
- 2 -- Steps 3-5 repeat for every row
- 3 -- Alphabetical. Can modify NEW or cancel (RETURN NULL).
- 4 -- INSERT/UPDATE/DELETE happens on disk.
- 5 -- Alphabetical. Row is confirmed. Cascading triggers fire here.
- 6 -- Fire once after all rows processed. No NEW/OLD.

### Beginner Trap: Trigger Performance
Here is a critical beginner trap with trigger performance. Every trigger adds overhead to every affected row. An AFTER ROW trigger on a table that gets 10,000 inserts per second means 10,000 trigger function calls per second. If your trigger function does an INSERT into the audit table, that is 10,000 extra INSERTs per second. For high-throughput tables, consider batching audit writes using STATEMENT-level triggers, or use logical replication to capture changes externally instead of triggers.

| Problem: Hidden Cost | Solutions |
| :--- | :--- |
| 10,000 rows/sec INSERT | STATEMENT triggers for batch logging |
| AFTER ROW trigger → 10k calls/sec | WHEN clause to skip no-ops |
| Each call does INSERT to audit | Disable triggers during bulk loads |
| Total: 20,000 writes/sec! | Use pgaudit extension instead |
| Doubles your write load | Logical replication for external capture |

### Beginner Trap: Triggers vs Constraints
Another trap: trigger-based foreign key enforcement. Never try to enforce referential integrity with triggers — use FOREIGN KEY constraints instead. Triggers have race conditions under concurrent access. Two transactions can both pass the trigger check simultaneously, and neither sees the other's uncommitted rows. Constraints use internal locking that triggers cannot replicate. Triggers are for business logic. Constraints are for data integrity.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Another trap** | trigger-based foreign key enforcement |
| **Point 2** | Never try to enforce referential integrity with triggers — use FOREIGN KEY constraints instead |
| **Point 3** | Triggers have race conditions under concurrent access |
| **Point 4** | Two transactions can both pass the trigger check simultaneously, and neither sees the other's uncommitted rows |
| **Point 5** | Constraints use internal locking that triggers cannot replicate |
| **Point 6** | Triggers are for business logic |
| **Point 7** | Constraints are for data integrity |

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too. Now let us continue with INSTEAD OF triggers.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Trigger Pattern Decision Framework
Here is a decision framework for choosing which trigger patterns to use in production. Use this as a quick reference when designing your trigger systems.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a decision framework for choosing which trigger patterns to use in production |
| **Point 2** | Use this as a quick reference when designing your trigger systems |

### Practice Exercises
Time to practice. Open psql and try these exercises. First, create a universal audit trigger and attach it to two different tables — verify both tables get logged to the same audit_log. Second, create a BEFORE trigger that prevents anyone from deleting more than one employee at a time — use a STATEMENT-level trigger with a count check. Third, create an INSTEAD OF trigger on a view that joins employees and departments. Fourth, create a cascading trigger: when an employee is deleted, the trigger inserts a row into a former_employees archive table.

- 1 -- Attach fn_audit_log() to two tables. Verify both appear in audit_log with correct table_name.
- 2 -- BEFORE DELETE STATEMENT trigger. Count affected rows. Raise exception if > 1.
- 3 -- INSTEAD OF INSERT on a view joining employees + departments. Route data to correct tables.
- 4 -- BEFORE DELETE trigger copies OLD row to former_employees with deleted_at timestamp.


---

## 3. Hands-On Commands & psql Output

### Building the Audit Log System
**Explanation:** Let us build it. First, the audit_log table. We store the table name, the operation, the old data as JSONB, the new data as JSONB, who made the change, and when. Then we create the trigger function. It uses TG_OP to branch on INSERT, UPDATE, or DELETE. For INSERT, there is no old data. For DELETE, there is no new data. For UPDATE, we store both. Watch how we use to_jsonb to capture the entire row.

```sql
trigger_lab=# CREATE TABLE audit_log (
    id          BIGSERIAL PRIMARY KEY,
    table_name  TEXT NOT NULL,
    operation   TEXT NOT NULL,
    old_data    JSONB,
    new_data    JSONB,
    changed_by  TEXT DEFAULT session_user,
    changed_at  TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE
```

### Universal Audit Trigger Function
**Explanation:** Now the trigger function. This single function handles all three operations on any table. For INSERT, we only log new_data. For DELETE, we only log old_data. For UPDATE, we log both — and we add a smart optimization: we skip the log if nothing actually changed, using the row equality check OLD is not distinct from NEW.

```sql
CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, operation, new_data)
        VALUES (TG_TABLE_NAME, 'INSERT', to_jsonb(NEW));
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        -- Skip if nothing actually changed
        IF OLD IS NOT DISTINCT FROM NEW THEN
            RETURN NEW;
        END IF;
        INSERT INTO audit_log (table_name, operation, old_data, new_data)
        VALUES (TG_TABLE_NAME, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, operation, old_data)
        VALUES (TG_TABLE_NAME, 'DELETE', to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

### Attaching and Testing the Audit Trigger
**Explanation:** Now we attach it to our employees table. We use AFTER triggers because we want to log only confirmed changes — if a BEFORE trigger cancels the operation, the audit should not record it. We create one trigger for all three events using INSERT OR UPDATE OR DELETE. Let us test it.

```sql
trigger_lab=# CREATE TRIGGER trg_audit_employees
    AFTER INSERT OR UPDATE OR DELETE ON employees
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();
CREATE TRIGGER
trigger_lab=# INSERT INTO employees (name, department, salary) VALUES ('Frank', 'HR', 52000);
INSERT 0 1
trigger_lab=# UPDATE employees SET salary = 55000 WHERE name = 'Frank';
UPDATE 1
trigger_lab=# DELETE FROM employees WHERE name = 'Frank';
DELETE 1
trigger_lab=# SELECT operation, old_data->>'name' AS who,
       old_data->>'salary' AS old_sal, new_data->>'salary' AS new_sal
FROM audit_log ORDER BY id;
 operation |  who  | old_sal | new_sal
-----------+-------+---------+---------
 INSERT    |       |         | 52000
 UPDATE    | Frank | 52000   | 55000
 DELETE    | Frank | 55000   |
(3 rows)
```

### Reusing the Audit Function on Another Table
**Explanation:** The beauty of this design is reusability. You can attach the same fn_audit_log function to any table. Just run CREATE TRIGGER with the same function on a different table. Let us add another table and audit it with zero extra code.

```sql
trigger_lab=# CREATE TABLE products (
    id    SERIAL PRIMARY KEY,
    name  TEXT NOT NULL,
    price NUMERIC(10,2)
);
CREATE TABLE
trigger_lab=# CREATE TRIGGER trg_audit_products
    AFTER INSERT OR UPDATE OR DELETE ON products
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();
CREATE TRIGGER
trigger_lab=# INSERT INTO products (name, price) VALUES ('Widget', 9.99);
INSERT 0 1
trigger_lab=# SELECT table_name, operation, new_data FROM audit_log WHERE table_name = 'products';
 table_name | operation |                 new_data
------------+-----------+------------------------------------------
 products   | INSERT    | {"id": 1, "name": "Widget", "price": 9.99}
(1 row)
```

### Multi-Rule Validation Function
**Explanation:** Here is the validation trigger function. Instead of failing on the first error, we collect all violations into an array and raise them all at once. This is much better for the user — they see every problem in one message instead of fixing them one at a time.

```sql
CREATE OR REPLACE FUNCTION fn_validate_salary_change()
RETURNS TRIGGER AS $$
DECLARE
    v_errors TEXT[] := '{}';
    v_max_salary NUMERIC;
BEGIN
    -- Rule 1: Department salary range
    v_max_salary := CASE NEW.department
        WHEN 'Engineering' THEN 150000
        WHEN 'Marketing'   THEN 120000
        WHEN 'HR'          THEN 100000
        ELSE 200000
    END;
    IF NEW.salary > v_max_salary THEN
        v_errors := array_append(v_errors,
            format('Salary %s exceeds %s max of %s',
                   NEW.salary, NEW.department, v_max_salary));
    END IF;

    -- Rule 2: Max 25% raise
    IF NEW.salary > OLD.salary * 1.25 THEN
        v_errors := array_append(v_errors,
            format('Raise from %s to %s exceeds 25%% limit',
                   OLD.salary, NEW.salary));
    END IF;

    -- Rule 3: Minimum 90-day tenure
    IF NEW.salary <> OLD.salary
       AND OLD.created_at > now() - INTERVAL '90 days' THEN
        v_errors := array_append(v_errors,
            'Employee hired less than 90 days ago');
    END IF;

    IF array_length(v_errors, 1) > 0 THEN
        RAISE EXCEPTION 'Validation failed: %',
            array_to_string(v_errors, '; ');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### Testing Multi-Rule Validation
**Explanation:** Let us test the validation trigger. We will try to give a new employee a massive raise that violates multiple rules at once. Watch how we see all violations in a single error message.

```sql
trigger_lab=# CREATE TRIGGER trg_validate_salary
    BEFORE UPDATE OF salary ON employees
    FOR EACH ROW EXECUTE FUNCTION fn_validate_salary_change();
CREATE TRIGGER
trigger_lab=# -- Bob is in Sales, salary 75000, hired recently
trigger_lab=# UPDATE employees SET salary = 200000 WHERE name = 'Bob';
ERROR:  Validation failed: Salary 200000 exceeds Sales max of 200000; Raise from 75000 to 200000 exceeds 25% limit; Employee hired less than 90 days ago
-- -- All three violations reported in ONE error message!
trigger_lab=# -- Valid change: small raise within limits
trigger_lab=# UPDATE employees SET salary = 80000 WHERE name = 'Alice';
UPDATE 1
```

### Project 3: Auto Data Normalization
**Explanation:** Project three: automatic data normalization. Triggers can clean up data before it is stored. Let us create a trigger that normalizes email addresses to lowercase, trims whitespace from names, and sets a default department when none is given. This runs on INSERT and UPDATE, so data is always clean regardless of how it enters the database.

```sql
trigger_lab=# ALTER TABLE employees ADD COLUMN email TEXT;
ALTER TABLE
trigger_lab=# CREATE OR REPLACE FUNCTION fn_normalize_employee()
RETURNS TRIGGER AS $$
BEGIN
    NEW.name  = initcap(trim(NEW.name));
    NEW.email = lower(trim(NEW.email));
    IF NEW.department IS NULL OR NEW.department = '' THEN
        NEW.department = 'Unassigned';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE TRIGGER trg_normalize BEFORE INSERT OR UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION fn_normalize_employee();
CREATE TRIGGER
trigger_lab=# INSERT INTO employees (name, department, salary, email)
VALUES ('  grace HOPPER  ', '', 78000, '  GRACE@EXAMPLE.COM  ');
INSERT 0 1
trigger_lab=# SELECT name, department, email FROM employees WHERE email = 'grace@example.com';
     name     | department |       email
--------------+------------+---------------------
 Grace Hopper | Unassigned | grace@example.com
(1 row)
```

### Proving the Firing Order — Live
**Explanation:** Let us prove the firing order with a live demo. We will create four triggers on one table — BEFORE STATEMENT, BEFORE ROW, AFTER ROW, and AFTER STATEMENT — and run an UPDATE that hits two rows. Watch the NOTICE messages to see the exact sequence.

```sql
trigger_lab=# CREATE TABLE order_test (id INT, val TEXT);
CREATE TABLE
trigger_lab=# INSERT INTO order_test VALUES (1,'a'), (2,'b');
INSERT 0 2
trigger_lab=# -- (Creating 4 trigger functions that RAISE NOTICE their name)
trigger_lab=# CREATE TRIGGER t1_before_stmt BEFORE UPDATE ON order_test
    FOR EACH STATEMENT EXECUTE FUNCTION log_stmt_trigger();
CREATE TRIGGER
trigger_lab=# CREATE TRIGGER t2_before_row BEFORE UPDATE ON order_test
    FOR EACH ROW EXECUTE FUNCTION log_row_trigger();
CREATE TRIGGER
trigger_lab=# UPDATE order_test SET val = 'x';
NOTICE:  STATEMENT trigger fired once for entire operation
NOTICE:  ROW trigger fired for: (row 1)
NOTICE:  ROW trigger fired for: (row 2)
UPDATE 2
-- -- STATEMENT fires first, then ROW fires per-row
```

### INSTEAD OF Trigger on a View
**Explanation:** INSTEAD OF triggers are special — they only work on views, not tables. When you try to INSERT, UPDATE, or DELETE on a view, PostgreSQL normally rejects it unless the view is simple enough to be auto-updatable. An INSTEAD OF trigger intercepts the operation and lets you define what actually happens. You control exactly which underlying tables get modified and how. This makes complex views writable.

```sql
trigger_lab=# CREATE VIEW v_employee_summary AS
SELECT e.id, e.name, e.department, e.salary,
       e.salary * 12 AS annual_salary
FROM employees e;
CREATE VIEW
trigger_lab=# -- Try to insert into the view — fails without trigger
trigger_lab=# INSERT INTO v_employee_summary (name, department, salary)
VALUES ('Helen', 'Engineering', 88000);
ERROR:  cannot insert into view "v_employee_summary"
trigger_lab=# CREATE OR REPLACE FUNCTION fn_insert_employee_summary()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO employees (name, department, salary)
    VALUES (NEW.name, NEW.department, NEW.salary);
    RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE TRIGGER trg_insert_summary
    INSTEAD OF INSERT ON v_employee_summary
    FOR EACH ROW EXECUTE FUNCTION fn_insert_employee_summary();
CREATE TRIGGER
trigger_lab=# INSERT INTO v_employee_summary (name, department, salary) VALUES ('Helen', 'Engineering', 88000);
INSERT 0 1
-- Success! Row goes into the employees table.
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Trigger Performance
Here is a critical beginner trap with trigger performance. Every trigger adds overhead to every affected row. An AFTER ROW trigger on a table that gets 10,000 inserts per second means 10,000 trigger function calls per second. If your trigger function does an INSERT into the audit table, that is 10,000 extra INSERTs per second. For high-throughput tables, consider batching audit writes using STATEMENT-level triggers, or use logical replication to capture changes externally instead of triggers.

### Beginner Trap: Triggers vs Constraints
Another trap: trigger-based foreign key enforcement. Never try to enforce referential integrity with triggers — use FOREIGN KEY constraints instead. Triggers have race conditions under concurrent access. Two transactions can both pass the trigger check simultaneously, and neither sees the other's uncommitted rows. Constraints use internal locking that triggers cannot replicate. Triggers are for business logic. Constraints are for data integrity.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review what we covered. We built a universal audit log using JSONB and to_jsonb that works on any table. We created multi-rule validation triggers that collect all errors at once. We learned trigger cascading and the complete firing order: BEFORE STATEMENT, then per-row BEFORE ROW, write, AFTER ROW, then AFTER STATEMENT. We saw INSTEAD OF triggers for making views writable. And we learned that triggers are for business logic, not referential integrity — use constraints for that.

- **Universal audit: to_jsonb(NEW/OLD) + TG_TABLE_NAME + TG_OP**
- **One trigger function can serve many tables**
- **Multi-rule validation: collect errors into array, raise all at once**
- **Firing order: BEFORE STMT → (BEFORE ROW → write → AFTER ROW) × N → AFTER STMT**
- **Alphabetical order within same timing/level**
- **INSTEAD OF triggers: make views writable (views only)**
- **Performance trap: ROW triggers multiply with row count**
- **Never use triggers for FK/UNIQUE — use constraints**
- **Name triggers trg_01_, trg_02_ to control order**


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
