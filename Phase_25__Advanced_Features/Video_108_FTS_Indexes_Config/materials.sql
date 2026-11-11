-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Full-Text Search — Indexes & Configuration (Class 214)
-- Phase 25: Advanced Features
-- ============================================================

-- ============================================================
-- 1. GENERATED tsvector COLUMN (Recommended)
-- ============================================================

-- Assumes articles table from previous class exists.
-- Add generated column with weights:
ALTER TABLE articles ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(body, '')), 'B')
    ) STORED;

-- Verify:
SELECT title, left(search_vector::text, 60)
FROM articles LIMIT 2;

-- ============================================================
-- 2. TRIGGER-BASED APPROACH
-- ============================================================

-- (Use this OR the generated column, not both)
-- ALTER TABLE articles ADD COLUMN search_vector tsvector;

CREATE OR REPLACE FUNCTION articles_search_trigger()
RETURNS trigger AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('english',
            coalesce(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english',
            coalesce(NEW.body, '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_articles_search
    BEFORE INSERT OR UPDATE ON articles
    FOR EACH ROW
    EXECUTE FUNCTION articles_search_trigger();

-- Backfill existing rows:
UPDATE articles SET search_vector =
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(body, '')), 'B');

-- ============================================================
-- 3. GIN INDEX
-- ============================================================

-- Create GIN index on stored column:
CREATE INDEX idx_articles_search
    ON articles USING GIN (search_vector);

-- Verify index usage:
EXPLAIN (COSTS OFF)
SELECT title FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgresql');

-- ============================================================
-- 4. EXPRESSION INDEX (no stored column)
-- ============================================================

CREATE INDEX idx_articles_fts ON articles
    USING GIN (to_tsvector('english', title || ' ' || body));

-- Query must match expression exactly:
SELECT title FROM articles
WHERE to_tsvector('english', title || ' ' || body)
   @@ to_tsquery('english', 'postgresql');

-- ============================================================
-- 5. GIN TUNING
-- ============================================================

-- Disable fastupdate (faster reads, slower inserts):
ALTER INDEX idx_articles_search
    SET (fastupdate = off);

-- Set pending list limit:
ALTER INDEX idx_articles_search
    SET (gin_pending_list_limit = 2048);

-- Force flush pending list:
SELECT gin_clean_pending_list('idx_articles_search');

-- ============================================================
-- 6. TEXT SEARCH CONFIGURATIONS
-- ============================================================

-- List available configs:
SELECT cfgname FROM pg_ts_config ORDER BY cfgname;

-- Check current default:
SHOW default_text_search_config;

-- Compare english vs simple:
SELECT to_tsvector('english', 'The running dogs are playing');
-- 'dog':3 'play':5 'run':2

SELECT to_tsvector('simple', 'The running dogs are playing');
-- 'are':4 'dogs':3 'playing':5 'running':2 'the':1

-- Set default for database:
ALTER DATABASE mydb SET default_text_search_config = 'english';

-- ============================================================
-- 7. CUSTOM CONFIGURATION
-- ============================================================

-- Create config based on english:
CREATE TEXT SEARCH CONFIGURATION myapp (COPY = english);

-- ============================================================
-- 8. SYNONYM DICTIONARY
-- ============================================================

-- Step 1: Create synonym file at:
--   /usr/share/postgresql/16/tsearch_data/myapp.syn
-- Contents:
--   pg    postgresql
--   db    database
--   idx   index
--   perf  performance

-- Step 2: Create dictionary:
CREATE TEXT SEARCH DICTIONARY myapp_syn (
    TEMPLATE = synonym,
    SYNONYMS = myapp
);

-- Step 3: Add to config:
ALTER TEXT SEARCH CONFIGURATION myapp
    ALTER MAPPING FOR asciiword
    WITH myapp_syn, english_stem;

-- Test:
SELECT to_tsvector('myapp', 'PG performance tuning');
-- 'perform':2 'postgresql':1 'tune':3

-- ============================================================
-- 9. DEBUGGING TEXT SEARCH
-- ============================================================

-- See how a word is processed:
SELECT * FROM ts_debug('english', 'running');

-- Test a specific dictionary:
SELECT ts_lexize('english_stem', 'running');
-- {run}

SELECT ts_lexize('english_stem', 'the');
-- {}  (stop word)

-- Debug a full string:
SELECT * FROM ts_debug('english',
    'Contact john@example.com at https://pg.dev');

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Add a generated tsvector column to the articles table.
--    Create a GIN index on it.
--    Use EXPLAIN to verify the index is used.

-- 2. Compare search speed with and without the GIN index.
--    (Hint: SET enable_indexscan = off; to test without index)

-- 3. Try to_tsvector with 'english' vs 'simple' config.
--    When would you choose 'simple'?

-- 4. Create a custom text search config based on english.
--    (Bonus: create a synonym dictionary for your domain)

-- 5. Use ts_debug to see how PostgreSQL processes the text:
--    'PostgreSQL 16 released with better performance'

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP INDEX IF EXISTS idx_articles_search;
-- DROP INDEX IF EXISTS idx_articles_fts;
-- ALTER TABLE articles DROP COLUMN IF EXISTS search_vector;
-- DROP TEXT SEARCH CONFIGURATION IF EXISTS myapp;
-- DROP TEXT SEARCH DICTIONARY IF EXISTS myapp_syn;
-- DROP FUNCTION IF EXISTS articles_search_trigger();
