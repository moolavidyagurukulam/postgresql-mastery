-- =============================================
-- PostgreSQL Mastery: UNION, INTERSECT & EXCEPT
-- Phase 10: Advanced SQL | Class 75
-- =============================================
-- Combining query results with set operations.
-- =============================================

-- === SETUP ===

CREATE TABLE customers (
    id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  VARCHAR(50),
    city  VARCHAR(50)
);

CREATE TABLE suppliers (
    id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  VARCHAR(50),
    city  VARCHAR(50)
);

INSERT INTO customers (name, city) VALUES
('Meera', 'Mumbai'), ('Ravi', 'Delhi'),
('Priya', 'Chennai'), ('Arjun', 'Mumbai'),
('Sonia', 'Bangalore');

INSERT INTO suppliers (name, city) VALUES
('Kiran', 'Pune'), ('Meera', 'Mumbai'),
('Deepak', 'Delhi'), ('Priya', 'Chennai'),
('Vikram', 'Hyderabad');

-- === UNION (removes duplicates) ===

-- All people from both tables, no duplicates
SELECT name, city FROM customers
UNION
SELECT name, city FROM suppliers
ORDER BY name;
-- Meera and Priya appear only ONCE

-- === UNION ALL (keeps duplicates) ===

-- All rows from both tables, duplicates kept
SELECT name, city FROM customers
UNION ALL
SELECT name, city FROM suppliers
ORDER BY name;
-- Meera and Priya appear TWICE (once from each table)

-- UNION ALL is faster: no dedup sort needed
-- Use it when duplicates are impossible or wanted

-- === INTERSECT (common rows) ===

-- People who are BOTH customers AND suppliers
SELECT name, city FROM customers
INTERSECT
SELECT name, city FROM suppliers;
-- Result: Meera (Mumbai), Priya (Chennai)
-- ALL columns must match (name AND city)

-- INTERSECT ALL: keeps duplicate counts (rare)
SELECT name, city FROM customers
INTERSECT ALL
SELECT name, city FROM suppliers;

-- === EXCEPT (set difference) ===

-- Customers who are NOT suppliers
SELECT name, city FROM customers
EXCEPT
SELECT name, city FROM suppliers;
-- Result: Arjun, Ravi, Sonia

-- Suppliers who are NOT customers (reversed!)
SELECT name, city FROM suppliers
EXCEPT
SELECT name, city FROM customers;
-- Result: Deepak, Kiran, Vikram
-- ORDER MATTERS for EXCEPT!

-- EXCEPT ALL: keeps duplicate counts (rare)
SELECT name, city FROM customers
EXCEPT ALL
SELECT name, city FROM suppliers;

-- === SOURCE LABELS ===

-- Add a label to identify which table each row came from
SELECT name, city, 'customer' AS source FROM customers
UNION ALL
SELECT name, city, 'supplier' AS source FROM suppliers
ORDER BY name, source;

-- === SET OPERATIONS WITH WHERE ===

-- Only Mumbai people from both tables
SELECT name, city FROM customers WHERE city = 'Mumbai'
UNION
SELECT name, city FROM suppliers WHERE city = 'Mumbai';

-- Customers in Mumbai who are NOT suppliers in Mumbai
SELECT name, city FROM customers WHERE city = 'Mumbai'
EXCEPT
SELECT name, city FROM suppliers WHERE city = 'Mumbai';

-- === CHAINING MULTIPLE SET OPERATIONS ===

-- You can chain as many as needed
-- (If you had a third table like partners)
-- SELECT name, city FROM customers
-- UNION ALL
-- SELECT name, city FROM suppliers
-- UNION ALL
-- SELECT name, city FROM partners
-- ORDER BY name;

-- === COLUMN MATCHING RULES ===

-- MUST have the same number of columns:
-- SELECT name, city FROM customers
-- UNION
-- SELECT name FROM suppliers;
-- ERROR: each UNION query must have the same number of columns

