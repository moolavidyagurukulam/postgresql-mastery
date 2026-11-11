# Full-Text Search — Indexes & Configuration
**Series:** PostgreSQL Mastery | **Phase:** Phase 25: Advanced Features | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we learned the basics of full-text search — tsvector, tsquery, and ranking. But there was a problem — calling to_tsvector on every row for every query is slow. Today we solve that. We learn how to store tsvector in a column, index it with GIN for instant lookups, and configure custom text search dictionaries so PostgreSQL understands your domain vocabulary.

### The Performance Problem
The problem with our previous approach is simple. Every time we search, PostgreSQL must convert every row's text to a tsvector and then compare it to the query. On a table with a million rows, that means a million to_tsvector calls per search. The solution is to pre-compute the tsvector and store it in a dedicated column, then create an index on that column.


---

## 2. Core Technical Concepts & Mechanisms

### The Performance Problem
The problem with our previous approach is simple. Every time we search, PostgreSQL must convert every row's text to a tsvector and then compare it to the query. On a table with a million rows, that means a million to_tsvector calls per search. The solution is to pre-compute the tsvector and store it in a dedicated column, then create an index on that column.

| Without Index (Slow) | With Stored Column + GIN (Fast) |
| :--- | :--- |
| to_tsvector called on EVERY row | tsvector pre-computed and stored |
| 1M rows = 1M conversions per search | GIN index on stored column |
| Sequential scan — reads entire table | Index scan — jumps to matching rows |
| Gets slower as table grows | Stays fast as table grows |
| Cannot use any index | Sub-millisecond on millions of rows |

### GIN vs GiST for Full-Text Search
GIN versus GiST — which index type should you choose? GIN is the default choice for full-text search. It is faster for lookups but slower to build and uses more disk. GiST is smaller and faster to update but slower for lookups. Use GIN unless you have heavy write loads with few reads.

| Term | Meaning / Explanation |
| :--- | :--- |
| **GIN versus GiST** | which index type should you choose? |
| **GIN is the default choice for full** | text search |
| **Point 3** | It is faster for lookups but slower to build and uses more disk |
| **Point 4** | GiST is smaller and faster to update but slower for lookups |
| **Point 5** | Use GIN unless you have heavy write loads with few reads |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Decision Framework
Here is a decision framework. For most applications, use a generated column with a GIN index and the english configuration. Switch to a trigger approach when you need custom logic. Create a custom configuration only when you need synonyms or domain-specific stemming.

- 1 -- Use generated column + GIN index + english config
- 2 -- Use trigger approach instead of generated column
- 3 -- Create synonym dictionary + custom config
- 4 -- Store language per row, use matching config
- 5 -- Consider GiST instead of GIN
- 6 -- Column is faster for ranking; expression saves disk


---

## 3. Hands-On Commands & psql Output

### Approach 1: Generated Column (Recommended)
**Explanation:** There are two approaches to store the tsvector. Approach one: a generated column — PostgreSQL automatically computes and maintains the tsvector whenever the source columns change. This is the cleanest approach for PostgreSQL 12 and later.

```sql
postgres=# -- Add a generated tsvector column:
postgres=# ALTER TABLE articles ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(body, '')), 'B')
    ) STORED;
postgres=# -- Verify it was populated:
postgres=# SELECT title, left(search_vector::text, 60)
postgres-# FROM articles LIMIT 2;
          title              |                left
postgres=# -----------------------------+------------------------------------
 PostgreSQL Performance...   | 'configur':14B 'cover':11B 'index':12B...
 Introduction to Database... | 'array':18B 'b':10B 'b-tree':9B...
```

### Approach 2: Regular Column + Trigger
**Explanation:** Approach two: a regular column with a trigger. This gives you more control — you can add custom logic, handle NULLs differently, or combine more fields. The trigger fires on INSERT and UPDATE to keep the vector current.

```sql
postgres=# -- Add a regular tsvector column:
postgres=# ALTER TABLE articles ADD COLUMN search_vector tsvector;
postgres=# -- Create trigger function:
postgres=# CREATE OR REPLACE FUNCTION articles_search_trigger()
RETURNS trigger AS $$
postgres=# BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('english',
            coalesce(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english',
            coalesce(NEW.body, '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
postgres=# -- Attach the trigger:
postgres=# CREATE TRIGGER trg_articles_search
    BEFORE INSERT OR UPDATE ON articles
    FOR EACH ROW
    EXECUTE FUNCTION articles_search_trigger();
postgres=# -- Backfill existing rows:
postgres=# UPDATE articles SET search_vector =
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(body, '')), 'B');
```

### GIN Index — The Key to Fast Search
**Explanation:** Now the important part — creating a GIN index on the tsvector column. GIN stands for Generalized Inverted Index. It works like the index at the back of a book — for each word, it stores which rows contain that word. This makes full-text search queries extremely fast.

