# Cursors & Dynamic SQL
**Series:** PostgreSQL Mastery | **Phase:** Phase 14: PL/pgSQL Programming | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover cursors and dynamic SQL. A cursor lets you process query results one row at a time — useful when the result set is too large to load into memory at once. Dynamic SQL lets you build and execute SQL statements at runtime using EXECUTE — the query itself is constructed as a string. Both are advanced PL/pgSQL tools. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Cursors — Row-by-Row Processing
A cursor is a pointer to a query result set. Instead of fetching all rows at once, you open the cursor, fetch rows one by one, and close it when done. This is useful for very large result sets where loading everything into memory would be expensive. In most cases, a FOR loop over a query is simpler and better — use cursors only when you need explicit row-by-row control or when working with very large datasets.

| Term | Meaning / Explanation |
| :--- | :--- |
| **DECLARE** | Declare a cursor variable for a query |
| **OPEN** | Execute the query and position before first row |
| **FETCH** | Get the next row into variables |
| **CLOSE** | Release the cursor resources |
| **When to use** | Very large results, explicit row control |

**Notes:**
- FOR rec IN SELECT ... is usually simpler than cursors
- Cursors are closed on COMMIT (in procedures)

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Dynamic SQL — Safety & Performance
Important safety rules for dynamic SQL. Never concatenate user input directly into a query string — always use format with percent-I for identifiers and percent-L for literals, or use the USING clause with dollar placeholders. These prevent SQL injection attacks. Also, dynamic SQL cannot be optimized by the planner — the query plan is created fresh each time EXECUTE runs, so use static SQL when possible.

