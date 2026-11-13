# CTEs & Recursive CTEs — The WITH Clause
**Series:** PostgreSQL Mastery | **Phase:** Phase 8: Subqueries & CTEs | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn Common Table Expressions — CTEs — the WITH clause that makes complex queries readable and maintainable. Then we tackle recursive CTEs for building hierarchies like org charts and category trees. Let us get started.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should know subqueries — we covered them in the previous class. You used derived tables in FROM and scalar subqueries in SELECT. Those work, but when queries get complex — multiple subqueries nested inside each other — the code becomes unreadable. CTEs solve this by letting you name each piece and build the query step by step, like writing paragraphs before assembling an essay.

- You know subqueries in WHERE, FROM, SELECT
- You know EXISTS, IN, ANY, ALL
- Problem: nested subqueries become unreadable
- Solution: WITH clause — name each piece
- CTE = Common Table Expression
- Think of it as a named temporary result set

### What Is a CTE?
A CTE is a named temporary result set defined with the WITH keyword. You write WITH, give it a name, then AS and a SELECT in parentheses. After the CTE definition, you write the main query that uses it. The CTE exists only for that one statement — it is not stored anywhere. Think of it like declaring a variable that holds a query result. The main advantage is readability — you break a complex query into named, understandable pieces.

| Term | Meaning / Explanation |
| :--- | :--- |
| **CTE** | Common Table Expression — a named temporary result set |
| **WITH keyword** | Defines the CTE before the main query |
| **Scope** | Exists only for the single statement that follows |
| **Readability** | Break complex queries into named, readable pieces |
| **Reuse** | Reference the same CTE multiple times in one query |

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. You can download today's class materials and practice files from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Every bit helps us keep creating. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Recursive CTE — How It Works
Now the powerful part — RECURSIVE CTEs. A recursive CTE has two parts: the BASE CASE that starts the recursion, UNION ALL, then the RECURSIVE CASE that references the CTE itself. It works like a loop: start with the base rows, then keep adding rows until no new rows are produced. This is perfect for hierarchical data like org charts, category trees, and file system paths.

| Term | Meaning / Explanation |
| :--- | :--- |
| **WITH RECURSIVE** | Tells PostgreSQL this CTE references itself |
| **Base Case** | Starting rows — the root of the hierarchy |
| **UNION ALL** | Combines base case with recursive results |
| **Recursive Case** | References the CTE itself to get the next level |
| **Termination** | Stops when recursive case returns no new rows |

**Notes:**
- Base case → recursive step → recursive step → ... → empty → done

### CTE vs Subquery vs Temp Table
When should you use a CTE versus a subquery versus a temporary table? CTEs are best for readability and single-statement logic. Subqueries are fine for simple one-off uses. Temporary tables are better when you need to reuse results across multiple statements or need indexes on the intermediate data. In PostgreSQL, CTEs are NOT automatically materialized — the optimizer can inline them like subqueries since PG 12.

