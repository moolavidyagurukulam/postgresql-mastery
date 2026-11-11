-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Event Triggers & Rules System (Classes 128-129)
-- Phase 15: Triggers & Rules
-- ============================================================

\c trigger_lab

-- ============================================================
-- 1. DDL AUDIT LOG WITH EVENT TRIGGERS
-- ============================================================

CREATE TABLE ddl_log (
    id         BIGSERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,
    command_tag TEXT NOT NULL,
    object_type TEXT,
    schema_name TEXT,
    object_name TEXT,
    executed_by TEXT DEFAULT session_user,
    executed_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION fn_log_ddl()
RETURNS event_trigger AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT * FROM pg_event_trigger_ddl_commands()
    LOOP
        INSERT INTO ddl_log (event_type, command_tag,
                             object_type, schema_name, object_name)
        VALUES (TG_EVENT, TG_TAG,
                r.object_type, r.schema_name, r.object_identity);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER evt_ddl_logger
    ON ddl_command_end
    EXECUTE FUNCTION fn_log_ddl();

-- Test it:
CREATE TABLE test_tracking (id SERIAL PRIMARY KEY, data TEXT);
CREATE INDEX idx_test_data ON test_tracking(data);
ALTER TABLE test_tracking ADD COLUMN status TEXT DEFAULT 'active';

SELECT command_tag, object_type, object_name, executed_by
FROM ddl_log ORDER BY id;

-- ============================================================
-- 2. BLOCKING DANGEROUS DDL
-- ============================================================

CREATE OR REPLACE FUNCTION fn_block_drop()
RETURNS event_trigger AS $$
BEGIN
    IF TG_TAG = 'DROP TABLE' AND NOT
       (SELECT usesuper FROM pg_user WHERE usename = session_user)
    THEN
        RAISE EXCEPTION 'DROP TABLE is blocked for non-superusers. Contact DBA for table removal requests.';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER evt_block_drop
    ON ddl_command_start
    WHEN TAG IN ('DROP TABLE')
    EXECUTE FUNCTION fn_block_drop();

-- ============================================================
-- 3. LOGGING DROPPED OBJECTS
-- ============================================================

CREATE OR REPLACE FUNCTION fn_log_drops()
RETURNS event_trigger AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        RAISE NOTICE 'DROPPED: % % (original: %)',
            r.object_type, r.object_identity, r.original;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER evt_log_drops ON sql_drop
    EXECUTE FUNCTION fn_log_drops();

-- Test (disable block trigger first):
ALTER EVENT TRIGGER evt_block_drop DISABLE;
DROP TABLE test_tracking;
ALTER EVENT TRIGGER evt_block_drop ENABLE;

-- ============================================================
-- 4. TABLE REWRITE DETECTION
-- ============================================================

CREATE OR REPLACE FUNCTION fn_warn_rewrite()
RETURNS event_trigger AS $$
DECLARE
    v_oid OID;
    v_table TEXT;
BEGIN
    v_oid := pg_event_trigger_table_rewrite_oid();
    SELECT relname INTO v_table FROM pg_class WHERE oid = v_oid;
    RAISE NOTICE 'TABLE REWRITE on: % — this locks the table!', v_table;
    -- Optional: block during business hours
    -- IF extract(hour FROM now()) BETWEEN 9 AND 17 THEN
    --     RAISE EXCEPTION 'Table rewrites blocked 9AM-5PM';
    -- END IF;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER evt_warn_rewrite ON table_rewrite
    EXECUTE FUNCTION fn_warn_rewrite();

-- Test:
CREATE TABLE rewrite_test (id SERIAL, val TEXT);
INSERT INTO rewrite_test (val) VALUES ('123');
ALTER TABLE rewrite_test ALTER COLUMN val TYPE INTEGER USING val::integer;

-- ============================================================
-- 5. MANAGING EVENT TRIGGERS
-- ============================================================

-- List all event triggers:
SELECT evtname, evtevent, evtenabled FROM pg_event_trigger;

-- Enable/Disable:
ALTER EVENT TRIGGER evt_block_drop DISABLE;
ALTER EVENT TRIGGER evt_block_drop ENABLE;

-- Drop:
DROP EVENT TRIGGER evt_warn_rewrite;

-- ============================================================
-- 6. RULES SYSTEM: Writable View
-- ============================================================

CREATE VIEW v_active_employees AS
SELECT id, name, department, salary FROM employees
WHERE department <> 'Unassigned';

CREATE RULE rule_insert_active AS ON INSERT TO v_active_employees
    DO INSTEAD
    INSERT INTO employees (name, department, salary)
    VALUES (NEW.name, NEW.department, NEW.salary);

CREATE RULE rule_update_active AS ON UPDATE TO v_active_employees
    DO INSTEAD
    UPDATE employees SET name = NEW.name, salary = NEW.salary
    WHERE id = OLD.id;

CREATE RULE rule_delete_active AS ON DELETE TO v_active_employees
    DO INSTEAD
    DELETE FROM employees WHERE id = OLD.id;

-- Test:
INSERT INTO v_active_employees (name, department, salary)
VALUES ('Iris', 'Engineering', 95000);
SELECT * FROM v_active_employees WHERE name = 'Iris';

-- ============================================================
-- 7. DO INSTEAD NOTHING (Black Hole Table)
-- ============================================================

CREATE TABLE blackhole_logs (id SERIAL, msg TEXT, ts TIMESTAMPTZ);

CREATE RULE rule_no_inserts AS ON INSERT TO blackhole_logs
    DO INSTEAD NOTHING;

-- INSERT succeeds but stores nothing:
INSERT INTO blackhole_logs (msg) VALUES ('This will vanish');
SELECT count(*) FROM blackhole_logs;  -- 0

-- ============================================================
-- 8. DO ALSO (Additional Action)
-- ============================================================

CREATE TABLE delete_log (
    table_name TEXT,
    deleted_id INT,
    deleted_at TIMESTAMPTZ DEFAULT now()
);

CREATE RULE rule_log_delete AS ON DELETE TO employees
    DO ALSO
    INSERT INTO delete_log (table_name, deleted_id)
    VALUES ('employees', OLD.id);

-- Test:
DELETE FROM employees WHERE name = 'Dave';
SELECT * FROM delete_log;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create an event trigger that logs all CREATE INDEX commands
--    Hint: WHEN TAG IN ('CREATE INDEX'), use pg_event_trigger_ddl_commands()

-- 2. Create an event trigger that blocks DROP TABLE between 9AM-5PM
--    Hint: ON ddl_command_start, check extract(hour FROM now())

-- 3. Create a rule using DO ALSO that logs every UPDATE to a changes table
--    Hint: CREATE RULE ... DO ALSO INSERT INTO changes (old_val, new_val)

-- 4. Create same writable view using INSTEAD OF trigger vs rule
--    Compare: test with RETURNING clause to see the difference

-- ============================================================
-- CLEANUP (optional)
-- ============================================================
-- DROP EVENT TRIGGER evt_ddl_logger;
-- DROP EVENT TRIGGER evt_block_drop;
-- DROP EVENT TRIGGER evt_log_drops;
-- DROP TABLE ddl_log, delete_log, blackhole_logs, rewrite_test;
-- DROP DATABASE trigger_lab;  -- run from another database
