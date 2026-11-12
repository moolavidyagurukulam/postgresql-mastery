-- =============================================
-- PostgreSQL Mastery: UPDATE, DELETE & UPSERT
-- Phase 5: DML | Classes 39-41
-- =============================================
-- Modifying, removing, and upserting data.
-- =============================================

-- === SETUP ===

CREATE TABLE products (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(100) UNIQUE NOT NULL,
    price      NUMERIC(10,2) CHECK (price > 0),
    stock      INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO products (name, price, stock) VALUES
('Laptop',     999.99, 10),
('Mouse',       29.99, 50),
('Keyboard',    49.99, 30),
('Monitor',    299.99, 15),
('Headphones',  79.99, 25),
('Webcam',      59.99, 20);

CREATE TABLE price_updates (
    product_name VARCHAR(100),
    new_price    NUMERIC(10,2)
);
INSERT INTO price_updates VALUES
('Laptop', 949.99), ('Mouse', 24.99), ('Webcam', 54.99);

-- === UPDATE — Basic ===

-- Single row
UPDATE products SET price = 949.99 WHERE name = 'Laptop';

-- Multiple columns
UPDATE products
SET price = 24.99, stock = 60, updated_at = NOW()
WHERE name = 'Mouse';

-- Expression-based update
UPDATE products
SET price = price * 0.90
WHERE stock > 20;
-- 10% discount on items with stock > 20

-- WARNING: no WHERE = ALL ROWS updated!
-- UPDATE products SET stock = 0;  -- DANGEROUS!

-- === UPDATE ... RETURNING ===

UPDATE products
SET price = price * 1.05
WHERE name = 'Monitor'
RETURNING id, name, price AS new_price;

-- Show old and new values
UPDATE products
SET stock = stock - 1
WHERE name = 'Laptop'
RETURNING name, stock AS new_stock, stock + 1 AS old_stock;

-- === UPDATE ... FROM (Join Update) ===

-- Reset prices first
UPDATE products SET price = 999.99 WHERE name = 'Laptop';
UPDATE products SET price = 29.99 WHERE name = 'Mouse';
UPDATE products SET price = 59.99 WHERE name = 'Webcam';

-- Update from another table
UPDATE products p
SET price = pu.new_price,
    updated_at = NOW()
FROM price_updates pu
WHERE p.name = pu.product_name
RETURNING p.name, p.price;

-- === DELETE — Basic ===

-- Delete specific row
DELETE FROM products WHERE name = 'Webcam';

-- Delete with condition
DELETE FROM products WHERE stock = 0;

-- DELETE ... RETURNING
DELETE FROM products
WHERE price < 30
RETURNING *;

-- WARNING: no WHERE = ALL ROWS deleted!
-- DELETE FROM products;  -- DANGEROUS!

-- === DELETE ... USING (Join Delete) ===

-- Re-insert test data
INSERT INTO products (name, price, stock) VALUES
('Webcam', 54.99, 20),
('Mouse', 24.99, 60)
ON CONFLICT (name) DO NOTHING;

CREATE TABLE blacklist (product_name VARCHAR(100));
INSERT INTO blacklist VALUES ('Webcam'), ('Headphones');

DELETE FROM products p
USING blacklist b
WHERE p.name = b.product_name
RETURNING p.name;

-- === DELETE with CTE (Delete and Archive) ===

CREATE TABLE products_archive (
    id          INT,
    name        VARCHAR(100),
    price       NUMERIC(10,2),
    archived_at TIMESTAMPTZ DEFAULT NOW()
);

-- Delete and archive atomically
WITH removed AS (
    DELETE FROM products
    WHERE stock < 20
    RETURNING id, name, price
)
INSERT INTO products_archive (id, name, price)
SELECT id, name, price
FROM removed;

SELECT * FROM products_archive;

-- === UPSERT: INSERT ... ON CONFLICT ===

-- Re-insert all products for upsert demos
INSERT INTO products (name, price, stock) VALUES
('Laptop',     999.99, 10),
('Mouse',       29.99, 50),
('Keyboard',    49.99, 30),
('Monitor',    299.99, 15),
('Headphones',  79.99, 25),
('Webcam',      59.99, 20)
ON CONFLICT (name) DO NOTHING;

-- === DO NOTHING — Skip Duplicates ===

INSERT INTO products (name, price, stock)
VALUES ('Laptop', 999.99, 5)
ON CONFLICT (name) DO NOTHING;
-- Laptop exists → silently skipped

-- Bulk insert, skip duplicates
INSERT INTO products (name, price, stock) VALUES
    ('Laptop',  999.99, 5),
    ('Tablet',  499.99, 8),
    ('Speaker', 149.99, 12)
ON CONFLICT (name) DO NOTHING;
-- INSERT 0 2  (Laptop skipped, Tablet+Speaker inserted)

-- === DO UPDATE — Update Existing Row ===

-- Replace price and stock on conflict
INSERT INTO products (name, price, stock)
VALUES ('Laptop', 899.99, 15)
ON CONFLICT (name) DO UPDATE
SET price = EXCLUDED.price,
    stock = EXCLUDED.stock,
    updated_at = NOW();

-- EXCLUDED = the row that WOULD have been inserted
-- EXCLUDED.price = 899.99, EXCLUDED.stock = 15
-- products.price = old value (current row in table)

-- Conditional upsert: only update if new price is lower
INSERT INTO products (name, price, stock)
VALUES ('Laptop', 799.99, 5)
ON CONFLICT (name) DO UPDATE
SET price = EXCLUDED.price,
    stock = products.stock + EXCLUDED.stock
WHERE EXCLUDED.price < products.price;

-- Accumulate stock on conflict
INSERT INTO products (name, price, stock)
VALUES ('Mouse', 29.99, 20)
ON CONFLICT (name) DO UPDATE
SET stock = products.stock + EXCLUDED.stock,
    updated_at = NOW()
RETURNING name, stock AS new_stock;

-- === UPSERT with RETURNING ===

INSERT INTO products (name, price, stock) VALUES
    ('Laptop', 849.99, 3),
    ('NewGadget', 199.99, 10)
ON CONFLICT (name) DO UPDATE
SET price = EXCLUDED.price,
    stock = products.stock + EXCLUDED.stock
RETURNING id, name, price, stock;

-- === COMMON ERRORS ===

-- Error 1: No matching constraint
-- INSERT INTO products (name, price) VALUES ('X', 9.99)
-- ON CONFLICT (price) DO NOTHING;
-- ERROR: no unique or exclusion constraint matching ON CONFLICT
-- Fix: price has no UNIQUE constraint

-- Error 2: Same row affected twice
-- INSERT INTO products (name, price) VALUES
-- ('X', 10), ('X', 20)
-- ON CONFLICT (name) DO UPDATE SET price = EXCLUDED.price;
-- ERROR: ON CONFLICT DO UPDATE cannot affect row a second time
-- Fix: remove duplicate values

-- === SAFETY CHECKLIST ===

-- 1. ALWAYS use WHERE with UPDATE/DELETE
-- 2. Test with SELECT first:
SELECT * FROM products WHERE stock < 20;
-- Then: DELETE FROM products WHERE stock < 20;

-- 3. Use RETURNING to confirm
-- 4. Wrap in transaction:
BEGIN;
  DELETE FROM products WHERE name = 'Speaker';
  -- Check... looks good
COMMIT;
-- or ROLLBACK; if wrong

-- 5. Back up before bulk operations:
CREATE TABLE products_backup AS SELECT * FROM products;

-- === PRACTICE EXERCISES ===

-- Exercise 1: 10% price increase with RETURNING
UPDATE products SET price = price * 1.10
RETURNING name, price AS new_price;

-- Exercise 2: UPDATE...FROM
UPDATE products p
SET price = pu.new_price
FROM price_updates pu
WHERE p.name = pu.product_name
RETURNING p.name, p.price;

-- Exercise 3: DELETE with RETURNING
DELETE FROM products WHERE stock = 0 RETURNING *;

-- Exercise 4: UPSERT DO NOTHING
INSERT INTO products (name, price, stock) VALUES
('Laptop', 999.99, 1),
('NewProduct', 39.99, 100)
ON CONFLICT (name) DO NOTHING;

-- Exercise 5: UPSERT DO UPDATE (accumulate stock)
INSERT INTO products (name, price, stock)
VALUES ('Mouse', 29.99, 25)
ON CONFLICT (name) DO UPDATE
SET stock = products.stock + EXCLUDED.stock
RETURNING name, stock;

-- Exercise 6: DELETE + Archive with CTE
WITH removed AS (
    DELETE FROM products WHERE name LIKE 'Batch%' RETURNING *
)
INSERT INTO products_archive (id, name, price) SELECT id, name, price FROM removed;

-- Exercise 7: Transaction safety
BEGIN;
  UPDATE products SET price = 0.01 WHERE name = 'Laptop';
  -- Oops, wrong price!
ROLLBACK;
SELECT price FROM products WHERE name = 'Laptop';  -- Original price!


-- =============================================
-- ANSWER KEY — UPDATE, DELETE & UPSERT SOLUTIONS
-- =============================================
-- 1. Give all products a 10% raise with RETURNING
-- Note: RETURNING displays updated values immediately.
UPDATE products
SET price = ROUND(price * 1.10, 2)
WHERE category = 'Electronics'
RETURNING id, name, price AS new_price;

-- 2. UPDATE FROM join syntax
-- Note: PostgreSQL UPDATE FROM allows joining a source table cleanly.
UPDATE products p
SET price = s.new_price
FROM price_staging s
WHERE p.sku = s.sku;

-- 3. DELETE with safety filter and RETURNING
-- Note: Always double-check WHERE clauses before executing DELETE.
DELETE FROM sessions
WHERE last_active < NOW() - INTERVAL '30 days'
RETURNING id, user_id;

-- 4. UPSERT: ON CONFLICT DO NOTHING
-- Note: Ignores unique constraint violations silently.
INSERT INTO tags (name)
VALUES ('postgresql'), ('database')
ON CONFLICT (name) DO NOTHING;

-- 5. UPSERT: ON CONFLICT DO UPDATE
-- Note: EXCLUDED represents the row proposed for insertion.
INSERT INTO inventory (sku, qty)
VALUES ('PROD-001', 50)
ON CONFLICT (sku) DO UPDATE
SET qty = inventory.qty + EXCLUDED.qty,
    updated_at = NOW();


-- === CLEANUP ===
-- DROP TABLE IF EXISTS products_backup, products_archive;
-- DROP TABLE IF EXISTS price_updates, blacklist, products;

-- =============================================
-- Next Class: COPY, CASE WHEN, COALESCE & NULLIF
-- =============================================
