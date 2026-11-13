# What Is an Index? B-Tree Deep Dive
**Series:** PostgreSQL Mastery | **Phase:** Phase 12: Indexes | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we tackle one of the most important topics in database performance — indexes. An index is a separate data structure that helps PostgreSQL find rows faster, just like a book index helps you find topics without reading every page. We will understand why indexes matter, how B-Tree indexes work internally, create indexes, and use EXPLAIN to see them in action. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Without Index vs With Index
Imagine a table with one million rows. You run SELECT * FROM orders WHERE customer_id = 42. Without an index, PostgreSQL must read EVERY row in the table to find the ones that match. This is called a sequential scan — it reads every single page on disk. With a million rows, that is slow. An index is a shortcut — a sorted structure that points directly to the matching rows. With an index, PostgreSQL finds customer_id = 42 in a few page reads instead of scanning the entire table.

| Without Index (Seq Scan) | With Index (Index Scan) |
| :--- | :--- |
| Reads EVERY row in the table | Jumps directly to matching rows |
| Checks each row against WHERE | Reads only the relevant pages |
| 1 million rows = 1 million checks | 1 million rows = ~3-4 page reads |
| Slow for large tables | Fast even for huge tables |
| Fine for small tables (<10K rows) | Small cost: extra disk space + write overhead |

### B-Tree Index Structure
A B-Tree — short for balanced tree — is the default index type in PostgreSQL. Think of it like a phone book. At the top is the root node. It points to internal nodes, which point to leaf nodes. The leaf nodes contain the actual index entries — each entry has the indexed value and a pointer to the row in the table. Because the tree is balanced, every lookup takes the same number of steps — O(log N). For a million rows, that is about 20 steps. For a billion rows, about 30 steps.

```
[Root Node
[50]]
[Internal
[20, 35]]
[Internal
[65, 80]]
[Leaf
5,10,15]
[Leaf
22,28,33]
[Leaf
52,58,63]
[Leaf
67,72,78]
```

### B-Tree — Default Index Type
B-Tree supports equality and range queries. It handles equals, less than, greater than, BETWEEN, IN, ORDER BY, and MIN/MAX efficiently. It is the default — when you write CREATE INDEX with no type specified, you get a B-Tree. It works for most columns and most query patterns. About 90 percent of all indexes in production databases are B-Trees.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Equality** | WHERE id = 42 — finds exact match in ~3 steps |
| **Range** | WHERE price > 100 AND price < 500 — scans leaf range |
| **Sorting** | ORDER BY name — walks leaf nodes in order, no sort needed |
| **MIN/MAX** | SELECT MIN(price) — reads first/last leaf entry |
| **BETWEEN / IN** | WHERE id BETWEEN 10 AND 50 — efficient range scan |

**Notes:**
- Default: CREATE INDEX = B-Tree
- ~90% of production indexes are B-Trees

### Index Scan Types
There are three scan types you will see with indexes. Index Scan fetches the index entry and then goes to the table to get the full row. Index Only Scan is even better — it reads only the index, without visiting the table, when all the columns you need are in the index. Bitmap Index Scan is used when many rows match — PostgreSQL builds a bitmap of matching pages, then reads them in physical order to avoid random I/O.

| Term | Meaning / Explanation |
| :--- | :--- |
| **There** | three scan types you will see with indexes |
| **Index Only Scan** | even better — it reads only the index, without visiting the table, when all the columns you need are in the index |
| **Bitmap Index Scan** | used when many rows match — PostgreSQL builds a bitmap of matching pages, then reads them in physical order to avoid ... |

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Index Costs and Benefits
Every index has a cost. It uses disk space — often 10 to 30 percent of the table size. Every INSERT, UPDATE, and DELETE must also update the index, which slows down writes. Too many indexes on a write-heavy table can hurt performance more than they help. The sweet spot: index columns used in WHERE, JOIN, and ORDER BY clauses of your most frequent queries. Do not index every column blindly.

| Benefits (Reads) | Costs (Writes + Storage) |
| :--- | :--- |
| WHERE lookups: O(log N) instead of O(N) | Extra disk space (10-30% of table size) |
| JOIN conditions: fast matching between tables | INSERT: must add entry to every index |
| ORDER BY: already sorted, no sort step needed | UPDATE: old entry deleted, new entry added |
| MIN/MAX: instant from first/last leaf | DELETE: entry must be marked dead |
| Unique constraints enforced via index | VACUUM must clean index dead entries too |

