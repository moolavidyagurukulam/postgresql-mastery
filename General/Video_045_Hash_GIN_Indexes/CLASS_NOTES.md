# Hash & GIN Indexes — Equality and Composite Search
**Series:** PostgreSQL Mastery | **Phase:** Phase 12: Indexes | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover two specialized index types. Hash indexes are optimized for equality-only lookups — faster than B-Tree when you only ever search with equals. GIN indexes — Generalized Inverted Indexes — are designed for searching INSIDE values: arrays, JSONB documents, and full-text search. Each solves a specific problem that B-Tree cannot handle efficiently. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Hash Index — Equality Only
A Hash index stores a hash of each value. When you search WHERE email = 'test@example.com', PostgreSQL hashes the search value and jumps directly to the bucket. It is faster than B-Tree for pure equality because there is no tree traversal. But hash indexes ONLY support equals — no range queries, no sorting, no MIN/MAX. Since PostgreSQL 10, hash indexes are WAL-logged and crash-safe, so they are production-ready in PostgreSQL 16.

| Term | Meaning / Explanation |
| :--- | :--- |
| **How** | Hashes the value → jumps to bucket → finds row pointer |
| **Supports** | ONLY the = operator (equality) |
| **Does NOT support** | No <, >, BETWEEN, ORDER BY, MIN, MAX |
| **When to use** | Column searched ONLY with = and never with range queries |
| **Size** | Often smaller than B-Tree for the same data |

**Notes:**
- WAL-logged since PG 10 — safe for production in PG 16
- B-Tree also handles = well, so Hash is a niche optimization

### Hash vs B-Tree — When to Choose
In practice, B-Tree handles equality well enough that Hash indexes are rarely needed. Use Hash only when you are certain the column is NEVER searched with range operators and you want to save disk space. The most common real-world use case is a session token or UUID column that is only ever looked up by exact value.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Hash indexes** | rarely needed |
| **Use Hash only when you** | certain the column is NEVER searched with range operators and you want to save disk space |
| **The most common real-world** | case is a session token or UUID column that is only ever looked up by exact value |

### GIN — Generalized Inverted Index
Now let us move to GIN — Generalized Inverted Index. This is a completely different beast. A GIN index indexes the ELEMENTS inside a composite value. For an array column containing the tags 'red', 'blue', 'green', the GIN index creates separate entries for each tag pointing back to the row. This means you can search for any row that CONTAINS 'red' — and the index finds it instantly. GIN works for arrays, JSONB, full-text search, and tsvector columns.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | Indexes ELEMENTS inside composite values |
| **Arrays** | Search rows containing specific array elements |
| **JSONB** | Search keys and values inside JSONB documents |
| **Full-Text** | Search words inside text documents (tsvector) |
| **Operators** | @> (contains), ? (key exists), @@ (text match) |

**Notes:**
- B-Tree cannot search INSIDE arrays or JSONB — GIN can
- Slow to build, fast to search

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### GIN Index Tradeoffs
GIN indexes are slow to build because they must decompose every value into its elements and index each one. They are also larger than B-Tree indexes. But once built, searches are very fast. For write-heavy tables, consider the fastupdate option — it batches index updates for better write performance at the cost of slightly slower searches until the batch is applied.

| Strengths | Weaknesses |
| :--- | :--- |
| Search INSIDE arrays, JSONB, tsvector | Slow to build (indexes every element) |
| Very fast read performance | Larger than B-Tree for same data |
| Supports containment (@>), exists (?), text (@@) | Write overhead (every INSERT updates many entries) |
| Essential for full-text search | fastupdate helps but adds search latency |
| Replaces Elasticsearch for many cases | Not for simple equality or range queries |

### Practice Exercises
Practice exercises: create a Hash index on a column and test equality versus range queries. Create a GIN index on an array column and search with the contains operator. Create a JSONB table with a GIN index and search for specific keys. Compare index sizes between Hash, B-Tree, and GIN.

- 1. CREATE INDEX USING hash on a VARCHAR column
- 2. EXPLAIN with = (uses Hash) vs > (Seq Scan)
- 3. CREATE TABLE with TEXT[] column, add GIN index
- 4. Search arrays with @> operator
- 5. CREATE TABLE with JSONB, add GIN index
- 6. Search JSONB with @> and ? operators
- 7. Compare index sizes: Hash vs B-Tree vs GIN


