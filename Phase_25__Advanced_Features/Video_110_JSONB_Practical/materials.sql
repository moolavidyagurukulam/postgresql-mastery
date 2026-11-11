-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- JSONB Practical — Modify, Index & Patterns (Class 216)
-- Phase 25: Advanced Features
-- ============================================================

-- ============================================================
-- 1. MODIFICATION — MERGE (||)
-- ============================================================

-- Add a new key:
UPDATE products
SET attrs = attrs || '{"warranty_years": 2}'
WHERE name = 'Laptop Pro';

-- Update an existing key:
UPDATE products
SET attrs = attrs || '{"ram_gb": 32}'
WHERE name = 'Laptop Pro';

-- Merge two objects:
SELECT '{"a": 1, "b": 2}'::jsonb ||
       '{"b": 99, "c": 3}'::jsonb;
-- {"a": 1, "b": 99, "c": 3}

-- ============================================================
-- 2. MODIFICATION — REMOVE (-)
-- ============================================================

-- Remove a key:
UPDATE products
SET attrs = attrs - 'warranty_years'
WHERE name = 'Laptop Pro';

-- Remove multiple keys:
SELECT '{"a": 1, "b": 2, "c": 3}'::jsonb - array['a', 'c'];
-- {"b": 2}

-- Remove array element by index:
SELECT '["red", "blue", "green"]'::jsonb - 1;
-- ["red", "green"]

-- Remove nested key with #-:
SELECT '{"a": {"b": 1, "c": 2}}'::jsonb #- '{a,b}';
-- {"a": {"c": 2}}

-- ============================================================
-- 3. MODIFICATION — jsonb_set
-- ============================================================

-- Update nested value:
SELECT jsonb_set(
    '{"server": {"host": "old.com", "port": 5432}}'::jsonb,
    '{server,host}',
    '"new.com"'::jsonb
);

-- Add new nested key:
SELECT jsonb_set(
    '{"server": {"host": "new.com"}}'::jsonb,
    '{server,port}',
    '8080'::jsonb,
    true  -- create_if_missing
);

-- Update in table:
UPDATE products
SET attrs = jsonb_set(attrs, '{brand}', '"TechCo Pro"')
WHERE name = 'Laptop Pro';

-- ============================================================
-- 4. MODIFICATION — ARRAYS
-- ============================================================

-- Append to array:
UPDATE products
SET attrs = jsonb_set(
    attrs, '{colors}',
    (attrs->'colors') || '"gold"'::jsonb
)
WHERE name = 'Laptop Pro';

-- Insert at position:
SELECT jsonb_insert(
    '["a", "b", "d"]'::jsonb,
    '{2}', '"c"'::jsonb);
-- ["a", "b", "c", "d"]

-- Strip null values:
SELECT jsonb_strip_nulls('{"a": 1, "b": null, "c": 3}'::jsonb);
-- {"a": 1, "c": 3}

-- ============================================================
-- 5. GIN INDEX — DEFAULT (jsonb_ops)
-- ============================================================

-- Supports: @>, ?, ?|, ?&
CREATE INDEX idx_products_attrs
    ON products USING GIN (attrs);

-- Uses index:
SELECT name FROM products
WHERE attrs @> '{"brand": "TechCo"}';

SELECT name FROM products
WHERE attrs ? 'wireless';

-- ============================================================
-- 6. GIN INDEX — jsonb_path_ops
-- ============================================================

-- Only supports: @> (but smaller and sometimes faster)
CREATE INDEX idx_products_attrs_path
    ON products USING GIN (attrs jsonb_path_ops);

-- ============================================================
-- 7. EXPRESSION INDEX
-- ============================================================

-- B-tree on specific key:
CREATE INDEX idx_products_brand
    ON products ((attrs->>'brand'));

-- Numeric expression index with partial:
CREATE INDEX idx_products_ram
    ON products (((attrs->>'ram_gb')::int))
    WHERE attrs ? 'ram_gb';

-- ============================================================
-- 8. PATTERN: APPLICATION SETTINGS
-- ============================================================

CREATE TABLE user_settings (
    user_id int PRIMARY KEY,
    settings jsonb NOT NULL DEFAULT '{
        "theme": "light",
        "language": "en",
        "notifications": true,
        "items_per_page": 25
    }'
);

INSERT INTO user_settings (user_id) VALUES (1);

-- Update one setting:
UPDATE user_settings
SET settings = settings || '{"theme": "dark"}'
WHERE user_id = 1;

-- Read with fallback:
SELECT coalesce(settings->>'theme', 'light') AS theme
FROM user_settings WHERE user_id = 1;

-- ============================================================
-- 9. PATTERN: AUDIT TRAIL
-- ============================================================

CREATE TABLE audit_log (
    id bigserial PRIMARY KEY,
    table_name text NOT NULL,
    record_id int NOT NULL,
    action text NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_by text NOT NULL,
    changed_at timestamptz DEFAULT now()
);

CREATE INDEX idx_audit_record
    ON audit_log (table_name, record_id);

-- ============================================================
-- 10. PATTERN: API RESPONSE BUILDER
-- ============================================================

SELECT jsonb_build_object(
    'status', 'success',
    'count', count(*),
    'products', jsonb_agg(
        jsonb_build_object(
            'id', id,
            'name', name,
            'brand', attrs->>'brand',
            'category', category
        ) ORDER BY name
    )
) AS response
FROM products
WHERE category = 'electronics';

-- ============================================================
-- 11. PATTERN: EVENT DATA
-- ============================================================

CREATE TABLE events (
    id bigserial PRIMARY KEY,
    event_type text NOT NULL,
    payload jsonb NOT NULL,
    created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_events_type ON events (event_type);
CREATE INDEX idx_events_payload ON events USING GIN (payload);

INSERT INTO events (event_type, payload) VALUES
('user_signup',
 '{"user_id": 42, "email": "alice@example.com",
  "source": "google_ads"}'),
('purchase',
 '{"user_id": 42, "order_id": 1001,
  "amount": 99.99, "currency": "USD"}');

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Add a "discount_percent" key to all electronics products.
--    Then remove it.

-- 2. Create a GIN index on the products attrs column.
--    Use EXPLAIN to verify it's used with @> queries.

-- 3. Create a user_settings table.
--    Insert a user with defaults, then update their theme.

-- 4. Build a JSON API response with jsonb_build_object
--    that returns all products grouped by category.

-- 5. Practice the shallow merge trap:
--    Try updating a nested key with || and see it fail.
--    Fix it with jsonb_set.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TABLE IF EXISTS events;
-- DROP TABLE IF EXISTS audit_log;
-- DROP TABLE IF EXISTS user_settings;
-- DROP INDEX IF EXISTS idx_products_attrs;
-- DROP INDEX IF EXISTS idx_products_attrs_path;
-- DROP INDEX IF EXISTS idx_products_brand;
-- DROP INDEX IF EXISTS idx_products_ram;
