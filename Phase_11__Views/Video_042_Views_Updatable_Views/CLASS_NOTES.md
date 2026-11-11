# Views & Updatable Views — Stored Queries You Can Write Through
**Series:** PostgreSQL Mastery | **Phase:** Phase 11: Views | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn about views — saved queries that act like virtual tables. You will create regular views, understand when a view is automatically updatable, use WITH CHECK OPTION for data validation, use views for security, and know when views help and when they hurt. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### What Is a View?
The problem: your application runs the same complex JOIN query in ten different places. If the table structure changes, you must update all ten. And some users should not see the salary column — but they query the same table. Views solve both: a named, saved query that hides complexity and restricts access. A view stores NO data — every SELECT from a view runs the saved query fresh.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | A named, saved SELECT query (virtual table) |
| **Storage** | NO data stored — query runs every time you SELECT from it |
| **Simplify** | Hide complex JOINs behind a simple table name |
| **Security** | Restrict which columns or rows users can see |
| **Maintain** | Change the query in one place, all users get the update |

**Notes:**
- CREATE VIEW name AS SELECT ...; then SELECT * FROM name;

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Automatically Updatable Views
Updatable views are views you can INSERT, UPDATE, and DELETE through — the changes go directly to the underlying table. PostgreSQL automatically makes a view updatable when it meets all these conditions: selects from exactly one table, no GROUP BY, HAVING, DISTINCT, UNION, LIMIT, OFFSET, no aggregate functions, and every column is a simple column reference — no expressions.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Requirement 1** | SELECT from exactly ONE table (no JOINs) |
| **Requirement 2** | No GROUP BY, HAVING, DISTINCT, LIMIT, OFFSET |
| **Requirement 3** | No aggregate functions (COUNT, SUM, etc.) |
| **Requirement 4** | No UNION, INTERSECT, EXCEPT |
| **Requirement 5** | All columns are simple column references (no expressions) |

**Notes:**
- v_engineering: updatable (single table, simple WHERE)
- v_emp_manager: NOT updatable (has a JOIN)

### When to Use Views
When should you use views? Use them to simplify complex repeated queries, for security by hiding columns or rows, and to provide a stable API when table structures change. Do NOT use views for performance — they add no caching. For cached results, use Materialized Views which we cover in the next class. And avoid deep nesting — views on views on views become impossible to debug.

| Good Use Cases | When NOT to Use |
| :--- | :--- |
| Simplify complex, repeated queries | Performance optimization (no caching!) |
| Security: hide columns (salary, SSN) | Deeply nested views (3+ levels deep) |
| Security: restrict rows by department | When a CTE or function is clearer |
| Stable API: insulate apps from schema changes | If you need indexed results (use matview) |
| Report views for BI tools | Temporary one-off queries (just use CTE) |
| WITH CHECK OPTION for data integrity | When the query changes often |

### Practice Exercises
Practice exercises: create views with single tables and JOINs, test which are updatable, demonstrate the disappearing row trap, add WITH CHECK OPTION, inspect views with pg_get_viewdef, check is_insertable_into, and run EXPLAIN on a view query.

- 1. CREATE VIEW for one department — query it
- 2. CREATE VIEW with a JOIN — query it
- 3. INSERT through the single-table view (updatable!)
- 4. INSERT through the JOIN view (observe error)
- 5. Demonstrate disappearing row (INSERT without dept)
- 6. Add WITH CHECK OPTION — test the constraint
- 7. Check is_insertable_into in information_schema
- 8. EXPLAIN a view query to see merged conditions


---

## 3. Hands-On Commands & psql Output

### Creating and Using Views
**Explanation:** Creating a view is straightforward. Use CREATE VIEW, give it a name, then AS followed by the SELECT query. You can then query the view exactly like a table — with WHERE, ORDER BY, LIMIT, everything. The view itself is just metadata — no rows are stored.