---

## 3. Hands-On Commands & psql Output

### Creating and Using Hash Indexes
**Explanation:** Let us create a Hash index and compare it with B-Tree. We will create two indexes on the same column — one B-Tree and one Hash — and look at the EXPLAIN output. You will see that when you use equals, both work, but Hash is more compact. When you use a range query, only B-Tree works.

```sql
-- Create a Hash index
practice=# CREATE INDEX idx_orders_status_hash
ON orders USING hash (status);
CREATE INDEX

-- Equality query uses the Hash index
practice=# EXPLAIN SELECT * FROM orders WHERE status = 'shipped';
 Index Scan using idx_orders_status_hash on orders
   Index Cond: (status = 'shipped'::text)

-- Range query CANNOT use Hash index
-- WHERE status > 'p' → falls back to Seq Scan

-- Compare sizes: Hash vs B-Tree on same column
practice=# CREATE INDEX idx_orders_status_btree ON orders (status);
CREATE INDEX

practice=# SELECT pg_size_pretty(pg_relation_size('idx_orders_status_hash'));
 256 kB   -- Hash: compact
practice=# SELECT pg_size_pretty(pg_relation_size('idx_orders_status_btree'));
 2208 kB  -- B-Tree: larger
```

### GIN Index on Arrays
**Explanation:** Let us see GIN in action with arrays. We create a products table with a tags array column, add a GIN index, and search for products that contain specific tags. Without GIN, PostgreSQL must scan every row and check every array. With GIN, it jumps directly to matching rows.

```sql
-- Table with array column
practice=# CREATE TABLE products (
  id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name  VARCHAR(100),
  tags  TEXT[]
);

practice=# INSERT INTO products (name, tags) VALUES
('Laptop', ARRAY['electronics','portable','computing']),
('Phone', ARRAY['electronics','mobile','portable']),
('Desk', ARRAY['furniture','office']),
('Chair', ARRAY['furniture','office','ergonomic']);

-- GIN index on the array column
practice=# CREATE INDEX idx_products_tags ON products USING gin (tags);
CREATE INDEX

-- Search: products that contain 'portable'
practice=# SELECT name, tags FROM products WHERE tags @> ARRAY['portable'];
  name  |            tags
--------+-----------------------------
 Laptop | {electronics,portable,computing}
 Phone  | {electronics,mobile,portable}
```

### GIN Index on JSONB
**Explanation:** GIN is essential for JSONB columns. When you store JSON documents in PostgreSQL, a GIN index lets you search for specific keys, values, or nested paths without scanning every document. The jsonb_ops operator class indexes all keys and values. The jsonb_path_ops class is smaller and faster but only supports the containment operator. For most JSONB use cases, jsonb_path_ops is the better choice.

```sql
-- Table with JSONB column
practice=# CREATE TABLE events (
  id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  data JSONB
);

practice=# INSERT INTO events (data) VALUES
('{"type":"click","page":"/home","user_id":1}'),
('{"type":"view","page":"/products","user_id":2}'),
('{"type":"click","page":"/cart","user_id":1}');

-- Default GIN: indexes all keys and values
practice=# CREATE INDEX idx_events_data ON events USING gin (data);

-- Search: containment operator @>
practice=# SELECT * FROM events WHERE data @> '{"type":"click"}';

-- Key exists: ? operator
practice=# SELECT * FROM events WHERE data ? 'user_id';

-- Smaller, faster: jsonb_path_ops (only supports @>)
-- CREATE INDEX idx_events_path
--   ON events USING gin (data jsonb_path_ops);
```

### GIN for Full-Text Search
**Explanation:** GIN also powers full-text search. When you create a tsvector column — a preprocessed text search column — and add a GIN index, PostgreSQL can search millions of documents by keyword almost instantly. This replaces the need for external search engines like Elasticsearch for many use cases.

```sql
-- Table with text content
practice=# CREATE TABLE articles (
  id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title   TEXT,
  body    TEXT,
  search  TSVECTOR
);

practice=# INSERT INTO articles (title, body, search) VALUES
('PG Indexes', 'B-Tree is the default index type',
 to_tsvector('B-Tree is the default index type'));

-- GIN index on the tsvector column
practice=# CREATE INDEX idx_articles_search
ON articles USING gin (search);
CREATE INDEX

-- Full-text search using @@ operator
practice=# SELECT title FROM articles
WHERE search @@ to_tsquery('index & default');
    title
-------------
 PG Indexes
```


