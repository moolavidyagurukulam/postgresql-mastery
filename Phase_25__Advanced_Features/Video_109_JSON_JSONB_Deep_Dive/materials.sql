-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- JSON & JSONB — Deep Dive (Class 215)
-- Phase 25: Advanced Features
-- ============================================================

-- ============================================================
-- 1. json vs jsonb
-- ============================================================

-- json preserves exact text:
SELECT '{"name": "Alice",  "name": "Bob"}'::json;
-- {"name": "Alice",  "name": "Bob"}

-- jsonb: strips whitespace, keeps last duplicate:
SELECT '{"name": "Alice",  "name": "Bob"}'::jsonb;
-- {"name": "Bob"}

-- jsonb does not preserve key order:
SELECT '{"z": 1, "a": 2, "m": 3}'::jsonb;
-- {"a": 2, "m": 3, "z": 1}

-- ============================================================
-- 2. SAMPLE TABLE
-- ============================================================

CREATE TABLE products (
    id serial PRIMARY KEY,
    name text NOT NULL,
    category text NOT NULL,
    attrs jsonb NOT NULL DEFAULT '{}'
);

INSERT INTO products (name, category, attrs) VALUES
('Laptop Pro', 'electronics',
 '{"brand": "TechCo", "cpu": "i7", "ram_gb": 16,
  "storage": "512GB SSD", "colors": ["silver", "black"]}'),
('Running Shoes', 'sports',
 '{"brand": "SportX", "size": 10, "waterproof": true,
  "colors": ["red", "blue", "white"]}'),
('Coffee Maker', 'kitchen',
 '{"brand": "BrewCo", "capacity_cups": 12,
  "features": ["timer", "auto-shutoff", "grinder"]}'),
('Headphones', 'electronics',
 '{"brand": "AudioMax", "type": "over-ear",
  "wireless": true, "battery_hours": 30}');

-- ============================================================
-- 3. EXTRACTION OPERATORS
-- ============================================================

-- -> returns jsonb (quoted strings):
SELECT name, attrs->'brand' AS brand_jsonb FROM products;

-- ->> returns text (unquoted):
SELECT name, attrs->>'brand' AS brand_text FROM products;

-- -> with integer for arrays (0-based):
SELECT name, attrs->'colors'->0 AS first_color
FROM products WHERE category = 'electronics';

-- #> path extraction (returns jsonb):
SELECT '{"a": {"b": {"c": 42}}}'::jsonb #> '{a,b,c}';
-- 42

-- #>> path extraction (returns text):
SELECT '{"a": {"b": {"c": 42}}}'::jsonb #>> '{a,b,c}';
-- 42 (as text)

-- ============================================================
-- 4. CONTAINMENT OPERATORS
-- ============================================================

-- @> contains:
SELECT name FROM products
WHERE attrs @> '{"brand": "TechCo"}';

-- Check boolean:
SELECT name FROM products
WHERE attrs @> '{"wireless": true}';

-- Array contains element:
SELECT name FROM products
WHERE attrs @> '{"colors": ["red"]}';

-- <@ is contained by:
SELECT '{"a": 1}'::jsonb <@ '{"a": 1, "b": 2}'::jsonb;
-- t

-- ============================================================
-- 5. EXISTENCE OPERATORS
-- ============================================================

-- ? key exists:
SELECT name FROM products WHERE attrs ? 'wireless';

-- ?| ANY key exists:
SELECT name FROM products
WHERE attrs ?| array['wireless', 'waterproof'];

-- ?& ALL keys exist:
SELECT name FROM products
WHERE attrs ?& array['brand', 'cpu', 'ram_gb'];

-- ============================================================
-- 6. CREATION FUNCTIONS
-- ============================================================

-- Build an object:
SELECT jsonb_build_object(
    'name', 'Alice', 'age', 30, 'active', true);

-- Build an array:
SELECT jsonb_build_array(1, 'two', true, null);

-- Aggregate rows into array:
SELECT jsonb_agg(
    jsonb_build_object('name', name, 'category', category)
) FROM products;

-- Convert row to jsonb:
SELECT to_jsonb(p) FROM products p WHERE id = 1;

-- ============================================================
-- 7. EXPANDING FUNCTIONS
-- ============================================================

-- jsonb_each: object → key-value rows:
SELECT key, value
FROM products, jsonb_each(attrs)
WHERE name = 'Headphones';

-- jsonb_each_text: values as text:
SELECT key, value
FROM products, jsonb_each_text(attrs)
WHERE name = 'Headphones';

-- jsonb_array_elements: array → rows:
SELECT name, color
FROM products,
     jsonb_array_elements_text(attrs->'colors') AS color
WHERE attrs ? 'colors';

-- ============================================================
-- 8. INSPECTION FUNCTIONS
-- ============================================================

-- Get top-level keys:
SELECT jsonb_object_keys(attrs)
FROM products WHERE name = 'Laptop Pro';

-- Check value type:
SELECT jsonb_typeof(attrs->'ram_gb') FROM products
WHERE name = 'Laptop Pro';
-- number

-- Pretty print:
SELECT jsonb_pretty(attrs) FROM products
WHERE name = 'Laptop Pro';

-- ============================================================
-- 9. FILTERING WITH JSONB
-- ============================================================

-- By text value:
SELECT name FROM products WHERE attrs->>'brand' = 'TechCo';

-- By numeric value (must cast):
SELECT name FROM products
WHERE (attrs->>'ram_gb')::int >= 16;

-- By containment (GIN-indexable, fastest):
SELECT name FROM products
WHERE attrs @> '{"brand": "TechCo", "cpu": "i7"}';

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create the products table and insert the sample data.
--    Query all electronics products using attrs->>'category'.

-- 2. Extract each product's brand as text.
--    Sort results alphabetically by brand.

-- 3. Find all products that have a 'colors' key.
--    Then expand the colors array into individual rows.

-- 4. Use jsonb_build_object to create a JSON API response
--    that includes product name, category, and brand.

-- 5. Use containment (@>) to find products where
--    wireless is true AND brand is "AudioMax".

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TABLE IF EXISTS products;