```sql
-- Simple view: engineering employees only
practice=# CREATE VIEW v_engineering AS
SELECT id, name, salary FROM employees
WHERE department = 'Engineering';
CREATE VIEW

-- Use it like a table
practice=# SELECT * FROM v_engineering ORDER BY salary DESC;
 id |  name  | salary
----+--------+---------
  2 | Ravi   |  95000
  5 | Arjun  |  92000
  4 | Priya  |  88000
  9 | Vikram |  82000

-- You can add WHERE, ORDER BY, LIMIT on top
practice=# SELECT name FROM v_engineering WHERE salary > 90000;
  name
--------
 Ravi
 Arjun
```

### View with JOIN — Hide Complexity
**Explanation:** Views can contain JOINs. This view joins employees with their managers to show a clean org chart. The consumer of this view does not need to know about the self-join — they just query v_emp_manager like a simple table.

```sql
-- View hiding a self-join
practice=# CREATE VIEW v_emp_manager AS
SELECT e.name AS employee, e.department, e.salary,
       COALESCE(m.name, 'None') AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;
CREATE VIEW

practice=# SELECT * FROM v_emp_manager WHERE department = 'HR';
 employee | department | salary | manager
----------+------------+--------+---------
 Sonia    | HR         |  85000 | Meera
 Kiran    | HR         |  78000 | Sonia

-- The JOIN complexity is hidden from the user
-- They just query v_emp_manager like a table
```

### Managing Views
**Explanation:** Managing views. Use CREATE OR REPLACE VIEW to update the query without dropping the view. Use backslash dv to list all views. Use backslash d-plus to see the full definition. To delete, DROP VIEW. If other views depend on it, use CASCADE — but be careful, it drops all dependent views too.

```sql
-- Update a view's query
practice=# CREATE OR REPLACE VIEW v_engineering AS
SELECT id, name, salary, manager_id FROM employees
WHERE department = 'Engineering';
CREATE VIEW

-- List all views
practice=# \dv
          List of relations
 Schema |     Name       | Type | Owner
--------+----------------+------+----------
 public | v_engineering  | view | postgres
 public | v_emp_manager  | view | postgres

-- See the view definition
practice=# SELECT pg_get_viewdef('v_engineering', true);
  SELECT id, name, salary, manager_id
  FROM employees
  WHERE department = 'Engineering'::text;

-- DROP VIEW IF EXISTS v_engineering CASCADE;
```

### Views for Security — Hide Sensitive Data
**Explanation:** Views for security. You can create a view that hides sensitive columns — like salary or personal data — and grant users access only to the view, not the underlying table. This is called column-level security through views. You can also restrict rows — show each user only their own department's data.

```sql
-- View hiding salary column
practice=# CREATE VIEW v_employee_public AS
SELECT id, name, department FROM employees;
CREATE VIEW

-- Grant access to view, not table
practice=# GRANT SELECT ON v_employee_public TO report_user;
GRANT

-- report_user can see names but NOT salaries
-- They have no access to the employees table directly

-- View restricting rows by department
practice=# CREATE VIEW v_hr_only AS
SELECT * FROM employees WHERE department = 'HR';
CREATE VIEW

-- HR team gets v_hr_only, can't see other departments
```

### Writing Through an Updatable View
**Explanation:** Let us INSERT and UPDATE through the v_engineering view. When we insert through the view, the row goes into the employees table. When we update, the underlying row changes. When we delete, the row is removed from the table. The view is transparent — writes go straight through to the base table.

```sql
-- INSERT through the view
practice=# INSERT INTO v_engineering (id, name, salary, manager_id)
VALUES (20, 'Neha', 90000, 2);
INSERT 0 1

-- Verify: it's in the base table
practice=# SELECT * FROM employees WHERE name = 'Neha';
 id | name | department | salary | manager_id
----+------+------------+--------+------------
 20 | Neha |            |  90000 |          2

-- UPDATE through the view
practice=# UPDATE v_engineering SET salary = 96000 WHERE name = 'Ravi';
UPDATE 1

-- DELETE through the view
practice=# DELETE FROM v_engineering WHERE name = 'Neha';
DELETE 1
```

### Beginner Trap: The Disappearing Row
**Explanation:** Beginner trap: the disappearing row. Notice that when we inserted Neha, we did not set department. The row went into employees with department NULL. But v_engineering has WHERE department equals Engineering — so the row is NOT visible through the view! The INSERT succeeded but the row disappeared from the view's perspective. This is dangerous. WITH CHECK OPTION prevents it.

