# Event Triggers & Rules System
**Series:** PostgreSQL Mastery | **Phase:** Phase 15: Triggers & Rules | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we explore two powerful features. First, event triggers — triggers that fire on DDL commands like CREATE TABLE, ALTER TABLE, and DROP TABLE. While regular triggers watch data changes, event triggers watch schema changes. Second, we cover PostgreSQL's rules system — an older mechanism that rewrites queries before they execute. You will learn when each is useful and when to avoid them. Let us begin.

### The Problem: DDL Goes Untracked
Here is the problem. You are a DBA managing a production database. Someone drops a table at 3 AM. Someone renames a column that breaks your application. Someone creates an index without CONCURRENTLY, locking the table during peak hours. With regular triggers, you cannot catch any of this — regular triggers only watch INSERT, UPDATE, and DELETE on data. You need something that watches DDL — the commands that change the database structure itself. That is what event triggers do.


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: DDL Goes Untracked
Here is the problem. You are a DBA managing a production database. Someone drops a table at 3 AM. Someone renames a column that breaks your application. Someone creates an index without CONCURRENTLY, locking the table during peak hours. With regular triggers, you cannot catch any of this — regular triggers only watch INSERT, UPDATE, and DELETE on data. You need something that watches DDL — the commands that change the database structure itself. That is what event triggers do.

| Regular Triggers Watch | Event Triggers Watch |
| :--- | :--- |
| INSERT INTO employees ... | CREATE TABLE ... |
| UPDATE employees SET ... | ALTER TABLE ... DROP COLUMN |
| DELETE FROM employees ... | DROP TABLE ... |
| Data changes only | Schema/structure changes |

### Event Trigger Events
An event trigger fires on four types of DDL events. ddl_command_start fires before a DDL command executes — you can use it to block commands. ddl_command_end fires after a DDL command completes successfully — you can use it to log what happened. sql_drop fires after a DROP command completes — it gives you details about what was dropped. And table_rewrite fires when a command requires rewriting a table, like ALTER TABLE changing a column type. Event triggers fire at the database level, not on a specific table.

| Term | Meaning / Explanation |
| :--- | :--- |
| **ddl_command_start** | BEFORE DDL executes — can block the command by raising an exception |
| **ddl_command_end** | AFTER DDL succeeds — log what happened using pg_event_trigger_ddl_commands() |
| **sql_drop** | AFTER DROP completes — details via pg_event_trigger_dropped_objects() |
| **table_rewrite** | When ALTER TABLE must rewrite data — pg_event_trigger_table_rewrite_oid() |

**Notes:**
- Event triggers are DATABASE-level, not table-level
- Function must return event_trigger (not trigger)

### Common Event Trigger Tags
You can filter event triggers to fire only for specific DDL commands using the WHEN TAG IN clause. This is much more efficient than checking TG_TAG inside the function. You can list multiple commands. Here are the most common tags you will filter on.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | You can filter event triggers to fire only for specific DDL commands using the WHEN TAG IN clause |
| **Point 2** | This is much more efficient than checking TG_TAG inside the function |
| **Point 3** | You can list multiple commands |

### The Rules System (pg_rewrite)
Now let us shift to the PostgreSQL rules system. Rules are an older mechanism — they were used before triggers existed for views. A rule rewrites a query before it executes. Instead of the original query running, PostgreSQL substitutes a different query. The most common use is making views updatable, but INSTEAD OF triggers on views have largely replaced this. Still, rules appear in legacy systems and you need to understand them.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Rule** | Rewrites a query before execution — replaces or supplements the original SQL |
| **DO INSTEAD** | Replace the original query entirely with the rule's action |
| **DO ALSO** | Run the rule's action in addition to the original query |
| **DO INSTEAD NOTHING** | Silently discard the original query — it never executes |

**Notes:**
- Rules fire at query PLANNING time, not execution time
- Triggers fire at EXECUTION time per-row
- Views already use rules internally (SELECT rules)

### Beginner Trap: Rules Gotchas
Here is a critical beginner trap: rules have surprising behavior with RETURNING, COPY, and row counts. When a rule rewrites a query, the RETURNING clause may not return what you expect — it can return rows from the rule's action instead of the original query. COPY INTO a table with rules does not fire the rules at all. And INSERT 0 0 with a DO INSTEAD rule confuses ORMs that check affected row counts. These are the main reasons the PostgreSQL community recommends triggers over rules for new code.

