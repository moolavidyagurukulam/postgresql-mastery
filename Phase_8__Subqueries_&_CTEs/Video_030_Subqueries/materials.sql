-- =============================================
-- PostgreSQL Mastery: Subqueries
-- Phase 8: Subqueries & CTEs | Classes 60-64
-- =============================================
-- WHERE, FROM, SELECT subqueries. EXISTS, IN,
-- ANY, ALL. Correlated vs non-correlated.
-- =============================================

-- === SETUP ===

CREATE TABLE employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    department VARCHAR(50),
    salary     NUMERIC(10,2)
);

INSERT INTO employees (name, department, salary) VALUES
('Ravi',   'Engineering', 95000),
('Priya',  'Engineering', 88000),
('Arjun',  'Marketing',   72000),
('Meera',  'Engineering', 105000),
('Kiran',  'Sales',       68000),
('Anita',  'Marketing',   75000),
('Deepak', 'Sales',       71000),
('Sonia',  'HR',          82000),
('Vikram', 'Engineering', 92000),
('Neha',   'HR',          78000);

CREATE TABLE orders (
    id          INT PRIMARY KEY,
    employee_id INT REFERENCES employees(id),
    product     VARCHAR(50),
    amount      NUMERIC(10,2)
);

INSERT INTO orders VALUES
(1, 1, 'Laptop',     75000),
(2, 1, 'Mouse',       1500),
(3, 2, 'Keyboard',    3000),
(4, 3, 'Monitor',    25000),
(5, 5, 'Headphones',  4000),
(6, 8, 'Webcam',      2500);

-- === SUBQUERY IN WHERE — Scalar ===

-- Employees earning more than the company average
SELECT name, salary
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees);
-- Inner query: AVG(salary) = 82600.00
-- Outer query: salary > 82600.00

-- Employee with the highest salary
SELECT name, salary
FROM employees
WHERE salary = (SELECT MAX(salary) FROM employees);
-- Meera: 105000

-- === SUBQUERY IN WHERE — IN ===

-- Employees who have placed orders
SELECT name, department
FROM employees
WHERE id IN (SELECT DISTINCT employee_id FROM orders);

-- Employees who have NOT placed orders
SELECT name, department
FROM employees
WHERE id NOT IN (
    SELECT employee_id FROM orders WHERE employee_id IS NOT NULL
);
-- IMPORTANT: filter NULLs in NOT IN subquery!

-- === SUBQUERY IN WHERE — EXISTS ===

-- EXISTS: true if subquery returns ANY rows
SELECT e.name, e.department
FROM employees e
WHERE EXISTS (
    SELECT 1 FROM orders o WHERE o.employee_id = e.id
);
-- Same result as IN, but often faster for large tables

-- NOT EXISTS: employees with zero orders (safe with NULLs!)
SELECT e.name, e.department
FROM employees e
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.employee_id = e.id
);
-- Always prefer NOT EXISTS over NOT IN

-- === THE NOT IN NULL TRAP ===

-- Add an order with NULL employee_id
INSERT INTO orders VALUES (7, NULL, 'Cable', 500);

-- NOT IN with NULL = EMPTY RESULT (wrong!)
SELECT name FROM employees
WHERE id NOT IN (SELECT employee_id FROM orders);
-- (0 rows) ← WRONG! Should return 5 rows!

-- Fix 1: NOT EXISTS (always safe)
SELECT e.name FROM employees e
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.employee_id = e.id);
-- (5 rows) ← correct

-- Fix 2: Filter NULLs in subquery
SELECT name FROM employees
WHERE id NOT IN (
    SELECT employee_id FROM orders WHERE employee_id IS NOT NULL
);
-- (5 rows) ← correct

-- Clean up the NULL row
DELETE FROM orders WHERE id = 7;

-- === ANY and ALL ===

-- ANY: salary > at least one Marketing salary (> 72000)
SELECT name, salary FROM employees
WHERE salary > ANY (
    SELECT salary FROM employees WHERE department = 'Marketing'
)
ORDER BY salary DESC;
-- Marketing salaries: 72000, 75000
-- > ANY means > min(72000, 75000) = > 72000

-- ALL: salary > every Marketing salary (> 75000)
SELECT name, salary FROM employees
WHERE salary > ALL (
    SELECT salary FROM employees WHERE department = 'Marketing'
)
ORDER BY salary DESC;
-- > ALL means > max(72000, 75000) = > 75000

