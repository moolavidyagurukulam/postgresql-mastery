-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- hstore — Key-Value Data Type (Class 228)
-- Phase 26: Extensions
-- ============================================================

-- ============================================================
-- INSTALLATION
-- ============================================================

CREATE EXTENSION hstore;
-- \dx hstore

-- ============================================================
-- 1. BASIC SYNTAX
-- ============================================================

-- hstore literal:
SELECT 'color => red, size => large'::hstore;

-- Keys and values are always text:
SELECT 'price => 29.99, stock => 100'::hstore;

-- NULL values:
SELECT 'key => NULL'::hstore;

-- ============================================================
-- 2. CREATE TABLE WITH HSTORE
-- ============================================================

CREATE TABLE products (
    id serial PRIMARY KEY,
    name text NOT NULL,
    category text,
    attributes hstore
);

INSERT INTO products (name, category, attributes) VALUES
('Cotton T-Shirt', 'Clothing',
  'color => blue, size => L, material => cotton'),
('Running Shoes', 'Footwear',
  'color => black, size => 10, brand => Nike'),
('Laptop Pro', 'Electronics',
  'ram => 16GB, storage => 512GB, cpu => i7'),
('Wireless Mouse', 'Electronics',
  'color => white, dpi => 1600, wireless => true');

-- ============================================================
-- 3. ACCESSING VALUES
-- ============================================================

-- Get value by key:
SELECT name, attributes -> 'color' AS color
FROM products;

-- Check if key exists:
SELECT name FROM products WHERE attributes ? 'color';

-- Any key exists:
SELECT name FROM products
WHERE attributes ?| ARRAY['ram', 'cpu'];

-- All keys exist:
SELECT name FROM products
WHERE attributes ?& ARRAY['color', 'size'];

-- ============================================================
-- 4. FILTERING
-- ============================================================

-- By value:
SELECT name FROM products
WHERE attributes -> 'color' = 'blue';

-- Contains key-value pair:
SELECT name FROM products
WHERE attributes @> 'color => black';

-- Contains multiple pairs:
SELECT name FROM products
WHERE attributes @> 'color => blue, size => L';

-- ============================================================
-- 5. MODIFYING DATA
-- ============================================================

-- Add/update key with ||:
UPDATE products
SET attributes = attributes || 'weight => 200g'
WHERE name = 'Cotton T-Shirt';

-- Update existing key:
UPDATE products
SET attributes = attributes || 'color => red'
WHERE name = 'Cotton T-Shirt';

-- Delete a key:
UPDATE products
SET attributes = delete(attributes, 'weight')
WHERE name = 'Cotton T-Shirt';

-- Delete with - operator:
UPDATE products
SET attributes = attributes - 'dpi'
WHERE name = 'Wireless Mouse';

-- Delete multiple keys:
UPDATE products
SET attributes = delete(attributes, ARRAY['weight', 'material'])
WHERE name = 'Cotton T-Shirt';

-- ============================================================
-- 6. USEFUL FUNCTIONS
-- ============================================================

-- All keys as array:
SELECT akeys(attributes) FROM products WHERE name = 'Laptop Pro';

-- All values as array:
SELECT avals(attributes) FROM products WHERE name = 'Laptop Pro';

-- Expand to rows:
SELECT (each(attributes)).* FROM products WHERE name = 'Laptop Pro';

-- Convert to JSON:
SELECT hstore_to_json(attributes) FROM products WHERE name = 'Laptop Pro';

-- Count key-value pairs:
SELECT name, array_length(akeys(attributes), 1) AS num_attrs
FROM products;

-- All unique keys across all rows:
SELECT DISTINCT skeys(attributes) AS key FROM products ORDER BY key;

-- ============================================================
-- 7. CREATING HSTORE VALUES
-- ============================================================

-- From two arrays:
SELECT hstore(
    ARRAY['color', 'size', 'weight'],
    ARRAY['red', 'M', '150g']
);

-- From key-value array:
SELECT hstore(ARRAY[['color', 'red'], ['size', 'M']]);

-- ============================================================
-- 8. INDEXING
-- ============================================================

-- GIN index (supports @>, ?, ?|, ?&):
CREATE INDEX idx_products_attrs ON products USING gin (attributes);

-- Expression index on specific key:
CREATE INDEX idx_products_color ON products ((attributes -> 'color'));

-- ============================================================
-- 9. USE CASE: USER PREFERENCES
-- ============================================================

CREATE TABLE user_settings (
    user_id int PRIMARY KEY,
    preferences hstore DEFAULT ''::hstore
);

INSERT INTO user_settings VALUES
(1, 'theme => dark, lang => en, notifications => on'),
(2, 'theme => light, lang => fr, font_size => 16'),
(3, 'theme => dark, lang => es, timezone => UTC');

-- Get preference:
SELECT preferences -> 'theme' FROM user_settings WHERE user_id = 1;

-- Update preference:
UPDATE user_settings
SET preferences = preferences || 'font_size => 14'
WHERE user_id = 1;

-- Find users by preference:
SELECT user_id FROM user_settings
WHERE preferences @> 'theme => dark';

-- ============================================================
-- 10. USE CASE: TAGS
-- ============================================================

CREATE TABLE articles (
    id serial PRIMARY KEY,
    title text NOT NULL,
    tags hstore
);

INSERT INTO articles (title, tags) VALUES
('PostgreSQL Tips', 'database => primary, sql => secondary'),
('Docker Guide', 'devops => primary, containers => primary'),
('Full-Stack App', 'database => secondary, web => primary');

-- Find by tag:
SELECT title FROM articles WHERE tags ? 'database';

-- Find by tag + value:
SELECT title FROM articles WHERE tags @> 'database => primary';

-- All unique tags:
SELECT DISTINCT skeys(tags) AS tag FROM articles ORDER BY tag;

-- ============================================================
-- OPERATORS REFERENCE
-- ============================================================

-- ->  : get value by key
-- ?   : key exists?
-- ?|  : any key exists?
-- ?&  : all keys exist?
-- @>  : contains pairs?
-- <@  : contained by?
-- ||  : merge/update
-- -   : remove key(s)

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a table with an hstore column. Insert 5 rows
--    with different key-value pairs.

-- 2. Query for rows containing a specific key.
--    Query for rows containing a specific key-value pair.

-- 3. Add a new key to all rows using ||.
--    Delete a key from specific rows using delete().

-- 4. Create a GIN index on the hstore column.
--    Use EXPLAIN to verify it is used.

-- 5. Use each() to expand all attributes into rows.
--    Use hstore_to_json() to convert to JSON.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TABLE IF EXISTS products;
-- DROP TABLE IF EXISTS user_settings;
-- DROP TABLE IF EXISTS articles;
-- DROP EXTENSION IF EXISTS hstore;