| Rules Problems | Why Triggers Are Better |
| :--- | :--- |
| RETURNING may return wrong rows | RETURNING works normally |
| COPY bypasses rules entirely | COPY fires triggers correctly |
| Row counts are misleading | Row counts are accurate |
| Conditional rules are complex | Simple IF/THEN logic |
| Hard to debug — invisible rewrite | RAISE NOTICE for debugging |

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too. Now let us continue with the decision framework.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Decision Framework: Triggers vs Event Triggers vs Rules
Here is the complete decision framework for triggers, event triggers, and rules. This covers when to use each mechanism and when to avoid them.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is the complete decision framework for triggers, event triggers, and rules |
| **Point 2** | This covers when to use each mechanism and when to avoid them |

### Event Trigger Limitations
Here is a beginner trap with event triggers: they cannot fire inside a transaction that is being replayed on a replica. Event triggers only fire on the primary server. If you rely on event trigger logging, your replica will not have those log entries. Also, event triggers cannot see the actual SQL text of the command — they see the parsed command tag like CREATE TABLE, but not the full CREATE TABLE statement with all its columns. For full SQL logging, use log_statement = 'ddl' in postgresql.conf.

- 1 -- Event triggers fire on primary server only. Replicas do not fire them.
- 2 -- TG_TAG = 'CREATE TABLE' but you cannot see column definitions.
- 3 -- Only superusers can CREATE EVENT TRIGGER — security measure.
- 4 -- Use postgresql.conf: log_statement = 'ddl' instead of event triggers.
- 5 -- Event triggers are automatically disabled during pg_dump and pg_restore.

### Practice Exercises
Time to practice. Open psql and try these exercises. First, create an event trigger that logs all CREATE INDEX commands, capturing the index name and table. Second, create an event trigger that blocks DROP TABLE between 9 AM and 5 PM. Third, create a rule using DO ALSO that logs every UPDATE on a table into a changes table. Fourth, create an INSTEAD OF trigger on a view that joins two tables — compare this with a rule approach and see which is easier to debug.

- 1 -- Event trigger on ddl_command_end, WHEN TAG IN ('CREATE INDEX'). Log index name.
- 2 -- Event trigger on ddl_command_start. Check extract(hour FROM now()). Raise exception 9-17.
- 3 -- CREATE RULE ... DO ALSO INSERT INTO changes_log with OLD and NEW values.
- 4 -- Create same writable view using both approaches. Test with RETURNING clause.


---

## 3. Hands-On Commands & psql Output

### Building a DDL Audit Log
**Explanation:** Let us build a DDL audit log. Every time someone runs a DDL command — CREATE, ALTER, DROP, anything — we will log it. First, we create a ddl_log table to store the records. Then we create an event trigger function. Notice: event trigger functions return event_trigger, not trigger. Inside the function, we use TG_EVENT for the event name and TG_TAG for the specific command like CREATE TABLE or DROP INDEX.

```sql
trigger_lab=# CREATE TABLE ddl_log (
    id         BIGSERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,
    command_tag TEXT NOT NULL,
    object_type TEXT,
    schema_name TEXT,
    object_name TEXT,
    executed_by TEXT DEFAULT session_user,
    executed_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE
```

### DDL Audit Event Trigger Function
**Explanation:** Now the event trigger function. We use pg_event_trigger_ddl_commands to get details about what was created or altered. This function is only available inside ddl_command_end triggers. It returns the object type, schema, and name of every object affected by the DDL command.

```sql
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
```

### Testing DDL Audit Logging
**Explanation:** We create the event trigger and test it. Notice the syntax: CREATE EVENT TRIGGER, not CREATE TRIGGER. We specify ON ddl_command_end. Let us create a table and an index, then check the log.

```sql
trigger_lab=# CREATE EVENT TRIGGER evt_ddl_logger
    ON ddl_command_end
    EXECUTE FUNCTION fn_log_ddl();
CREATE EVENT TRIGGER
trigger_lab=# CREATE TABLE test_tracking (id SERIAL PRIMARY KEY, data TEXT);
CREATE TABLE
trigger_lab=# CREATE INDEX idx_test_data ON test_tracking(data);
CREATE INDEX
trigger_lab=# ALTER TABLE test_tracking ADD COLUMN status TEXT DEFAULT 'active';
ALTER TABLE
trigger_lab=# SELECT command_tag, object_type, object_name, executed_by
FROM ddl_log ORDER BY id;
  command_tag  | object_type |            object_name             | executed_by
---------------+-------------+------------------------------------+------------
 CREATE TABLE  | table       | public.test_tracking               | postgres
 CREATE TABLE  | sequence    | public.test_tracking_id_seq        | postgres
 CREATE INDEX  | index       | public.idx_test_data               | postgres
 ALTER TABLE   | table       | public.test_tracking               | postgres
(4 rows)
```

