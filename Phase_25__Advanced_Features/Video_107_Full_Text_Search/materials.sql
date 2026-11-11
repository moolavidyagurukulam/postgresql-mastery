-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Full-Text Search — tsvector, tsquery & Ranking (Class 213)
-- Phase 25: Advanced Features
-- ============================================================

-- ============================================================
-- 1. tsvector — DOCUMENT REPRESENTATION
-- ============================================================

-- Convert text to tsvector (normalized lexemes):
SELECT to_tsvector('english',
    'The quick brown foxes jumped over the lazy dogs');
-- Result: 'brown':3 'dog':9 'fox':4 'jump':5 'lazi':8 'quick':2
-- Stop words removed, words stemmed, positions tracked

-- Without language (no stemming!):
SELECT to_tsvector('Running dogs');
-- 'dogs':2 'running':1  ← NOT stemmed

-- With language (proper stemming):
SELECT to_tsvector('english', 'Running dogs');
-- 'dog':2 'run':1  ← properly stemmed

-- ============================================================
-- 2. tsquery — SEARCH QUERIES
-- ============================================================

-- AND: both terms must match
SELECT to_tsquery('english', 'quick & fox');

-- OR: either term matches
SELECT to_tsquery('english', 'cat | dog');

-- NOT: exclude a term
SELECT to_tsquery('english', 'fox & !lazy');

-- Phrase: terms must be adjacent
SELECT to_tsquery('english', 'quick <-> fox');

-- ============================================================
-- 3. @@ MATCH OPERATOR
-- ============================================================

-- Does document match the query?
SELECT to_tsvector('english',
    'The quick brown fox jumped over the lazy dog')
    @@ to_tsquery('english', 'quick & fox');
-- t

-- Stemming works automatically:
SELECT to_tsvector('english', 'Many foxes')
    @@ to_tsquery('english', 'fox');
-- t

-- ============================================================
-- 4. PRACTICAL EXAMPLE — ARTICLES TABLE
-- ============================================================

CREATE TABLE articles (
    id serial PRIMARY KEY,
    title text NOT NULL,
    body text NOT NULL,
    created_at timestamptz DEFAULT now()
);

INSERT INTO articles (title, body) VALUES
('PostgreSQL Performance Tuning',
 'Learn how to tune PostgreSQL for maximum performance. We cover indexing strategies, query optimization, configuration parameters, and monitoring tools.'),
('Introduction to Database Indexing',
 'Indexes speed up queries by creating sorted structures. B-tree indexes are the default. GIN indexes work well for full-text search and arrays.'),
('PostgreSQL Replication Guide',
 'Streaming replication copies data to standby servers. This provides high availability and read scaling for your PostgreSQL cluster.'),
('MySQL vs PostgreSQL Comparison',
 'Both databases have strengths in different areas. PostgreSQL excels at complex queries, JSON support, and extensibility.');

-- Search for PostgreSQL + performance:
SELECT title FROM articles
WHERE to_tsvector('english', title || ' ' || body)
   @@ to_tsquery('english', 'postgresql & performance');

-- ============================================================
-- 5. tsquery HELPER FUNCTIONS
-- ============================================================

-- plainto_tsquery: plain text → AND query
SELECT plainto_tsquery('english', 'quick brown fox');
-- 'quick' & 'brown' & 'fox'

-- phraseto_tsquery: plain text → phrase query
SELECT phraseto_tsquery('english', 'quick brown fox');
-- 'quick' <-> 'brown' <-> 'fox'

-- websearch_to_tsquery: Google-style syntax
SELECT websearch_to_tsquery('english', '"quick fox" -lazy');
-- 'quick' <-> 'fox' & !'lazi'

-- ============================================================
-- 6. ts_rank — RELEVANCE RANKING
-- ============================================================

-- Rank results by relevance:
SELECT
    title,
    ts_rank(
        to_tsvector('english', title || ' ' || body),
        to_tsquery('english', 'postgresql')
    ) AS rank
FROM articles
WHERE to_tsvector('english', title || ' ' || body)
   @@ to_tsquery('english', 'postgresql')
ORDER BY rank DESC;

-- ============================================================
-- 7. WEIGHTED SEARCH — setweight
-- ============================================================

-- Title (weight A) more important than body (weight B):
SELECT
    title,
    ts_rank(
        setweight(to_tsvector('english', title), 'A') ||
        setweight(to_tsvector('english', body), 'B'),
        to_tsquery('english', 'postgresql')
    ) AS rank
FROM articles
WHERE
    setweight(to_tsvector('english', title), 'A') ||
    setweight(to_tsvector('english', body), 'B')
    @@ to_tsquery('english', 'postgresql')
ORDER BY rank DESC;

-- Weight levels: A (highest) > B > C > D (lowest/default)

-- ============================================================
-- 8. ts_headline — HIGHLIGHTED SNIPPETS
-- ============================================================

SELECT
    title,
    ts_headline('english', body,
        to_tsquery('english', 'postgresql & performance'),
        'StartSel=<b>, StopSel=</b>, MaxWords=35, MinWords=15'
    ) AS snippet
FROM articles
WHERE to_tsvector('english', title || ' ' || body)
   @@ to_tsquery('english', 'postgresql & performance');

-- ============================================================
-- 9. SET DEFAULT LANGUAGE
-- ============================================================

-- Set default text search config for the database:
ALTER DATABASE mydb SET default_text_search_config = 'english';

-- Check current config:
SHOW default_text_search_config;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create the articles table above and insert the sample data.
--    Search for articles about 'indexing'.

-- 2. Try all four tsquery functions with the same input text:
--    'database performance tuning'
--    Compare the outputs.

-- 3. Use ts_rank to rank articles matching 'postgresql'.
--    Then use setweight to make title matches rank higher.

-- 4. Use ts_headline to show highlighted snippets
--    for the search term 'replication'.

-- 5. Try searching without specifying 'english'.
--    Compare the tsvector output with and without the language.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TABLE IF EXISTS articles;