```sql
postgres=# -- Create GIN index on the tsvector column:
postgres=# CREATE INDEX idx_articles_search
postgres-# ON articles USING GIN (search_vector);
postgres=# -- Now search uses the index:
postgres=# SELECT title FROM articles
postgres-# WHERE search_vector @@ to_tsquery('english', 'postgresql');
postgres=# -- Verify with EXPLAIN:
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT title FROM articles
postgres-# WHERE search_vector @@ to_tsquery('english', 'postgresql');
              QUERY PLAN
postgres=# --------------------------------------
 Bitmap Heap Scan on articles
   Recheck Cond: (search_vector @@ ...)
   ->  Bitmap Index Scan on idx_articles_search
         Index Cond: (search_vector @@ ...)
postgres=# -- Index scan, not sequential scan!
```

### Expression Index — No Stored Column Needed
**Explanation:** You can also create a GIN index directly on an expression — without a stored column. This saves disk space but is slightly slower for ranking because PostgreSQL must recompute the tsvector for each matching row to calculate the rank.

```sql
postgres=# -- GIN index on an expression (no stored column):
postgres=# CREATE INDEX idx_articles_fts ON articles
postgres-# USING GIN (to_tsvector('english', title || ' ' || body));
postgres=# -- Query MUST match the expression exactly:
postgres=# SELECT title FROM articles
postgres-# WHERE to_tsvector('english', title || ' ' || body)
   @@ to_tsquery('english', 'postgresql');
postgres=# -- ✓ Uses the index
postgres=# -- This does NOT use the index:
postgres=# SELECT title FROM articles
postgres-# WHERE to_tsvector('english', title)
   @@ to_tsquery('english', 'postgresql');
postgres=# -- ✗ Different expression → sequential scan!
```

### GIN fastupdate Tuning
**Explanation:** GIN has a useful tuning parameter — fastupdate. When enabled, which is the default, new entries go into a pending list instead of the main index. This makes inserts faster but searches must also check the pending list. You can tune when the pending list is flushed.

```sql
postgres=# -- Check current setting:
postgres=# SELECT reloptions FROM pg_class
postgres-# WHERE relname = 'idx_articles_search';
postgres=# -- Disable fastupdate (slower inserts, faster searches):
postgres=# ALTER INDEX idx_articles_search
postgres=# SET (fastupdate = off);
postgres=# -- Set pending list limit (default 4MB):
postgres=# ALTER INDEX idx_articles_search
postgres=# SET (gin_pending_list_limit = 2048);  -- 2MB
postgres=# -- Force flush the pending list:
postgres=# SELECT gin_clean_pending_list('idx_articles_search');
postgres=# -- For high-read workloads: fastupdate = off
postgres=# -- For balanced workloads: keep default (on)
```

### Text Search Configurations
**Explanation:** Now let us talk about text search configurations. A configuration defines how PostgreSQL processes text — which parser breaks text into tokens, which dictionaries process each token type, and which stop words to remove. PostgreSQL ships with configurations for many languages.

```sql
postgres=# -- List all available configurations:
postgres=# SELECT cfgname FROM pg_ts_config ORDER BY cfgname;
    cfgname
postgres=# ---------------
 arabic
 danish
 dutch
 english
 finnish
 french
 german
 hungarian
 ...
 simple
 spanish
 swedish
 turkish
postgres=# -- Check current default:
postgres=# SHOW default_text_search_config;
postgres=# -- pg_catalog.english
postgres=# -- See what a configuration does:
postgres=# \dF+ english
```

### simple vs english Configuration
**Explanation:** The 'simple' configuration is special — it lowercases text but does NO stemming and NO stop word removal. This is useful for searching identifiers, product codes, or proper names that should not be stemmed.

```sql
postgres=# -- English config: stems and removes stop words:
postgres=# SELECT to_tsvector('english', 'The running dogs are playing');
postgres=# -- 'dog':3 'play':5 'run':2
postgres=# -- 'The' removed, 'running'→'run', 'dogs'→'dog'
postgres=# -- Simple config: lowercase only, no stemming:
postgres=# SELECT to_tsvector('simple', 'The running dogs are playing');
postgres=# -- 'are':4 'dogs':3 'playing':5 'running':2 'the':1
postgres=# -- Nothing removed, nothing stemmed
postgres=# -- Use 'simple' for:
postgres=# -- Product codes: 'ABC-123-XYZ'
postgres=# -- Usernames: 'john_smith42'
postgres=# -- Technical terms that should not be stemmed
```

### Creating a Custom Configuration
**Explanation:** You can create your own text search configuration. Start by copying an existing one and then customize it. Let us create a configuration that uses english stemming but also recognizes our custom terms.

```sql
postgres=# -- Create a new config based on english:
postgres=# CREATE TEXT SEARCH CONFIGURATION myapp (COPY = english);
postgres=# -- See what token types it handles:
postgres=# \dF+ myapp
postgres=# -- Shows: asciiword, word, email, url, host, etc.
postgres=# -- Use the custom config:
postgres=# SELECT to_tsvector('myapp',
    'PostgreSQL performance tuning guide');
postgres=# -- Same as english for now:
postgres=# -- 'guid':4 'perform':2 'postgresql':1 'tune':3
```

