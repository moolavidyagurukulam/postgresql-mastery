-- =============================================
-- PostgreSQL Mastery: Naming Conventions, Best Practices & OLTP vs OLAP
-- Phase 3: Database Design | Classes 22-24
-- =============================================
-- Design rules that save you pain later.
-- =============================================

-- === THE PROBLEM: PostgreSQL Lowercases Unquoted Identifiers ===

CREATE TABLE UserAccounts (id SERIAL PRIMARY KEY, name TEXT);
-- PostgreSQL stores this as: useraccounts (all lowercase!)

-- Try to find it with original casing:
-- \dt UserAccounts  → "Did not find any relation"
-- \dt useraccounts  → Found!

-- With double quotes, PG preserves case:
CREATE TABLE "MixedCase" (id SERIAL PRIMARY KEY);
-- Must ALWAYS quote it: SELECT * FROM "MixedCase";
-- Forget the quotes → ERROR: relation "mixedcase" does not exist

-- Lesson: avoid double-quoted identifiers, use snake_case
DROP TABLE IF EXISTS useraccounts, "MixedCase";

-- === RULE 1: snake_case FOR EVERYTHING ===

-- Tables: plural snake_case
-- users, order_items, product_categories

-- Columns: singular snake_case
-- first_name, email, created_at

-- Primary Key: id
-- Foreign Key: referenced_table_id (customer_id, product_id)

-- Indexes: idx_table_column
-- idx_users_email, idx_orders_customer_id

-- Constraints: type_table_column
-- pk_users_id, uq_users_email, ck_orders_qty

-- === GOOD vs BAD NAMING ===

-- BAD:
-- tbl_usr          → meaningless prefix
-- data, info       → too vague
-- x, n, val        → single letters
-- user_data_info   → too long
-- acct_dtl         → cryptic abbreviation
-- type, order      → reserved words (need quoting!)

-- GOOD:
-- users            → clear, simple
-- accounts         → specific noun
-- first_name       → descriptive
-- order_items      → shows relationship
-- account_details  → full words
-- user_type        → prefixed to avoid reserved word

-- === ANTI-PATTERN 1: EAV (Entity-Attribute-Value) ===

-- BAD: Everything as key-value pairs
CREATE TABLE user_attributes_bad (
    user_id    INT,
    attr_name  VARCHAR(50),
    attr_value VARCHAR(255)
);
INSERT INTO user_attributes_bad VALUES
(1, 'name', 'Ravi'),
(1, 'email', 'ravi@ex.com'),
(1, 'age', '30');  -- age as text!
-- Want users older than 25? Need to cast text to int...
-- No type safety, no constraints, terrible performance

-- GOOD: Proper typed columns
CREATE TABLE users (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    age   INT CHECK (age > 0 AND age < 150)
);
INSERT INTO users (name, email, age)
VALUES ('Ravi', 'ravi@ex.com', 30);

-- === ANTI-PATTERN 2: One Big Table ===

-- BAD: 50+ columns, most NULL
-- CREATE TABLE everything (
--     id SERIAL, user_name TEXT, user_email TEXT,
--     order_id INT, order_date DATE, order_total NUMERIC,
--     product_name TEXT, product_price NUMERIC,
--     ... 40 more columns ...
-- );

-- GOOD: Normalized into separate tables (you already know this!)

-- === ANTI-PATTERN 3: Stringly Typed ===

-- BAD:
CREATE TABLE events_bad (
    id         SERIAL,
    event_date VARCHAR(20),   -- should be DATE!
    is_active  VARCHAR(5),    -- should be BOOLEAN!
    price      VARCHAR(20)    -- should be NUMERIC!
);
INSERT INTO events_bad VALUES (1, '2026-10-15', 'yes', '29.99');
-- No date math, no boolean logic, no numeric operations!

-- GOOD:
CREATE TABLE events (
    id         SERIAL PRIMARY KEY,
    event_date DATE NOT NULL,
    is_active  BOOLEAN DEFAULT true,
    price      NUMERIC(10,2) CHECK (price >= 0)
);
INSERT INTO events (event_date, is_active, price)
VALUES ('2026-10-15', true, 29.99);

