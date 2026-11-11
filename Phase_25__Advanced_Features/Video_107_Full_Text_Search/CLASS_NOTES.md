# Full-Text Search — tsvector, tsquery, and Ranking
**Series:** PostgreSQL Mastery | **Phase:** Phase 25: Advanced Features | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! We now enter Phase 25 — Advanced Features. Imagine you have a million articles in your database and a user types 'database performance tuning' into a search box. A LIKE query would be painfully slow and miss word variations like 'databases' or 'tuned'. PostgreSQL has a built-in full-text search engine that handles this — it understands language, stems words, ranks results by relevance, and uses indexes for speed. Let us learn how it works.


---

## 2. Core Technical Concepts & Mechanisms

### LIKE vs Full-Text Search
Why not just use LIKE or ILIKE? LIKE percent search percent scans every row and every character — no index can help. It does not understand language — 'running' does not match 'run'. It cannot rank results by relevance. And it has no concept of stop words — it matches 'the' and 'a' just like meaningful terms. Full-text search solves all of these problems.

| LIKE / ILIKE | Full-Text Search |
| :--- | :--- |
| Sequential scan (no index help) | Uses GIN or GiST indexes (fast) |
| No stemming: 'running' ≠ 'run' | Stemming: 'running' = 'run' = 'runs' |
| No ranking by relevance | Ranks results by relevance (ts_rank) |
| Matches stop words (the, a, is) | Ignores stop words automatically |
| No language awareness | Language-aware (English, Spanish, etc.) |
| Slow on large datasets | Fast on millions of rows |

### Core Concepts
Full-text search has two core data types. tsvector is the document side — it represents a text document as a sorted list of lexemes, which are normalized words. tsquery is the search side — it represents the search terms with operators like AND, OR, and NOT. Matching is done with the double-at operator.

| Term | Meaning / Explanation |
| :--- | :--- |
| **tsvector** | Normalized representation of a document — sorted, stemmed lexemes with positions |
| **tsquery** | Search query — stemmed terms connected with & (AND), | (OR), ! (NOT) |
| **@@ operator** | Matches a tsvector against a tsquery — returns true if the document matches |

**Notes:**
- Lexeme = base form of a word (e.g., 'running' → 'run')
- Stop words (the, is, a) are removed automatically
- Positions track where each word appears in the document

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### ts_rank vs ts_rank_cd
ts_rank_cd is a variant that uses cover density ranking — it considers how close the search terms are to each other in the document. Documents where the terms appear near each other score higher.

| ts_rank (frequency) | ts_rank_cd (cover density) |
| :--- | :--- |
| Based on term frequency | Based on term proximity |
| More occurrences = higher score | Terms close together = higher score |
| Does not consider term proximity | Better for phrase-like queries |
| Good for general search | Good for relevance ranking |

### tsquery Functions Comparison
Here is a comparison of the tsquery functions and when to use each one.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a comparison of the tsquery functions and when to use each one |


---

## 3. Hands-On Commands & psql Output

### to_tsvector — Converting Text to Lexemes
**Explanation:** Let us see tsvector in action. The to_tsvector function takes a language and a text string, and returns the normalized lexemes with their positions.

```sql
postgres=# SELECT to_tsvector('english',
    'The quick brown foxes jumped over the lazy dogs');
              to_tsvector
postgres=# ------------------------------------------
 'brown':3 'dog':9 'fox':4 'jump':5 'lazi':8 'quick':2
postgres=# -- Notice:
postgres=# -- 'The' → removed (stop word)
postgres=# -- 'foxes' → 'fox' (stemmed)
postgres=# -- 'jumped' → 'jump' (stemmed)
postgres=# -- 'lazy' → 'lazi' (stemmed)
postgres=# -- 'over' → removed (stop word)
postgres=# -- Numbers after colon = word positions
```

### to_tsquery — Building Search Queries
**Explanation:** Now let us see tsquery. The to_tsquery function normalizes search terms the same way. You connect terms with ampersand for AND, pipe for OR, and exclamation for NOT.

```sql
postgres=# -- AND: both terms must match
postgres=# SELECT to_tsquery('english', 'quick & fox');
  to_tsquery
postgres=# --------------
 'quick' & 'fox'
postgres=# -- OR: either term matches
postgres=# SELECT to_tsquery('english', 'cat | dog');
  to_tsquery
postgres=# --------------
 'cat' | 'dog'
postgres=# -- NOT: exclude a term
postgres=# SELECT to_tsquery('english', 'fox & !lazy');
  to_tsquery
postgres=# --------------
 'fox' & !'lazi'
postgres=# -- Phrase search: terms must be adjacent
postgres=# SELECT to_tsquery('english', 'quick <-> fox');
  to_tsquery
postgres=# --------------
 'quick' <-> 'fox'
```

