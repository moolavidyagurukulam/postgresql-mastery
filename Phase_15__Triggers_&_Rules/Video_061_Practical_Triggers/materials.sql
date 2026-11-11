-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Practical Triggers (Classes 126-127)
-- Phase 15: Triggers & Rules
-- ============================================================

-- Prerequisite: trigger_lab database from previous class
\c trigger_lab

-- ============================================================
-- PROJECT 1: UNIVERSAL AUDIT LOG
-- ============================================================

CREATE TABLE audit_log (
    id          BIGSERIAL PRIMARY KEY,
    table_name  TEXT NOT NULL,
    operation   TEXT NOT NULL,
    old_data    JSONB,
    new_data    JSONB,
    changed_by  TEXT DEFAULT session_user,
    changed_at  TIMESTAMPTZ DEFAULT now()
);

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

-- Attach to employees table
CREATE TRIGGER trg_audit_employees
    AFTER INSERT OR UPDATE OR DELETE ON employees
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Test all three operations:
INSERT INTO employees (name, department, salary) VALUES ('Frank', 'HR', 52000);
UPDATE employees SET salary = 55000 WHERE name = 'Frank';
DELETE FROM employees WHERE name = 'Frank';

-- Check the audit log:
SELECT operation, old_data->>'name' AS who,
       old_data->>'salary' AS old_sal, new_data->>'salary' AS new_sal
FROM audit_log ORDER BY id;

-- Reuse on another table:
CREATE TABLE products (
    id    SERIAL PRIMARY KEY,
    name  TEXT NOT NULL,
    price NUMERIC(10,2)
);

CREATE TRIGGER trg_audit_products
    AFTER INSERT OR UPDATE OR DELETE ON products
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

INSERT INTO products (name, price) VALUES ('Widget', 9.99);
SELECT table_name, operation, new_data FROM audit_log WHERE table_name = 'products';

-- ============================================================
-- PROJECT 2: MULTI-RULE VALIDATION TRIGGER
-- ============================================================

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

CREATE TRIGGER trg_validate_salary
    BEFORE UPDATE OF salary ON employees
    FOR EACH ROW EXECUTE FUNCTION fn_validate_salary_change();

-- Test: violate multiple rules at once
UPDATE employees SET salary = 200000 WHERE name = 'Bob';

-- ============================================================
-- PROJECT 3: AUTO DATA NORMALIZATION
-- ============================================================

ALTER TABLE employees ADD COLUMN IF NOT EXISTS email TEXT;

CREATE OR REPLACE FUNCTION fn_normalize_employee()
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

CREATE TRIGGER trg_normalize BEFORE INSERT OR UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION fn_normalize_employee();

-- Test:
INSERT INTO employees (name, department, salary, email)
VALUES ('  grace HOPPER  ', '', 78000, '  GRACE@EXAMPLE.COM  ');

SELECT name, department, email FROM employees WHERE email = 'grace@example.com';

-- ============================================================
-- TRIGGER FIRING ORDER DEMO
-- ============================================================

CREATE TABLE order_test (id INT, val TEXT);
INSERT INTO order_test VALUES (1,'a'), (2,'b');

-- Create functions that announce their execution
CREATE OR REPLACE FUNCTION log_before_stmt()
RETURNS TRIGGER AS $$
BEGIN RAISE NOTICE '1. BEFORE STATEMENT'; RETURN NULL; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_before_row()
RETURNS TRIGGER AS $$
BEGIN RAISE NOTICE '2. BEFORE ROW for id=%', NEW.id; RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_after_row()
RETURNS TRIGGER AS $$
BEGIN RAISE NOTICE '3. AFTER ROW for id=%', NEW.id; RETURN NULL; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_after_stmt()
RETURNS TRIGGER AS $$
BEGIN RAISE NOTICE '4. AFTER STATEMENT'; RETURN NULL; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t1_before_stmt BEFORE UPDATE ON order_test
    FOR EACH STATEMENT EXECUTE FUNCTION log_before_stmt();
CREATE TRIGGER t2_before_row BEFORE UPDATE ON order_test
    FOR EACH ROW EXECUTE FUNCTION log_before_row();
CREATE TRIGGER t3_after_row AFTER UPDATE ON order_test
    FOR EACH ROW EXECUTE FUNCTION log_after_row();
CREATE TRIGGER t4_after_stmt AFTER UPDATE ON order_test
    FOR EACH STATEMENT EXECUTE FUNCTION log_after_stmt();

UPDATE order_test SET val = 'x';

-- ============================================================
-- INSTEAD OF TRIGGER ON VIEW
-- ============================================================

CREATE VIEW v_employee_summary AS
SELECT e.id, e.name, e.department, e.salary,
       e.salary * 12 AS annual_salary
FROM employees e;

CREATE OR REPLACE FUNCTION fn_insert_employee_summary()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO employees (name, department, salary)
    VALUES (NEW.name, NEW.department, NEW.salary);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_insert_summary
    INSTEAD OF INSERT ON v_employee_summary
    FOR EACH ROW EXECUTE FUNCTION fn_insert_employee_summary();

INSERT INTO v_employee_summary (name, department, salary)
VALUES ('Helen', 'Engineering', 88000);

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Attach fn_audit_log() to products table. Insert/update/delete rows.
--    Verify both tables appear in audit_log with correct table_name.

-- 2. Create BEFORE DELETE STATEMENT trigger that counts affected rows
--    and raises exception if trying to delete more than 1 employee at once.

-- 3. Create INSTEAD OF trigger on a view joining employees and products.
--    Route INSERTs to the correct underlying table.

-- 4. Create BEFORE DELETE trigger that archives deleted employees to
--    a former_employees table (with deleted_at timestamp).