### Should You Add an Index?
Here is the key decision framework for indexing. Primary keys and unique constraints automatically get an index — you do not need to create one. Foreign key columns should almost always be indexed — without one, JOINs and CASCADE deletes are slow. Columns in frequent WHERE clauses are strong candidates. Columns used only in INSERT statements do not need indexes. And remember: for small tables under a few thousand rows, PostgreSQL will just do a sequential scan regardless.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Primary keys and unique constraints automatically get an index — you do not need to create one |
| **Point 2** | Foreign key columns should almost always be indexed — without one, JOINs and CASCADE deletes are slow |
| **Point 3** | Columns in frequent WHERE clauses are strong candidates |
| **Point 4** | Columns used only in INSERT statements do not need indexes |
| **And remember** | for small tables under a few thousand rows, PostgreSQL will just do a sequential scan regardless |

### Practice Exercises
Practice exercises: create a large test table, run EXPLAIN without an index, create a B-Tree index, run EXPLAIN again, compare costs, check index size, create a multi-column index and test the leftmost rule, list indexes with backslash di, and try CREATE INDEX CONCURRENTLY.

- 1. Create a table with 100K rows using generate_series
- 2. EXPLAIN SELECT ... WHERE col = value (Seq Scan)
- 3. CREATE INDEX on that column
- 4. EXPLAIN again — see Index Scan
- 5. Compare cost numbers before/after
- 6. pg_size_pretty(pg_relation_size('idx_name'))
- 7. Multi-column index: (customer_id, order_date)
- 8. Test leftmost rule: query only order_date
- 9. \di to list all indexes
- 10. REINDEX to rebuild a bloated index


---

## 3. Hands-On Commands & psql Output

### Setup: Create Test Data
**Explanation:** Let us create a test table with a large number of rows and see the difference an index makes. We will use generate_series to create one hundred thousand orders, then query without an index — seeing a sequential scan — then create an index and see the query plan change to an index scan.

```sql
-- Create a table with 100K rows for testing
practice=# CREATE TABLE orders (
  id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id INT,
  order_date  DATE,
  amount      NUMERIC(10,2),
  status      VARCHAR(20)
);
CREATE TABLE

practice=# INSERT INTO orders (customer_id, order_date, amount, status)
SELECT
  (RANDOM() * 1000 + 1)::INT,
  '2023-01-01'::DATE + (RANDOM() * 730)::INT,
  ROUND((RANDOM() * 990 + 10)::NUMERIC, 2),
  (ARRAY['pending','shipped','delivered','cancelled'])
    [FLOOR(RANDOM()*4+1)::INT]
FROM generate_series(1, 100000);
INSERT 0 100000
```

### EXPLAIN — Before and After Index
**Explanation:** Now let us see EXPLAIN in action. EXPLAIN shows the query plan — how PostgreSQL will execute the query. Without an index on customer_id, it does a sequential scan. The cost numbers show estimated startup cost and total cost. Rows shows estimated matching rows. After we create an index, the same query switches to an index scan — much faster.

```sql
-- Before index: Sequential Scan (reads all rows)
practice=# EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
                       QUERY PLAN
--------------------------------------------------------
 Seq Scan on orders  (cost=0.00..2137.00 rows=98
   Filter: (customer_id = 42)

-- Create index on customer_id
practice=# CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX

-- After index: Index Scan (jumps to matching rows)
practice=# EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
                       QUERY PLAN
--------------------------------------------------------
 Index Scan using idx_orders_customer on orders
   (cost=0.29..12.45 rows=98)
   Index Cond: (customer_id = 42)
```

### When PostgreSQL Ignores the Index
**Explanation:** PostgreSQL does NOT always use an index even when one exists. If the query returns a large percentage of the table — say more than 10 to 15 percent — a sequential scan is actually faster because sequential disk reads are cheaper than random jumps. The query planner decides based on table statistics. After loading data, run ANALYZE to update statistics so the planner makes good decisions.

```sql
-- Returns ~25% of rows: planner chooses Seq Scan
practice=# EXPLAIN SELECT * FROM orders WHERE status = 'pending';
 Seq Scan on orders  (cost=0.00..2137.00 rows=25032)
   Filter: (status = 'pending'::text)

-- Even with an index, planner prefers Seq Scan
-- because reading 25% of rows sequentially is faster
-- than 25,000 random index lookups

-- Update statistics so planner has accurate info
practice=# ANALYZE orders;
ANALYZE

-- Force an index scan (for testing only, not production!)
-- SET enable_seqscan = off;
-- Trust the planner — it's usually right
```

### Managing Indexes
**Explanation:** Let us look at how to manage indexes. Use backslash di to list indexes in psql. Query pg_indexes for programmatic access. Use DROP INDEX to remove an index. CREATE INDEX CONCURRENTLY builds the index without locking writes — essential for production tables. The common error: trying to create an index that already exists. Use IF NOT EXISTS to avoid that.