### The @@ Match Operator
**Explanation:** The double-at operator matches a tsvector against a tsquery. It returns true or false. Let us use it to search documents.

```sql
postgres=# -- Does the document match the query?
postgres=# SELECT to_tsvector('english',
    'The quick brown fox jumped over the lazy dog')
    @@ to_tsquery('english', 'quick & fox');
 ?column?
postgres=# ----------
 t
postgres=# -- 'cat' is not in the document:
postgres=# SELECT to_tsvector('english',
    'The quick brown fox jumped over the lazy dog')
    @@ to_tsquery('english', 'quick & cat');
 ?column?
postgres=# ----------
 f
postgres=# -- Stemming works: 'foxes' matches 'fox'
postgres=# SELECT to_tsvector('english', 'Many foxes')
    @@ to_tsquery('english', 'fox');
 ?column?
postgres=# ----------
 t
```

### Real Example: Search Articles
**Explanation:** Let us build a real example. Create an articles table with title and body, insert some data, and search it using full-text search.

```sql
postgres=# CREATE TABLE articles (
    id serial PRIMARY KEY,
    title text NOT NULL,
    body text NOT NULL,
    created_at timestamptz DEFAULT now()
);
postgres=# INSERT INTO articles (title, body) VALUES
('PostgreSQL Performance Tuning',
 'Learn how to tune PostgreSQL for maximum performance...'),
('Introduction to Database Indexing',
 'Indexes speed up queries by creating sorted structures...'),
('PostgreSQL Replication Guide',
 'Streaming replication copies data to standby servers...'),
('MySQL vs PostgreSQL Comparison',
 'Both databases have strengths in different areas...');
postgres=# -- Search for articles about PostgreSQL performance:
postgres=# SELECT title FROM articles
postgres-# WHERE to_tsvector('english', title || ' ' || body)
   @@ to_tsquery('english', 'postgresql & performance');
             title
postgres=# -------------------------------
 PostgreSQL Performance Tuning
```

### tsquery Helper Functions
**Explanation:** There are several tsquery helper functions. plainto_tsquery takes plain text and converts it to an AND query. phraseto_tsquery creates a phrase query where words must appear adjacent. websearch_to_tsquery understands Google-style search syntax with quotes and minus signs.

```sql
postgres=# -- plainto_tsquery: words joined with AND
postgres=# SELECT plainto_tsquery('english',
    'quick brown fox');
        plainto_tsquery
postgres=# -------------------------------
 'quick' & 'brown' & 'fox'
postgres=# -- phraseto_tsquery: words must be adjacent
postgres=# SELECT phraseto_tsquery('english',
    'quick brown fox');
        phraseto_tsquery
postgres=# -------------------------------
 'quick' <-> 'brown' <-> 'fox'
postgres=# -- websearch_to_tsquery: Google-style syntax
postgres=# SELECT websearch_to_tsquery('english',
    '"quick fox" -lazy');
        websearch_to_tsquery
postgres=# ---------------------------------
 'quick' <-> 'fox' & !'lazi'
postgres=# -- Quotes = phrase, minus = NOT
```

### ts_rank — Ranking Results by Relevance
**Explanation:** Now ranking. ts_rank scores how well a document matches a query. Higher scores mean better matches. You can use this to sort results by relevance — just like a search engine.

```sql
SELECT
    title,
    ts_rank(
        to_tsvector('english', title || ' ' || body),
        to_tsquery('english', 'postgresql')
    ) AS rank
postgres-# FROM articles
postgres-# WHERE to_tsvector('english', title || ' ' || body)
   @@ to_tsquery('english', 'postgresql')
postgres-# ORDER BY rank DESC;
              title                | rank
postgres=# -----------------------------------+-----------
 PostgreSQL Performance Tuning     | 0.0607927
 PostgreSQL Replication Guide      | 0.0607927
 MySQL vs PostgreSQL Comparison    | 0.0303964
```

### Weighted Search — Title More Important Than Body
**Explanation:** You can weight different parts of a document. For example, make the title more important than the body. tsvector supports four weight levels: A is highest, D is lowest. Use setweight to assign weights.

