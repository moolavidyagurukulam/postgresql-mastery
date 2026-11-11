-- =============================================
-- PostgreSQL Mastery: CTEs & Recursive CTEs
-- Phase 8: Subqueries & CTEs | Classes 65-66
-- =============================================
-- WITH clause, multiple CTEs, recursive CTEs
-- for hierarchies, and cycle prevention.
-- =============================================

-- === SETUP ===

CREATE TABLE employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    manager_id INT REFERENCES employees(id)
);

INSERT INTO employees (name, department, salary, manager_id) VALUES
('Meera',  'Executive',   120000, NULL),  -- CEO
('Ravi',   'Engineering',  95000, 1),
('Sonia',  'HR',           85000, 1),
('Priya',  'Engineering',  88000, 2),
('Arjun',  'Engineering',  92000, 2),
('Kiran',  'HR',           78000, 3),
('Deepak', 'Sales',        71000, 1),
('Anita',  'Marketing',    75000, 1),
('Vikram', 'Engineering',  82000, 5);

CREATE TABLE orders (
    id          INT PRIMARY KEY,
    employee_id INT REFERENCES employees(id),
    product     VARCHAR(50),
    amount      NUMERIC(10,2)
);

INSERT INTO orders VALUES
(1, 1, 'Laptop',     75000),
(2, 2, 'Mouse',       1500),
(3, 4, 'Keyboard',    3000),
(4, 5, 'Monitor',    25000),
(5, 6, 'Headphones',  4000);

-- === BASIC CTE ===

-- Simple CTE: department statistics
WITH dept_stats AS (
    SELECT department,
           COUNT(*) AS emp_count,
           ROUND(AVG(salary), 2) AS avg_salary
    FROM employees
    GROUP BY department
)
SELECT * FROM dept_stats ORDER BY avg_salary DESC;

-- CTE used in a JOIN
WITH dept_stats AS (
    SELECT department,
           ROUND(AVG(salary), 2) AS avg_salary
    FROM employees GROUP BY department
)
SELECT e.name, e.department, e.salary,
       d.avg_salary,
       e.salary - d.avg_salary AS diff
FROM employees e
JOIN dept_stats d ON e.department = d.department
ORDER BY diff DESC;

-- === MULTIPLE CTEs ===

-- Chain CTEs: each can reference ones defined before it
WITH
dept_avg AS (
    SELECT department, ROUND(AVG(salary), 2) AS avg_sal
    FROM employees GROUP BY department
),
above_avg AS (
    SELECT e.name, e.department, e.salary, d.avg_sal
    FROM employees e
    JOIN dept_avg d ON e.department = d.department
    WHERE e.salary > d.avg_sal
)
SELECT department, COUNT(*) AS above_avg_count
FROM above_avg
GROUP BY department
ORDER BY above_avg_count DESC;

-- Three CTEs: stats → above avg → with orders
WITH
dept_avg AS (
    SELECT department, ROUND(AVG(salary), 2) AS avg_sal
    FROM employees GROUP BY department
),
above_avg AS (
    SELECT e.id, e.name, e.department, e.salary
    FROM employees e
    JOIN dept_avg d ON e.department = d.department
    WHERE e.salary > d.avg_sal
),
with_orders AS (
    SELECT a.name, a.department, COUNT(o.id) AS order_count
    FROM above_avg a
    LEFT JOIN orders o ON a.id = o.employee_id
    GROUP BY a.name, a.department
)
SELECT * FROM with_orders ORDER BY order_count DESC;

-- === CTE REFERENCED MULTIPLE TIMES ===

WITH dept_stats AS (
    SELECT department, COUNT(*) AS cnt, ROUND(AVG(salary),2) AS avg_sal
    FROM employees GROUP BY department
)
SELECT
    (SELECT SUM(cnt) FROM dept_stats) AS total_employees,
    (SELECT MAX(avg_sal) FROM dept_stats) AS highest_avg,
    (SELECT department FROM dept_stats ORDER BY avg_sal DESC LIMIT 1)
        AS top_dept;
-- Same CTE used 3 times — computed only once

-- === CTE WITH INSERT/UPDATE/DELETE ===

CREATE TABLE employees_archive (
    id          INT,
    name        VARCHAR(50),
    department  VARCHAR(50),
    salary      NUMERIC(10,2),
    archived_at TIMESTAMPTZ DEFAULT NOW()
);

-- Delete + Archive atomically
WITH removed AS (
    DELETE FROM employees
    WHERE department = 'Marketing'
    RETURNING id, name, department, salary
)
INSERT INTO employees_archive (id, name, department, salary)
SELECT id, name, department, salary FROM removed;

SELECT * FROM employees_archive;

-- CTE with UPDATE + RETURNING
WITH updated AS (
    UPDATE employees
    SET salary = salary * 1.05
    WHERE department = 'Engineering'
    RETURNING id, name, salary
)
SELECT name, salary AS new_salary FROM updated;

-- === RECURSIVE CTE — Org Chart ===

-- Build org chart from employee-manager hierarchy
WITH RECURSIVE org_tree AS (
    -- Base case: CEO (no manager)
    SELECT id, name, manager_id, 1 AS level
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive case: find reports of current level
    SELECT e.id, e.name, e.manager_id, ot.level + 1
    FROM employees e
    INNER JOIN org_tree ot ON e.manager_id = ot.id
)
SELECT level,
       REPEAT('  ', level - 1) || name AS org_chart
FROM org_tree
ORDER BY level, name;

-- === RECURSIVE CTE — Management Path ===