```sql
-- List all indexes
practice=# \di
                 List of relations
 Schema |       Name        | Type  | Owner    | Table
--------+-------------------+-------+----------+--------
 public | orders_pkey       | index | postgres | orders
 public | idx_orders_customer| index | postgres | orders

-- Query pg_indexes for details
practice=# SELECT indexname, indexdef FROM pg_indexes
WHERE tablename = 'orders';

-- Check index size
practice=# SELECT pg_size_pretty(pg_relation_size('idx_orders_customer'));
 pg_size_pretty
----------------
 2208 kB

-- Drop an index
-- DROP INDEX idx_orders_customer;

-- Production: build without locking writes
-- CREATE INDEX CONCURRENTLY idx_name ON table (col);
```

### Common Index Errors
**Explanation:** A common error: trying to create an index with a name that already exists. Use CREATE INDEX IF NOT EXISTS to avoid this. Also note that the primary key column already has an index — do not create a duplicate. And when creating indexes on production tables with active traffic, always use CONCURRENTLY to avoid blocking writes.

```sql
-- ERROR: index already exists
practice=# CREATE INDEX idx_orders_customer ON orders (customer_id);
ERROR:  relation "idx_orders_customer" already exists

-- Fix: use IF NOT EXISTS
practice=# CREATE INDEX IF NOT EXISTS idx_orders_customer
ON orders (customer_id);
NOTICE:  relation "idx_orders_customer" already exists, skipping
CREATE INDEX

-- Don't index the primary key — it already has one!
-- CREATE INDEX ON orders (id); ← waste of space!

-- Production: CONCURRENTLY avoids write locks
practice=# CREATE INDEX CONCURRENTLY idx_orders_date
ON orders (order_date);
CREATE INDEX
-- Takes longer but doesn't block INSERT/UPDATE/DELETE
```

### Multi-Column Indexes & Leftmost Rule
**Explanation:** Multi-column indexes cover queries that filter on multiple columns. CREATE INDEX ON orders (customer_id, order_date) helps queries that filter on customer_id alone, OR on customer_id AND order_date together. But it does NOT help queries that filter only on order_date. The leftmost column rule: the index is useful for queries starting from the leftmost column. Think of it like a phone book sorted by last name, then first name — you can look up by last name, or by last name plus first name, but not by first name alone.

```sql
practice=# CREATE INDEX idx_orders_cust_date
ON orders (customer_id, order_date);
CREATE INDEX

-- Works: leftmost column present
practice=# EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
 Index Scan using idx_orders_cust_date on orders

-- Works: both columns present
practice=# EXPLAIN SELECT * FROM orders
WHERE customer_id = 42 AND order_date > '2024-01-01';
 Index Scan using idx_orders_cust_date on orders

-- Does NOT use this index: leftmost column missing!
practice=# EXPLAIN SELECT * FROM orders WHERE order_date > '2024-06-01';
 Seq Scan on orders
   Filter: (order_date > '2024-06-01')

-- Rule: (A, B) index helps A, and A+B, but NOT B alone
```

### Beginner Trap: Index Bloat & REINDEX
**Explanation:** Beginner trap: indexes can get bloated over time. As you UPDATE and DELETE rows, dead entries accumulate in the index. VACUUM cleans dead table rows but is less effective at reclaiming index space. REINDEX rebuilds an index from scratch, eliminating bloat. Use REINDEX CONCURRENTLY in production to avoid locking. Check index bloat by comparing pg_relation_size of the index to the expected size based on row count.

```sql
-- Check index size vs table size
practice=# SELECT
  pg_size_pretty(pg_relation_size('orders')) AS table_size,
  pg_size_pretty(pg_relation_size('idx_orders_customer'))
    AS index_size;
 table_size | index_size
------------+-----------
 7168 kB    | 2208 kB

-- Rebuild a bloated index
practice=# REINDEX INDEX idx_orders_customer;
REINDEX

-- Production: REINDEX CONCURRENTLY (PG 12+)
-- REINDEX INDEX CONCURRENTLY idx_orders_customer;

-- Rebuild all indexes on a table
-- REINDEX TABLE orders;
-- REINDEX TABLE CONCURRENTLY orders;
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Index Bloat & REINDEX
Beginner trap: indexes can get bloated over time. As you UPDATE and DELETE rows, dead entries accumulate in the index. VACUUM cleans dead table rows but is less effective at reclaiming index space. REINDEX rebuilds an index from scratch, eliminating bloat. Use REINDEX CONCURRENTLY in production to avoid locking. Check index bloat by comparing pg_relation_size of the index to the expected size based on row count.

```sql
-- Check index size vs table size
SELECT
  pg_size_pretty(pg_relation_size('orders')) AS table_size,
  pg_size_pretty(pg_relation_size('idx_orders_customer'))
    AS index_size;
 table_size | index_size
