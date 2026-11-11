# Optimization Techniques & pg_stat_statements
**Series:** PostgreSQL Mastery | **Phase:** Phase 20: Query Optimization & Performance | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! So far in this phase we have learned to read EXPLAIN plans, understand scan types, and how the planner picks join algorithms. Now we bring it all together with practical optimization techniques you can apply right away — and pg_stat_statements, the extension that shows you which queries are actually slowest in your database. Let us begin.

### The Optimization Problem
Before optimizing anything, you need to know WHAT to optimize. Most beginners guess — they look at a query and think it is slow. But the real bottleneck is often a different query entirely. pg_stat_statements tracks every query that runs, how many times it ran, and how much total time it consumed. It answers the question: where is my database spending its time?


---

## 2. Core Technical Concepts & Mechanisms

### The Optimization Problem
Before optimizing anything, you need to know WHAT to optimize. Most beginners guess — they look at a query and think it is slow. But the real bottleneck is often a different query entirely. pg_stat_statements tracks every query that runs, how many times it ran, and how much total time it consumed. It answers the question: where is my database spending its time?

| Term | Meaning / Explanation |
| :--- | :--- |
| **The Wrong Way** | Guess which query is slow, optimize it, hope for the best |
| **The Right Way** | Measure with pg_stat_statements, find the TOP queries by total time, optimize those |
| **The 80/20 Rule** | Often 3-5 queries consume 80% of database time — fix those first |

**Notes:**
- A query running 10ms × 100,000 times = 1,000 seconds total
- A query running 5 seconds × 10 times = 50 seconds total
- The first one matters MORE despite being 'fast'

### pg_stat_statements Diagnostic Queries
Here are the most useful pg_stat_statements queries for finding performance problems. Each one answers a different question about your workload.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are the most useful pg_stat_statements queries for finding performance problems |
| **Point 2** | Each one answers a different question about your workload |

### Technique 3: Query Rewrites — Anti-Patterns
Technique three: rewrite queries to avoid common anti-patterns. Functions on indexed columns prevent index usage. OR conditions may prevent index usage. SELECT * fetches unnecessary columns. LIKE with a leading wildcard cannot use an index.

| Bad — Index Cannot Be Used | Good — Index Can Be Used |
| :--- | :--- |
| WHERE UPPER(name) = 'ALICE' | WHERE name = 'Alice' (+ citext) |
| WHERE amount + 10 > 100 | WHERE amount > 90 |
| WHERE date_trunc('month', created) = ... | WHERE created >= '2026-01-01' AND ... |
| SELECT * FROM orders WHERE ... | SELECT id, amount FROM orders WHERE ... |
| WHERE name LIKE '%alice%' | WHERE name LIKE 'alice%' (prefix only) |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Technique 5: Keyset Pagination vs OFFSET
Technique five: optimize pagination. Many applications use OFFSET for pagination — page 1 is OFFSET 0, page 2 is OFFSET 50, page 100 is OFFSET 5000. The problem? PostgreSQL must scan and discard all rows before the offset. Page 100 scans 5000 rows to show 50. Keyset pagination avoids this entirely.

| OFFSET (Gets Slower) | Keyset (Constant Speed) |
| :--- | :--- |
| Page 1: OFFSET 0 LIMIT 50 | Page 1: WHERE id > 0 ORDER BY id LIMIT 50 |
| Page 100: OFFSET 4950 LIMIT 50 | Page 2: WHERE id > last_id ORDER BY id LIMIT 50 |
| Page 1000: OFFSET 49950 LIMIT 50 | Page 1000: WHERE id > last_id ORDER BY id LIMIT 50 |
| Must scan & discard all skipped rows | Index seek directly to the right spot |
| Gets slower on every page | Same speed on every page |
| O(N) — linear degradation | O(1) — constant time |

### Optimization Decision Framework
Here is a decision framework for choosing the right optimization technique based on what you see in EXPLAIN output.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a decision framework for choosing the right optimization technique based on what you see in EXPLAIN output |