### Blocking Dangerous DDL Commands
**Explanation:** Now let us build a safety guard: blocking dangerous DDL in production. We will create an event trigger on ddl_command_start that prevents anyone from dropping tables unless they are a superuser. This is a real production pattern — it stops accidental DROP TABLE commands.

```sql
trigger_lab=# CREATE OR REPLACE FUNCTION fn_block_drop()
RETURNS event_trigger AS $$
BEGIN
    IF TG_TAG = 'DROP TABLE' AND NOT
       (SELECT usesuper FROM pg_user WHERE usename = session_user)
    THEN
        RAISE EXCEPTION 'DROP TABLE is blocked for non-superusers.
Contact DBA for table removal requests.';
    END IF;
END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE EVENT TRIGGER evt_block_drop
    ON ddl_command_start
    WHEN TAG IN ('DROP TABLE')
    EXECUTE FUNCTION fn_block_drop();
CREATE EVENT TRIGGER
-- -- Now non-superusers cannot DROP TABLE
```

### Logging Dropped Objects with sql_drop
**Explanation:** The sql_drop event gives you details about dropped objects. This is different from ddl_command_end — it fires specifically on DROP commands and provides a function called pg_event_trigger_dropped_objects that tells you exactly what was removed: the object type, schema, name, and even whether it was the original target or a cascade victim.

```sql
trigger_lab=# CREATE OR REPLACE FUNCTION fn_log_drops()
RETURNS event_trigger AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        RAISE NOTICE 'DROPPED: % % (original: %)',
            r.object_type, r.object_identity, r.original;
    END LOOP;
END; $$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE EVENT TRIGGER evt_log_drops ON sql_drop
    EXECUTE FUNCTION fn_log_drops();
CREATE EVENT TRIGGER
trigger_lab=# -- Disable the block trigger temporarily for testing
trigger_lab=# ALTER EVENT TRIGGER evt_block_drop DISABLE;
ALTER EVENT TRIGGER
trigger_lab=# DROP TABLE test_tracking;
NOTICE:  DROPPED: table public.test_tracking (original: t)
NOTICE:  DROPPED: sequence public.test_tracking_id_seq (original: f)
NOTICE:  DROPPED: index public.idx_test_data (original: f)
DROP TABLE
```

### table_rewrite: Detecting Dangerous ALTER TABLE
**Explanation:** The table_rewrite event fires when ALTER TABLE needs to physically rewrite the entire table — for example, changing a column's data type from TEXT to INTEGER. Table rewrites lock the table and can take a very long time on large tables. This trigger lets you detect and potentially block rewrites during business hours.

```sql
trigger_lab=# CREATE OR REPLACE FUNCTION fn_warn_rewrite()
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
END; $$ LANGUAGE plpgsql;
CREATE FUNCTION
trigger_lab=# CREATE EVENT TRIGGER evt_warn_rewrite ON table_rewrite
    EXECUTE FUNCTION fn_warn_rewrite();
CREATE EVENT TRIGGER
trigger_lab=# CREATE TABLE rewrite_test (id SERIAL, val TEXT);
CREATE TABLE
trigger_lab=# ALTER TABLE rewrite_test ALTER COLUMN val TYPE INTEGER USING val::integer;
NOTICE:  TABLE REWRITE on: rewrite_test — this locks the table!
ALTER TABLE
```

### Managing Event Triggers
**Explanation:** Managing event triggers. You can list all event triggers using pg_event_trigger catalog. You can enable and disable them with ALTER EVENT TRIGGER. And you can drop them. Only superusers can create event triggers — this is a security measure since event triggers fire on every DDL in the database.

```sql
trigger_lab=# SELECT evtname, evtevent, evtenabled
FROM pg_event_trigger;
     evtname      |     evtevent      | evtenabled
------------------+-------------------+-----------
 evt_ddl_logger   | ddl_command_end   | O
 evt_block_drop   | ddl_command_start | D
 evt_log_drops    | sql_drop          | O
 evt_warn_rewrite | table_rewrite     | O
(4 rows)
-- -- O = Origin (enabled), D = Disabled, R = Replica, A = Always
trigger_lab=# ALTER EVENT TRIGGER evt_block_drop ENABLE;
ALTER EVENT TRIGGER
trigger_lab=# DROP EVENT TRIGGER evt_warn_rewrite;
DROP EVENT TRIGGER
```

### Rules in Action: Writable View via Rules
**Explanation:** Here is how rules work. When you create a view, PostgreSQL automatically creates a SELECT rule. That is why querying a view works — the rule rewrites your SELECT into the underlying query. We can add INSERT, UPDATE, and DELETE rules to make views writable. Let us see a simple example.

