-- =============================================
-- PostgreSQL Mastery: Hash & GIN Indexes
-- Phase 12: Indexes | Classes 92-93
-- =============================================
-- Hash indexes for equality, GIN for arrays,
-- JSONB, and full-text search.
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

-- === HASH INDEX ===

-- Hash index: equality only, smaller than B-Tree
CREATE INDEX idx_orders_status_hash ON orders USING hash (status);

-- Equality works with Hash
EXPLAIN SELECT * FROM orders WHERE status = 'shipped';
-- Index Scan using idx_orders_status_hash

-- Range DOES NOT work with Hash
EXPLAIN SELECT * FROM orders WHERE status > 'p';
-- Falls back to Seq Scan (Hash can't do ranges)

-- Compare with B-Tree on same column
CREATE INDEX idx_orders_status_btree ON orders (status);

-- Both handle equality:
EXPLAIN SELECT * FROM orders WHERE status = 'shipped';
-- May use either — planner picks the best one

-- Size comparison
SELECT
  pg_size_pretty(pg_relation_size('idx_orders_status_hash')) AS hash_size,
  pg_size_pretty(pg_relation_size('idx_orders_status_btree')) AS btree_size;
-- Hash is often smaller

-- Clean up B-Tree duplicate
DROP INDEX idx_orders_status_btree;

-- === WHEN TO USE HASH ===

-- Good: column only searched with =, want smaller index
-- Examples: session tokens, UUIDs, email exact match

-- Bad: column ever used with <, >, BETWEEN, ORDER BY
-- Use B-Tree instead (it handles = just fine too)

-- === GIN INDEX ON ARRAYS ===

CREATE TABLE products (
    id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  VARCHAR(100),
    price NUMERIC(10,2),
    tags  TEXT[]
);

INSERT INTO products (name, price, tags) VALUES
('Laptop',     999.99, ARRAY['electronics','portable','computing']),
('Phone',      699.99, ARRAY['electronics','mobile','portable']),
('Desk',       299.99, ARRAY['furniture','office']),
('Chair',      449.99, ARRAY['furniture','office','ergonomic']),
('Monitor',    399.99, ARRAY['electronics','display','office']),
('Keyboard',    89.99, ARRAY['electronics','input','office']),
('Headphones', 149.99, ARRAY['electronics','audio','portable']),
('Bookshelf',  199.99, ARRAY['furniture','storage']),
('Tablet',     549.99, ARRAY['electronics','portable','mobile']),
('Webcam',      79.99, ARRAY['electronics','video','office']);

-- Without GIN: Seq Scan on every array search
EXPLAIN SELECT name FROM products WHERE tags @> ARRAY['portable'];

-- Create GIN index
CREATE INDEX idx_products_tags ON products USING gin (tags);

-- With GIN: Bitmap Index Scan
EXPLAIN SELECT name FROM products WHERE tags @> ARRAY['portable'];

-- Contains: @> operator
SELECT name, tags FROM products WHERE tags @> ARRAY['portable'];

-- Contains multiple tags
SELECT name FROM products WHERE tags @> ARRAY['electronics','portable'];

-- Overlap: && operator (has ANY of these tags)
SELECT name FROM products WHERE tags && ARRAY['mobile','ergonomic'];

-- === GIN INDEX ON JSONB ===

CREATE TABLE events (
    id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    data JSONB
);

INSERT INTO events (data) VALUES
('{"type":"click","page":"/home","user_id":1,"device":"mobile"}'),
('{"type":"view","page":"/products","user_id":2,"device":"desktop"}'),
('{"type":"click","page":"/cart","user_id":1,"device":"mobile"}'),
('{"type":"purchase","page":"/checkout","user_id":3,"amount":99.99}'),
('{"type":"view","page":"/home","user_id":2,"device":"tablet"}');

-- Default GIN: indexes all keys and values
CREATE INDEX idx_events_data ON events USING gin (data);

-- Containment: @> (most common JSONB search)
SELECT * FROM events WHERE data @> '{"type":"click"}';
SELECT * FROM events WHERE data @> '{"user_id":1,"type":"click"}';

-- Key exists: ? operator
SELECT * FROM events WHERE data ? 'amount';

-- Any key exists: ?| operator
SELECT * FROM events WHERE data ?| ARRAY['amount','device'];

-- All keys exist: ?& operator
SELECT * FROM events WHERE data ?& ARRAY['type','page','user_id'];

-- === jsonb_ops vs jsonb_path_ops ===

-- Default: jsonb_ops — indexes keys AND values
-- Supports: @>, ?, ?|, ?&
-- Larger index

-- Alternative: jsonb_path_ops — indexes paths only
-- Supports: ONLY @> (containment)
-- Smaller and faster for @> queries

DROP INDEX idx_events_data;
CREATE INDEX idx_events_data_path ON events USING gin (data jsonb_path_ops);

-- Only @> works with jsonb_path_ops
SELECT * FROM events WHERE data @> '{"type":"click"}';

-- ? does NOT work with jsonb_path_ops
-- SELECT * FROM events WHERE data ? 'amount';
-- Falls back to Seq Scan!

-- === GIN FOR FULL-TEXT SEARCH ===

CREATE TABLE articles (
    id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title   TEXT,
    body    TEXT,
    search  TSVECTOR
);

INSERT INTO articles (title, body, search) VALUES
('PostgreSQL Indexes',
 'B-Tree is the default index type in PostgreSQL',
 to_tsvector('english', 'B-Tree is the default index type in PostgreSQL')),
('GIN Deep Dive',
 'GIN indexes are used for arrays and JSONB',
 to_tsvector('english', 'GIN indexes are used for arrays and JSONB')),
('Query Optimization',
 'Use EXPLAIN to understand query plans and index usage',
 to_tsvector('english', 'Use EXPLAIN to understand query plans and index usage'));

-- GIN index on tsvector column
CREATE INDEX idx_articles_search ON articles USING gin (search);

-- Full-text search with @@ operator
SELECT title FROM articles WHERE search @@ to_tsquery('index');
SELECT title FROM articles WHERE search @@ to_tsquery('index & default');
SELECT title FROM articles WHERE search @@ to_tsquery('array | jsonb');

-- Without a tsvector column (computed on the fly):
-- CREATE INDEX idx_articles_body_gin
--   ON articles USING gin (to_tsvector('english', body));
-- SELECT * FROM articles
--   WHERE to_tsvector('english', body) @@ to_tsquery('index');

-- === GIN TRADEOFFS ===

-- Slow to build: decomposes every value into elements
-- Larger than B-Tree for same column
-- Write overhead: every INSERT updates many index entries

-- fastupdate option: batches pending updates
-- CREATE INDEX idx_fast ON products USING gin (tags) WITH (fastupdate = on);
-- Better write performance, slightly slower searches until batch applied

-- === COMPARE INDEX SIZES ===

SELECT
  indexname,
  pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_indexes
WHERE tablename IN ('orders', 'products', 'events', 'articles')
ORDER BY pg_relation_size(indexname::regclass) DESC;

-- === COMMON ERRORS ===

-- ERROR: operator @> not supported for B-Tree
-- CREATE INDEX idx_bad ON products (tags);
-- SELECT * FROM products WHERE tags @> ARRAY['portable'];
-- → Seq Scan! B-Tree can't search inside arrays
-- Fix: CREATE INDEX ... USING gin (tags);

-- ERROR: operator ? not supported for jsonb_path_ops
-- Use default gin(data) if you need ? operator
-- Use gin(data jsonb_path_ops) if you only need @>

-- === PRACTICE EXERCISES ===

-- Exercise 1: Hash index on customer_id
CREATE INDEX idx_orders_cust_hash ON orders USING hash (customer_id);
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;

-- Exercise 2: Array containment search
SELECT name FROM products WHERE tags @> ARRAY['office'];
SELECT name FROM products WHERE tags && ARRAY['audio','video'];

-- Exercise 3: JSONB search
SELECT data->>'type' AS event_type, data->>'page' AS page
FROM events WHERE data @> '{"device":"mobile"}';

-- Exercise 4: Full-text search
SELECT title FROM articles
WHERE search @@ to_tsquery('english', 'query & plan');

-- Exercise 5: Compare GIN operator classes
-- Try @> with jsonb_path_ops (works)
-- Try ? with jsonb_path_ops (Seq Scan)

-- Exercise 6: Check index sizes
SELECT indexname, pg_size_pretty(pg_relation_size(indexname::regclass))
FROM pg_indexes WHERE schemaname = 'public';

-- === CLEANUP ===
DROP INDEX IF EXISTS idx_orders_status_hash, idx_orders_cust_hash;
-- DROP TABLE IF EXISTS products, events, articles;
-- DROP TABLE IF EXISTS orders;

-- =============================================
-- Next Class: GiST, BRIN & SP-GiST Indexes
-- =============================================
