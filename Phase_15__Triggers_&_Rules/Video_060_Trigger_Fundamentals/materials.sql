-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Trigger Fundamentals (Classes 124-125)
-- Phase 15: Triggers & Rules
-- ============================================================

-- Setup: Create practice database and table
CREATE DATABASE trigger_lab;
\c trigger_lab

CREATE TABLE employees (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    department  VARCHAR(50),
    salary      NUMERIC(10,2),
    created_at  TIMESTAMPTZ DEFAULT now(),
    modified_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO employees (name, department, salary) VALUES
  ('Alice', 'Engineering', 85000),
  ('Bob', 'Marketing', 65000),
  ('Carol', 'Engineering', 92000);

-- ============================================================
-- 1. TRIGGER FUNCTION ANATOMY
-- ============================================================
-- Trigger functions MUST return TRIGGER type
-- Special variables: NEW, OLD, TG_OP, TG_TABLE_NAME, TG_WHEN, TG_LEVEL

-- ============================================================
-- 2. FIRST TRIGGER: Auto-update modified_at
-- ============================================================

CREATE OR REPLACE FUNCTION update_modified_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.modified_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_employees_modified
    BEFORE UPDATE ON employees
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_at();

-- Test it:
SELECT name, salary, modified_at FROM employees WHERE name = 'Alice';
UPDATE employees SET salary = 90000 WHERE name = 'Alice';
SELECT name, salary, modified_at FROM employees WHERE name = 'Alice';

-- ============================================================
-- 3. BEFORE vs AFTER: Blocking an Operation
-- ============================================================

CREATE OR REPLACE FUNCTION enforce_min_salary()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.salary < 30000 THEN
        RAISE NOTICE 'Salary % is below minimum 30000. Update blocked.', NEW.salary;
        RETURN NULL;  -- cancels the operation
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_min_salary
    BEFORE UPDATE ON employees
    FOR EACH ROW
    EXECUTE FUNCTION enforce_min_salary();

-- Test: this will be blocked
UPDATE employees SET salary = 20000 WHERE name = 'Bob';
SELECT name, salary FROM employees WHERE name = 'Bob';

-- ============================================================
-- 4. ROW vs STATEMENT Triggers
-- ============================================================

CREATE OR REPLACE FUNCTION log_row_trigger()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'ROW trigger fired for: %', NEW.name;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_stmt_trigger()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'STATEMENT trigger fired once for entire operation';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_row_demo BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION log_row_trigger();

CREATE TRIGGER trg_stmt_demo BEFORE UPDATE ON employees
    FOR EACH STATEMENT EXECUTE FUNCTION log_stmt_trigger();

-- Update all rows — watch the output
UPDATE employees SET salary = salary * 1.05;

-- Cleanup demo triggers
DROP TRIGGER trg_row_demo ON employees;
DROP TRIGGER trg_stmt_demo ON employees;

-- ============================================================
-- 5. COLUMN-SPECIFIC TRIGGERS
-- ============================================================

CREATE TRIGGER trg_salary_change
    AFTER UPDATE OF salary ON employees
    FOR EACH ROW
    EXECUTE FUNCTION log_row_trigger();

-- This does NOT fire the trigger (not a salary change):
UPDATE employees SET department = 'Sales' WHERE name = 'Bob';

-- This DOES fire:
UPDATE employees SET salary = 70000 WHERE name = 'Bob';

DROP TRIGGER trg_salary_change ON employees;

-- ============================================================
-- 6. CONDITIONAL TRIGGERS WITH WHEN
-- ============================================================

CREATE TRIGGER trg_salary_actual_change
    AFTER UPDATE OF salary ON employees
    FOR EACH ROW
    WHEN (OLD.salary IS DISTINCT FROM NEW.salary)
    EXECUTE FUNCTION log_row_trigger();

-- Same value — no trigger:
UPDATE employees SET salary = 70000 WHERE name = 'Bob';

-- Different value — trigger fires:
UPDATE employees SET salary = 75000 WHERE name = 'Bob';

DROP TRIGGER trg_salary_actual_change ON employees;

-- ============================================================
-- 7. TRIGGER FIRING ORDER (Alphabetical)
-- ============================================================

CREATE OR REPLACE FUNCTION trigger_a()
RETURNS TRIGGER AS $$
BEGIN RAISE NOTICE 'Trigger A fired'; RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_b()
RETURNS TRIGGER AS $$
BEGIN RAISE NOTICE 'Trigger B fired'; RETURN NEW; END;
$$ LANGUAGE plpgsql;

-- trg_zzz uses trigger_a, trg_aaa uses trigger_b
CREATE TRIGGER trg_zzz BEFORE INSERT ON employees
    FOR EACH ROW EXECUTE FUNCTION trigger_a();
CREATE TRIGGER trg_aaa BEFORE INSERT ON employees
    FOR EACH ROW EXECUTE FUNCTION trigger_b();

-- trg_aaa fires FIRST (alphabetical), despite being created second
INSERT INTO employees (name, department, salary) VALUES ('Dave', 'HR', 55000);

-- ============================================================
-- 8. BEGINNER TRAP: Wrong Return Type
-- ============================================================

-- This will FAIL:
CREATE FUNCTION bad_trigger() RETURNS void AS $$
BEGIN RAISE NOTICE 'hello'; END; $$ LANGUAGE plpgsql;

-- ERROR: function bad_trigger() must return type trigger
CREATE TRIGGER trg_bad BEFORE INSERT ON employees
    FOR EACH ROW EXECUTE FUNCTION bad_trigger();

-- ============================================================
-- 9. BEGINNER TRAP: Accidental NULL Return
-- ============================================================

CREATE OR REPLACE FUNCTION accidental_null()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'Processing %', NEW.name;
    -- Forgot RETURN NEW! PL/pgSQL returns NULL by default.
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_oops BEFORE INSERT ON employees
    FOR EACH ROW EXECUTE FUNCTION accidental_null();

-- INSERT silently does nothing! (INSERT 0 0)
INSERT INTO employees (name, department, salary) VALUES ('Eve', 'Finance', 60000);

-- ============================================================
-- 10. MANAGING TRIGGERS
-- ============================================================

-- List triggers on a table:
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE event_object_table = 'employees';

-- Disable/Enable (useful during bulk loads):
ALTER TABLE employees DISABLE TRIGGER trg_min_salary;
ALTER TABLE employees ENABLE TRIGGER trg_min_salary;

-- Disable ALL triggers on a table:
ALTER TABLE employees DISABLE TRIGGER ALL;
ALTER TABLE employees ENABLE TRIGGER ALL;

-- Drop a trigger (does NOT drop the function):
DROP TRIGGER trg_min_salary ON employees;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a trigger that auto-converts names to title case on INSERT
--    Hint: NEW.name = initcap(NEW.name); RETURN NEW;

-- 2. Create BEFORE DELETE trigger that blocks deleting Engineering employees
--    Hint: IF OLD.department = 'Engineering' THEN RETURN NULL;

-- 3. Create a trigger that fires only on 20%+ salary increases
--    Hint: WHEN (NEW.salary > OLD.salary * 1.20)

-- 4. List all triggers: SELECT * FROM information_schema.triggers;