```sql
trigger_lab=# CREATE VIEW v_active_employees AS
SELECT id, name, department, salary FROM employees
WHERE department <> 'Unassigned';
CREATE VIEW
trigger_lab=# CREATE RULE rule_insert_active AS ON INSERT TO v_active_employees
    DO INSTEAD
    INSERT INTO employees (name, department, salary)
    VALUES (NEW.name, NEW.department, NEW.salary);
CREATE RULE
trigger_lab=# CREATE RULE rule_update_active AS ON UPDATE TO v_active_employees
    DO INSTEAD
    UPDATE employees SET name = NEW.name, salary = NEW.salary
    WHERE id = OLD.id;
CREATE RULE
trigger_lab=# INSERT INTO v_active_employees (name, department, salary)
VALUES ('Iris', 'Engineering', 95000);
INSERT 0 1
trigger_lab=# SELECT * FROM v_active_employees WHERE name = 'Iris';
 id |  name  | department  |  salary
----+--------+-------------+----------
  9 | Iris   | Engineering | 95000.00
(1 row)
```

### DO INSTEAD NOTHING — Silent Discard
**Explanation:** DO INSTEAD NOTHING is a useful pattern. It silently discards the query. This can be used to make a table appear read-only to certain applications, or to create a black hole table that accepts INSERTs but does not store anything — useful for test environments where you want to discard data without changing application code.

```sql
trigger_lab=# CREATE TABLE blackhole_logs (id SERIAL, msg TEXT, ts TIMESTAMPTZ);
CREATE TABLE
trigger_lab=# CREATE RULE rule_no_inserts AS ON INSERT TO blackhole_logs
    DO INSTEAD NOTHING;
CREATE RULE
trigger_lab=# INSERT INTO blackhole_logs (msg) VALUES ('This will vanish');
INSERT 0 0
trigger_lab=# SELECT count(*) FROM blackhole_logs;
 count
-------
     0
(1 row)
-- -- INSERT succeeded (no error) but stored nothing
```

### DO ALSO — Additional Action
**Explanation:** DO ALSO adds an action alongside the original query. For example, you can create a rule that logs every DELETE from a table by also inserting into a log table. The original DELETE still happens, but the log INSERT happens too.

```sql
trigger_lab=# CREATE TABLE delete_log (table_name TEXT, deleted_id INT, deleted_at TIMESTAMPTZ DEFAULT now());
CREATE TABLE
trigger_lab=# CREATE RULE rule_log_delete AS ON DELETE TO employees
    DO ALSO
    INSERT INTO delete_log (table_name, deleted_id)
    VALUES ('employees', OLD.id);
CREATE RULE
trigger_lab=# DELETE FROM employees WHERE name = 'Dave';
DELETE 1
trigger_lab=# SELECT * FROM delete_log;
 table_name | deleted_id |          deleted_at
------------+------------+-------------------------------
 employees  |          4 | 2026-11-03 10:30:15.123+05:30
(1 row)
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Rules Gotchas
Here is a critical beginner trap: rules have surprising behavior with RETURNING, COPY, and row counts. When a rule rewrites a query, the RETURNING clause may not return what you expect — it can return rows from the rule's action instead of the original query. COPY INTO a table with rules does not fire the rules at all. And INSERT 0 0 with a DO INSTEAD rule confuses ORMs that check affected row counts. These are the main reasons the PostgreSQL community recommends triggers over rules for new code.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review what we covered. Event triggers watch DDL commands — schema changes, not data changes. They fire on four events: ddl_command_start, ddl_command_end, sql_drop, and table_rewrite. Event trigger functions return event_trigger and use TG_EVENT and TG_TAG variables. The rules system rewrites queries before execution using DO INSTEAD, DO ALSO, or DO INSTEAD NOTHING. Rules are largely replaced by INSTEAD OF triggers for views, but you may encounter them in legacy systems. For new code, always prefer triggers over rules.

- **Event triggers: watch DDL (CREATE/ALTER/DROP), not data**
- **Four events: ddl_command_start, ddl_command_end, sql_drop, table_rewrite**
- **Function returns event_trigger, uses TG_EVENT and TG_TAG**
- **pg_event_trigger_ddl_commands() for details in ddl_command_end**
- **pg_event_trigger_dropped_objects() for details in sql_drop**
- **Only superusers can create event triggers**
- **Rules rewrite queries at PLANNING time, not execution**
- **DO INSTEAD replaces query, DO ALSO adds to it**
- **Rules: COPY bypasses, RETURNING misleading, hard to debug**
- **For new code: always triggers over rules**


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
