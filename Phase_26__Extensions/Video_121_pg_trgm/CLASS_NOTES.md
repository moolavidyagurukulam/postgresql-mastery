# pg_trgm — Fuzzy Text Matching
**Series:** PostgreSQL Mastery | **Phase:** Phase 26: Extensions | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Users make typos. They search for 'Postgre' instead of 'PostgreSQL', or 'Jon' when they mean 'John'. LIKE and ILIKE cannot handle these fuzzy matches. pg_trgm — the trigram extension — solves this. It measures how similar two strings are and enables fast similarity searches. Perfect for autocomplete, search-as-you-type, and handling misspellings. Let us learn how it works.


---

## 2. Core Technical Concepts & Mechanisms

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### GIN vs GiST Trigram Indexes
GIN versus GiST for trigram indexes — when to use which. GIN is faster for reads and better for most search workloads. GiST is faster for writes and better for the distance operator with KNN queries. In most cases, choose GIN.

| Term | Meaning / Explanation |
| :--- | :--- |
| **GIN versus GiST for trigram indexes** | when to use which |
| **Point 2** | GIN is faster for reads and better for most search workloads |
| **Point 3** | GiST is faster for writes and better for the distance operator with KNN queries |
| **Point 4** | In most cases, choose GIN |

### pg_trgm Operators Reference
Here is a reference of all pg_trgm operators. The percent operator checks similarity, the angle-bracket-arrow returns distance, and the word-level variants use double angle brackets.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a reference of all pg_trgm operators. The percent operator checks similarity, the angle-bracket-arrow returns distance,... |

### pg_trgm Performance Tips
Performance tips. Always create a trigram index — without it, similarity searches scan the entire table. Use GIN for read-heavy workloads and GiST when you need KNN ordering. Lower the threshold cautiously — too low returns too many false positives.

| Do This | Avoid This |
| :--- | :--- |
| Always create a trigram index | Fuzzy search without an index |
| GIN for read-heavy workloads | Threshold too low (false positives) |
| GiST for KNN (ORDER BY <->) | Comparing very long strings (slow) |
| Use LIMIT with fuzzy queries | Ignoring EXPLAIN output |
| Combine with FTS for best results | Using % on unindexed columns |
| lower() for case-insensitive matching | Forgetting GIN for ILIKE indexing |


---

## 3. Hands-On Commands & psql Output

### What Are Trigrams?
**Explanation:** A trigram is a group of three consecutive characters from a string. PostgreSQL breaks every string into trigrams and compares the overlapping sets. The more trigrams two strings share, the more similar they are. For example, the word 'cat' produces the trigrams: two-spaces-c, space-c-a, c-a-t, and a-t-space.

```sql
postgres=# -- Install pg_trgm (trusted — no restart needed):
postgres=# CREATE EXTENSION pg_trgm;
postgres=# -- See trigrams of a word:
postgres=# SELECT show_trgm('cat');
postgres=# -- {"  c"," ca","at ","cat"}
postgres=# SELECT show_trgm('PostgreSQL');
postgres=# -- {"  p"," po","esq","gre","ostg","pos","ql ",
postgres=# --  "res","sql","stg","tgr"}
postgres=# -- Two similar words share many trigrams:
postgres=# SELECT show_trgm('John');
postgres=# -- {"  j"," jo","hn ","joh","ohn"}
postgres=# SELECT show_trgm('Jon');
postgres=# -- {"  j"," jo","jon","on "}
postgres=# -- Shared: "  j", " jo" — they are similar!
```

### similarity() — Measuring String Closeness
**Explanation:** The similarity function returns a number between 0 and 1. Zero means completely different, one means identical. The default threshold is 0.3 — strings with similarity above this are considered a match. You can adjust this threshold.