### Optimization Workflow Checklist
Here is your optimization checklist — a summary of everything covered in this class. Follow this workflow whenever you need to optimize query performance.

- 1. Enable pg_stat_statements — find the REAL slow queries
- 2. Pick the top 3-5 queries by total_exec_time
- 3. Run EXPLAIN (ANALYZE, BUFFERS) on each
- 4. Check: missing indexes? Add them (CREATE INDEX)
- 5. Check: function on column? Create expression index
- 6. Check: only need a subset? Create partial index
- 7. Check: sort/hash disk spill? Increase work_mem per session
- 8. Check: stale stats? Run ANALYZE
- 9. Check: high Heap Fetches? Add covering index (INCLUDE)
- 10. Check: OFFSET pagination? Switch to keyset pagination
- 11. Monitor: re-check pg_stat_statements after changes
- 12. Clean up: drop unused indexes periodically


---

## 3. Hands-On Commands & psql Output

### Create pg_stat_statements Extension
**Explanation:** After restarting, create the extension and verify it works.

```sql
postgres=# -- Create the extension:
postgres=# CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
postgres=# -- Verify it is loaded:
postgres=# SELECT * FROM pg_stat_statements LIMIT 1;
postgres=# -- Reset statistics (start fresh):
postgres=# SELECT pg_stat_statements_reset();
postgres=# -- Now run some queries to generate data:
postgres=# SELECT count(*) FROM orders;
postgres=# SELECT * FROM customers WHERE id = 42;
postgres=# SELECT o.id, c.name FROM orders o JOIN customers c
postgres-# ON o.customer_id = c.id WHERE o.status = 'shipped';
postgres=# -- Repeat a few times to build up statistics...
```

### Top 10 Slowest Queries by Total Time
**Explanation:** Now the powerful part. This query shows you the top 10 slowest queries by total execution time. The total_exec_time column is the cumulative time — if a query ran 10,000 times at 2 milliseconds each, that is 20 seconds of total time. The mean_exec_time shows the average per call.

```sql
SELECT
  queryid,
  calls,
  ROUND(total_exec_time::numeric, 2) AS total_ms,
  ROUND(mean_exec_time::numeric, 2)  AS avg_ms,
  ROUND(min_exec_time::numeric, 2)   AS min_ms,
  ROUND(max_exec_time::numeric, 2)   AS max_ms,
  rows,
  LEFT(query, 60) AS query_preview
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- queryid: unique hash of the normalized query
-- calls: how many times this query ran
-- total_exec_time: cumulative execution time (ms)
-- mean_exec_time: average per execution (ms)
-- rows: total rows returned across all calls
```

### Query Normalization — Patterns, Not Literals
**Explanation:** pg_stat_statements normalizes queries — it replaces literal values with $1, $2 placeholders. So SELECT * FROM orders WHERE id = 5 and SELECT * FROM orders WHERE id = 999 are counted as the same query pattern. This grouping is critical — it shows you patterns, not individual calls.

```sql
postgres=# -- These three queries:
postgres=# SELECT * FROM orders WHERE id = 5;
postgres=# SELECT * FROM orders WHERE id = 999;
postgres=# SELECT * FROM orders WHERE id = 42;
postgres=# -- Become ONE entry in pg_stat_statements:
postgres=# --   query: SELECT * FROM orders WHERE id = $1
postgres=# --   calls: 3
postgres=# -- View normalized queries:
postgres=# SELECT query, calls
postgres-# FROM pg_stat_statements
postgres-# WHERE query LIKE '%orders%'
postgres-# ORDER BY calls DESC;
         query                          | calls
postgres=# ----------------------------------------+-------
postgres=# SELECT * FROM orders WHERE id = $1     |     3
postgres=# SELECT count(*) FROM orders            |     2
postgres=# SELECT * FROM orders WHERE status = $1 |     1
```

