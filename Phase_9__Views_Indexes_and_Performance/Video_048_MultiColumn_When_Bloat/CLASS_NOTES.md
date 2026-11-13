# Multi-Column Indexes, When to Index & Index Bloat
**Series:** PostgreSQL Mastery | **Phase:** Phase 12: Indexes | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this final class on indexes, we cover three critical topics. Multi-column indexes and the leftmost prefix rule — how PostgreSQL uses a composite index and which column order matters. When to add and when to remove indexes — the strategy for a balanced indexing approach. And index bloat — why indexes grow over time and how REINDEX fixes it. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Multi-Column Index — Leftmost Prefix Rule
A multi-column index — also called a composite index — indexes two or more columns together. CREATE INDEX ON orders (customer_id, order_date) creates a B-Tree sorted first by customer_id, then within each customer by order_date. The critical rule: the LEFTMOST PREFIX rule. This index can be used for queries on customer_id alone, or customer_id AND order_date together. But it CANNOT be used for queries on order_date alone — because order_date is not the leftmost column.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Index** | CREATE INDEX ... ON table (A, B, C); |
| **Can use** | WHERE A = ... (uses the index) |
| **Can use** | WHERE A = ... AND B = ... (uses the index) |
| **Can use** | WHERE A = ... AND B = ... AND C = ... (uses all) |
| **CANNOT use** | WHERE B = ... (leftmost column A is missing!) |

**Notes:**
- Column order matters! Put the most selective column first
- Also called composite index or compound index

### Column Order Strategy
Column order in a multi-column index matters. Put the most selective column first — the one that filters out the most rows. If customer_id narrows to 100 rows and status narrows to 25,000 rows, put customer_id first. Also consider which column is queried independently: if you often query by customer_id alone but never by status alone, customer_id must be first so the leftmost prefix rule works.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Column order in a multi** | column index matters |
| **Put the most selective column first** | the one that filters out the most rows |
| **Point 3** | If customer_id narrows to 100 rows and status narrows to 25,000 rows, put customer_id first |
| **Point 4** | Also consider which column is queried independently: if you often query by customer_id alone but never by status alone, customer_id must be first so the leftmost prefix rule works |

### Index Strategy — Step by Step
When should you add an index? Start with the obvious candidates: foreign keys, columns in frequent WHERE clauses, and columns used in JOIN conditions. Then use EXPLAIN ANALYZE on your slowest queries to see which ones do sequential scans on large tables. Do not index blindly — every index slows down writes and uses disk space. A table with ten indexes has ten structures to update on every INSERT.

- 1. Primary keys: automatic (do nothing)
- 2. Unique constraints: automatic (do nothing)
- 3. Foreign keys: CREATE INDEX on EVERY FK column
- 4. Frequent WHERE columns: index the top 3-5 filters
- 5. JOIN columns: index both sides of frequent JOINs
- 6. EXPLAIN ANALYZE: find Seq Scans on large tables
- 7. Check pg_stat_user_indexes: drop unused indexes (idx_scan = 0)

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Index Bloat — Why Indexes Grow
Index bloat happens when dead tuples accumulate in the index. When you UPDATE or DELETE a row, PostgreSQL does not immediately remove the old index entry — it marks it as dead. VACUUM cleans up dead entries in the table, but index cleanup can lag behind, especially on busy tables. Over time, the index grows larger than necessary, wasting space and slowing down scans. REINDEX rebuilds the index from scratch, eliminating all bloat.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Cause** | UPDATE/DELETE leaves dead entries in the index |
| **Effect** | Index grows larger than needed, slower scans |
| **Detection** | Compare pg_relation_size to estimated ideal size |
| **Fix: REINDEX** | REINDEX INDEX idx_name; — rebuilds from scratch |
| **Fix: CONCURRENTLY** | REINDEX INDEX CONCURRENTLY idx_name; (PG 12+) |

**Notes:**
- Regular VACUUM helps but doesn't fully compact indexes
- REINDEX CONCURRENTLY doesn't lock the table for reads

### Production Indexing Rules
Here is a complete decision framework for indexing in production. These rules cover the most common scenarios you will encounter when managing indexes on real PostgreSQL databases.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a complete decision framework for indexing in production |
| **Point 2** | These rules cover the most common scenarios you will encounter when managing indexes on real PostgreSQL databases |

### Practice Exercises
Practice exercises: create multi-column indexes and test the leftmost prefix rule, find unused indexes with pg_stat_user_indexes, check for duplicate indexes, practice REINDEX, and review the complete indexing strategy.

- 1. CREATE INDEX (A, B) — test with WHERE A, WHERE B, WHERE A AND B
- 2. Verify leftmost prefix rule with EXPLAIN
- 3. Find unused indexes: idx_scan = 0
- 4. Find duplicate indexes: same indexdef
- 5. REINDEX a single index, then REINDEX TABLE
- 6. Check index sizes before/after REINDEX
- 7. Review: which columns should be indexed?


---

## 3. Hands-On Commands & psql Output

### Multi-Column Index in Action
**Explanation:** Let us create a multi-column index and test which queries use it. The index on customer_id, status will handle queries that filter by customer_id, or by customer_id AND status together. But a query filtering only by status cannot use this index — it needs its own separate index.

```sql
-- Multi-column index: customer_id + status
practice=# CREATE INDEX idx_orders_cust_status
ON orders (customer_id, status);
CREATE INDEX

-- ✓ Uses index: leftmost column present
practice=# EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
 Index Scan using idx_orders_cust_status
   Index Cond: (customer_id = 42)

-- ✓ Uses index: both columns present
practice=# EXPLAIN SELECT * FROM orders
WHERE customer_id = 42 AND status = 'pending';
 Index Scan using idx_orders_cust_status
   Index Cond: (customer_id = 42 AND status = 'pending')

-- ✗ CANNOT use index: leftmost column missing
practice=# EXPLAIN SELECT * FROM orders WHERE status = 'pending';
 Seq Scan on orders
   Filter: (status = 'pending'::text)
-- Needs a separate index on (status) if this is frequent
```