-- === BEST PRACTICES ===

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,                    -- 1. Always have a PK
    customer_id INT NOT NULL REFERENCES users(id),     -- 2. FK for relationships
    total       NUMERIC(10,2) NOT NULL CHECK (total >= 0), -- 3. Correct type + constraint
    status      VARCHAR(20) DEFAULT 'pending'
                CHECK (status IN ('pending','confirmed','shipped','delivered','cancelled')),
    created_at  TIMESTAMPTZ DEFAULT NOW(),             -- 4. Timestamps
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Document your schema
COMMENT ON TABLE orders IS 'Customer purchase orders';
COMMENT ON COLUMN orders.status IS 'pending, confirmed, shipped, delivered, cancelled';
COMMENT ON COLUMN orders.total IS 'Order total after discounts, before tax';

-- View comments:
-- \d+ orders

-- 6. Index columns used in WHERE and JOIN
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
CREATE INDEX idx_orders_status ON orders (status);
CREATE INDEX idx_orders_created_at ON orders (created_at);

-- === OLTP: Online Transaction Processing ===

-- Purpose: Process many small, fast transactions
-- Examples: e-commerce checkout, banking, ticket booking
-- Design: Normalized (3NF), many tables, foreign keys
-- Queries: Simple — INSERT 1 row, UPDATE 1 row
-- Priority: Write speed, data integrity, ACID

-- OLTP example query:
INSERT INTO orders (customer_id, total, status)
VALUES (1, 129.98, 'pending');

UPDATE orders SET status = 'confirmed' WHERE id = 1;

SELECT id, total, status FROM orders WHERE customer_id = 1;

-- === OLAP: Online Analytical Processing ===

-- Purpose: Analyze large volumes of historical data
-- Examples: Sales reports, revenue trends, BI dashboards
-- Design: Denormalized star schema (fact + dimension tables)
-- Queries: Complex — SUM, AVG, GROUP BY across millions of rows
-- Priority: Read speed, aggregation, query performance

-- === STAR SCHEMA EXAMPLE ===

-- Dimension tables (descriptive attributes)
CREATE TABLE dim_customers (
    customer_key SERIAL PRIMARY KEY,
    name         VARCHAR(100),
    city         VARCHAR(100),
    segment      VARCHAR(50)
);

CREATE TABLE dim_products (
    product_key SERIAL PRIMARY KEY,
    name        VARCHAR(100),
    category    VARCHAR(50),
    brand       VARCHAR(100)
);

CREATE TABLE dim_date (
    date_key   INT PRIMARY KEY,
    full_date  DATE,
    year       INT,
    quarter    INT,
    month      INT,
    month_name VARCHAR(20),
    day_of_week VARCHAR(20)
);

CREATE TABLE dim_stores (
    store_key SERIAL PRIMARY KEY,
    name      VARCHAR(100),
    city      VARCHAR(100),
    region    VARCHAR(50)
);

-- Fact table (measurements + foreign keys to dimensions)
CREATE TABLE fact_sales (
    sale_id      SERIAL PRIMARY KEY,
    customer_key INT REFERENCES dim_customers(customer_key),
    product_key  INT REFERENCES dim_products(product_key),
    date_key     INT REFERENCES dim_date(date_key),
    store_key    INT REFERENCES dim_stores(store_key),
    qty          INT NOT NULL,
    revenue      NUMERIC(12,2) NOT NULL
);

-- Sample dimension data
INSERT INTO dim_customers (name, city, segment) VALUES
('Ravi', 'Mumbai', 'Premium'),
('Priya', 'Delhi', 'Standard'),
('Arjun', 'Bangalore', 'Premium');

INSERT INTO dim_products (name, category, brand) VALUES
('Laptop', 'Electronics', 'TechBrand'),
('Mouse', 'Accessories', 'TechBrand'),
('Keyboard', 'Accessories', 'TypePro');