```sql
postgres=# -- Similarity score (0 to 1):
postgres=# SELECT similarity('PostgreSQL', 'PostgreSQL');
postgres=# -- 1.0 (identical)
postgres=# SELECT similarity('PostgreSQL', 'Postgre');
postgres=# -- 0.5384615 (similar)
postgres=# SELECT similarity('PostgreSQL', 'MySQL');
postgres=# -- 0.09090909 (very different)
postgres=# SELECT similarity('John', 'Jon');
postgres=# -- 0.333333 (above threshold — match!)
postgres=# SELECT similarity('John', 'Jane');
postgres=# -- 0.142857 (below threshold — no match)
postgres=# -- Check/set the threshold:
postgres=# SHOW pg_trgm.similarity_threshold;
postgres=# -- 0.3 (default)
postgres=# SET pg_trgm.similarity_threshold = 0.2;
postgres=# -- Lower = more fuzzy matches
```

### Operators: % (Similar) and <-> (Distance)
**Explanation:** The percent operator checks if two strings are similar above the threshold. The distance operator returns 1 minus similarity — useful for ORDER BY closest match. These operators can use indexes for fast lookups.

```sql
postgres=# -- % operator: true if similarity > threshold
postgres=# SELECT 'PostgreSQL' % 'Postgre';
postgres=# -- true (0.54 > 0.3)
postgres=# SELECT 'PostgreSQL' % 'MySQL';
postgres=# -- false (0.09 < 0.3)
postgres=# -- <-> operator: distance (1 - similarity)
postgres=# -- Lower = more similar (good for ORDER BY)
postgres=# SELECT 'PostgreSQL' <-> 'Postgre';
postgres=# -- 0.461538 (1 - 0.538462)
postgres=# SELECT 'PostgreSQL' <-> 'PostgreSQL';
postgres=# -- 0 (identical — zero distance)
postgres=# -- Practical: find closest match:
postgres=# SELECT name FROM products
postgres-# WHERE name % 'Postgre'
postgres-# ORDER BY name <-> 'Postgre'
postgres-# LIMIT 5;
```

### Practical: Product Search with Trigrams
**Explanation:** Let us build a practical example. A products table with a GIN or GiST trigram index. This makes similarity searches fast — even on millions of rows.

```sql
postgres=# CREATE TABLE products (
    id serial PRIMARY KEY,
    name text NOT NULL,
    category text
);
postgres=# INSERT INTO products (name, category) VALUES
('PostgreSQL Handbook', 'Books'),
('MySQL Quick Guide', 'Books'),
('MongoDB in Action', 'Books'),
('Mechanical Keyboard', 'Electronics'),
('Wireless Mouse', 'Electronics'),
('PostgreSQL Sticker Pack', 'Merchandise'),
('Database T-Shirt', 'Merchandise');
postgres=# -- Create GIN trigram index:
postgres=# CREATE INDEX idx_products_trgm ON products
postgres-# USING gin (name gin_trgm_ops);
postgres=# -- Fuzzy search:
postgres=# SELECT name, similarity(name, 'Postgre') AS sim
postgres-# FROM products
postgres-# WHERE name % 'Postgre'
postgres-# ORDER BY name <-> 'Postgre';
postgres=# -- PostgreSQL Handbook      | 0.35
postgres=# -- PostgreSQL Sticker Pack  | 0.28
```

### Indexed LIKE / ILIKE with Trigrams
**Explanation:** pg_trgm also supercharges LIKE and ILIKE queries. Normally, LIKE with a leading wildcard — percent something percent — cannot use a B-tree index. But with a GIN trigram index, it can. This is a huge performance win.

```sql
postgres=# -- Without pg_trgm — %pattern% cannot use index:
postgres=# EXPLAIN SELECT * FROM products
postgres-# WHERE name ILIKE '%keyboard%';
postgres=# -- Seq Scan (full table scan — slow!)
postgres=# -- With GIN trigram index — it CAN use index:
postgres=# CREATE INDEX idx_products_trgm ON products
postgres-# USING gin (name gin_trgm_ops);
postgres=# EXPLAIN SELECT * FROM products
postgres-# WHERE name ILIKE '%keyboard%';
postgres=# -- Bitmap Index Scan using idx_products_trgm
postgres=# -- (fast — uses the index!)
postgres=# -- Works with LIKE, ILIKE, ~ (regex) too:
postgres=# SELECT * FROM products WHERE name ILIKE '%sql%';
postgres=# -- PostgreSQL Handbook
postgres=# -- MySQL Quick Guide
postgres=# -- This is often reason enough to install pg_trgm
postgres=# -- even without fuzzy search
```