### Technique 1: Add the Right Index
**Explanation:** Now that you can find slow queries, let us cover optimization techniques. Technique one: add the right index. This is the single most impactful optimization in most databases. If EXPLAIN shows a Sequential Scan on a large table for a selective WHERE clause, adding an index on that column can improve performance by orders of magnitude.

```sql
postgres=# -- Before index — Sequential Scan:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM orders WHERE customer_id = 42;
 Seq Scan on orders  (cost=0.00..1459.00 rows=51 width=32)
                     (actual time=0.034..6.234 rows=48 loops=1)
   Filter: (customer_id = 42)
   Rows Removed by Filter: 49952
 Execution Time: 6.289 ms
postgres=# -- Add index:
postgres=# CREATE INDEX idx_orders_customer_id ON orders(customer_id);
postgres=# -- After index — Index Scan:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM orders WHERE customer_id = 42;
 Index Scan using idx_orders_customer_id on orders
   (cost=0.29..10.75 rows=51 width=32)
   (actual time=0.025..0.089 rows=48 loops=1)
   Index Cond: (customer_id = 42)
 Execution Time: 0.118 ms
postgres=# -- 6.289 ms → 0.118 ms = 53x faster!
```

### Technique 2: Covering Index (Index Only Scan)
**Explanation:** Technique two: use covering indexes to avoid table lookups entirely. When all columns your query needs are in the index, PostgreSQL can do an Index Only Scan — it never touches the table heap. This is especially powerful for frequently-run queries that only need a few columns.

```sql
postgres=# -- Query only needs customer_id and amount:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT customer_id, amount
postgres-# FROM orders WHERE customer_id = 42;
postgres=# -- Still Index Scan — must fetch 'amount' from table heap
postgres=# -- Create covering index using INCLUDE:
postgres=# CREATE INDEX idx_orders_cust_cover
postgres-# ON orders(customer_id) INCLUDE (amount);
postgres=# EXPLAIN ANALYZE
postgres=# SELECT customer_id, amount
postgres-# FROM orders WHERE customer_id = 42;
 Index Only Scan using idx_orders_cust_cover on orders
   (cost=0.29..4.52 rows=51 width=14)
   (actual time=0.022..0.045 rows=48 loops=1)
   Index Cond: (customer_id = 42)
   Heap Fetches: 0     ← zero table access!
 Execution Time: 0.067 ms
postgres=# -- Heap Fetches: 0 = pure index read
```

### Expression Indexes — Index a Function Result
**Explanation:** If you must search with a function like UPPER or LOWER, create an expression index. PostgreSQL indexes the result of the function, so UPPER(name) can use the index.

```sql
postgres=# -- Without expression index:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM customers WHERE UPPER(name) = 'CUSTOMER_42';
 Seq Scan on customers (actual time=0.023..0.345 rows=1 loops=1)
   Filter: (upper(name) = 'CUSTOMER_42')
   Rows Removed by Filter: 999
postgres=# -- Create expression index:
postgres=# CREATE INDEX idx_customers_upper_name
postgres-# ON customers (UPPER(name));
postgres=# -- Now it uses the index:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM customers WHERE UPPER(name) = 'CUSTOMER_42';
 Index Scan using idx_customers_upper_name on customers
   (actual time=0.018..0.019 rows=1 loops=1)
   Index Cond: (upper(name) = 'CUSTOMER_42')
```

### Technique 4: Partial Indexes
**Explanation:** Technique four: use partial indexes when you only query a subset of the data. If 95% of your queries filter on status = 'pending', a partial index on just pending rows is smaller, faster, and cheaper to maintain.