INSERT INTO dim_date (date_key, full_date, year, quarter, month, month_name, day_of_week) VALUES
(20261001, '2026-10-01', 2026, 4, 10, 'October', 'Thursday'),
(20261005, '2026-10-05', 2026, 4, 10, 'October', 'Monday'),
(20261010, '2026-10-10', 2026, 4, 10, 'October', 'Saturday');

INSERT INTO dim_stores (name, city, region) VALUES
('Store Mumbai', 'Mumbai', 'West'),
('Store Delhi', 'Delhi', 'North');

INSERT INTO fact_sales (customer_key, product_key, date_key, store_key, qty, revenue) VALUES
(1, 1, 20261001, 1, 1, 999.99),
(1, 2, 20261001, 1, 2, 59.98),
(2, 3, 20261005, 2, 1, 49.99),
(3, 1, 20261010, 1, 1, 999.99);

-- OLAP query: Revenue by product category
SELECT p.category,
       SUM(f.revenue) AS total_revenue,
       SUM(f.qty) AS units_sold
FROM fact_sales f
JOIN dim_products p ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;

-- OLAP query: Revenue by customer segment and month
SELECT c.segment,
       d.month_name,
       SUM(f.revenue) AS revenue,
       COUNT(*) AS transactions
FROM fact_sales f
JOIN dim_customers c ON f.customer_key = c.customer_key
JOIN dim_date d ON f.date_key = d.date_key
GROUP BY c.segment, d.month_name
ORDER BY c.segment, revenue DESC;

-- OLAP query: Store performance
SELECT s.name AS store,
       s.region,
       SUM(f.revenue) AS revenue,
       SUM(f.qty) AS items_sold
FROM fact_sales f
JOIN dim_stores s ON f.store_key = s.store_key
GROUP BY s.name, s.region
ORDER BY revenue DESC;

-- === PRACTICE EXERCISES ===

-- Exercise 1: Fix bad naming
-- Rename these in your head (don't run — just practice):
-- tblProducts → products
-- UserEmail → user_email  (or just email)
-- CUST_ADDR → customer_address
-- fn → first_name
-- isActv → is_active

-- Exercise 2: Fix stringly typed table
CREATE TABLE meetings_bad (
    id          SERIAL,
    start_time  VARCHAR(30),
    duration    VARCHAR(10),
    is_virtual  VARCHAR(5)
);
-- Rewrite with correct types:
CREATE TABLE meetings (
    id          SERIAL PRIMARY KEY,
    start_time  TIMESTAMPTZ NOT NULL,
    duration    INTERVAL NOT NULL,
    is_virtual  BOOLEAN DEFAULT false
);

-- Exercise 3: Add COMMENT to your tables
COMMENT ON TABLE users IS 'Registered application users';
COMMENT ON COLUMN users.email IS 'Unique email address, used for login';
COMMENT ON COLUMN users.age IS 'Age in years, must be between 1 and 149';

-- Exercise 4: Write an OLAP query
-- Total revenue by store region:
SELECT s.region, SUM(f.revenue) AS revenue
FROM fact_sales f
JOIN dim_stores s ON f.store_key = s.store_key
GROUP BY s.region
ORDER BY revenue DESC;

-- Exercise 5: Identify the anti-pattern
-- What's wrong with this table?
-- CREATE TABLE settings (
--     user_id INT,
--     key     VARCHAR(50),
--     value   VARCHAR(255)
-- );
-- Answer: EAV pattern! Use proper typed columns instead.

-- === CLEANUP ===
-- DROP TABLE IF EXISTS fact_sales, dim_customers, dim_products, dim_date, dim_stores;
-- DROP TABLE IF EXISTS orders, users, events, events_bad, user_attributes_bad;
-- DROP TABLE IF EXISTS meetings, meetings_bad;

-- =============================================
-- Phase 3: Database Design — COMPLETE!
-- Next Phase: Phase 4 — DDL (Data Definition Language)
-- Next Class: CREATE TABLE, ALTER TABLE & DROP TABLE
-- =============================================
