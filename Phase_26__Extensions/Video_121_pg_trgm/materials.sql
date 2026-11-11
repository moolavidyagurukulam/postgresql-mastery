-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- pg_trgm — Fuzzy Text Matching (Class 227)
-- Phase 26: Extensions
-- ============================================================

-- ============================================================
-- INSTALLATION
-- ============================================================

CREATE EXTENSION pg_trgm;

-- Verify:
-- \dx pg_trgm

-- ============================================================
-- 1. TRIGRAMS
-- ============================================================

-- See trigrams of a word:
SELECT show_trgm('cat');
-- {"  c"," ca","at ","cat"}

SELECT show_trgm('PostgreSQL');

-- ============================================================
-- 2. SIMILARITY
-- ============================================================

-- Similarity score (0 to 1):
SELECT similarity('PostgreSQL', 'PostgreSQL');  -- 1.0
SELECT similarity('PostgreSQL', 'Postgre');     -- ~0.54
SELECT similarity('PostgreSQL', 'MySQL');       -- ~0.09
SELECT similarity('John', 'Jon');               -- ~0.33

-- Check/set threshold:
SHOW pg_trgm.similarity_threshold;  -- 0.3
SET pg_trgm.similarity_threshold = 0.2;  -- more fuzzy

-- ============================================================
-- 3. OPERATORS
-- ============================================================

-- % : true if similar above threshold
SELECT 'PostgreSQL' % 'Postgre';  -- true
SELECT 'PostgreSQL' % 'MySQL';    -- false

-- <-> : distance (1 - similarity), for ORDER BY
SELECT 'PostgreSQL' <-> 'Postgre';     -- ~0.46
SELECT 'PostgreSQL' <-> 'PostgreSQL';  -- 0

-- ============================================================
-- 4. PRACTICAL: PRODUCT SEARCH
-- ============================================================

CREATE TABLE products (
    id serial PRIMARY KEY,
    name text NOT NULL,
    category text
);

INSERT INTO products (name, category) VALUES
('PostgreSQL Handbook', 'Books'),
('MySQL Quick Guide', 'Books'),
('MongoDB in Action', 'Books'),
('Mechanical Keyboard', 'Electronics'),
('Wireless Mouse', 'Electronics'),
('PostgreSQL Sticker Pack', 'Merchandise'),
('Database T-Shirt', 'Merchandise');

-- GIN trigram index:
CREATE INDEX idx_products_trgm ON products
    USING gin (name gin_trgm_ops);

-- Fuzzy search:
SELECT name, similarity(name, 'Postgre') AS sim
FROM products
WHERE name % 'Postgre'
ORDER BY name <-> 'Postgre';

-- ============================================================
-- 5. INDEXED LIKE / ILIKE
-- ============================================================

-- With GIN trigram index, these use the index:
SELECT * FROM products WHERE name ILIKE '%keyboard%';
SELECT * FROM products WHERE name ILIKE '%sql%';

-- Verify with EXPLAIN:
EXPLAIN SELECT * FROM products WHERE name ILIKE '%keyboard%';
-- Should show Bitmap Index Scan

-- ============================================================
-- 6. WORD SIMILARITY
-- ============================================================

-- similarity compares entire strings:
SELECT similarity('keyboard', 'Mechanical Keyboard');  -- low

-- word_similarity finds best matching word:
SELECT word_similarity('keyboard', 'Mechanical Keyboard');  -- 1.0

-- Operators:
-- <<% : word similarity check
-- <<-> : word distance
SELECT name FROM products
WHERE 'keyboard' <<% name
ORDER BY 'keyboard' <<-> name;

-- strict_word_similarity: stricter matching
SELECT strict_word_similarity('key', 'Mechanical Keyboard');

-- ============================================================
-- 7. AUTOCOMPLETE
-- ============================================================

-- GiST index for KNN ordering:
CREATE INDEX idx_products_trgm_gist ON products
    USING gist (name gist_trgm_ops);

-- Autocomplete as user types:
SELECT name, similarity(name, 'post') AS score
FROM products
WHERE name % 'post'
ORDER BY name <-> 'post'
LIMIT 5;

-- Handle typo:
SET pg_trgm.similarity_threshold = 0.2;
SELECT name, similarity(name, 'mechancal') AS score
FROM products
WHERE name % 'mechancal'
ORDER BY name <-> 'mechancal'
LIMIT 5;

-- ============================================================
-- 8. COMBINING WITH FULL-TEXT SEARCH
-- ============================================================

ALTER TABLE products ADD COLUMN search_vector tsvector;

UPDATE products SET search_vector =
    to_tsvector('english', name || ' ' || coalesce(category, ''));

CREATE INDEX idx_products_fts ON products USING gin (search_vector);

-- Exact FTS:
SELECT name FROM products
WHERE search_vector @@ to_tsquery('english', 'postgresql');

-- Fuzzy fallback:
SELECT name FROM products
WHERE name % 'postgre'
ORDER BY name <-> 'postgre'
LIMIT 5;

-- ============================================================
-- 9. DEDUPLICATION
-- ============================================================

-- Find potential duplicates:
SELECT a.id, a.name, b.id, b.name,
    similarity(a.name, b.name) AS sim
FROM products a
JOIN products b ON a.id < b.id
WHERE similarity(a.name, b.name) > 0.4
ORDER BY sim DESC;

-- ============================================================
-- OPERATORS REFERENCE
-- ============================================================

-- %     : strings are similar (threshold check)
-- <->   : distance = 1 - similarity
-- <<%   : word similarity check
-- <<->  : word distance
-- %>>   : word similarity (reversed)
-- <->>  : word distance (reversed)

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install pg_trgm and show the trigrams of your name.

-- 2. Create a table of city names (at least 10 cities).
--    Add a GIN trigram index.

-- 3. Search for a misspelled city name and find the correct one.

-- 4. Use ILIKE '%pattern%' with EXPLAIN to verify the index is used.

-- 5. Compare similarity() and word_similarity() for
--    'York' vs 'New York City'.

-- 6. Build an autocomplete query that returns the top 3
--    matches as the user types.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TABLE IF EXISTS products;
-- DROP EXTENSION IF EXISTS pg_trgm;