---

## 6. Hands-On Practice Exercises & Verified Answer Key

### Practice Challenges

1. **Hash Equality Verification:** Build a Hash index on `orders(customer_id)`. Run `EXPLAIN` on an equality search (`WHERE customer_id = 42`) and compare it with a range query (`WHERE customer_id > 42`).
2. **Array Containment with GIN:** Index the `tags` array column in `products` using GIN. Query products matching the tag `'portable'` using the containment operator `@>`.
3. **JSONB Search Multi-Operators:** Query the `events` table to find all mobile device clicks using `@>`, and test for the existence of an `amount` key using `?`.
4. **Operator Class Footprint Benchmark:** Compare on-disk size between `idx_events_data` (`jsonb_ops`) and `idx_events_data_path` (`jsonb_path_ops`).
5. **Full-Text Inverted Indexing:** Create a GIN index on `articles(search)` and query for articles mentioning both `'postgres'` and `'index'` using `to_tsquery('english', 'postgres & index')`.

---

### Verified Solutions & Explanations

#### Exercise 1: Hash Index Equality Lookup
```sql
CREATE INDEX idx_orders_cust_hash
ON orders USING hash (customer_id);

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_id = 42;
```
*Explanation:* Hash indexes calculate a 32-bit hash code to jump straight to the target bucket in $O(1)$ constant time. Range queries (`> 42`) cannot use hash codes and fall back to sequential scans.

#### Exercise 2: Array Containment with GIN
```sql
CREATE INDEX idx_products_tags
ON products USING gin (tags);

SELECT name, tags
FROM products
WHERE tags @> ARRAY['portable'];
```
*Explanation:* GIN inverts the array by indexing every individual element. Searching for `'portable'` performs a Bitmap Index Scan directly against the `'portable'` posting list.

#### Exercise 3: JSONB Containment & Existence
```sql
-- Containment:
SELECT * FROM events WHERE data @> '{"device":"mobile"}';

-- Top-level key existence:
SELECT * FROM events WHERE data ? 'amount';
```
*Explanation:* The default `jsonb_ops` operator class breaks JSONB documents into distinct keys, paths, and values, supporting both containment (`@>`) and existence (`?`, `?|`, `?&`) operators.

#### Exercise 4: Operator Class Comparison
```sql
CREATE INDEX idx_events_data_path
ON events USING gin (data jsonb_path_ops);

SELECT
  pg_size_pretty(pg_relation_size('idx_events_data')) AS jsonb_ops_size,
  pg_size_pretty(pg_relation_size('idx_events_data_path')) AS path_ops_size;
```
*Explanation:* `jsonb_path_ops` hashes entire path-value pairs rather than individual keys, reducing index size by 40–50% and speeding up `@>` queries at the cost of not supporting key existence (`?`).

#### Exercise 5: Full-Text Search with GIN
```sql
CREATE INDEX idx_articles_search
ON articles USING gin (search);

SELECT title
FROM articles
WHERE search @@ to_tsquery('english', 'postgres & index');
```
*Explanation:* `to_tsvector` parses text into normalized lexemes. GIN stores these lexemes in its Entry Tree, allowing complex Boolean queries (`&`, `|`, `!`) to be resolved via bitwise postings intersection.


## 7. Key Takeaways & Cheat Sheet

Let us recap. Hash indexes are for equality-only lookups — smaller than B-Tree but cannot do ranges or sorting. Use them for UUIDs, tokens, and exact-match columns. GIN indexes search INSIDE composite values — arrays, JSONB, and full-text tsvector columns. GIN is slow to build but fast to search. Use GIN whenever you need to search inside arrays, query JSONB documents, or do full-text search. In the next class, we cover GiST, BRIN, and SP-GiST — indexes for geometric data, range types, and very large sorted tables. See you there!

- **Hash: CREATE INDEX ... USING hash (col)**
- **Hash: equality (=) only, no range/sort**
- **Hash: smaller than B-Tree, niche optimization**
- **GIN: CREATE INDEX ... USING gin (col)**
- **GIN: searches INSIDE arrays, JSONB, tsvector**
- **GIN operators: @> (contains), ? (exists), @@ (text)**
- **GIN: slow build, fast search**
- **jsonb_path_ops: smaller GIN, only supports @>**


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
