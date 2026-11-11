-- =============================================
-- PostgreSQL Mastery: JOIN Types
-- Phase 6: JOINs | Classes 45-49
-- =============================================
-- INNER, LEFT, RIGHT, FULL OUTER, and CROSS JOIN.
-- =============================================

-- === SETUP ===

CREATE TABLE customers (
    id   INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    city VARCHAR(50)
);

CREATE TABLE orders (
    id          INT PRIMARY KEY,
    customer_id INT,
    product     VARCHAR(50),
    amount      NUMERIC(10,2)
);

INSERT INTO customers VALUES
(1, 'Ravi',   'Mumbai'),
(2, 'Priya',  'Delhi'),
(3, 'Arjun',  'Chennai'),
(4, 'Meera',  'Pune'),
(5, 'Kiran',  'Hyderabad');

INSERT INTO orders VALUES
(101, 1, 'Laptop',     75000),
(102, 1, 'Mouse',       1500),
(103, 2, 'Keyboard',    3000),
(104, 3, 'Monitor',    25000),
(105, 3, 'Headphones',  4000),
(106, 6, 'Webcam',      2500),   -- customer_id 6 does NOT exist
(107, 7, 'Speaker',     8000);   -- customer_id 7 does NOT exist
-- Customers 4,5 have NO orders
-- Orders 106,107 have NO matching customer

-- === INNER JOIN — Only Matching Rows ===

SELECT c.name, c.city, o.product, o.amount
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;
-- 5 rows: Ravi(2), Priya(1), Arjun(2)
-- Meera, Kiran excluded (no orders)
-- Orders 106,107 excluded (no matching customer)

-- JOIN without INNER keyword = same thing
SELECT c.name, o.product
FROM customers c
JOIN orders o ON c.id = o.customer_id;
-- JOIN = INNER JOIN (INNER is optional)

-- === LEFT JOIN — All Left Rows + Matching Right ===

SELECT c.name, c.city, o.product, o.amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id;
-- 7 rows: 5 matches + Meera(NULL) + Kiran(NULL)

-- LEFT OUTER JOIN = same as LEFT JOIN
SELECT c.name, o.product
FROM customers c
LEFT OUTER JOIN orders o ON c.id = o.customer_id;

-- === LEFT JOIN + IS NULL — Find Unmatched Rows ===

-- Customers with NO orders
SELECT c.name, c.city
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.id IS NULL;
-- Meera, Kiran

-- This pattern works for ANY "find missing" query:
-- LEFT JOIN + WHERE right_table.key IS NULL

-- === RIGHT JOIN — All Right Rows + Matching Left ===

SELECT c.name, c.city, o.product, o.amount
FROM customers c
RIGHT JOIN orders o ON c.id = o.customer_id;
-- 7 rows: 5 matches + Webcam(NULL) + Speaker(NULL)

-- Orders with NO matching customer
SELECT o.product, o.amount
FROM customers c
RIGHT JOIN orders o ON c.id = o.customer_id
WHERE c.id IS NULL;
-- Webcam, Speaker

-- RIGHT JOIN = LEFT JOIN with tables swapped:
SELECT c.name, c.city, o.product, o.amount
FROM orders o
LEFT JOIN customers c ON c.id = o.customer_id;
-- Same result as the RIGHT JOIN above!

-- === FULL OUTER JOIN — Everything from Both ===

SELECT c.name, c.city, o.product, o.amount
FROM customers c
FULL OUTER JOIN orders o ON c.id = o.customer_id;
-- 9 rows: 5 matches + 2 unmatched customers + 2 unmatched orders

-- Find ALL unmatched rows from both sides
SELECT
    COALESCE(c.name, '(no customer)') AS customer,
    COALESCE(o.product, '(no order)') AS product
FROM customers c
FULL OUTER JOIN orders o ON c.id = o.customer_id
WHERE c.id IS NULL OR o.customer_id IS NULL;
-- Shows gaps from BOTH sides

-- === CROSS JOIN — Every Combination ===

-- No ON clause — every row × every row
SELECT c.name, o.product
FROM customers c
CROSS JOIN orders o
ORDER BY c.name, o.product;
-- 5 × 7 = 35 rows

-- Practical use: generate all variants
SELECT s.size, c.color
FROM (VALUES ('S'),('M'),('L')) AS s(size)
CROSS JOIN (VALUES ('Red'),('Blue'),('Green'),('Black')) AS c(color);
-- 3 × 4 = 12 combinations