### word_similarity() — Word-Level Matching
**Explanation:** word_similarity and strict_word_similarity compare at the word level rather than the whole string. This is useful when searching for a word within a longer text — like finding 'keyboard' in 'Mechanical Keyboard RGB'.

```sql
postgres=# -- similarity compares entire strings:
postgres=# SELECT similarity('keyboard', 'Mechanical Keyboard');
postgres=# -- 0.238095 (low — strings differ in length)
postgres=# -- word_similarity finds the best matching word:
postgres=# SELECT word_similarity('keyboard', 'Mechanical Keyboard');
postgres=# -- 1.0 (perfect — 'keyboard' matches a word exactly!)
postgres=# -- Operators for word similarity:
postgres=# -- <<% and %>> (word_similarity threshold check)
postgres=# -- <<-> and <->> (word distance)
postgres=# SELECT name FROM products
postgres-# WHERE 'keyboard' <<% name
postgres-# ORDER BY 'keyboard' <<-> name;
postgres=# -- Mechanical Keyboard
postgres=# -- strict_word_similarity: even stricter matching
postgres=# SELECT strict_word_similarity('key', 'Mechanical Keyboard');
postgres=# -- Matches only at word boundaries
```

### Building Autocomplete Search
**Explanation:** Let us build a complete autocomplete search. As the user types, we find the closest matching products — handling typos, partial words, and abbreviations.

```sql
postgres=# -- GiST index for KNN ordering:
postgres=# CREATE INDEX idx_products_trgm_gist ON products
postgres-# USING gist (name gist_trgm_ops);
postgres=# -- Autocomplete as user types 'post':
postgres=# SELECT name, similarity(name, 'post') AS score
postgres-# FROM products
postgres-# WHERE name % 'post'
postgres-# ORDER BY name <-> 'post'
postgres-# LIMIT 5;
postgres=# -- PostgreSQL Handbook      | 0.176
postgres=# -- PostgreSQL Sticker Pack  | 0.148
postgres=# -- Handle typo: 'mechancal' (misspelled):
postgres=# SET pg_trgm.similarity_threshold = 0.2;
postgres=# SELECT name, similarity(name, 'mechancal') AS score
postgres-# FROM products
postgres-# WHERE name % 'mechancal'
postgres-# ORDER BY name <-> 'mechancal'
postgres-# LIMIT 5;
postgres=# -- Mechanical Keyboard  | 0.25
```

### Combining Trigrams + Full-Text Search
**Explanation:** Combining pg_trgm with full-text search gives you the best of both worlds. Use trigrams for typo tolerance and full-text search for relevance ranking. Here is a hybrid approach.

```sql
postgres=# -- Add a tsvector column:
postgres=# ALTER TABLE products
    ADD COLUMN search_vector tsvector;
postgres=# UPDATE products SET search_vector =
    to_tsvector('english', name || ' ' || coalesce(category, ''));
postgres=# CREATE INDEX idx_products_fts ON products USING gin (search_vector);
postgres=# -- Hybrid search function:
postgres=# -- 1. Try exact FTS first
postgres=# -- 2. Fall back to fuzzy trigram if no FTS results
postgres=# -- Step 1: FTS (fast, exact):
postgres=# SELECT name FROM products
postgres-# WHERE search_vector @@ to_tsquery('english', 'postgresql');
postgres=# -- Step 2: If no results, try fuzzy:
postgres=# SELECT name FROM products
postgres-# WHERE name % 'postgre'
postgres-# ORDER BY name <-> 'postgre'
postgres-# LIMIT 5;
```

### Deduplication with Trigrams
**Explanation:** pg_trgm also works great for deduplication — finding similar records that might be duplicates. Compare every pair of records and flag those above a similarity threshold.

