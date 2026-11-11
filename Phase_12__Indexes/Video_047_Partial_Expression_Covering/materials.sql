-- =============================================
-- PostgreSQL Mastery: Partial, Expression & Covering
-- Phase 12: Indexes | Classes 97-99
-- =============================================
-- Partial indexes, expression indexes, covering
-- indexes with INCLUDE, unique partial indexes.
-- =============================================

-- === SETUP ===

CREATE TABLE IF NOT EXISTS orders (
    id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT,
    order_date  DATE,
    amount      NUMERIC(10,2),
    status      VARCHAR(20)
);

INSERT INTO orders (customer_id, order_date, amount, status)
SELECT
  (RANDOM() * 1000 + 1)::INT,
  '2023-01-01'::DATE + (RANDOM() * 730)::INT,
  ROUND((RANDOM() * 990 + 10)::NUMERIC, 2),
  (ARRAY['pending','shipped','delivered','cancelled'])[
    FLOOR(RANDOM() * 4 + 1)::INT
  ]
FROM generate_series(1, 100000)
WHERE NOT EXISTS (SELECT 1 FROM orders);

ANALYZE orders;

-- === PARTIAL INDEX ===

-- Full index: indexes ALL rows
CREATE INDEX idx_orders_status ON orders (status);

-- Partial index: indexes ONLY pending orders
CREATE INDEX idx_orders_pending ON orders (customer_id)
WHERE status = 'pending';

-- Query that matches the partial index condition
EXPLAIN SELECT * FROM orders
WHERE status = 'pending' AND customer_id = 42;
-- Uses idx_orders_pending

-- Query that does NOT match → cannot use partial index
EXPLAIN SELECT * FROM orders
WHERE status = 'shipped' AND customer_id = 42;
-- Uses idx_orders_status or Seq Scan

-- Size comparison
SELECT
  pg_size_pretty(pg_relation_size('idx_orders_status')) AS full_index,
  pg_size_pretty(pg_relation_size('idx_orders_pending')) AS partial_index;

-- More partial index examples:
-- Only recent orders
CREATE INDEX idx_orders_recent ON orders (customer_id, amount)
WHERE order_date >= '2024-01-01';

-- Only non-null values
-- CREATE INDEX idx_orders_manager ON orders (manager_id)
-- WHERE manager_id IS NOT NULL;

-- === UNIQUE PARTIAL INDEX ===

-- Enforce: one pending order per customer
CREATE UNIQUE INDEX idx_one_pending
ON orders (customer_id) WHERE status = 'pending';

-- If customer 42 already has a pending order:
-- INSERT INTO orders (customer_id, ..., status) VALUES (42, ..., 'pending');
-- ERROR: duplicate key value violates unique constraint

-- But customer 42 CAN have many delivered orders
-- (partial index only constrains pending rows)

-- Soft-delete pattern: unique on non-deleted rows
CREATE TABLE users (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      VARCHAR(200) NOT NULL,
    name       VARCHAR(100),
    deleted_at TIMESTAMP
);

INSERT INTO users (email, name) VALUES
('alice@example.com', 'Alice'),
('bob@example.com', 'Bob'),
('carol@example.com', 'Carol');

-- Email must be unique only for active (non-deleted) users
CREATE UNIQUE INDEX idx_users_active_email
ON users (email) WHERE deleted_at IS NULL;

-- Soft-delete Alice
UPDATE users SET deleted_at = NOW() WHERE email = 'alice@example.com';

-- Now we can insert a new Alice with the same email
INSERT INTO users (email, name) VALUES ('alice@example.com', 'Alice New');
-- Works! Old Alice is deleted, new one takes the email

-- === EXPRESSION INDEX ===

-- Case-insensitive email search
CREATE INDEX idx_users_email_lower ON users (LOWER(email));

-- Query MUST use the same expression
EXPLAIN SELECT * FROM users WHERE LOWER(email) = 'bob@example.com';
-- Index Scan using idx_users_email_lower