| CTE Advantages | When NOT to Use CTE |
| :--- | :--- |
| Readable — named, step-by-step logic | Simple one-off → subquery is fine |
| Reuse same CTE multiple times in one query | Need result across multiple statements → TEMP TABLE |
| Recursive capability (subqueries can't) | Need index on intermediate data → TEMP TABLE |
| Works with INSERT/UPDATE/DELETE RETURNING | CTE scope = one statement only |
| PG 12+: optimizer can inline (no perf penalty) | Very complex CTEs can be hard to debug |

### Practice Exercises
Practice time! Exercise one: write a simple CTE for department stats. Exercise two: multiple CTEs — department stats then above-average employees. Exercise three: CTE with DELETE and archive. Exercise four: recursive CTE for the org chart with levels. Exercise five: recursive CTE with a full management path. Exercise six: generate a number series from one to twenty. Exercise seven: add a depth limit to prevent infinite recursion.

- 1. Simple CTE: department stats (count, avg salary)
- 2. Multiple CTEs: dept stats → above-avg employees → count
- 3. CTE with DELETE RETURNING to archive rows
- 4. Recursive CTE: org chart with indented tree
- 5. Recursive CTE: full management path (CEO → ... → you)
- 6. Recursive CTE: generate numbers 1 to 20
- 7. Add depth limit (WHERE level < 10) to prevent infinite loops


---

## 3. Hands-On Commands & psql Output

### Setup: Employees and Orders
**Explanation:** Let us set up our tables. An employees table with departments and salaries, and an orders table for demonstrating multi-CTE queries.

```sql
practice=# CREATE TABLE employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    manager_id INT REFERENCES employees(id)
);
CREATE TABLE

practice=# INSERT INTO employees (name,department,salary,manager_id) VALUES
('Meera','Executive',120000,NULL),
('Ravi','Engineering',95000,1),('Sonia','HR',85000,1),
('Priya','Engineering',88000,2),('Arjun','Engineering',92000,2),
('Kiran','HR',78000,3),('Deepak','Sales',71000,1),
('Anita','Marketing',75000,1),('Vikram','Engineering',82000,5);
INSERT 0 9

practice=# CREATE TABLE orders (
    id INT PRIMARY KEY, employee_id INT REFERENCES employees(id),
    product VARCHAR(50), amount NUMERIC(10,2));
CREATE TABLE
practice=# INSERT INTO orders VALUES
(1,1,'Laptop',75000),(2,2,'Mouse',1500),(3,4,'Keyboard',3000),
(4,5,'Monitor',25000),(5,6,'Headphones',4000);
INSERT 0 5
```

### Basic CTE — Named Result Set
**Explanation:** Here is a basic CTE. We define dept_stats as a named result set that computes department averages. Then the main query joins employees to dept_stats to show each employee's salary compared to their department average. Compare this to the nested subquery version — the CTE is much easier to read. The name dept_stats tells you exactly what that piece computes.

```sql
-- CTE: name the result, then use it in the main query
practice=# WITH dept_stats AS (
  SELECT department,
    ROUND(AVG(salary),2) AS avg_salary,
    COUNT(*) AS emp_count
  FROM employees GROUP BY department
)
SELECT e.name, e.department, e.salary,
       d.avg_salary,
       e.salary - d.avg_salary AS diff
FROM employees e
JOIN dept_stats d ON e.department = d.department
ORDER BY diff DESC;
  name  | department  |  salary   | avg_salary |   diff
--------+-------------+-----------+------------+----------
 Meera  | Executive   | 120000.00 | 120000.00  |     0.00
 Arjun  | Engineering |  92000.00 |  89250.00  |  2750.00
 Ravi   | Engineering |  95000.00 |  89250.00  |  5750.00
(9 rows)
```

### Multiple CTEs — Step by Step
**Explanation:** You can define MULTIPLE CTEs separated by commas. Each one can reference the CTEs defined BEFORE it. This lets you build complex queries step by step — first compute department stats, then find above-average employees, then count them. Each step has a clear name. This is much more readable than nesting three subqueries inside each other.

```sql
-- Multiple CTEs: each can reference the ones above
practice=# WITH
dept_avg AS (
  SELECT department, ROUND(AVG(salary),2) AS avg_sal
  FROM employees GROUP BY department
),
above_avg AS (
  SELECT e.name, e.department, e.salary, d.avg_sal
  FROM employees e JOIN dept_avg d ON e.department = d.department
  WHERE e.salary > d.avg_sal
)
SELECT department, COUNT(*) AS above_avg_count
FROM above_avg GROUP BY department ORDER BY above_avg_count DESC;
 department  | above_avg_count
-------------+-----------------
 Engineering |               2
 HR          |               1
(2 rows)

-- Step 1: dept_avg computes averages
-- Step 2: above_avg finds above-average employees
-- Step 3: main query counts them per department
```

### CTE with INSERT/DELETE — Delete and Archive
**Explanation:** CTEs also work with INSERT, UPDATE, and DELETE — not just SELECT. Here is a powerful pattern: delete rows and archive them in a single atomic statement. The CTE performs the DELETE with RETURNING, capturing the deleted rows. The main query INSERTs those rows into the archive table. All in one transaction, one statement.

```sql
practice=# CREATE TABLE employees_archive (
    id INT, name VARCHAR(50), department VARCHAR(50),
    salary NUMERIC(10,2), archived_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE

-- Delete + Archive in one atomic statement
practice=# WITH removed AS (
  DELETE FROM employees
  WHERE department = 'Marketing'
  RETURNING id, name, department, salary
)
INSERT INTO employees_archive (id, name, department, salary)
SELECT id, name, department, salary FROM removed;
INSERT 0 1

practice=# SELECT * FROM employees_archive;
 id | name  | department | salary   | archived_at
----+-------+------------+----------+------------------
  8 | Anita | Marketing  | 75000.00 | 2024-01-15 10:...
(1 row)
```

### Recursive CTE — Org Chart
**Explanation:** Let us build an org chart. The base case selects the CEO — Meera — who has no manager. The recursive case joins employees to the CTE, finding everyone who reports to the current level. Level one is Meera. Level two is everyone reporting to Meera. Level three is everyone reporting to level two. And so on, until no more reports are found.

```sql
-- Build org chart: CEO → managers → employees
practice=# WITH RECURSIVE org_tree AS (
  -- Base case: the CEO (no manager)
  SELECT id, name, manager_id, 1 AS level
  FROM employees WHERE manager_id IS NULL
  UNION ALL
  -- Recursive case: employees reporting to current level
  SELECT e.id, e.name, e.manager_id, ot.level + 1
  FROM employees e
  INNER JOIN org_tree ot ON e.manager_id = ot.id
)
SELECT level,
  REPEAT('  ', level - 1) || name AS org_chart
FROM org_tree ORDER BY level, name;
 level |     org_chart
-------+-----------------
     1 | Meera
     2 |   Deepak
     2 |   Ravi
     2 |   Sonia
     3 |     Arjun
     3 |     Kiran
     3 |     Priya
     4 |       Vikram
(8 rows)
```

### Recursive CTE — Full Management Path
**Explanation:** We can also build a full path showing the management chain. The base case starts with the CEO name. The recursive case concatenates the manager's path with the current employee's name. This shows the complete chain of command for every employee — like a breadcrumb trail from the CEO down.

```sql
-- Build management chain path for each employee
practice=# WITH RECURSIVE org_path AS (
  SELECT id, name, manager_id,
    name::TEXT AS path, 1 AS level
  FROM employees WHERE manager_id IS NULL
  UNION ALL
  SELECT e.id, e.name, e.manager_id,
    op.path || ' → ' || e.name, op.level + 1
  FROM employees e
  JOIN org_path op ON e.manager_id = op.id
)
SELECT name, level, path FROM org_path ORDER BY path;
  name   | level | path
---------+-------+----------------------------
 Meera   |     1 | Meera
 Deepak  |     2 | Meera → Deepak
 Ravi    |     2 | Meera → Ravi
 Arjun   |     3 | Meera → Ravi → Arjun
 Priya   |     3 | Meera → Ravi → Priya
 Sonia   |     2 | Meera → Sonia
 Kiran   |     3 | Meera → Sonia → Kiran
 Vikram  |     4 | Meera → Ravi → Arjun → Vikram
(8 rows)
```

### Recursive CTE — Generate a Number Series
**Explanation:** Another classic use case for recursive CTEs: generating a number series. The base case starts at one, the recursive case adds one until we hit ten. This is useful for generating date ranges, filling gaps in data, or creating test data. PostgreSQL also has the built-in generate_series function, but understanding the recursive approach helps you solve more complex problems.

```sql
-- Generate numbers 1 to 10
practice=# WITH RECURSIVE nums AS (
  SELECT 1 AS n         -- base case: start at 1
  UNION ALL
  SELECT n + 1 FROM nums WHERE n < 10  -- add 1 until 10
)
SELECT n FROM nums;
  n
----
  1
  2
 ...
 10
(10 rows)

-- Built-in alternative:
-- SELECT generate_series(1, 10);
-- But recursive CTEs handle complex patterns generate_series can't
```

### Avoiding Infinite Recursion
**Explanation:** Danger zone: infinite recursion. If your recursive case never produces an empty result, the query runs forever — or until PostgreSQL's default max_recursive_iterations limit stops it. Always make sure your WHERE condition narrows down with each step. As a safety net, you can add a depth limit to your recursive CTE — WHERE level is less than some maximum. PostgreSQL also has a CYCLE detection clause in PG 14 and later, but in PG 16 you can also just track visited IDs in an array.

```sql
-- DANGER: infinite recursion (no stopping condition)
-- WITH RECURSIVE bad AS (
--   SELECT 1 AS n
--   UNION ALL
--   SELECT n + 1 FROM bad  -- no WHERE! runs forever!
-- ) SELECT * FROM bad;

-- SAFETY: always add a depth limit
practice=# WITH RECURSIVE org_tree AS (
  SELECT id, name, manager_id, 1 AS level
  FROM employees WHERE manager_id IS NULL
  UNION ALL
  SELECT e.id, e.name, e.manager_id, ot.level + 1
  FROM employees e JOIN org_tree ot ON e.manager_id = ot.id
  WHERE ot.level < 10  -- safety: max 10 levels deep
)
SELECT * FROM org_tree;
(8 rows)  -- stops safely even if data has cycles
```

### Common CTE Errors
**Explanation:** Here are the common CTE errors. First: forgetting the WITH RECURSIVE keyword for recursive CTEs — without RECURSIVE, self-reference is not allowed. Second: the recursive query must have the form: non-recursive term UNION ALL recursive term. You cannot swap the order. Third: infinite recursion — always add a depth limit or cycle detection.

```sql
-- Error 1: Missing RECURSIVE keyword
-- WITH org AS (
--   SELECT ... UNION ALL SELECT ... FROM org ...
-- )
-- ERROR: recursive reference to query "org" not allowed
-- FIX: WITH RECURSIVE org AS (...)

-- Error 2: Wrong recursive CTE structure
-- WITH RECURSIVE bad AS (
--   SELECT ... FROM bad  -- recursive case FIRST
--   UNION ALL
--   SELECT ... -- non-recursive SECOND
-- )
-- ERROR: recursive query does not have the form ...
-- FIX: non-recursive term FIRST, then UNION ALL recursive

-- Error 3: Forgetting alias when referencing CTE
-- FIX: CTEs are referenced by name, no alias needed
-- ... FROM org_tree (works) not FROM org_tree ot (needed for self-join only)
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. CTEs use the WITH clause to name temporary result sets — much more readable than nested subqueries. Multiple CTEs are separated by commas, and each can reference the ones before it. CTEs work with INSERT, UPDATE, DELETE — not just SELECT. Recursive CTEs need WITH RECURSIVE, a base case, UNION ALL, and a recursive case. They are perfect for hierarchies: org charts, category trees, bill of materials. Always add a depth limit to prevent infinite recursion. Since PostgreSQL 12, the optimizer can inline CTEs, so there is no performance penalty. In the next class, we move to Architecture — how PostgreSQL works inside. See you there!

- **WITH name AS (SELECT ...) — named temporary result**
- **Multiple CTEs: WITH a AS (...), b AS (...) SELECT ...**
- **CTE scope = one statement only (not stored)**
- **Works with INSERT/UPDATE/DELETE + RETURNING**
- **WITH RECURSIVE: base case UNION ALL recursive case**
- **Org chart: start at root, join to next level, repeat**
- **Always add depth limit: WHERE level < 10**
- **PG 12+: optimizer inlines CTEs (no perf penalty)**


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


---

## 8. Answer Key — Verified Practice Solutions

### Challenge 1: Modular Aggregation with Single CTE
```sql
WITH dept AS (
    SELECT department, COUNT(*) AS cnt, ROUND(AVG(salary), 2) AS avg_sal
    FROM employees
    GROUP BY department
)
SELECT * FROM dept ORDER BY avg_sal DESC;
```
*Why:* Encapsulates complex grouping logic into a named expression, avoiding convoluted subqueries.

### Challenge 2: Chaining Multiple CTEs
```sql
WITH dept_avg AS (
    SELECT department, AVG(salary) AS avg_sal
    FROM employees
    GROUP BY department
),
above AS (
    SELECT e.name, e.department
    FROM employees e
    JOIN dept_avg d USING (department)
    WHERE e.salary > d.avg_sal
)
SELECT department, COUNT(*) AS above_avg_count
FROM above
GROUP BY department;
```
*Why:* Downstream CTEs can cleanly reference upstream CTEs, creating an intuitive step-by-step pipeline.

### Challenge 3: Data-Modifying CTE (Atomic Archive)
```sql
WITH removed AS (
    DELETE FROM employees WHERE department = 'Marketing' RETURNING *
)
INSERT INTO employees_archive (id, name, department, salary)
SELECT id, name, department, salary FROM removed;
```
*Why:* Executes delete and archive operations in a single atomic snapshot, preventing race conditions.

### Challenge 4: Recursive Hierarchy Traversal
```sql
WITH RECURSIVE org AS (
    SELECT id, name, 1 AS level
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, o.level + 1
    FROM employees e
    JOIN org o ON e.manager_id = o.id
)
SELECT REPEAT('  ', level - 1) || name AS hierarchy_tree
FROM org
ORDER BY level, name;
```
*Why:* Anchor member retrieves roots; recursive member joins children until the execution queue is empty.

### Challenge 5: Management Breadcrumbs Path
```sql
WITH RECURSIVE path AS (
    SELECT id, name, name::TEXT AS chain
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, p.chain || ' -> ' || e.name
    FROM employees e
    JOIN path p ON e.manager_id = p.id
)
SELECT name, chain
FROM path
ORDER BY chain;
```
*Why:* Accumulates ancestors into a text string at each recursion step to display complete reporting lines.
