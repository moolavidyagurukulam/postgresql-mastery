-- =============================================
-- PostgreSQL Mastery: INSERT — Adding Data to Tables
-- Phase 5: DML | Class 34
-- =============================================
-- Every INSERT variant: single, multi-row, SELECT,
-- RETURNING, DEFAULT VALUES, CTE.
-- =============================================

-- === SETUP ===

CREATE TABLE users (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(150) UNIQUE NOT NULL,
    age        INT CHECK (age >= 18),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- === SINGLE ROW INSERT ===

INSERT INTO users (name, email, age)
VALUES ('Ravi', 'ravi@ex.com', 28);

-- id and created_at filled automatically!
SELECT * FROM users;

-- Without column list (provide ALL values in order):
INSERT INTO users
VALUES (DEFAULT, 'Priya', 'priya@ex.com', 25, DEFAULT);
-- DEFAULT = use the column's default value

-- BEST PRACTICE: always list columns explicitly!

-- === MULTI-ROW INSERT ===

INSERT INTO users (name, email, age) VALUES
    ('Arjun', 'arjun@ex.com', 30),
    ('Meera', 'meera@ex.com', 22),
    ('Kiran', 'kiran@ex.com', 35),
    ('Anita', 'anita@ex.com', 27);
-- INSERT 0 4  (4 rows at once)

-- Why multi-row?
-- Single: 4 round trips to server → slow
-- Multi:  1 round trip → 10-100x faster for bulk inserts

SELECT * FROM users;

-- === INSERT ... RETURNING ===

-- Get back the inserted data (including auto-generated values!)
INSERT INTO users (name, email, age)
VALUES ('Deepak', 'deepak@ex.com', 29)
RETURNING *;

-- Return specific columns
INSERT INTO users (name, email, age)
VALUES ('Sonia', 'sonia@ex.com', 31)
RETURNING id, name;

-- Return computed values
INSERT INTO users (name, email, age)
VALUES ('Vikram', 'vikram@ex.com', 26)
RETURNING id, name, created_at::DATE AS join_date;

-- Multi-row with RETURNING
INSERT INTO users (name, email, age) VALUES
    ('Neha', 'neha@ex.com', 24),
    ('Raj', 'raj@ex.com', 33)
RETURNING id, email;

-- === INSERT ... SELECT ===

-- Copy data from one table to another
CREATE TABLE users_archive (
    id          INT,
    name        VARCHAR(100),
    email       VARCHAR(150),
    archived_at TIMESTAMPTZ DEFAULT NOW()
);

-- Copy users aged 30+ into archive
INSERT INTO users_archive (id, name, email)
SELECT id, name, email
FROM users
WHERE age >= 30;

SELECT * FROM users_archive;

-- INSERT...SELECT with transformation
INSERT INTO users_archive (id, name, email)
SELECT id, UPPER(name), email
FROM users
WHERE created_at::DATE = CURRENT_DATE
  AND id NOT IN (SELECT id FROM users_archive);

-- === DEFAULT VALUES ===

-- Insert a row using ALL defaults (no data provided)
CREATE TABLE audit_log (
    id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    action    VARCHAR(50) DEFAULT 'unknown',
    details   TEXT DEFAULT '',
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO audit_log DEFAULT VALUES;
SELECT * FROM audit_log;
-- id=1, action='unknown', details='', logged_at=now

-- Partial columns: provide only what you have
INSERT INTO audit_log (action) VALUES ('user_login');
INSERT INTO audit_log (action, details) VALUES ('page_view', '/dashboard');
SELECT * FROM audit_log;

-- === INSERT WITH CTE ===

-- CTE to generate test data
WITH new_users AS (
    SELECT 'Batch User ' || n AS name,
           'batch' || n || '@ex.com' AS email,
           20 + n AS age
    FROM generate_series(1, 5) AS n
)
INSERT INTO users (name, email, age)
SELECT name, email, age
FROM new_users
RETURNING id, name, email;

-- Writable CTE: delete + archive in ONE statement
WITH deleted AS (
    DELETE FROM users
    WHERE name LIKE 'Batch%'
    RETURNING *
)
INSERT INTO users_archive (id, name, email)
SELECT id, name, email
FROM deleted;

SELECT * FROM users_archive;

-- === ON CONFLICT PREVIEW (UPSERT) ===

-- Handle duplicate key gracefully (full coverage in later class)

-- DO NOTHING: skip if conflict
INSERT INTO users (name, email, age)
VALUES ('Ravi', 'ravi@ex.com', 28)
ON CONFLICT (email) DO NOTHING;
-- No error! Row simply not inserted.

-- DO UPDATE: update existing row
INSERT INTO users (name, email, age)
VALUES ('Ravi Kumar', 'ravi@ex.com', 29)
ON CONFLICT (email) DO UPDATE
SET name = EXCLUDED.name, age = EXCLUDED.age;
-- EXCLUDED = the rejected row's values

SELECT * FROM users WHERE email = 'ravi@ex.com';
-- name is now 'Ravi Kumar', age is 29

-- === COMMON ERRORS ===

-- Error 1: NOT NULL violation
-- INSERT INTO users (email, age) VALUES ('x@ex.com', 25);
-- ERROR: null value in column "name" violates not-null constraint
-- Fix: provide the name column

-- Error 2: UNIQUE violation
-- INSERT INTO users (name, email, age) VALUES ('X', 'ravi@ex.com', 20);
-- ERROR: duplicate key value violates unique constraint
-- Fix: different email, or use ON CONFLICT

-- Error 3: CHECK violation
-- INSERT INTO users (name, email, age) VALUES ('Kid', 'kid@ex.com', 15);
-- ERROR: new row violates check constraint "users_age_check"
-- Fix: age must be >= 18

-- Error 4: FK violation (if FK exists)
-- INSERT INTO orders (customer_id, product) VALUES (999, 'Laptop');
-- ERROR: violates foreign key constraint
-- Fix: customer_id must exist in customers table

-- === TRANSACTION SAFETY ===

-- Wrap bulk inserts in a transaction
BEGIN;
  INSERT INTO users (name, email, age) VALUES ('Txn1', 'txn1@ex.com', 20);
  INSERT INTO users (name, email, age) VALUES ('Txn2', 'txn2@ex.com', 21);
  INSERT INTO users (name, email, age) VALUES ('Txn3', 'txn3@ex.com', 22);
COMMIT;
-- All 3 succeed or all 3 fail (atomic)

-- === PRACTICE EXERCISES ===

-- Exercise 1: Single insert with RETURNING
CREATE TABLE products (
    id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    price NUMERIC(10,2) CHECK (price > 0),
    stock INT DEFAULT 0
);

INSERT INTO products (name, price, stock)
VALUES ('Laptop', 999.99, 10)
RETURNING *;

-- Exercise 2: Multi-row insert
INSERT INTO products (name, price, stock) VALUES
('Mouse', 29.99, 50),
('Keyboard', 49.99, 30),
('Monitor', 299.99, 15),
('Headphones', 79.99, 25),
('Webcam', 59.99, 20);

-- Exercise 3: INSERT...SELECT
CREATE TABLE expensive_products (
    id    INT,
    name  VARCHAR(100),
    price NUMERIC(10,2)
);

INSERT INTO expensive_products (id, name, price)
SELECT id, name, price
FROM products
WHERE price > 100;

SELECT * FROM expensive_products;

-- Exercise 4: CTE insert with generate_series
WITH test_products AS (
    SELECT 'Test Product ' || n AS name,
           (RANDOM() * 100 + 1)::NUMERIC(10,2) AS price,
           (RANDOM() * 50)::INT AS stock
    FROM generate_series(1, 10) AS n
)
INSERT INTO products (name, price, stock)
SELECT name, price, stock
FROM test_products
RETURNING id, name, price;

-- Exercise 5: DEFAULT VALUES
INSERT INTO audit_log DEFAULT VALUES;
INSERT INTO audit_log (action) VALUES ('test_insert');
SELECT * FROM audit_log;

-- Exercise 6: Try constraint violations
-- INSERT INTO products (name, price) VALUES ('Free', 0);       -- CHECK fail
-- INSERT INTO products (name, price) VALUES (NULL, 9.99);      -- NOT NULL fail
-- INSERT INTO users (name, email, age) VALUES ('X', 'ravi@ex.com', 20);  -- UNIQUE fail


-- =============================================
-- ANSWER KEY — INSERT SOLUTIONS
-- =============================================
-- 1. Basic INSERT with explicit column list
-- Note: Always specify column list so table alterations don't break queries.
INSERT INTO employees (first_name, last_name, email, hire_date, salary)
VALUES ('Ravi', 'Kumar', 'ravi@company.com', '2026-01-15', 75000.00);

-- 2. Multi-row INSERT in a single statement
-- Note: Multi-row inserts run in a single transaction round-trip.
INSERT INTO products (name, price, stock)
VALUES
  ('Mechanical Keyboard', 89.99, 50),
  ('Wireless Mouse', 45.50, 120),
  ('USB-C Dock', 129.00, 30);

-- 3. INSERT ... RETURNING clause
-- Note: RETURNING avoids a secondary SELECT query for auto-generated IDs.
INSERT INTO orders (customer_id, total)
VALUES (101, 249.99)
RETURNING id, created_at, total;

-- 4. INSERT INTO ... SELECT from another table
-- Note: Copies query output directly into the target table.
INSERT INTO high_value_customers (customer_id, total_spent)
SELECT customer_id, SUM(total)
FROM orders GROUP BY customer_id HAVING SUM(total) > 5000;

-- 5. DEFAULT values in INSERT
-- Note: Explicitly requests the column default expression.
INSERT INTO tasks (title, status)
VALUES ('Audit Security Logs', DEFAULT);


-- === CLEANUP ===
-- DROP TABLE IF EXISTS expensive_products, products, audit_log;
-- DROP TABLE IF EXISTS users_archive, users;

-- =============================================
-- Next Class: SELECT, WHERE, ORDER BY & LIMIT
-- =============================================