-- Without LOWER() in query → index NOT used
EXPLAIN SELECT * FROM users WHERE email = 'bob@example.com';
-- Seq Scan (expression doesn't match)

-- Date extraction index
CREATE INDEX idx_orders_year ON orders (EXTRACT(YEAR FROM order_date));

-- Year-based query uses the expression index
EXPLAIN SELECT * FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 2024;

-- Month extraction
CREATE INDEX idx_orders_month ON orders (EXTRACT(MONTH FROM order_date));

EXPLAIN SELECT COUNT(*) FROM orders
WHERE EXTRACT(MONTH FROM order_date) = 6;

-- JSON field extraction (for JSONB columns)
-- CREATE INDEX idx_events_type ON events ((data->>'type'));
-- WHERE data->>'type' = 'click' → uses this index

-- === EXPRESSION INDEX: IMMUTABILITY ===

-- Expression must be IMMUTABLE (same input → same output)
-- LOWER() is immutable ✓
-- NOW() is NOT immutable ✗
-- to_char() depends on locale (may not be immutable)

-- This would fail:
-- CREATE INDEX idx_bad ON orders (NOW() - order_date);
-- ERROR: functions in index must be marked IMMUTABLE

-- === COVERING INDEX (INCLUDE) ===

-- Regular index on customer_id
CREATE INDEX idx_orders_customer ON orders (customer_id);

-- Query needs customer_id + amount → visits table
EXPLAIN SELECT customer_id, amount FROM orders
WHERE customer_id = 42;
-- Index Scan (visits table to get amount)

-- Covering index: include amount in the index
CREATE INDEX idx_orders_cust_cover ON orders
(customer_id) INCLUDE (amount, order_date);

-- Now: Index Only Scan (no table visit!)
EXPLAIN SELECT customer_id, amount FROM orders
WHERE customer_id = 42;
-- Index Only Scan using idx_orders_cust_cover

-- INCLUDE vs adding to key columns:
-- (customer_id, amount) → amount is in the B-Tree key
--   → can search/sort by amount too
-- (customer_id) INCLUDE (amount) → amount stored in leaves only
--   → cannot search by amount, but index is smaller
--   → use INCLUDE when column is needed in SELECT, not WHERE

-- === COMBINING TECHNIQUES ===

-- Partial + Expression: case-insensitive search on active users
CREATE INDEX idx_active_email_lower ON users (LOWER(email))
WHERE deleted_at IS NULL;

-- Partial + Covering: pending orders with included columns
DROP INDEX IF EXISTS idx_orders_pending;
CREATE INDEX idx_pending_cover ON orders
(customer_id) INCLUDE (amount, order_date)
WHERE status = 'pending';

-- Query gets Index Only Scan on the partial covering index
EXPLAIN SELECT customer_id, amount, order_date
FROM orders
WHERE status = 'pending' AND customer_id = 42;

-- === INDEX ONLY SCAN REQUIREMENTS ===

-- Index Only Scan needs:
-- 1. All columns in SELECT are in the index (key + INCLUDE)
-- 2. All columns in WHERE are in the index
-- 3. Visibility Map shows pages are all-visible
--    (run VACUUM to update visibility map)

VACUUM orders;  -- updates visibility map

EXPLAIN SELECT customer_id, amount FROM orders
WHERE customer_id = 42;
-- After VACUUM: more likely to get Index Only Scan

-- === PRACTICE EXERCISES ===

-- Exercise 1: Partial index for shipped orders
CREATE INDEX idx_shipped ON orders (order_date)
WHERE status = 'shipped';

EXPLAIN SELECT * FROM orders
WHERE status = 'shipped' AND order_date > '2024-06-01';

-- Exercise 2: Expression index on UPPER
CREATE INDEX idx_users_name_upper ON users (UPPER(name));
EXPLAIN SELECT * FROM users WHERE UPPER(name) = 'BOB';

-- Exercise 3: Covering index
CREATE INDEX idx_orders_date_cover ON orders
(order_date) INCLUDE (customer_id, amount);

EXPLAIN SELECT order_date, customer_id, amount
FROM orders WHERE order_date = '2024-06-15';

-- Exercise 4: Unique partial
-- Already created: idx_one_pending (one pending per customer)

-- Exercise 5: Combined partial + covering
-- Already created: idx_pending_cover

-- Exercise 6: Compare index sizes
SELECT indexname, pg_size_pretty(pg_relation_size(indexname::regclass))
FROM pg_indexes WHERE tablename = 'orders'
ORDER BY pg_relation_size(indexname::regclass) DESC;

-- === CLEANUP ===
DROP INDEX IF EXISTS idx_orders_status, idx_orders_pending;
DROP INDEX IF EXISTS idx_orders_recent, idx_one_pending;
DROP INDEX IF EXISTS idx_orders_customer, idx_orders_cust_cover;
DROP INDEX IF EXISTS idx_pending_cover, idx_orders_year, idx_orders_month;
DROP INDEX IF EXISTS idx_shipped, idx_orders_date_cover;
-- DROP TABLE IF EXISTS users;
-- DROP TABLE IF EXISTS orders;

-- =============================================
-- Next Class: Multi-Column, When to Index & Bloat
-- =============================================