-- = ANY is same as IN
SELECT name FROM employees
WHERE department = ANY (ARRAY['Engineering', 'HR']);
-- Same as: WHERE department IN ('Engineering', 'HR')

-- Salary less than all Engineering salaries
SELECT name, salary FROM employees
WHERE salary < ALL (
    SELECT salary FROM employees WHERE department = 'Engineering'
);
-- < ALL Engineering (88000,92000,95000,105000) means < 88000

-- === SUBQUERY IN FROM — Derived Table ===

-- Top earner per department
SELECT e.name, e.department, e.salary
FROM employees e
INNER JOIN (
    SELECT department, MAX(salary) AS max_sal
    FROM employees
    GROUP BY department
) dept_max ON e.department = dept_max.department
           AND e.salary = dept_max.max_sal
ORDER BY e.salary DESC;

-- Department summary as a derived table
SELECT d.department, d.emp_count, d.avg_sal
FROM (
    SELECT department,
           COUNT(*) AS emp_count,
           ROUND(AVG(salary), 2) AS avg_sal
    FROM employees
    GROUP BY department
) d
WHERE d.emp_count >= 2
ORDER BY d.avg_sal DESC;
-- Note: derived tables MUST have an alias (d)

-- === SUBQUERY IN SELECT — Scalar ===

-- Each employee with their department's average
SELECT name, department, salary,
    ROUND((SELECT AVG(salary) FROM employees e2
           WHERE e2.department = e.department), 2) AS dept_avg,
    salary - (SELECT AVG(salary) FROM employees e2
              WHERE e2.department = e.department) AS diff_from_avg
FROM employees e
ORDER BY diff_from_avg DESC;
-- Correlated: e2.department = e.department

-- Each employee with company-wide stats
SELECT name, salary,
    salary - (SELECT AVG(salary) FROM employees) AS vs_company_avg,
    ROUND(salary::NUMERIC / (SELECT MAX(salary) FROM employees) * 100, 1)
        AS pct_of_max
FROM employees
ORDER BY salary DESC;

-- === CORRELATED vs NON-CORRELATED ===

-- Non-correlated: runs ONCE (independent)
SELECT name, salary FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees);
-- The subquery doesn't reference the outer query

-- Correlated: runs PER ROW (depends on outer)
SELECT name, department, salary FROM employees e
WHERE salary > (
    SELECT AVG(salary) FROM employees
    WHERE department = e.department  -- references e!
);
-- For each row, computes that department's average

-- === COMMON ERRORS ===

-- Error 1: Subquery returns more than one row for scalar
-- SELECT name FROM employees
-- WHERE salary = (SELECT salary FROM employees WHERE department = 'Engineering');
-- ERROR: more than one row returned by a subquery used as an expression
-- Fix: use IN or = ANY instead of =

-- Error 2: NOT IN with NULLs
-- Fix: use NOT EXISTS or filter NULLs

-- Error 3: Missing alias on derived table
-- SELECT * FROM (SELECT department, COUNT(*) FROM employees GROUP BY department);
-- ERROR: subquery in FROM must have an alias
-- Fix: add AS counts after the closing parenthesis

-- === PRACTICE EXERCISES ===

-- Exercise 1: Above company average
SELECT name, salary FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees)
ORDER BY salary DESC;

-- Exercise 2: IN — employees with orders
SELECT name FROM employees
WHERE id IN (SELECT DISTINCT employee_id FROM orders);

-- Exercise 3: EXISTS — employees with orders
SELECT e.name FROM employees e
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.employee_id = e.id);

-- Exercise 4: NOT EXISTS — employees without orders
SELECT e.name FROM employees e
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.employee_id = e.id);

-- Exercise 5: ALL — salary > every Sales salary
SELECT name, salary FROM employees
WHERE salary > ALL (SELECT salary FROM employees WHERE department = 'Sales')
ORDER BY salary;

-- Exercise 6: Derived table — top earner per department
SELECT e.name, e.department, e.salary
FROM employees e
JOIN (SELECT department, MAX(salary) AS max_sal
      FROM employees GROUP BY department) d
  ON e.department = d.department AND e.salary = d.max_sal;

-- Exercise 7: Scalar in SELECT — show dept avg
SELECT name, department, salary,
  (SELECT ROUND(AVG(salary),2) FROM employees e2
   WHERE e2.department = e.department) AS dept_avg
FROM employees e ORDER BY department, salary DESC;

-- === CLEANUP ===
-- DROP TABLE IF EXISTS orders, employees;

-- =============================================
-- Next Class: CTEs & Recursive CTEs
-- =============================================