```sql
-- View has WHERE department = 'Engineering'
-- But we can insert a row WITHOUT that department!
practice=# INSERT INTO v_engineering (id, name, salary)
VALUES (21, 'Ghost', 50000);
INSERT 0 1

-- Row exists in the base table...
practice=# SELECT * FROM employees WHERE name = 'Ghost';
 id | name  | department | salary
----+-------+------------+--------
 21 | Ghost | (NULL)     |  50000

-- ...but NOT visible through the view!
practice=# SELECT * FROM v_engineering WHERE name = 'Ghost';
(0 rows)

-- The row DISAPPEARED from view. Dangerous!
practice=# DELETE FROM employees WHERE id = 21;
```

### WITH CHECK OPTION — Prevent Disappearing Rows
**Explanation:** WITH CHECK OPTION prevents disappearing rows. When you add it to a view, any INSERT or UPDATE through the view must satisfy the view's WHERE clause. If the row would not be visible through the view after the change, PostgreSQL rejects it with an error. There are two modes: LOCAL checks only this view's condition, CASCADED — the default — also checks any parent views.

```sql
-- Recreate view WITH CHECK OPTION
practice=# CREATE OR REPLACE VIEW v_engineering AS
SELECT id, name, department, salary, manager_id
FROM employees
WHERE department = 'Engineering'
WITH CHECK OPTION;
CREATE VIEW

-- Now try inserting a Sales employee
practice=# INSERT INTO v_engineering (id, name, department, salary)
VALUES (22, 'Test', 'Sales', 50000);
ERROR:  new row violates check option for view
        "v_engineering"
DETAIL: Failing row contains (..., Test, Sales, 50000, ...).

-- Engineering rows pass the check:
practice=# INSERT INTO v_engineering (id, name, department, salary)
VALUES (22, 'Test', 'Engineering', 50000);
INSERT 0 1  -- OK!
```

### Beginner Trap: Non-Updatable View
**Explanation:** Beginner trap: trying to write through a non-updatable view. If the view has a JOIN, GROUP BY, DISTINCT, or aggregates, PostgreSQL refuses INSERT, UPDATE, and DELETE with a clear error. The fix for non-updatable views is either to use an INSTEAD OF trigger or to write directly to the base table.

```sql
-- v_emp_manager has a JOIN — NOT updatable
practice=# INSERT INTO v_emp_manager (employee, department, salary)
VALUES ('Test', 'HR', 50000);
ERROR:  cannot insert into view "v_emp_manager"
DETAIL: Views that do not select from a single table or
view are not automatically updatable.
HINT:  To enable inserting into the view, provide an
INSTEAD OF INSERT trigger.

-- Check if a view is updatable:
practice=# SELECT table_name, is_insertable_into
FROM information_schema.views
WHERE table_schema = 'public';
   table_name    | is_insertable_into
----------------+--------------------
 v_engineering  | YES
 v_emp_manager  | NO
```

### View Performance — EXPLAIN
**Explanation:** View performance: since views store no data, every query runs the full underlying SELECT. PostgreSQL inlines the view definition into your query and optimizes the whole thing together. Adding WHERE to a view query does not run two queries — PostgreSQL merges the conditions. But deeply nested views — views on views on views — can confuse the query planner. Use EXPLAIN to check.

```sql
-- PostgreSQL merges your WHERE with the view's WHERE
practice=# EXPLAIN SELECT * FROM v_engineering WHERE salary > 90000;
                       QUERY PLAN
---------------------------------------------------------
 Seq Scan on employees
   Filter: ((department = 'Engineering') AND (salary > 90000))

-- Notice: both conditions merged into ONE filter
-- PostgreSQL does NOT run the view query separately
-- It inlines the view and optimizes the whole thing

-- But nested views (v1 → v2 → v3) can confuse
-- the planner. Use EXPLAIN to verify performance.
-- Rule: keep view nesting to 2 levels max
```