WITH RECURSIVE org_path AS (
    SELECT id, name, manager_id,
           name::TEXT AS path,
           1 AS level
    FROM employees WHERE manager_id IS NULL

    UNION ALL

    SELECT e.id, e.name, e.manager_id,
           op.path || ' → ' || e.name,
           op.level + 1
    FROM employees e
    JOIN org_path op ON e.manager_id = op.id
)
SELECT name, level, path
FROM org_path
ORDER BY path;

-- === RECURSIVE CTE — Number Series ===

WITH RECURSIVE nums AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 10
)
SELECT n FROM nums;
-- Same as: SELECT generate_series(1, 10);

-- Date series
WITH RECURSIVE dates AS (
    SELECT DATE '2024-01-01' AS d
    UNION ALL
    SELECT d + INTERVAL '1 day' FROM dates WHERE d < '2024-01-07'
)
SELECT d::DATE FROM dates;
-- Same as: SELECT generate_series('2024-01-01'::date, '2024-01-07', '1 day');

-- === AVOIDING INFINITE RECURSION ===

-- Always add a depth/level limit
WITH RECURSIVE safe_tree AS (
    SELECT id, name, manager_id, 1 AS level
    FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, e.manager_id, st.level + 1
    FROM employees e
    JOIN safe_tree st ON e.manager_id = st.id
    WHERE st.level < 10  -- SAFETY: max 10 levels
)
SELECT * FROM safe_tree;

-- PG 14+ cycle detection syntax:
-- WITH RECURSIVE tree AS (
--   SELECT id, name, manager_id FROM employees WHERE manager_id IS NULL
--   UNION ALL
--   SELECT e.id, e.name, e.manager_id
--   FROM employees e JOIN tree t ON e.manager_id = t.id
-- ) CYCLE id SET is_cycle USING path
-- SELECT * FROM tree WHERE NOT is_cycle;

-- === CTE vs SUBQUERY vs TEMP TABLE ===

-- CTE:        readable, single-statement, optimizer can inline (PG 12+)
-- Subquery:   fine for simple one-off uses
-- Temp table: reuse across statements, can add indexes

-- Force materialization (if needed):
-- WITH cte AS MATERIALIZED (SELECT ...) ...
-- Force inlining (if needed):
-- WITH cte AS NOT MATERIALIZED (SELECT ...) ...

-- === COMMON ERRORS ===

-- Error 1: Missing RECURSIVE keyword
-- WITH org AS (SELECT ... UNION ALL SELECT ... FROM org ...)
-- ERROR: recursive reference to query "org" is not allowed
-- Fix: WITH RECURSIVE org AS (...)

-- Error 2: Wrong order in recursive CTE
-- Recursive term MUST come after UNION ALL
-- Non-recursive (base case) FIRST, recursive SECOND

-- Error 3: Infinite recursion
-- No WHERE limit in recursive case → runs until memory exhausted
-- Fix: WHERE level < max_depth

-- === PRACTICE EXERCISES ===

-- Exercise 1: Simple CTE — department stats
WITH dept AS (
    SELECT department, COUNT(*) AS cnt, ROUND(AVG(salary),2) AS avg_sal
    FROM employees GROUP BY department
)
SELECT * FROM dept ORDER BY avg_sal DESC;

-- Exercise 2: Multiple CTEs — above-average count per department
WITH
dept_avg AS (
    SELECT department, AVG(salary) AS avg_sal FROM employees GROUP BY department
),
above AS (
    SELECT e.name, e.department FROM employees e
    JOIN dept_avg d ON e.department = d.department
    WHERE e.salary > d.avg_sal
)
SELECT department, COUNT(*) FROM above GROUP BY department;

-- Exercise 3: CTE with DELETE + archive
-- (run only if you want to delete; re-insert Anita first)
-- INSERT INTO employees (name,department,salary,manager_id) VALUES ('Anita','Marketing',75000,1);
-- WITH removed AS (DELETE FROM employees WHERE department='Marketing' RETURNING *)
-- INSERT INTO employees_archive (id,name,department,salary) SELECT id,name,department,salary FROM removed;

-- Exercise 4: Recursive org chart with levels
WITH RECURSIVE org AS (
    SELECT id, name, 1 AS level FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, o.level + 1
    FROM employees e JOIN org o ON e.manager_id = o.id
)
SELECT REPEAT('  ', level-1) || name AS tree FROM org ORDER BY level, name;

-- Exercise 5: Management path
WITH RECURSIVE path AS (
    SELECT id, name, name::TEXT AS chain FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, p.chain || ' → ' || e.name
    FROM employees e JOIN path p ON e.manager_id = p.id
)
SELECT name, chain FROM path ORDER BY chain;

-- Exercise 6: Number series 1-20
WITH RECURSIVE nums AS (
    SELECT 1 AS n UNION ALL SELECT n+1 FROM nums WHERE n < 20
)
SELECT n FROM nums;

-- Exercise 7: Depth-limited recursive CTE
WITH RECURSIVE safe AS (
    SELECT id, name, 1 AS level FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, s.level + 1
    FROM employees e JOIN safe s ON e.manager_id = s.id
    WHERE s.level < 5
)
SELECT * FROM safe ORDER BY level;

-- === CLEANUP ===
-- DROP TABLE IF EXISTS employees_archive, orders, employees;

-- =============================================
-- Phase 8: Subqueries & CTEs — COMPLETE!
-- Next Phase: Phase 9 — Architecture
-- Next Class: PostgreSQL Architecture Overview
-- =============================================