```sql
postgres=# -- Full index on status — indexes ALL 50,000 rows:
postgres=# CREATE INDEX idx_orders_status ON orders(status);
postgres=# -- Partial index — only 'pending' rows (~10,000 rows):
postgres=# CREATE INDEX idx_orders_pending
postgres-# ON orders(status)
postgres-# WHERE status = 'pending';
postgres=# -- Compare sizes:
postgres=# SELECT indexname,
       pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
postgres-# FROM pg_indexes
postgres-# WHERE tablename = 'orders'
postgres-# AND indexname LIKE 'idx_orders_%';
      indexname       | size
postgres=# ---------------------+-------
 idx_orders_status   | 384 kB   ← all rows
 idx_orders_pending  | 112 kB   ← only pending rows
postgres=# -- Partial index is used automatically when WHERE matches:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM orders WHERE status = 'pending';
postgres=# -- Uses idx_orders_pending (smaller, faster)
```

### Keyset Pagination — Constant Speed Demo
**Explanation:** Here is the keyset pagination pattern in action. Notice how the execution time stays constant regardless of which page you are on.

```sql
postgres=# -- OFFSET approach (page 1000):
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM orders
postgres-# ORDER BY id
OFFSET 49950 LIMIT 50;
 Limit (actual time=28.456..28.472 rows=50 loops=1)
   -> Index Scan using orders_pkey on orders
      (actual time=0.015..22.345 rows=50000 loops=1)
 Execution Time: 28.512 ms
postgres=# -- Keyset approach (same page, id > 49950):
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM orders
postgres-# WHERE id > 49950
postgres-# ORDER BY id
postgres-# LIMIT 50;
 Limit (actual time=0.025..0.042 rows=50 loops=1)
   -> Index Scan using orders_pkey on orders
      (actual time=0.023..0.038 rows=50 loops=1)
      Index Cond: (id > 49950)
 Execution Time: 0.068 ms
postgres=# -- 28.512 ms → 0.068 ms = 419x faster on page 1000!
```

### Technique 6: EXISTS vs IN for Subqueries
**Explanation:** Technique six: use EXISTS instead of IN for subqueries. When the subquery could return many rows, IN must build the entire list before filtering. EXISTS can stop at the first match.

```sql
postgres=# -- IN subquery — builds entire list first:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM customers c
postgres-# WHERE c.id IN (
postgres=# SELECT customer_id FROM orders
postgres-# WHERE amount > 400
);
postgres=# -- EXISTS — stops at first match per customer:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM customers c
postgres-# WHERE EXISTS (
postgres=# SELECT 1 FROM orders o
postgres-# WHERE o.customer_id = c.id
postgres-# AND o.amount > 400
);
postgres=# -- Modern PostgreSQL often optimizes both to the same plan
postgres=# -- But EXISTS is safer when:
postgres=# --   • The subquery returns many duplicates
postgres=# --   • The subquery is correlated
postgres=# --   • You want to short-circuit early
```

### Technique 7: Per-Query work_mem Tuning
**Explanation:** Technique seven: tune work_mem for sort-heavy and hash-heavy queries. Instead of setting work_mem globally to a high value — which risks using too much memory when many connections run complex queries at once — set it per-session or per-transaction for known heavy queries.

```sql
postgres=# -- Check current work_mem:
postgres=# SHOW work_mem;
postgres=# -- 4MB (default)
postgres=# -- A heavy report query spills to disk:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT customer_id, SUM(amount) AS total
postgres-# FROM orders
postgres-# GROUP BY customer_id
postgres-# ORDER BY total DESC;
postgres=# -- Sort Method: external merge  Disk: 1234kB  ← BAD
postgres=# -- Increase work_mem just for this session:
postgres=# SET work_mem = '128MB';
postgres=# -- Re-run — now fits in memory:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT customer_id, SUM(amount) AS total
postgres-# FROM orders
postgres-# GROUP BY customer_id
postgres-# ORDER BY total DESC;
postgres=# -- Sort Method: quicksort  Memory: 1024kB  ← GOOD
postgres=# -- Reset for safety:
RESET work_mem;
```

### Beginner Trap: Too Many Indexes
**Explanation:** A common beginner trap: creating too many indexes. Every index slows down INSERT, UPDATE, and DELETE because PostgreSQL must update all indexes when data changes. More is not better. Target your indexes to the queries pg_stat_statements shows are actually slow. And periodically check for unused indexes.

