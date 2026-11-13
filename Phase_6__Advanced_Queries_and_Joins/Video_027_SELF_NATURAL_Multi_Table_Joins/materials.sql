-- =============================================
-- PostgreSQL Mastery: SELF JOIN, NATURAL JOIN,
-- USING, Multi-table Joins & Performance
-- Phase 6: JOINs | Classes 50-54
-- =============================================
-- Joining a table to itself, safe join shortcuts,
-- chaining 3+ tables, and checking performance.
-- =============================================

-- === SETUP: Employee-Manager Hierarchy ===

CREATE TABLE employees (
    id          INT PRIMARY KEY,
    name        VARCHAR(50) NOT NULL,
    department  VARCHAR(50),
    manager_id  INT REFERENCES employees(id)
);

INSERT INTO employees VALUES
(1, 'Meera', 'Executive',   NULL),  -- CEO, no manager
(2, 'Ravi',  'Engineering', 1),     -- reports to Meera
(3, 'Sonia', 'HR',          1),     -- reports to Meera
(4, 'Priya', 'Engineering', 2),     -- reports to Ravi
(5, 'Arjun', 'Engineering', 2),     -- reports to Ravi
(6, 'Kiran', 'HR',          3);     -- reports to Sonia

-- === SELF JOIN — Join a Table to Itself ===

-- Show each employee with their manager's name
SELECT e.name AS employee,
       e.department,
       m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;
-- LEFT JOIN so Meera (CEO, NULL manager) still appears

-- Only employees WHO HAVE a manager
SELECT e.name AS employee,
       m.name AS manager
FROM employees e
INNER JOIN employees m ON e.manager_id = m.id;
-- Meera excluded (no manager)

-- Find the CEO (employees with no manager)
SELECT name, department
FROM employees
WHERE manager_id IS NULL;
-- Meera

