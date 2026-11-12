-- =============================================
-- PostgreSQL Mastery: Data Types Part 3 — Arrays & JSON
-- Phase 2: Database Objects | Classes 16-17
-- =============================================
-- Arrays, JSON, JSONB — store multiple values & documents
-- =============================================

-- === ARRAYS ===

-- Declare: add [] after any type → INTEGER[], TEXT[], BOOLEAN[]
-- Arrays start at index 1 (not 0!)

CREATE TABLE products (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(100),
    tags TEXT[]
);

-- Insert with curly braces
INSERT INTO products (name, tags) VALUES ('Laptop', '{electronics,computers,sale}');

-- Insert with ARRAY constructor
INSERT INTO products (name, tags) VALUES ('Headphones', ARRAY['electronics','audio','wireless']);
INSERT INTO products (name, tags) VALUES ('Notebook', ARRAY['stationery','paper']);

-- === QUERYING ARRAYS ===

-- Access by index (starts at 1!)
SELECT name, tags[1] AS first_tag FROM products;

-- Find rows containing a specific value
SELECT name FROM products WHERE 'sale' = ANY(tags);

-- Contains operator (@>)
SELECT name FROM products WHERE tags @> ARRAY['electronics'];

-- Overlap operator (&&) — any element in common?
SELECT name FROM products WHERE tags && ARRAY['audio','paper'];

-- Unnest: expand array into rows
SELECT name, unnest(tags) AS tag FROM products;

-- Unique tags across all products
SELECT DISTINCT unnest(tags) AS unique_tag FROM products ORDER BY unique_tag;

-- Array length
SELECT name, array_length(tags, 1) AS tag_count FROM products;

-- === MODIFYING ARRAYS ===

-- Append element
UPDATE products SET tags = array_append(tags, 'premium') WHERE name = 'Laptop';

-- Remove element
UPDATE products SET tags = array_remove(tags, 'sale') WHERE name = 'Laptop';

-- Concatenate arrays
UPDATE products SET tags = tags || ARRAY['new_arrival'] WHERE name = 'Headphones';

-- Update specific index
UPDATE products SET tags[2] = 'laptops' WHERE name = 'Laptop';

-- === JSON vs JSONB ===

-- JSON  = stored as text, preserves formatting, no indexing
-- JSONB = stored as binary, faster queries, supports GIN indexing
-- RULE: ALWAYS use JSONB!

CREATE TABLE app_users (
    id       SERIAL PRIMARY KEY,
    name     VARCHAR(100),
    settings JSONB
);

INSERT INTO app_users (name, settings) VALUES
('Ravi', '{"theme": "dark", "language": "en", "notifications": {"email": true, "sms": false}}'),
('Priya', '{"theme": "light", "language": "hi", "notifications": {"email": true, "sms": true}}');

-- === QUERYING JSONB ===

-- -> returns JSON value (still quoted)
SELECT name, settings->'theme' AS theme FROM app_users;

-- ->> returns TEXT value (unquoted, use for comparisons!)
SELECT name FROM app_users WHERE settings->>'theme' = 'dark';

-- Nested access: chain -> then ->>
SELECT name, settings->'notifications'->>'email' AS email_notif FROM app_users;

-- Containment (@>) — does the JSONB contain this?
SELECT name FROM app_users WHERE settings @> '{"theme": "dark"}';

-- Key existence (?)
SELECT name FROM app_users WHERE settings ? 'language';

-- === MODIFYING JSONB ===

-- Update a specific key
UPDATE app_users SET settings = jsonb_set(settings, '{theme}', '"blue"') WHERE name = 'Ravi';

-- Update nested key
UPDATE app_users SET settings = jsonb_set(settings, '{notifications,sms}', 'true') WHERE name = 'Ravi';

-- Add a new key (|| concatenation)
UPDATE app_users SET settings = settings || '{"font_size": 14}' WHERE name = 'Ravi';

-- Remove a key (- operator)
UPDATE app_users SET settings = settings - 'font_size' WHERE name = 'Ravi';

