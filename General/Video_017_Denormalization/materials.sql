-- =============================================
-- PostgreSQL Mastery: Denormalization
-- Phase 3: Database Design | Class 21
-- =============================================
-- When to break normalization rules for performance.
-- =============================================

-- === SETUP: Normalized Tables (from Normalization class) ===

CREATE TABLE customers (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    city  VARCHAR(100)
);

CREATE TABLE products (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    price NUMERIC(10,2) NOT NULL
);

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    order_date  DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE order_items (
    id         SERIAL PRIMARY KEY,
    order_id   INT NOT NULL REFERENCES orders(id),
    product_id INT NOT NULL REFERENCES products(id),
    qty        INT NOT NULL DEFAULT 1
);

-- Sample data
INSERT INTO customers (name, email, city) VALUES
('Ravi',  'ravi@ex.com',  'Mumbai'),
('Priya', 'priya@ex.com', 'Delhi'),
('Arjun', 'arjun@ex.com', 'Bangalore');

INSERT INTO products (name, price) VALUES
('Laptop',   999.99),
('Mouse',     29.99),
('Keyboard',  49.99),
('Monitor',  299.99),
('Headphones', 79.99);

INSERT INTO orders (customer_id, order_date) VALUES
(1, '2026-10-01'),
(1, '2026-10-05'),
(2, '2026-10-03'),
(3, '2026-10-07'),
(2, '2026-10-10');

INSERT INTO order_items (order_id, product_id, qty) VALUES
(1, 1, 1), (1, 2, 2),
(2, 4, 1),
(3, 3, 1), (3, 5, 2),
(4, 1, 1), (4, 3, 1),
(5, 2, 3);

-- === THE SLOW NORMALIZED QUERY (4 JOINs) ===

SELECT o.id AS order_id,
       c.name AS customer,
       c.city,
       p.name AS product,
       oi.qty,
       oi.qty * p.price AS line_total,
       o.order_date
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
ORDER BY o.order_date DESC;

-- This runs every page load on a dashboard!

-- === STRATEGY 1: Redundant Columns ===

-- Add customer_name directly to orders
ALTER TABLE orders ADD COLUMN customer_name VARCHAR(100);

-- Fill from customers table
UPDATE orders o
SET customer_name = c.name
FROM customers c
WHERE o.customer_id = c.id;

-- Now: no JOIN needed for basic order list
SELECT id, customer_name, order_date
FROM orders
ORDER BY order_date DESC;

-- Trade-off: if customer renames, must update BOTH tables
-- UPDATE customers SET name = 'Ravi Kumar' WHERE id = 1;
-- UPDATE orders SET customer_name = 'Ravi Kumar' WHERE customer_id = 1;

-- === STRATEGY 2: Summary / Aggregate Table ===

CREATE TABLE daily_sales (
    sale_date     DATE PRIMARY KEY,
    total_orders  INT,
    total_revenue NUMERIC(12,2)
);

-- Populate from normalized tables
INSERT INTO daily_sales
SELECT o.order_date,
       COUNT(DISTINCT o.id),
       SUM(oi.qty * p.price)
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
GROUP BY o.order_date;

-- Dashboard reads this — instant!
SELECT * FROM daily_sales ORDER BY sale_date DESC;

-- Must refresh when new orders arrive
-- (use trigger, scheduled job, or application logic)

-- === STRATEGY 3: Materialized View (Best of Both) ===

CREATE MATERIALIZED VIEW mv_order_dashboard AS
SELECT o.id AS order_id,
       c.name AS customer,
       c.city,
       p.name AS product,
       oi.qty,
       oi.qty * p.price AS line_total,
       o.order_date
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id;

-- Query the materialized view — reads cached data!
SELECT * FROM mv_order_dashboard
ORDER BY order_date DESC;

-- === REFRESHING MATERIALIZED VIEWS ===

-- Basic refresh (locks view during refresh)
REFRESH MATERIALIZED VIEW mv_order_dashboard;