### Synonym Dictionary
**Explanation:** Text search dictionaries control how individual words are processed. The english_stem dictionary handles stemming. The simple dictionary just lowercases. You can also create synonym dictionaries to map domain-specific terms — for example, mapping 'PG' to 'postgresql' or 'DB' to 'database'.

```sql
postgres=# -- Create a synonym file:
postgres=# -- File: /usr/share/postgresql/16/tsearch_data/myapp.syn
postgres=# -- Contents (one mapping per line):
postgres=# -- pg    postgresql
postgres=# -- db    database
postgres=# -- idx   index
postgres=# -- perf  performance
postgres=# -- Create the dictionary:
postgres=# CREATE TEXT SEARCH DICTIONARY myapp_syn (
    TEMPLATE = synonym,
    SYNONYMS = myapp  -- references myapp.syn file
);
postgres=# -- Add it to our config (check synonyms first):
postgres=# ALTER TEXT SEARCH CONFIGURATION myapp
postgres=# ALTER MAPPING FOR asciiword
postgres=# WITH myapp_syn, english_stem;
postgres=# -- Now 'pg' maps to 'postgresql':
postgres=# SELECT to_tsvector('myapp', 'PG performance tuning');
postgres=# -- 'perform':2 'postgresql':1 'tune':3
```

### Beginner Trap: Config Mismatch
**Explanation:** Here is a common beginner trap. If you create an expression index with one language configuration but search with a different one, the index will NOT be used. The configuration in the WHERE clause must exactly match the one used in the index.

```sql
postgres=# -- Index created with 'english':
postgres=# CREATE INDEX idx_fts ON articles
postgres-# USING GIN (to_tsvector('english', body));
postgres=# -- This uses the index (config matches):
postgres=# SELECT * FROM articles
postgres-# WHERE to_tsvector('english', body)
   @@ to_tsquery('english', 'postgresql');
postgres=# -- ✓ Bitmap Index Scan on idx_fts
postgres=# -- This does NOT use the index:
postgres=# SELECT * FROM articles
postgres-# WHERE to_tsvector('simple', body)
   @@ to_tsquery('simple', 'postgresql');
postgres=# -- ✗ Sequential Scan (different config!)
postgres=# -- Fix: always use the same config in index and query
```

### Debugging Text Search
**Explanation:** Let us look at some useful text search functions for debugging and understanding what PostgreSQL does internally.

```sql
postgres=# -- See how a word is processed:
postgres=# SELECT * FROM ts_debug('english', 'running');
postgres=# -- alias | description | token | dictionaries | dictionary | lexemes
postgres=# -- word  | Word, all.. | running | {english_stem} | english_stem | {run}
postgres=# -- See all token types the parser produces:
postgres=# SELECT * FROM ts_debug('english',
    'Contact john@example.com at https://pg.dev');
postgres=# -- email → john@example.com
postgres=# -- url   → https://pg.dev
postgres=# -- word  → Contact, at
postgres=# -- Test a specific dictionary:
postgres=# SELECT ts_lexize('english_stem', 'running');
postgres=# -- {run}
postgres=# SELECT ts_lexize('english_stem', 'the');
postgres=# -- {}   (empty = stop word)
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Config Mismatch
Here is a common beginner trap. If you create an expression index with one language configuration but search with a different one, the index will NOT be used. The configuration in the WHERE clause must exactly match the one used in the index.

```sql
-- Index created with 'english':
CREATE INDEX idx_fts ON articles
USING GIN (to_tsvector('english', body));
-- This uses the index (config matches):
SELECT * FROM articles
WHERE to_tsvector('english', body)
   @@ to_tsquery('english', 'postgresql');
-- ✓ Bitmap Index Scan on idx_fts
-- This does NOT use the index:
SELECT * FROM articles
WHERE to_tsvector('simple', body)
   @@ to_tsquery('simple', 'postgresql');
-- ✗ Sequential Scan (different config!)
-- Fix: always use the same config in index and query
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Store tsvector in a generated column or trigger-maintained column. Create a GIN index for fast lookups — GIN is the default choice over GiST. Use setweight with the stored column to weight title over body. The text search configuration controls stemming and stop words — english is the default, simple does no stemming. Create custom configurations with synonym dictionaries for domain vocabulary. Always match the configuration between your index and your queries. In the next class, we explore JSON and JSONB — storing and querying structured data inside PostgreSQL.

- **Generated column: GENERATED ALWAYS AS (to_tsvector(...)) STORED**
- **Trigger column: more control, custom logic, manual backfill**
- **GIN index: default choice — fast reads, inverted index**
- **GiST index: smaller, faster writes, slower reads**
- **Expression index: no stored column, but must match exactly**
- **fastupdate: off for read-heavy, on (default) for balanced**
- **Configs: english (stems), simple (no stemming), custom**
- **Synonym dictionary: map domain terms (PG → postgresql)**
- **ts_debug: see how text is parsed and processed**
- **Config in WHERE must match config in index**
- **Next: JSON & JSONB Deep Dive**


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