```sql
postgres=# -- Find unused indexes (wasting space + slowing writes):
postgres=# SELECT s.indexrelname AS index_name,
       s.idx_scan AS times_used,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size,
       s.relname AS table_name
postgres-# FROM pg_stat_user_indexes s
postgres-# WHERE s.idx_scan = 0
postgres-# AND pg_relation_size(s.indexrelid) > 1024 * 1024
postgres-# ORDER BY pg_relation_size(s.indexrelid) DESC;
   index_name           | times_used | size   | table_name
postgres=# ------------------------+------------+--------+-----------
 idx_orders_old_status  |          0 | 2048kB | orders
 idx_customers_email_v2 |          0 | 512kB  | customers
postgres=# -- These indexes are NEVER used — only slowing writes
postgres=# -- Safe to drop after confirming with the team:
postgres=# -- DROP INDEX idx_orders_old_status;
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf — Enable the Extension` — Enable pg_stat_statements
To enable pg_stat_statements, add it to shared_preload_libraries in postgresql.conf and restart PostgreSQL. Then create the extension in your database. This is a one-time setup.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `shared_preload_libraries` | `'pg_stat_statements'` | **`[RESTART]`** (Postmaster Restart) | Load the extension at server start (requires restart) (Default: '') |
| `pg_stat_statements.max` | `5000` | `[SETTING]` | Maximum number of statements tracked (default 5000) |
| `pg_stat_statements.track` | `top` | `[SETTING]` | Track top-level statements (use 'all' for nested too) |
| `compute_query_id` | `on` | `[SETTING]` | Required in PG 14+ for query identification |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Too Many Indexes
A common beginner trap: creating too many indexes. Every index slows down INSERT, UPDATE, and DELETE because PostgreSQL must update all indexes when data changes. More is not better. Target your indexes to the queries pg_stat_statements shows are actually slow. And periodically check for unused indexes.

```sql
-- Find unused indexes (wasting space + slowing writes):
SELECT s.indexrelname AS index_name,
       s.idx_scan AS times_used,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size,
       s.relname AS table_name
FROM pg_stat_user_indexes s
WHERE s.idx_scan = 0
AND pg_relation_size(s.indexrelid) > 1024 * 1024
ORDER BY pg_relation_size(s.indexrelid) DESC;
   index_name           | times_used | size   | table_name
------------------------+------------+--------+-----------
 idx_orders_old_status  |          0 | 2048kB | orders
 idx_customers_email_v2 |          0 | 512kB  | customers
-- These indexes are NEVER used — only slowing writes
-- Safe to drop after confirming with the team:
-- DROP INDEX idx_orders_old_status;
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Use pg_stat_statements to find queries consuming the most total time — optimize those first, not what you guess is slow. The main optimization techniques are: adding the right index, covering indexes with INCLUDE, expression indexes for function-based filters, partial indexes for subsets, keyset pagination instead of OFFSET, EXISTS over IN for large subqueries, and per-session work_mem tuning. Always EXPLAIN ANALYZE before and after changes to verify improvement. In the next class, we cover Index Only Scans, parallel query execution, and JIT compilation.

- **pg_stat_statements: tracks every query's calls, time, rows**
- **ORDER BY total_exec_time DESC = your optimization hit list**
- **Queries are normalized ($1 placeholders) — shows patterns**
- **Index: fastest single optimization — check EXPLAIN for Seq Scans**
- **Covering index (INCLUDE): eliminates Heap Fetches**
- **Expression index: enables index use on UPPER(), LOWER(), etc.**
- **Partial index: smaller + faster for common WHERE patterns**
- **Keyset pagination: constant speed vs OFFSET degradation**
- **EXISTS: short-circuits vs IN building full list**
- **work_mem: SET per session for heavy sorts/hashes**
- **Drop unused indexes — they slow writes for no benefit**
- **Next: Index Only Scans, Parallel Queries & JIT**


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