### Common View Errors
**Explanation:** Common errors with views. CREATE OR REPLACE cannot change the column names or types — only the query logic. To change columns, you must DROP and recreate. Dropping a table that has dependent views fails unless you use CASCADE. And renaming columns in CREATE OR REPLACE requires the exact same column count and types.

```sql
-- ERROR: cannot change column types with OR REPLACE
practice=# CREATE OR REPLACE VIEW v_engineering AS
SELECT id, name, salary::TEXT FROM employees
WHERE department = 'Engineering';
ERROR:  cannot change data type of view column "salary"
        from numeric to text

-- Fix: DROP then CREATE
practice=# DROP VIEW v_engineering;
practice=# CREATE VIEW v_engineering AS ...;

-- ERROR: dependent views block table drop
-- DROP TABLE employees;
-- ERROR: cannot drop: other objects depend on it
-- Fix: DROP TABLE employees CASCADE;
-- WARNING: also drops ALL dependent views!
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: The Disappearing Row
Beginner trap: the disappearing row. Notice that when we inserted Neha, we did not set department. The row went into employees with department NULL. But v_engineering has WHERE department equals Engineering — so the row is NOT visible through the view! The INSERT succeeded but the row disappeared from the view's perspective. This is dangerous. WITH CHECK OPTION prevents it.

```sql
-- View has WHERE department = 'Engineering'
-- But we can insert a row WITHOUT that department!
INSERT INTO v_engineering (id, name, salary)
VALUES (21, 'Ghost', 50000);
INSERT 0 1

-- Row exists in the base table...
SELECT * FROM employees WHERE name = 'Ghost';
 id | name  | department | salary
----+-------+------------+--------
 21 | Ghost | (NULL)     |  50000

-- ...but NOT visible through the view!
SELECT * FROM v_engineering WHERE name = 'Ghost';
(0 rows)

-- The row DISAPPEARED from view. Dangerous!
DELETE FROM employees WHERE id = 21;
```

### Beginner Trap: Non-Updatable View
Beginner trap: trying to write through a non-updatable view. If the view has a JOIN, GROUP BY, DISTINCT, or aggregates, PostgreSQL refuses INSERT, UPDATE, and DELETE with a clear error. The fix for non-updatable views is either to use an INSTEAD OF trigger or to write directly to the base table.

```sql
-- v_emp_manager has a JOIN — NOT updatable
INSERT INTO v_emp_manager (employee, department, salary)
VALUES ('Test', 'HR', 50000);
ERROR:  cannot insert into view "v_emp_manager"
DETAIL: Views that do not select from a single table or
view are not automatically updatable.
HINT:  To enable inserting into the view, provide an
INSTEAD OF INSERT trigger.

-- Check if a view is updatable:
SELECT table_name, is_insertable_into
FROM information_schema.views
WHERE table_schema = 'public';
   table_name    | is_insertable_into
----------------+--------------------
 v_engineering  | YES
 v_emp_manager  | NO
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. Views are saved queries that act as virtual tables — no data stored, the query runs every time. Create with CREATE VIEW name AS SELECT. Automatically updatable if: single table, no GROUP BY, no aggregates, no UNION, simple columns only. The disappearing row trap: rows inserted through a view may not satisfy the view's WHERE clause. WITH CHECK OPTION prevents this by rejecting non-qualifying rows. Use views for simplicity and security, not for performance or caching. PostgreSQL merges view conditions with your query — check EXPLAIN to verify. CREATE OR REPLACE cannot change column types — you must DROP and recreate. In the next class, we cover Materialized Views — views that actually store data on disk and can be indexed. See you there!

- **CREATE VIEW name AS SELECT — saved query, no data**
- **CREATE OR REPLACE VIEW — update without dropping**
- **Updatable: single table, no GROUP BY/UNION/aggregates**
- **Disappearing row: INSERT may not match view's WHERE**
- **WITH CHECK OPTION: block rows violating the WHERE**
- **LOCAL vs CASCADED check (CASCADED is default)**
- **Security: GRANT on view, not on base table**
- **Performance: PG inlines views into query plan**
- **NOT for caching — use materialized views instead**


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