------------+-----------
 7168 kB    | 2208 kB

-- Rebuild a bloated index
REINDEX INDEX idx_orders_customer;
REINDEX

-- Production: REINDEX CONCURRENTLY (PG 12+)
-- REINDEX INDEX CONCURRENTLY idx_orders_customer;

-- Rebuild all indexes on a table
-- REINDEX TABLE orders;
-- REINDEX TABLE CONCURRENTLY orders;
```


---

## 6. Hands-On Practice Exercises & Verified Answer Key

### Practice Challenges

1. **Unindexed Performance Baseline:** Run `EXPLAIN (ANALYZE, BUFFERS)` on an unindexed filter condition and note the execution cost, buffer reads, and sequential scan operation.
2. **Concurrent Index Creation:** Build a B-Tree index on `orders(amount)` using `CREATE INDEX CONCURRENTLY` and explain why this syntax is required on production databases.
3. **Planner Selectivity Comparison:** Compare the execution plans for `WHERE amount > 990` versus `WHERE amount > 10`. Explain why the planner chooses a sequential scan for the second query despite an index existing.
4. **Index Only Scan Verification:** Query only the indexed column (`order_date`) with an equality filter and verify that the plan achieves an `Index Only Scan` without reading heap table pages.
5. **Index Maintenance Monitoring:** Query `pg_stat_user_indexes` and `pg_relation_size` to inspect the on-disk size of all indexes on `orders` and count how many times each index has been scanned.

---

### Verified Solutions & Explanations

#### Exercise 1: Baseline Unindexed Scan
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE amount > 950;
```
*Explanation:* Scans every 8KB data page in the heap sequentially. Without an index, cost scales linearly with table size.

#### Exercise 2: Online Concurrent Indexing
```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_amount
ON orders(amount);
```
*Explanation:* Standard `CREATE INDEX` acquires a `ShareLock` that blocks all concurrent writes (`INSERT`, `UPDATE`, `DELETE`). `CONCURRENTLY` builds the index in two transactions without blocking DML.

#### Exercise 3: Selectivity Threshold (Index vs Seq Scan)
```sql
-- High selectivity (small % of rows):
EXPLAIN SELECT * FROM orders WHERE amount > 990; -- Uses Index Scan

-- Low selectivity (large % of rows):
EXPLAIN SELECT * FROM orders WHERE amount > 10;  -- Uses Seq Scan
```
*Explanation:* When a query matches more than ~5-10% of a table, random I/O from index lookups is slower than sequential page scanning. The optimizer correctly falls back to a sequential scan.

#### Exercise 4: Index Only Scan
```sql
EXPLAIN SELECT order_date
FROM orders
WHERE order_date = '2024-06-15';
```
*Explanation:* When every column referenced in `SELECT` and `WHERE` is present in the B-Tree leaf node, and the table visibility map confirms tuples are unmodified, PostgreSQL never touches the table heap.

#### Exercise 5: Usage & Footprint Inspection
```sql
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
       idx_scan AS number_of_scans
FROM pg_stat_user_indexes
WHERE relname = 'orders'
ORDER BY idx_scan DESC;
```
*Explanation:* Unused indexes consume disk space and slow down every `INSERT`/`UPDATE`. Regularly review `idx_scan` to safely identify and drop redundant indexes.


## 7. Key Takeaways & Cheat Sheet

Let us recap. An index is a separate data structure that speeds up lookups — like a book index. B-Tree is the default index type, supporting equality, range, sorting, and MIN/MAX queries. Use EXPLAIN to see if your query uses an index. PostgreSQL may choose a sequential scan for large result sets — trust the planner. Indexes cost disk space and slow down writes. Index foreign keys, frequent WHERE columns, and let primary keys and unique constraints auto-index. In the next class, we cover Hash and GIN indexes — for equality-only lookups and JSONB or array searches. See you there!

- **Index = sorted structure for fast lookups**
- **B-Tree: default, supports =, <, >, BETWEEN, ORDER BY**
- **CREATE INDEX name ON table (column);**
- **EXPLAIN shows: Seq Scan → Index Scan → Index Only Scan**
- **Planner chooses Seq Scan when >10-15% of rows match**
- **ANALYZE updates statistics for the planner**
- **Cost: disk space + write overhead per index**
- **CONCURRENTLY: build index without locking writes**


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