```sql
postgres=# -- Find potential duplicate products:
postgres=# SELECT a.id, a.name, b.id, b.name,
    similarity(a.name, b.name) AS sim
postgres-# FROM products a
postgres-# JOIN products b ON a.id < b.id
postgres-# WHERE similarity(a.name, b.name) > 0.4
postgres-# ORDER BY sim DESC;
postgres=# -- Example: might catch
postgres=# -- 'PostgreSQL Handbook' vs 'PostgresQL Handbook' (typo)
postgres=# -- 'Wireless Mouse' vs 'Wireless Mouse Pro'
postgres=# -- For customer deduplication:
postgres=# -- SELECT a.id, b.id, similarity(a.email, b.email)
postgres=# -- FROM customers a JOIN customers b ON a.id < b.id
postgres=# -- WHERE similarity(a.name, b.name) > 0.5
postgres=# --   AND similarity(a.email, b.email) > 0.6;
```

### Beginner Trap: Threshold vs String Length
**Explanation:** A common beginner trap — the similarity threshold is too high for short strings. Short words have fewer trigrams, so their similarity scores are naturally lower. You may need to lower the threshold for searching short terms.

```sql
postgres=# -- Short strings have fewer trigrams:
postgres=# SELECT show_trgm('DB');
postgres=# -- {"  d"," db","db "} — only 3 trigrams
postgres=# SELECT show_trgm('Database Management System');
postgres=# -- Many trigrams — more to compare
postgres=# -- Default threshold 0.3 may miss short matches:
postgres=# SELECT similarity('DB', 'Database');
postgres=# -- 0.1 — below 0.3 threshold!
postgres=# -- Fix: lower threshold for short search terms:
postgres=# SET pg_trgm.similarity_threshold = 0.1;
postgres=# -- Or: use word_similarity for better short-term matching
postgres=# -- Another trap: trigrams are case-sensitive!
postgres=# -- 'Cat' and 'cat' have different trigrams
postgres=# -- Fix: use lower() or citext:
postgres=# SELECT similarity(lower('Cat'), lower('CAT'));
postgres=# -- 1.0 (identical after lowering)
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Threshold vs String Length
A common beginner trap — the similarity threshold is too high for short strings. Short words have fewer trigrams, so their similarity scores are naturally lower. You may need to lower the threshold for searching short terms.

```sql
-- Short strings have fewer trigrams:
SELECT show_trgm('DB');
-- {"  d"," db","db "} — only 3 trigrams
SELECT show_trgm('Database Management System');
-- Many trigrams — more to compare
-- Default threshold 0.3 may miss short matches:
SELECT similarity('DB', 'Database');
-- 0.1 — below 0.3 threshold!
-- Fix: lower threshold for short search terms:
SET pg_trgm.similarity_threshold = 0.1;
-- Or: use word_similarity for better short-term matching
-- Another trap: trigrams are case-sensitive!
-- 'Cat' and 'cat' have different trigrams
-- Fix: use lower() or citext:
SELECT similarity(lower('Cat'), lower('CAT'));
-- 1.0 (identical after lowering)
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. pg_trgm breaks strings into trigrams for similarity comparison. The similarity function returns 0 to 1 — higher means more similar. The percent operator checks if strings are similar above the threshold. GIN trigram indexes make LIKE, ILIKE, and similarity searches fast. word_similarity matches at the word level — better for search-in-text. Combine with full-text search for the best search experience. In the next class, we learn hstore — a key-value data type.

- **Trigrams: groups of 3 consecutive characters**
- **similarity(): returns 0-1 closeness score**
- **% operator: above threshold = match**
- **<-> operator: distance for ORDER BY**
- **GIN index: fast LIKE, ILIKE, similarity**
- **GiST index: fast KNN ordering**
- **word_similarity(): word-level matching**
- **Indexes ILIKE '%pattern%' (normally impossible)**
- **Great for: autocomplete, typo handling, dedup**
- **Default threshold 0.3 — adjust for short strings**
- **Next: hstore — Key-Value Data Type**


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