-- Remove nested key (#- operator)
UPDATE app_users SET settings = settings #- '{notifications,sms}' WHERE name = 'Ravi';

-- === INDEXING JSONB ===

-- GIN index for containment (@>) and key existence (?)
CREATE INDEX idx_settings ON app_users USING GIN (settings);

-- Expression index for specific key queries
CREATE INDEX idx_theme ON app_users ((settings->>'theme'));
-- Now: WHERE settings->>'theme' = 'dark' uses this index

-- === JSONB OPERATORS CHEAT SHEET ===

-- ->    Get JSON object by key     settings->'theme' → "dark"
-- ->>   Get TEXT value by key      settings->>'theme' → dark
-- @>    Contains?                  settings @> '{"theme":"dark"}'
-- ?     Key exists?                settings ? 'theme'
-- ||    Merge/add                  settings || '{"new": 1}'
-- -     Remove key                 settings - 'theme'
-- #-    Remove nested path         settings #- '{a,b}'

-- === USEFUL JSONB FUNCTIONS ===

SELECT jsonb_keys(settings) FROM app_users WHERE id = 1;      -- list keys
SELECT jsonb_each(settings) FROM app_users WHERE id = 1;      -- key-value pairs
SELECT jsonb_typeof(settings->'theme') FROM app_users;         -- type of value
SELECT jsonb_pretty(settings) FROM app_users WHERE id = 1;    -- pretty print

-- === WHEN TO USE WHAT ===

-- Arrays: short lists belonging to the row (tags, skills, colors)
-- JSONB: flexible data, user settings, API responses, varying structure
-- Regular columns: consistent structure, frequent queries, FK constraints

-- === COMMON ERRORS ===

-- ERROR: malformed array literal: "[a,b,c]"
-- FIX: Use '{a,b,c}' or ARRAY['a','b','c']

-- ERROR: invalid input syntax for type json
-- FIX: Validate JSON — keys need double quotes

-- ERROR: operator does not exist: text -> text
-- FIX: Column must be JSON/JSONB, not TEXT

-- === PRACTICE EXERCISES ===

-- Exercise 1: Array querying
CREATE TABLE developers (
    id     SERIAL PRIMARY KEY,
    name   VARCHAR(100),
    skills TEXT[]
);
INSERT INTO developers (name, skills) VALUES
('Ravi', ARRAY['PostgreSQL','Python','Docker']),
('Priya', ARRAY['PostgreSQL','Java','Kubernetes']),
('Arjun', ARRAY['MySQL','Python','AWS']);
SELECT name FROM developers WHERE 'PostgreSQL' = ANY(skills);

-- Exercise 2: Unique skills
SELECT DISTINCT unnest(skills) AS skill FROM developers ORDER BY skill;

-- Exercise 3: JSONB querying
CREATE TABLE configs (
    id       SERIAL PRIMARY KEY,
    app_name VARCHAR(100),
    config   JSONB
);
INSERT INTO configs (app_name, config) VALUES
('WebApp', '{"port": 3000, "debug": true, "db": {"host": "localhost", "name": "mydb"}}'),
('API', '{"port": 8080, "debug": false, "rate_limit": 100}');
SELECT app_name, config->>'port' AS port FROM configs;
SELECT app_name, config->'db'->>'host' AS db_host FROM configs WHERE config ? 'db';

-- Exercise 4: GIN index
CREATE INDEX idx_config ON configs USING GIN (config);
SELECT app_name FROM configs WHERE config @> '{"debug": true}';

-- Exercise 5: Modify JSONB
UPDATE configs SET config = jsonb_set(config, '{debug}', 'false') WHERE app_name = 'WebApp';
UPDATE configs SET config = config || '{"version": "2.0"}' WHERE app_name = 'API';
SELECT app_name, jsonb_pretty(config) FROM configs;

-- === CLEANUP ===
-- DROP TABLE IF EXISTS products, app_users, developers, configs;

-- =============================================
-- Next Class: Data Types — Special Types & Casting
-- =============================================

-- === ANSWER KEY ===
-- 1. Create skills table with TEXT[] and query 'PostgreSQL'
CREATE TABLE skills (id SERIAL, name TEXT, skills TEXT[]);
SELECT * FROM skills WHERE 'PostgreSQL' = ANY(skills);

-- 2. List all unique skills across rows
SELECT DISTINCT unnest(skills) AS skill FROM skills ORDER BY skill;

-- 3. Create configs table with JSONB and query nested key
CREATE TABLE configs (id SERIAL, app_name TEXT, config JSONB);
SELECT app_name, config->'db'->>'host' AS db_host FROM configs;

-- 4. Add GIN index and use @> containment operator
CREATE INDEX idx_configs_gin ON configs USING GIN (config);
SELECT * FROM configs WHERE config @> '{"env":"prod"}';

-- 5. Update nested value with jsonb_set & merge key with ||
UPDATE configs SET config = jsonb_set(config, '{db,port}', '5433') || '{"debug":false}'::jsonb WHERE id = 1;