-- Comma syntax = implicit CROSS JOIN (old style, avoid):
SELECT c.name, o.product
FROM customers c, orders o;
-- Same as CROSS JOIN but less readable

-- WARNING: CROSS JOIN on large tables is DANGEROUS
-- 1000 rows × 1000 rows = 1,000,000 rows!

-- === ROW COUNT COMPARISON ===

SELECT 'INNER'      AS join_type, COUNT(*) AS rows
FROM customers c INNER JOIN orders o ON c.id = o.customer_id
UNION ALL
SELECT 'LEFT',  COUNT(*)
FROM customers c LEFT JOIN orders o ON c.id = o.customer_id
UNION ALL
SELECT 'RIGHT', COUNT(*)
FROM customers c RIGHT JOIN orders o ON c.id = o.customer_id
UNION ALL
SELECT 'FULL',  COUNT(*)
FROM customers c FULL OUTER JOIN orders o ON c.id = o.customer_id
UNION ALL
SELECT 'CROSS', COUNT(*)
FROM customers c CROSS JOIN orders o;
-- INNER: 5, LEFT: 7, RIGHT: 7, FULL: 9, CROSS: 35

-- === COMMON ERRORS ===

-- Error 1: Ambiguous column reference
-- SELECT id, name, product
-- FROM customers INNER JOIN orders ON customers.id = orders.customer_id;
-- ERROR: column reference "id" is ambiguous
-- Fix: use aliases: SELECT c.id, c.name, o.product

-- Error 2: Forgetting ON clause (accidental CROSS JOIN)
-- SELECT c.name, o.product
-- FROM customers c INNER JOIN orders o;
-- ERROR: missing join condition
-- Fix: add ON c.id = o.customer_id

-- Error 3: Wrong join column
-- SELECT c.name, o.product
-- FROM customers c INNER JOIN orders o ON c.id = o.id;
-- Runs but gives WRONG results! Should be o.customer_id, not o.id

-- === JOIN SYNTAX SHORTCUTS ===

-- INNER JOIN = JOIN (INNER is optional)
-- LEFT OUTER JOIN = LEFT JOIN (OUTER is optional)
-- RIGHT OUTER JOIN = RIGHT JOIN (OUTER is optional)
-- FULL OUTER JOIN = FULL JOIN (OUTER is optional)

-- === PRACTICE EXERCISES ===

-- Exercise 1: INNER JOIN
SELECT c.name, c.city, o.product, o.amount
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;

-- Exercise 2: LEFT JOIN
SELECT c.name, c.city, o.product, o.amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id;

-- Exercise 3: Find customers with no orders
SELECT c.name, c.city
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.id IS NULL;

-- Exercise 4: FULL OUTER JOIN — all gaps
SELECT
    COALESCE(c.name, '???') AS customer,
    COALESCE(o.product, '???') AS product
FROM customers c
FULL OUTER JOIN orders o ON c.id = o.customer_id
WHERE c.id IS NULL OR o.customer_id IS NULL;

-- Exercise 5: CROSS JOIN — size × color grid
SELECT s.size, c.color
FROM (VALUES ('XS'),('S'),('M'),('L'),('XL')) AS s(size)
CROSS JOIN (VALUES ('Red'),('Blue'),('Black')) AS c(color)
ORDER BY s.size, c.color;

-- Exercise 6: Count rows per join type
SELECT 'INNER' AS type, COUNT(*) AS rows
FROM customers c INNER JOIN orders o ON c.id = o.customer_id
UNION ALL
SELECT 'LEFT', COUNT(*) FROM customers c LEFT JOIN orders o ON c.id = o.customer_id
UNION ALL
SELECT 'RIGHT', COUNT(*) FROM customers c RIGHT JOIN orders o ON c.id = o.customer_id
UNION ALL
SELECT 'FULL', COUNT(*) FROM customers c FULL OUTER JOIN orders o ON c.id = o.customer_id
UNION ALL
SELECT 'CROSS', COUNT(*) FROM customers c CROSS JOIN orders o;

-- Exercise 7: Rewrite RIGHT JOIN as LEFT JOIN
-- Original RIGHT JOIN:
SELECT c.name, o.product FROM customers c
RIGHT JOIN orders o ON c.id = o.customer_id;
-- Equivalent LEFT JOIN (swap table order):
SELECT c.name, o.product FROM orders o
LEFT JOIN customers c ON c.id = o.customer_id;

-- === CLEANUP ===
-- DROP TABLE IF EXISTS orders, customers;

-- =============================================
-- Next Class: SELF JOIN, NATURAL JOIN,
-- Multi-table Joins & Performance
-- =============================================