-- CONCURRENTLY: no lock, reads continue
-- Requires a UNIQUE INDEX on the view
CREATE UNIQUE INDEX idx_mv_order
  ON mv_order_dashboard (order_id, product);

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_order_dashboard;

-- Add new data, then refresh to see it
INSERT INTO orders (customer_id, order_date) VALUES (3, '2026-10-15');
INSERT INTO order_items (order_id, product_id, qty) VALUES (6, 5, 1);

-- View still shows old data until refreshed:
SELECT * FROM mv_order_dashboard ORDER BY order_date DESC;

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_order_dashboard;

-- Now view includes new order:
SELECT * FROM mv_order_dashboard ORDER BY order_date DESC;

-- === REGULAR VIEW vs MATERIALIZED VIEW ===

-- Regular view: runs the query every time (always fresh, but slow)
CREATE VIEW v_order_dashboard AS
SELECT o.id AS order_id,
       c.name AS customer,
       c.city,
       p.name AS product,
       oi.qty,
       oi.qty * p.price AS line_total,
       o.order_date
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id;

-- Compare:
-- Regular view: always up-to-date, runs JOIN every time
SELECT * FROM v_order_dashboard ORDER BY order_date DESC;

-- Materialized view: cached, fast, must refresh manually
SELECT * FROM mv_order_dashboard ORDER BY order_date DESC;

-- === WHEN TO DENORMALIZE — DECISION FRAMEWORK ===

-- Frequent JOINs on same cols  → Redundant columns
-- Dashboard aggregates         → Summary table
-- Complex report queries       → Materialized view
-- Write-heavy workload         → Stay normalized!
-- Small dataset (< 100K rows)  → Stay normalized!
-- Rule: Start normalized, denormalize only when proven slow

-- === PRACTICE EXERCISES ===

-- Exercise 1: Create a summary table for revenue by customer
CREATE TABLE customer_revenue AS
SELECT c.id AS customer_id,
       c.name,
       COUNT(DISTINCT o.id) AS total_orders,
       COALESCE(SUM(oi.qty * p.price), 0) AS total_spent
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
LEFT JOIN order_items oi ON oi.order_id = o.id
LEFT JOIN products p ON oi.product_id = p.id
GROUP BY c.id, c.name;

SELECT * FROM customer_revenue ORDER BY total_spent DESC;

-- Exercise 2: Create a materialized view of product popularity
CREATE MATERIALIZED VIEW mv_product_popularity AS
SELECT p.id AS product_id,
       p.name,
       p.price,
       COALESCE(SUM(oi.qty), 0) AS units_sold,
       COALESCE(SUM(oi.qty * p.price), 0) AS revenue
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.id
GROUP BY p.id, p.name, p.price;

SELECT * FROM mv_product_popularity ORDER BY units_sold DESC;

-- Exercise 3: Add unique index and refresh concurrently
CREATE UNIQUE INDEX idx_mv_product ON mv_product_popularity (product_id);
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_popularity;

-- Exercise 4: Compare query plans
EXPLAIN ANALYZE
SELECT o.id, c.name, p.name, oi.qty * p.price
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id;

EXPLAIN ANALYZE
SELECT * FROM mv_order_dashboard;

-- Exercise 5: Drop the materialized view
-- DROP MATERIALIZED VIEW IF EXISTS mv_order_dashboard;
-- DROP MATERIALIZED VIEW IF EXISTS mv_product_popularity;

-- === CLEANUP ===
-- DROP VIEW IF EXISTS v_order_dashboard;
-- DROP MATERIALIZED VIEW IF EXISTS mv_order_dashboard;
-- DROP MATERIALIZED VIEW IF EXISTS mv_product_popularity;
-- DROP TABLE IF EXISTS customer_revenue, daily_sales;
-- DROP TABLE IF EXISTS order_items, orders, products, customers;

-- =============================================
-- Next Class: Naming Conventions, Best Practices & OLTP vs OLAP
-- =============================================