```sql
postgres=# -- Weight A for title, B for body:
SELECT
    title,
    ts_rank(
        setweight(to_tsvector('english', title), 'A') ||
        setweight(to_tsvector('english', body), 'B'),
        to_tsquery('english', 'postgresql')
    ) AS rank
postgres-# FROM articles
WHERE
    setweight(to_tsvector('english', title), 'A') ||
    setweight(to_tsvector('english', body), 'B')
    @@ to_tsquery('english', 'postgresql')
postgres-# ORDER BY rank DESC;
postgres=# -- Weight levels: A (highest) > B > C > D (lowest/default)
postgres=# -- A match in the title scores higher than in the body
```

### ts_headline — Highlighted Snippets
**Explanation:** ts_headline generates a snippet with the matching terms highlighted. This is what you show in search results — the relevant excerpt with terms in bold.

```sql
SELECT
    title,
    ts_headline('english', body,
        to_tsquery('english', 'postgresql & performance'),
        'StartSel=<b>, StopSel=</b>, MaxWords=35, MinWords=15'
    ) AS snippet
postgres-# FROM articles
postgres-# WHERE to_tsvector('english', title || ' ' || body)
   @@ to_tsquery('english', 'postgresql & performance');
              title               |           snippet
postgres=# ----------------------------------+-----------------------------
 PostgreSQL Performance Tuning    | Learn how to tune
                                  | <b>PostgreSQL</b> for
                                  | maximum <b>performance</b>...
```

### Beginner Trap: Forgetting the Language
**Explanation:** A common beginner mistake is forgetting to specify the language. Without a language configuration, PostgreSQL uses the 'default' config which may not stem words correctly for your language. Always specify 'english' or your language explicitly.

```sql
postgres=# -- WITHOUT language (uses 'default' config):
postgres=# SELECT to_tsvector('Running dogs');
     to_tsvector
postgres=# ---------------------
 'dogs':2 'running':1
postgres=# -- No stemming! 'running' stays as 'running'
postgres=# -- WITH English language:
postgres=# SELECT to_tsvector('english', 'Running dogs');
     to_tsvector
postgres=# ---------------------
 'dog':2 'run':1
postgres=# -- Properly stemmed: 'running'→'run', 'dogs'→'dog'
postgres=# -- Set default config for the database:
postgres=# ALTER DATABASE mydb SET default_text_search_config = 'english';
postgres=# -- Now to_tsvector('Running dogs') stems correctly
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Forgetting the Language
A common beginner mistake is forgetting to specify the language. Without a language configuration, PostgreSQL uses the 'default' config which may not stem words correctly for your language. Always specify 'english' or your language explicitly.

```sql
-- WITHOUT language (uses 'default' config):
postgres=# SELECT to_tsvector('Running dogs');
     to_tsvector
---------------------
 'dogs':2 'running':1
-- No stemming! 'running' stays as 'running'
-- WITH English language:
postgres=# SELECT to_tsvector('english', 'Running dogs');
     to_tsvector
---------------------
 'dog':2 'run':1
-- Properly stemmed: 'running'→'run', 'dogs'→'dog'
-- Set default config for the database:
ALTER DATABASE mydb SET default_text_search_config = 'english';
-- Now to_tsvector('Running dogs') stems correctly
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. PostgreSQL full-text search converts documents into tsvector lexemes and search terms into tsquery. The double-at operator matches them. to_tsvector stems words and removes stop words. Use plainto_tsquery for simple search, websearch_to_tsquery for Google-style search. ts_rank ranks results by relevance. setweight gives different parts different importance. ts_headline generates highlighted snippets. Always specify the language. In the next class, we add GIN indexes and custom configurations to make full-text search fast and powerful.

- **tsvector: normalized document — sorted, stemmed lexemes**
- **tsquery: search query with & (AND), | (OR), ! (NOT), <-> (adjacent)**
- **@@: match operator — tsvector @@ tsquery returns boolean**
- **to_tsvector('english', text): converts text to lexemes**
- **plainto_tsquery: 'quick fox' → 'quick' & 'fox'**
- **websearch_to_tsquery: Google-style with quotes and minus**
- **ts_rank / ts_rank_cd: score results by relevance**
- **setweight: A (title) > B (body) for weighted search**
- **ts_headline: highlighted snippets for search results**
- **Always specify language: 'english', 'spanish', etc.**
- **Next: Full-Text Search Indexes & Configuration**


---

## 8. Downloadable SQL Script Instructions

Every command demonstrated in this video is compiled into the companion `materials.sql` file.

To execute it directly in PostgreSQL:

```bash
# From your command line:
psql -U postgres -d postgres -f materials.sql

# Or from inside psql prompt:
postgres=# \i materials.sql
```