### Finding and Removing Unused Indexes
**Explanation:** Just as important as adding indexes is removing them. Unused indexes waste disk space and slow down writes for zero benefit. Query pg_stat_user_indexes — any index with idx_scan equal to zero has NEVER been used since the last statistics reset. Before dropping, check how long statistics have been accumulating — an index used only during monthly reports might show zero scans most of the time.

```sql
-- Find indexes that have NEVER been scanned
practice=# SELECT
  schemaname, relname AS table, indexrelname AS index,
  idx_scan, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- Check when stats were last reset
practice=# SELECT stats_reset FROM pg_stat_bgwriter;

-- If stats have been running for weeks and idx_scan = 0,
-- the index is likely unused — safe to drop

-- Drop unused index
-- DROP INDEX idx_never_used;

-- Duplicate indexes: same columns, different names
practice=# SELECT indexdef, COUNT(*) FROM pg_indexes
WHERE schemaname = 'public'
GROUP BY indexdef HAVING COUNT(*) > 1;
```

### Detecting and Fixing Index Bloat
**Explanation:** Let us see how to detect and fix index bloat. Check the index size, compare it to what you would expect, and use REINDEX to rebuild. In production, always use REINDEX CONCURRENTLY to avoid locking the table. You can also use the pgstattuple extension for a detailed bloat analysis.

```sql
-- Check index sizes
practice=# SELECT
  indexrelname AS index_name,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size,
  idx_scan AS scans
FROM pg_stat_user_indexes
WHERE relname = 'orders'
ORDER BY pg_relation_size(indexrelid) DESC;

-- REINDEX a single index
practice=# REINDEX INDEX idx_orders_cust_status;
REINDEX

-- REINDEX all indexes on a table
practice=# REINDEX TABLE orders;
REINDEX

-- Production: CONCURRENTLY (no lock, PG 12+)
practice=# REINDEX INDEX CONCURRENTLY idx_orders_cust_status;
REINDEX

-- REINDEX entire database (maintenance window)
-- REINDEX DATABASE practice;
```


---


## 6. Hands-On Practice Exercises & Verified Solutions

### Exercise 1: Multi-Column Composite Index
**Challenge:** Create a composite index on `orders(status, order_date)` and evaluate queries that satisfy the leftmost prefix rule.
```sql
CREATE INDEX idx_orders_status_date ON orders (status, order_date);

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE status = 'pending' AND order_date > '2024-01-01';
```
*Explanation:* Because `status` is the leftmost column, PostgreSQL traverses the B-Tree directly to `'pending'` entries, then scans the sorted `order_date` branch.

### Exercise 2: Auditing Unused Production Indexes
**Challenge:** Query PostgreSQL system catalogs to locate every index that has zero scans recorded.
```sql
SELECT
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS times_scanned,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;
```
*Explanation:* Identifies dead indexes consuming write amplification and disk space without delivering query acceleration.

### Exercise 3: Calculating Index Storage Overhead Ratio
**Challenge:** Calculate the percentage of total disk storage consumed by indexes compared to heap table data for `orders`.
```sql
SELECT
    pg_size_pretty(pg_table_size('orders')) AS table_size,
    pg_size_pretty(pg_indexes_size('orders')) AS total_indexes_size,
    ROUND(100.0 * pg_indexes_size('orders') / pg_table_size('orders'), 1) AS index_pct;
```
*Explanation:* Ratios exceeding 150-200% indicate severe B-Tree bloat or redundant overlapping indexes.

### Exercise 4: Zero-Downtime Concurrent Reindexing
**Challenge:** Rebuild all indexes on the `orders` table concurrently without locking application queries.
```sql
REINDEX TABLE CONCURRENTLY orders;
```
*Explanation:* `CONCURRENTLY` builds duplicate indexes in the background, swaps catalog pointers atomically, and drops the bloated structures without acquiring `AccessExclusiveLock`.

### Exercise 5: Foreign Key Indexing
**Challenge:** Create an index on `order_items(order_id)` to eliminate table locks during foreign key cascade operations.
```sql
CREATE INDEX idx_order_items_order_id ON order_items (order_id);
```
*Explanation:* Prevents sequential scans across child tables during parent row deletions and accelerates foreign key joins.


## 7. Key Takeaways & Cheat Sheet

Let us recap the entire Indexes phase. B-Tree is the default for 90 percent of use cases. Hash for equality only. GIN for arrays, JSONB, and full-text search. GiST for ranges, geometry, and exclusion constraints. BRIN for huge sorted tables. Partial indexes save space by indexing only a subset. Expression indexes handle functions in WHERE. Covering indexes with INCLUDE enable Index Only Scans. Multi-column indexes follow the leftmost prefix rule. Monitor unused indexes and fix bloat with REINDEX. This completes the Indexes phase! In the next phase, we start Transactions and Concurrency — BEGIN, COMMIT, ROLLBACK, ACID, isolation levels, and locking. See you there!

- **B-Tree: default, =/</>/ BETWEEN/ORDER BY**
- **Hash: = only | GIN: arrays/JSONB/text | GiST: ranges/geo**
- **BRIN: tiny index for huge sorted tables**
- **Partial: WHERE clause limits indexed rows**
- **Expression: index on LOWER(col), EXTRACT(...)**
- **Covering: INCLUDE (col) for Index Only Scan**
- **Multi-column: leftmost prefix rule**
- **Monitor: pg_stat_user_indexes, REINDEX for bloat**


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