-- Find managers (employees who ARE someone's manager)
SELECT DISTINCT m.name AS manager, m.department
FROM employees e
INNER JOIN employees m ON e.manager_id = m.id;
-- Meera, Ravi, Sonia

-- === SELF JOIN — Same-Department Colleagues ===

-- Find pairs of employees in the same department
SELECT e1.name AS employee1,
       e2.name AS employee2,
       e1.department
FROM employees e1
INNER JOIN employees e2
  ON e1.department = e2.department
  AND e1.id < e2.id;
-- e1.id < e2.id avoids duplicates and self-pairs

-- === NATURAL JOIN — Auto-Match (Dangerous!) ===

CREATE TABLE dept_info (
    department VARCHAR(50),
    budget     INT
);
INSERT INTO dept_info VALUES
('Engineering', 500000),
('HR', 200000),
('Executive', 100000);

-- NATURAL JOIN: auto-matches on 'department' column
SELECT name, department, budget
FROM employees NATURAL JOIN dept_info;
-- Works... but fragile!

-- WHY IT'S DANGEROUS:
-- If someone adds a 'name' column to dept_info:
--   ALTER TABLE dept_info ADD COLUMN name VARCHAR(50);
-- NATURAL JOIN now matches on department AND name → 0 rows!
-- No error, no warning. Just silently wrong.

-- === USING Clause — Safe Alternative ===

-- USING: explicitly name the shared column
SELECT name, department, budget
FROM employees JOIN dept_info USING (department);
-- Same result as NATURAL JOIN, but explicit and safe

-- USING works with any JOIN type
SELECT name, department, budget
FROM employees LEFT JOIN dept_info USING (department);

-- Multiple shared columns? List them:
-- JOIN other_table USING (col1, col2)

-- USING vs ON:
-- USING (department) = ON e.department = d.department
-- USING: shared column appears once in result
-- ON:    shared column appears twice (e.department, d.department)

-- === MULTI-TABLE JOINs (3+ Tables) ===

CREATE TABLE shop_customers (
    id   INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL
);

CREATE TABLE products (
    id    INT PRIMARY KEY,
    name  VARCHAR(50),
    price NUMERIC(10,2)
);

CREATE TABLE shop_orders (
    id          INT PRIMARY KEY,
    customer_id INT REFERENCES shop_customers(id),
    product_id  INT REFERENCES products(id),
    quantity    INT,
    order_date  DATE DEFAULT CURRENT_DATE
);

INSERT INTO shop_customers VALUES
(1, 'Ravi'), (2, 'Priya'), (3, 'Arjun');

INSERT INTO products VALUES
(1, 'Laptop', 75000), (2, 'Mouse', 1500),
(3, 'Keyboard', 3000), (4, 'Monitor', 25000);

INSERT INTO shop_orders VALUES
(1, 1, 1, 1, '2024-01-15'), (2, 1, 2, 2, '2024-01-15'),
(3, 2, 3, 1, '2024-02-01'), (4, 2, 1, 1, '2024-02-10'),
(5, 3, 4, 2, '2024-03-05'), (6, 3, 2, 3, '2024-03-05');

-- Three-table JOIN
SELECT c.name AS customer,
       p.name AS product,
       o.quantity,
       p.price,
       o.quantity * p.price AS total
FROM shop_orders o
INNER JOIN shop_customers c ON o.customer_id = c.id
INNER JOIN products p ON o.product_id = p.id
ORDER BY c.name, o.order_date;

-- Customer order summary (3 tables + aggregation)
SELECT c.name AS customer,
       COUNT(*) AS total_orders,
       SUM(o.quantity * p.price) AS total_spent
FROM shop_orders o
INNER JOIN shop_customers c ON o.customer_id = c.id
INNER JOIN products p ON o.product_id = p.id
GROUP BY c.name
ORDER BY total_spent DESC;

-- === JOIN PERFORMANCE — EXPLAIN ===

-- See the query plan (does NOT execute the query)
EXPLAIN SELECT c.name, o.product, o.amount
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;
-- Look for: Hash Join, Nested Loop, or Merge Join
-- Look for: Seq Scan vs Index Scan

-- See actual execution time
EXPLAIN ANALYZE SELECT c.name, o.product, o.amount
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;
-- ANALYZE actually runs the query and reports timing

-- === INDEX ON FOREIGN KEY COLUMNS ===

-- PostgreSQL does NOT auto-create indexes on FK columns!
-- This means joins on FK columns may use Seq Scan (slow on large tables)

-- Create index to speed up joins
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_shop_orders_customer ON shop_orders(customer_id);
CREATE INDEX idx_shop_orders_product ON shop_orders(product_id);

-- Compare EXPLAIN before and after adding the index
EXPLAIN SELECT c.name, o.product
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;
-- May now show Index Scan instead of Seq Scan (on larger tables)

-- === COMMON ERRORS ===

-- Error 1: SELF JOIN without aliases
-- SELECT employees.name FROM employees JOIN employees
--   ON employees.manager_id = employees.id;
-- ERROR: table name "employees" specified more than once
-- Fix: use aliases: FROM employees e JOIN employees m

-- Error 2: NATURAL JOIN surprise
-- After ALTER TABLE dept_info ADD COLUMN name VARCHAR(50):
-- SELECT * FROM employees NATURAL JOIN dept_info;
-- Returns 0 rows! (matches on department AND name now)
-- Fix: use USING (department) instead

-- Error 3: Missing FK index
-- Slow joins on large tables → check with EXPLAIN
-- Fix: CREATE INDEX idx_name ON table(fk_column);

-- === ON vs USING vs NATURAL — Quick Reference ===

-- ON:      Any condition (most flexible)
--          ON c.id = o.customer_id
--          ON c.id = o.customer_id AND o.amount > 100

-- USING:   Same-named columns only (clean, safe)
--          USING (department)
--          USING (department, region)

-- NATURAL: Auto-match all same-named columns (AVOID!)
--          Schema changes silently break queries

-- === PRACTICE EXERCISES ===

-- Exercise 1: SELF JOIN — employee + manager
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;

-- Exercise 2: Find employees with no manager (CEO)
SELECT e.name AS employee
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id
WHERE m.id IS NULL;
-- Or simpler: WHERE manager_id IS NULL

-- Exercise 3: Three-table JOIN
SELECT c.name, p.name AS product, o.quantity, p.price
FROM shop_orders o
JOIN shop_customers c ON o.customer_id = c.id
JOIN products p ON o.product_id = p.id;

-- Exercise 4: Rewrite NATURAL as USING
-- Before (dangerous):
-- SELECT * FROM employees NATURAL JOIN dept_info;
-- After (safe):
SELECT e.name, e.department, d.budget
FROM employees e JOIN dept_info d USING (department);

-- Exercise 5: EXPLAIN a join
EXPLAIN ANALYZE
SELECT c.name, p.name, o.quantity * p.price AS total
FROM shop_orders o
JOIN shop_customers c ON o.customer_id = c.id
JOIN products p ON o.product_id = p.id;

-- Exercise 6: Find colleague pairs (same department)
SELECT e1.name, e2.name, e1.department
FROM employees e1
JOIN employees e2 ON e1.department = e2.department AND e1.id < e2.id;

-- Exercise 7: Managers and their direct report count
SELECT m.name AS manager,
       COUNT(e.id) AS direct_reports
FROM employees e
INNER JOIN employees m ON e.manager_id = m.id
GROUP BY m.name
ORDER BY direct_reports DESC;

-- === CLEANUP ===
-- DROP TABLE IF EXISTS shop_orders, shop_customers, products;
-- DROP TABLE IF EXISTS dept_info, employees;
-- DROP INDEX IF EXISTS idx_orders_customer_id;
-- DROP INDEX IF EXISTS idx_shop_orders_customer;
-- DROP INDEX IF EXISTS idx_shop_orders_product;

-- =============================================
-- Phase 6: JOINs — COMPLETE!
-- Next Phase: Phase 7 — Aggregation & Grouping
-- Next Class: COUNT, SUM, AVG, GROUP BY & HAVING
-- =============================================


-- =============================================
-- ANSWER KEY — SELF, NATURAL & MULTI-TABLE JOIN SOLUTIONS
-- =============================================

-- 1. SELF JOIN: Employee-Manager Hierarchy
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;

-- 2. Find Root Hierarchy Entity (CEO)
SELECT e.name AS employee
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id
WHERE m.id IS NULL;

-- 3. Three-Table Relational Join
SELECT c.name, p.name AS product, o.quantity, p.price
FROM shop_orders o
JOIN shop_customers c ON o.customer_id = c.id
JOIN products p ON o.product_id = p.id;

-- 4. Safe USING Replacement for Fragile NATURAL JOIN
SELECT e.name, e.department, d.budget
FROM employees e
JOIN dept_info d USING (department);

-- 5. Colleague Pairing Without Duplicates
SELECT e1.name, e2.name, e1.department
FROM employees e1
JOIN employees e2 ON e1.department = e2.department AND e1.id < e2.id;