-- Types must be compatible:
-- SELECT id, name FROM customers    -- id is INT
-- UNION
-- SELECT name, city FROM suppliers; -- name is VARCHAR
-- ERROR: UNION types integer and character varying cannot be matched

-- You can cast to make types match:
SELECT id::TEXT, name FROM customers
UNION
SELECT name, city FROM suppliers;

-- Column names come from the FIRST query
SELECT name AS person, city AS location FROM customers
UNION
SELECT name, city FROM suppliers;
-- Result columns: person, location (from first query)

-- === ORDER BY AND LIMIT ===

-- ORDER BY applies to the COMBINED result
-- Must reference column names from the first query
SELECT name, city FROM customers
UNION
SELECT name, city FROM suppliers
ORDER BY city, name;

-- LIMIT on the combined result
SELECT name, city FROM customers
UNION ALL
SELECT name, city FROM suppliers
ORDER BY name
LIMIT 5;

-- === PARENTHESES FOR COMPLEX OPERATIONS ===

-- Use parentheses to control evaluation order
(SELECT name, city FROM customers
 EXCEPT
 SELECT name, city FROM suppliers)
UNION
(SELECT name, city FROM suppliers
 EXCEPT
 SELECT name, city FROM customers);
-- Result: people who are ONLY in one table (symmetric difference)

-- === EXPLAIN SET OPERATIONS ===

-- See how PostgreSQL executes set operations
EXPLAIN SELECT name, city FROM customers
UNION
SELECT name, city FROM suppliers;
-- Shows: Unique → Sort → Append → two Seq Scans

EXPLAIN SELECT name, city FROM customers
UNION ALL
SELECT name, city FROM suppliers;
-- Shows: Append → two Seq Scans (no Sort/Unique)

-- === REAL-WORLD EXAMPLES ===

-- Example 1: Combined activity log from multiple tables
-- SELECT user_id, action, created_at FROM login_events
-- UNION ALL
-- SELECT user_id, action, created_at FROM page_views
-- UNION ALL
-- SELECT user_id, action, created_at FROM purchases
-- ORDER BY created_at DESC;

-- Example 2: Find users who never placed an order
-- SELECT email FROM users
-- EXCEPT
-- SELECT u.email FROM users u JOIN orders o ON u.id = o.user_id;

-- Example 3: Find products in both wishlists AND carts
-- SELECT product_id FROM wishlists
-- INTERSECT
-- SELECT product_id FROM cart_items;

-- === PRACTICE EXERCISES ===

-- Exercise 1: UNION all people
SELECT name, city FROM customers
UNION
SELECT name, city FROM suppliers;

-- Exercise 2: UNION ALL (see duplicates)
SELECT name, city FROM customers
UNION ALL
SELECT name, city FROM suppliers;

-- Exercise 3: INTERSECT (both customer AND supplier)
SELECT name, city FROM customers
INTERSECT
SELECT name, city FROM suppliers;

-- Exercise 4: EXCEPT (customers not suppliers)
SELECT name, city FROM customers
EXCEPT
SELECT name, city FROM suppliers;

-- Exercise 5: Reversed EXCEPT
SELECT name, city FROM suppliers
EXCEPT
SELECT name, city FROM customers;

-- Exercise 6: With source label
SELECT name, city, 'C' AS src FROM customers
UNION ALL
SELECT name, city, 'S' FROM suppliers
ORDER BY name;

-- Exercise 7: EXPLAIN a UNION vs UNION ALL
EXPLAIN SELECT name, city FROM customers
UNION SELECT name, city FROM suppliers;

EXPLAIN SELECT name, city FROM customers
UNION ALL SELECT name, city FROM suppliers;

-- === CLEANUP ===
-- DROP TABLE IF EXISTS customers, suppliers;

-- =============================================
-- Next Class: Window Functions (Part 1)
-- =============================================