| Safe Patterns | Dangerous (Never Do) |
| :--- | :--- |
| format('%I', tbl) for table/column names | EXECUTE 'SELECT * FROM ' || user_input |
| format('%L', val) for literal values | 'WHERE name = ''' || name || '''' |
| EXECUTE ... USING $1, $2 for parameters | Using %s for user-supplied values |
| Validate inputs before building SQL | Trusting input without validation |
| Use static SQL when query shape is fixed | Building SQL from external data |

### Decision Framework: Cursor vs Dynamic vs Static
When should you use cursors versus dynamic SQL versus regular queries? Here is the decision framework. For fixed queries, use regular static SQL — it is fastest. For queries with unknown table or column names, use dynamic SQL with format. For very large result sets where you need row-by-row processing with explicit control, use cursors. For most row-by-row needs, a FOR loop over a query is simpler than a cursor.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | When should you use cursors versus dynamic SQL versus regular queries? |
| **For fixed queries** | use regular static SQL — it is fastest |
| **Point 3** | For queries with unknown table or column names, use dynamic SQL with format |
| **Point 4** | For very large result sets where you need row-by-row processing with explicit control, use cursors |
| **For most row** | by-row needs, a FOR loop over a query is simpler than a cursor |

### Practice Exercises
Practice exercises: create a cursor that processes accounts row by row, write a parameterized cursor, build a dynamic SQL function that counts rows in any table, create a search function with optional filters using format and percent-L, use EXECUTE with USING for safe parameter passing, and build a dynamic archive function.

- 1. Cursor: OPEN, FETCH, CLOSE loop over accounts
- 2. Parameterized cursor: filter by minimum balance
- 3. SCROLL cursor: FETCH FIRST, FETCH LAST, FETCH PRIOR
- 4. EXECUTE format('SELECT * FROM %I', table_name)
- 5. EXECUTE ... USING: safe parameter substitution
- 6. Dynamic search: build WHERE from optional params
- 7. Dynamic DDL: create archive table with timestamp
- 8. Debug: use RAISE NOTICE to print generated SQL


---

## 3. Hands-On Commands & psql Output

### Declaring and Using Cursors
**Explanation:** There are two ways to declare cursors. A bound cursor has its query defined at declaration time. An unbound cursor — declared as REFCURSOR — gets its query assigned when you OPEN it. Bound cursors can accept parameters. After OPEN, use FETCH to get rows and check FOUND to know when there are no more rows.

```sql
practice=# CREATE OR REPLACE FUNCTION cursor_demo()
RETURNS TEXT AS $$
DECLARE
    -- Bound cursor: query defined here
    cur CURSOR FOR SELECT name, bal FROM accounts ORDER BY bal DESC;
    rec RECORD;
    result TEXT := '';
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        result := result || rec.name || ': $' || rec.bal || E'\n';
    END LOOP;
    CLOSE cur;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

practice=# SELECT cursor_demo();
   cursor_demo
-----------------
 Alice: $1000.00
 Bob: $500.00
 Carol: $300.00
```

### Parameterized Cursors & FOR Shorthand
**Explanation:** Cursors with parameters are powerful. You declare the cursor with parameter placeholders, then pass values when you OPEN it. This lets you reuse the same cursor definition with different filters. You can also use the FOR loop shorthand — FOR rec IN cursor_name — which automatically opens, fetches, and closes the cursor.

```sql
practice=# CREATE OR REPLACE FUNCTION rich_accounts(min_bal NUMERIC)
RETURNS TEXT AS $$
DECLARE
    -- Parameterized cursor
    cur CURSOR(threshold NUMERIC) FOR
        SELECT name, bal FROM accounts WHERE bal >= threshold;
    rec RECORD;
    result TEXT := '';
BEGIN
    -- FOR loop shorthand: auto open/fetch/close
    FOR rec IN cur(min_bal) LOOP
        result := result || rec.name || ' ';
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

practice=# SELECT rich_accounts(500);
 rich_accounts
---------------
 Alice Bob
```

### Unbound Cursor & SCROLL
**Explanation:** An unbound cursor is declared as REFCURSOR — it has no query yet. You assign the query when you OPEN it. This is useful when the query depends on runtime conditions. You can also use SCROLL to move backwards through results with FETCH PRIOR or FETCH FIRST. Without SCROLL, you can only move forward.

```sql
practice=# CREATE OR REPLACE FUNCTION scroll_demo()
RETURNS TEXT AS $$
DECLARE
    cur REFCURSOR;  -- unbound: no query yet
    rec RECORD;
    result TEXT := '';
BEGIN
    OPEN cur SCROLL FOR  -- SCROLL allows backward
        SELECT name, bal FROM accounts ORDER BY id;

    FETCH FIRST FROM cur INTO rec;
    result := 'First: ' || rec.name;

    FETCH LAST FROM cur INTO rec;
    result := result || ', Last: ' || rec.name;

    FETCH PRIOR FROM cur INTO rec;  -- go backward!
    result := result || ', Before last: ' || rec.name;

    CLOSE cur;
    RETURN result;
END; $$ LANGUAGE plpgsql;

practice=# SELECT scroll_demo();
 First: Alice, Last: Carol, Before last: Bob
```

### Beginner Trap: Cursor Closed on COMMIT
**Explanation:** Beginner trap: cursors are automatically closed when a transaction ends. In a procedure with COMMIT, this means any open cursor is destroyed after the COMMIT. If you try to FETCH from it afterward, you get 'cursor is not open.' The fix: either process all cursor rows before COMMIT, or re-open the cursor after each COMMIT.

```sql
-- This FAILS in a procedure:
practice=# CREATE OR REPLACE PROCEDURE bad_batch() AS $$
DECLARE
    cur CURSOR FOR SELECT id, bal FROM accounts;
    rec RECORD;
BEGIN
    OPEN cur;
    FETCH cur INTO rec;
    UPDATE accounts SET bal = bal * 1.05 WHERE id = rec.id;
    COMMIT;  -- cursor is now CLOSED!
    FETCH cur INTO rec;  -- ERROR!
END; $$ LANGUAGE plpgsql;

practice=# CALL bad_batch();
ERROR:  cursor "cur" is not open

-- Fix: use FOR loop instead of cursor in procedures
-- Or re-OPEN cursor after each COMMIT
-- Or use DECLARE cur CURSOR WITH HOLD FOR ...
-- WITH HOLD keeps cursor open across COMMIT
```

### Dynamic SQL with EXECUTE
**Explanation:** Dynamic SQL with EXECUTE lets you build SQL queries as strings and run them at runtime. This is essential when the table name, column name, or condition is not known until the function is called. Use the format function with percent-I for identifiers — it properly quotes table and column names — and percent-L for literal values — it properly escapes strings. Never concatenate user input directly — that causes SQL injection.

```sql
-- EXECUTE runs a string as SQL
practice=# CREATE OR REPLACE FUNCTION count_rows(tbl_name TEXT)
RETURNS BIGINT AS $$
DECLARE
    result BIGINT;
BEGIN
    -- format(%I) quotes identifiers safely
    EXECUTE format('SELECT COUNT(*) FROM %I', tbl_name)
    INTO result;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

practice=# SELECT count_rows('accounts');
 count_rows
------------
          3

-- format placeholders:
--   %I = identifier (table/column, quoted if needed)
--   %L = literal value (string, properly escaped)
--   %s = simple substitution (NO escaping — avoid!)

-- NEVER do this (SQL injection!):
-- EXECUTE 'SELECT * FROM ' || user_input;
```

### EXECUTE with USING — Safe Parameters
**Explanation:** The USING clause is another safe way to pass values into dynamic SQL. Instead of embedding values in the string, you put dollar-sign placeholders — dollar-one, dollar-two — in the query and pass the actual values with USING. PostgreSQL substitutes them safely, preventing SQL injection. USING is preferred for values; format with percent-I is needed for identifiers like table names.

```sql
practice=# CREATE OR REPLACE FUNCTION find_by_balance(
    tbl TEXT, min_bal NUMERIC
) RETURNS TABLE(acct_name VARCHAR, balance NUMERIC) AS $$
BEGIN
    RETURN QUERY EXECUTE
        format('SELECT name, bal FROM %I WHERE bal >= $1', tbl)
        USING min_bal;  -- $1 is replaced safely
END;
$$ LANGUAGE plpgsql;

practice=# SELECT * FROM find_by_balance('accounts', 500);
 acct_name | balance
-----------+---------
 Alice     | 1000.00
 Bob       |  500.00

-- Multiple USING params:
-- EXECUTE 'SELECT $1 + $2' INTO result USING 10, 20;
-- result = 30
```

### Practical: Dynamic Search Builder
**Explanation:** Here is a practical dynamic SQL function that builds a flexible search query. The WHERE clause is constructed conditionally — only filters that have values are included. This pattern is common in applications with optional search filters where you do not know which criteria the user will provide.

```sql
practice=# CREATE OR REPLACE FUNCTION search_accounts(
    p_name TEXT DEFAULT NULL,
    p_min_bal NUMERIC DEFAULT NULL,
    p_max_bal NUMERIC DEFAULT NULL
) RETURNS TABLE(id INT, name VARCHAR, bal NUMERIC) AS $$
DECLARE
    sql TEXT := 'SELECT id, name, bal FROM accounts WHERE 1=1';
BEGIN
    IF p_name IS NOT NULL THEN
        sql := sql || format(' AND name ILIKE %L', '%'||p_name||'%');
    END IF;
    IF p_min_bal IS NOT NULL THEN
        sql := sql || format(' AND bal >= %L', p_min_bal);
    END IF;
    IF p_max_bal IS NOT NULL THEN
        sql := sql || format(' AND bal <= %L', p_max_bal);
    END IF;
    RAISE NOTICE 'Query: %', sql;
    RETURN QUERY EXECUTE sql;
END; $$ LANGUAGE plpgsql;

practice=# SELECT * FROM search_accounts(p_min_bal := 500);
NOTICE:  Query: SELECT id, name, bal FROM accounts WHERE 1=1 AND bal >= '500'
 id | name  |   bal
----+-------+---------
  1 | Alice | 1000.00
  2 | Bob   |  500.00
```

### Dynamic DDL — Create Tables at Runtime
**Explanation:** Dynamic DDL: you can also create and alter tables dynamically. This function creates a timestamped archive table and copies data into it. This is useful for automated maintenance scripts — for example, archiving old data into monthly tables, or creating partitions programmatically.

```sql
practice=# CREATE OR REPLACE FUNCTION archive_accounts()
RETURNS TEXT AS $$
DECLARE
    archive_name TEXT;
    row_count INT;
BEGIN
    archive_name := 'accounts_' || to_char(NOW(), 'YYYY_MM_DD');
    EXECUTE format(
        'CREATE TABLE %I (LIKE accounts INCLUDING ALL)',
        archive_name);
    EXECUTE format(
        'INSERT INTO %I SELECT * FROM accounts', archive_name);
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RETURN format('Archived %s rows to %s', row_count, archive_name);
END; $$ LANGUAGE plpgsql;

practice=# SELECT archive_accounts();
 Archived 3 rows to accounts_2024_01_15

practice=# \dt accounts*
           List of relations
 Schema |        Name         | Type  | Owner
--------+---------------------+-------+----------
 public | accounts            | table | postgres
 public | accounts_2024_01_15 | table | postgres
```

### Beginner Trap: Debugging Dynamic SQL
**Explanation:** Beginner trap: dynamic SQL errors are hard to debug because the error points to the EXECUTE line, not the actual SQL that failed. Always use RAISE NOTICE to print the generated SQL before executing it. This lets you copy and paste the query into psql to test it directly. Once it works, you can remove the RAISE NOTICE.

```sql
-- Error message is unhelpful:
practice=# DO $$ BEGIN
  EXECUTE format('SELECT * FROM %I', 'no_such_table');
END $$;
ERROR:  relation "no_such_table" does not exist
CONTEXT:  SQL statement "SELECT * FROM no_such_table"
PL/pgSQL function inline_code_block line 2 at EXECUTE

-- Fix: ALWAYS print the SQL before running it
practice=# DO $$ DECLARE sql TEXT; BEGIN
  sql := format('SELECT * FROM %I WHERE %I > %L',
    'accounts', 'bal', 500);
  RAISE NOTICE 'DEBUG SQL: %', sql;
  EXECUTE sql;
END $$;
NOTICE:  DEBUG SQL: SELECT * FROM accounts WHERE bal > '500'

-- Now copy that SQL and test it directly in psql!
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Cursor Closed on COMMIT
Beginner trap: cursors are automatically closed when a transaction ends. In a procedure with COMMIT, this means any open cursor is destroyed after the COMMIT. If you try to FETCH from it afterward, you get 'cursor is not open.' The fix: either process all cursor rows before COMMIT, or re-open the cursor after each COMMIT.

```sql
-- This FAILS in a procedure:
CREATE OR REPLACE PROCEDURE bad_batch() AS $$
DECLARE
    cur CURSOR FOR SELECT id, bal FROM accounts;
    rec RECORD;
BEGIN
    OPEN cur;
    FETCH cur INTO rec;
    UPDATE accounts SET bal = bal * 1.05 WHERE id = rec.id;
    COMMIT;  -- cursor is now CLOSED!
    FETCH cur INTO rec;  -- ERROR!
END; $$ LANGUAGE plpgsql;

CALL bad_batch();
ERROR:  cursor "cur" is not open

-- Fix: use FOR loop instead of cursor in procedures
-- Or re-OPEN cursor after each COMMIT
-- Or use DECLARE cur CURSOR WITH HOLD FOR ...
-- WITH HOLD keeps cursor open across COMMIT
```

### Beginner Trap: Debugging Dynamic SQL
Beginner trap: dynamic SQL errors are hard to debug because the error points to the EXECUTE line, not the actual SQL that failed. Always use RAISE NOTICE to print the generated SQL before executing it. This lets you copy and paste the query into psql to test it directly. Once it works, you can remove the RAISE NOTICE.

```sql
-- Error message is unhelpful:
DO $$ BEGIN
  EXECUTE format('SELECT * FROM %I', 'no_such_table');
END $$;
ERROR:  relation "no_such_table" does not exist
CONTEXT:  SQL statement "SELECT * FROM no_such_table"
PL/pgSQL function inline_code_block line 2 at EXECUTE

-- Fix: ALWAYS print the SQL before running it
DO $$ DECLARE sql TEXT; BEGIN
  sql := format('SELECT * FROM %I WHERE %I > %L',
    'accounts', 'bal', 500);
  RAISE NOTICE 'DEBUG SQL: %', sql;
  EXECUTE sql;
END $$;
NOTICE:  DEBUG SQL: SELECT * FROM accounts WHERE bal > '500'

-- Now copy that SQL and test it directly in psql!
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. Cursors process query results one row at a time — DECLARE, OPEN, FETCH, CLOSE. Use SCROLL to move backwards. Cursors close on COMMIT — use FOR loops in procedures. Dynamic SQL with EXECUTE builds queries as strings. Use format with percent-I for identifiers and percent-L for literals. Use USING for safe values. Always RAISE NOTICE the SQL for debugging. Never concatenate user input. In the next class, we cover error handling with EXCEPTION blocks. See you there!

- **Bound cursor: CURSOR FOR SELECT ... (query at declare)**
- **Unbound: REFCURSOR, query at OPEN time**
- **SCROLL: FETCH FIRST/LAST/PRIOR/NEXT**
- **Cursors close on COMMIT — use FOR loop instead**
- **EXECUTE format('%I', name): safe identifiers**
- **EXECUTE ... USING $1: safe value parameters**
- **RAISE NOTICE '%', sql: debug dynamic SQL**
- **Static SQL > Dynamic SQL > Cursor (prefer simpler)**


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
