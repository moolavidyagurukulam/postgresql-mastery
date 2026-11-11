# Real-World Optimization Scenarios
**Series:** PostgreSQL Mastery | **Phase:** Phase 20: Query Optimization & Performance | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! This is the final class of Phase 20 — Query Optimization and Performance. In this class we bring together everything we have learned and work through real-world optimization scenarios. Each scenario presents a slow query, shows you how to diagnose it using EXPLAIN, and walks through the fix step by step. Let us begin.

### Real-World Optimization
Scenarios
Welcome back to PostgreSQL Mastery! This is the final class of Phase 20 — Query Optimization and Performance. In this class we bring together everything we have learned and work through real-world optimization scenarios. Each scenario presents a slow query, shows you how to diagnose it using EXPLAIN, and walks through the fix step by step. Let us begin.

### Scenario 1: Slow Dashboard — The Problem
Scenario one: the slow dashboard query. Your application dashboard shows recent orders with customer names. Users report it takes 3 seconds to load. Let us diagnose it.

### Scenario 1: The Fix — Composite Index
The fix: create a composite index on the two columns used in WHERE and ORDER BY. Since we filter on status and sort by order_date descending, the index should be (status, order_date DESC). This lets PostgreSQL go directly to the pending rows in sorted order.

### Scenario 2: Slow Monthly Report — The Problem
Scenario two: the slow report query. A monthly report aggregates orders by customer with total amounts. It runs every morning and takes 15 seconds.


---

## 2. Core Technical Concepts & Mechanisms

### Scenario 3: The N+1 Query Problem
Scenario three: the N+1 query problem. Your application loads a list of customers, then for each customer it runs a separate query to get their order count. With 1000 customers, that is 1001 queries — 1 for the list, plus 1000 individual lookups.

| N+1 Pattern (1001 Queries) | Single Query (1 Query) |
| :--- | :--- |
| Query 1: SELECT * FROM customers | SELECT c.name, COUNT(o.id) AS orders |
| Query 2: SELECT COUNT(*) FROM orders WHERE customer_id = 1 | FROM customers c |
| Query 3: SELECT COUNT(*) FROM orders WHERE customer_id = 2 | LEFT JOIN orders o ON o.customer_id = c.id |
| ... repeat 998 more times ... | GROUP BY c.name; |
| Total: 1001 round trips to database | Total: 1 round trip to database |
| Each query is fast, but 1001 of them is slow | PostgreSQL optimizes the join internally |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Scenario 9: UNION vs UNION ALL
Scenario nine: UNION versus UNION ALL. Many beginners use UNION when they mean UNION ALL. UNION removes duplicates — which requires sorting or hashing all the results. If you know there are no duplicates, or duplicates are acceptable, always use UNION ALL.

| UNION (Removes Duplicates) | UNION ALL (Keeps All Rows) |
| :--- | :--- |
| Combines results from both queries | Combines results — no duplicate check |
| Sorts or hashes ALL rows to remove duplicates | Just appends one result set to the other |
| Adds a HashAggregate or Sort + Unique node | Adds only an Append node (no extra work) |
| Slower — O(N log N) or O(N) extra work | Faster — O(1) overhead per query |
| Use ONLY when duplicates must be removed | Use when queries return disjoint sets |

### Optimization Scenarios — Quick Reference
Here is a quick reference of all the scenarios we covered and their fixes.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a quick reference of all the scenarios we covered and their fixes |

### Complete Optimization Workflow
Here is the complete optimization workflow you should follow. This is your playbook for any performance problem.

- 1. MEASURE: Use pg_stat_statements to find top queries by total_exec_time
- 2. DIAGNOSE: Run EXPLAIN (ANALYZE, BUFFERS) on each slow query
- 3. CHECK STATS: Compare estimated vs actual rows — run ANALYZE if off
- 4. CHECK INDEXES: Look for Seq Scan on WHERE/JOIN columns → add index
- 5. CHECK SORTS: Look for external merge Disk → increase work_mem
- 6. CHECK JOINS: Wrong algorithm? Usually fix stats, not the algorithm
- 7. CHECK APP: N+1 queries? Rewrite as JOIN or use materialized view
- 8. CHECK TEXT: LIKE '%text%'? Use pg_trgm GIN index
- 9. CHECK CONNECTIONS: Too many idle? Use pgBouncer
- 10. VERIFY: Re-run EXPLAIN ANALYZE after each change
- 11. MONITOR: Recheck pg_stat_statements after deployment

### Phase 20 Review — Query Optimization & Performance
Here is the Phase 20 review — everything we covered across all five classes of Query Optimization and Performance.

| Topic | Key Takeaway |
| :--- | :--- |
| EXPLAIN & Scan Types | Read plans bottom-up; Seq Scan, Index Scan, Bitmap Scan |
| Join Algorithms | Nested Loop (small), Hash Join (medium), Merge Join (sorted) |
| Query Planner | Generates plans, estimates costs from pg_statistic, picks cheapest |
| pg_stat_statements | Find real slow queries by total time, not guessing |
| Index Optimization | Composite, covering (INCLUDE), expression, partial indexes |
| Pagination | Keyset pagination instead of OFFSET for constant speed |
| Index Only Scan | Covers all SELECT columns + VACUUM for visibility map |
| Parallel Queries | Multiple workers for large scans and aggregations |
| JIT Compilation | LLVM compiles expressions — good for large, CPU-heavy queries |
| Optimization Workflow | Measure → Diagnose → Fix → Verify → Monitor |


---

## 3. Hands-On Commands & psql Output

### Scenario 1: Slow Dashboard — The Problem
**Explanation:** Scenario one: the slow dashboard query. Your application dashboard shows recent orders with customer names. Users report it takes 3 seconds to load. Let us diagnose it.

```sql
postgres=# -- The slow query:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT o.id, o.amount, o.status, o.order_date,
       c.name AS customer_name
postgres-# FROM orders o
postgres-# JOIN customers c ON o.customer_id = c.id
postgres-# WHERE o.status = 'pending'
postgres-# ORDER BY o.order_date DESC
postgres-# LIMIT 20;
 Sort  (actual time=45.678..45.689 rows=20 loops=1)
   Sort Key: o.order_date DESC
   -> Hash Join  (actual time=0.890..38.456 rows=10050 loops=1)
      Hash Cond: (o.customer_id = c.id)
      -> Seq Scan on orders o
         (actual time=0.023..25.345 rows=10050 loops=1)
         Filter: (status = 'pending')
         Rows Removed by Filter: 39950
      -> Hash  ...
postgres=# -- Problems spotted:
postgres=# -- 1. Seq Scan on orders: scanning 50,000 rows to find 10,050
postgres=# -- 2. Sort: sorting 10,050 rows to return only 20
postgres=# -- 3. No index on status or order_date
```

### Scenario 1: The Fix — Composite Index
**Explanation:** The fix: create a composite index on the two columns used in WHERE and ORDER BY. Since we filter on status and sort by order_date descending, the index should be (status, order_date DESC). This lets PostgreSQL go directly to the pending rows in sorted order.

```sql
postgres=# -- Create composite index:
postgres=# CREATE INDEX idx_orders_status_date
postgres-# ON orders(status, order_date DESC);
postgres=# -- Re-run the query:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT o.id, o.amount, o.status, o.order_date,
       c.name AS customer_name
postgres-# FROM orders o
postgres-# JOIN customers c ON o.customer_id = c.id
postgres-# WHERE o.status = 'pending'
postgres-# ORDER BY o.order_date DESC
postgres-# LIMIT 20;
 Limit (actual time=0.089..0.234 rows=20 loops=1)
   -> Nested Loop
      -> Index Scan using idx_orders_status_date on orders o
         (actual time=0.045..0.112 rows=20 loops=1)
         Index Cond: (status = 'pending')
      -> Index Scan using customers_pkey on customers c
         (actual time=0.004..0.004 rows=1 loops=20)
 Execution Time: 0.278 ms
postgres=# -- 45.689 ms → 0.278 ms = 164x faster
postgres=# -- No Sort node — index provides order
postgres=# -- Only 20 rows scanned, not 10,050
```

### Scenario 2: Slow Monthly Report — The Problem
**Explanation:** Scenario two: the slow report query. A monthly report aggregates orders by customer with total amounts. It runs every morning and takes 15 seconds.

```sql
postgres=# -- The slow query:
postgres=# EXPLAIN (ANALYZE, BUFFERS)
postgres=# SELECT c.name,
       COUNT(*) AS order_count,
       SUM(o.amount) AS total_amount,
       AVG(o.amount) AS avg_amount
postgres-# FROM orders o
postgres-# JOIN customers c ON o.customer_id = c.id
postgres-# WHERE o.order_date >= '2025-07-01'
postgres-# AND o.order_date < '2025-08-01'
postgres-# GROUP BY c.name
postgres-# ORDER BY total_amount DESC;
 Sort  (actual time=125.678..125.890 rows=950 loops=1)
   Sort Key: (sum(o.amount)) DESC
   -> HashAggregate  (actual time=115.234..115.678 rows=950 loops=1)
      -> Hash Join  (actual time=5.456..95.234 rows=4200 loops=1)
         -> Seq Scan on orders o
            (actual time=0.034..78.901 rows=4200 loops=1)
            Filter: (order_date >= ... AND order_date < ...)
            Rows Removed by Filter: 45800
         -> Hash  ...
   Buffers: shared hit=128 read=634   ← lots of disk reads!
postgres=# -- Problems:
postgres=# -- 1. Seq Scan on orders filtering 45,800 rows
postgres=# -- 2. 634 disk reads (shared read)
postgres=# -- 3. work_mem may be low for the sort
```

### Scenario 2: The Fix — Index + work_mem
**Explanation:** The fix has two parts. First, add an index on order_date to eliminate the sequential scan. Second, increase work_mem for the reporting session so the sort and hash operations stay in memory.

```sql
postgres=# -- Step 1: Index on order_date
postgres=# CREATE INDEX idx_orders_date ON orders(order_date);
postgres=# -- Step 2: Increase work_mem for this session
postgres=# SET work_mem = '64MB';
postgres=# -- Re-run:
postgres=# EXPLAIN (ANALYZE, BUFFERS)
postgres=# SELECT c.name,
       COUNT(*) AS order_count,
       SUM(o.amount) AS total_amount,
       AVG(o.amount) AS avg_amount
postgres-# FROM orders o
postgres-# JOIN customers c ON o.customer_id = c.id
postgres-# WHERE o.order_date >= '2025-07-01'
postgres-# AND o.order_date < '2025-08-01'
postgres-# GROUP BY c.name
postgres-# ORDER BY total_amount DESC;
 Sort  (actual time=8.234..8.289 rows=950 loops=1)
   Sort Method: quicksort  Memory: 102kB     ← in memory!
   -> HashAggregate (actual time=7.456..7.890 rows=950 loops=1)
      -> Hash Join  (actual time=1.234..5.678 rows=4200 loops=1)
         -> Bitmap Index Scan on idx_orders_date
            (actual time=0.345..2.567 rows=4200 loops=1)
   Buffers: shared hit=680 read=12     ← mostly cache hits!
postgres=# -- 125.890 ms → 8.289 ms = 15x faster
postgres=# -- Disk reads: 634 → 12
RESET work_mem;
```

### Scenario 3: The Fix — Single JOIN or Materialized View
**Explanation:** The fix is straightforward — replace the N+1 loop with a single JOIN query. If you cannot change the application code, a materialized view can pre-compute the result.

```sql
postgres=# -- Option A: Single JOIN query
postgres=# EXPLAIN ANALYZE
postgres=# SELECT c.name,
       COUNT(o.id) AS order_count,
       COALESCE(SUM(o.amount), 0) AS total_amount
postgres-# FROM customers c
postgres-# LEFT JOIN orders o ON o.customer_id = c.id
postgres-# GROUP BY c.id, c.name
postgres-# ORDER BY total_amount DESC;
postgres=# -- Execution Time: ~35 ms (single query)
postgres=# -- vs N+1 approach: ~1200 ms (1001 queries)
postgres=# -- Option B: Materialized view (pre-computed)
postgres=# CREATE MATERIALIZED VIEW customer_order_summary AS
postgres=# SELECT c.id AS customer_id,
       c.name,
       COUNT(o.id) AS order_count,
       COALESCE(SUM(o.amount), 0) AS total_amount
postgres-# FROM customers c
postgres-# LEFT JOIN orders o ON o.customer_id = c.id
postgres-# GROUP BY c.id, c.name;
postgres=# -- Create index on the materialized view:
postgres=# CREATE INDEX idx_cos_total ON customer_order_summary(total_amount DESC);
postgres=# -- Query is now instant:
postgres=# SELECT * FROM customer_order_summary ORDER BY total_amount DESC;
postgres=# -- Execution Time: ~0.5 ms
postgres=# -- Refresh periodically:
REFRESH MATERIALIZED VIEW CONCURRENTLY customer_order_summary;
```

### Scenario 4: Slow Text Search — The Problem
**Explanation:** Scenario four: the slow text search. Your application has a search box where users type a customer name. The query uses LIKE with wildcards on both sides — this cannot use a regular B-tree index.

```sql
postgres=# -- The slow query (LIKE with leading wildcard):
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM customers
postgres-# WHERE name ILIKE '%customer_42%';
 Seq Scan on customers (actual time=0.023..0.456 rows=1 loops=1)
   Filter: (name ~~* '%customer_42%')
   Rows Removed by Filter: 999
postgres=# -- B-tree index CANNOT help with leading wildcard
postgres=# -- With 1,000 rows it is fast, but with 10 million rows
postgres=# -- this becomes a full table scan taking seconds
postgres=# -- Solution: pg_trgm extension (trigram index)
postgres=# CREATE EXTENSION IF NOT EXISTS pg_trgm;
postgres=# CREATE INDEX idx_customers_name_trgm
postgres-# ON customers USING gin (name gin_trgm_ops);
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM customers
postgres-# WHERE name ILIKE '%customer_42%';
 Bitmap Heap Scan on customers
   (actual time=0.089..0.095 rows=1 loops=1)
   Recheck Cond: (name ~~* '%customer_42%')
   -> Bitmap Index Scan on idx_customers_name_trgm
      (actual time=0.078..0.078 rows=1 loops=1)
postgres=# -- GIN trigram index supports LIKE '%text%' and ILIKE
```

### Scenario 5: Connection Storm — Diagnosis
**Explanation:** Scenario five: the connection storm. During peak hours, your application opens hundreds of connections. Each connection triggers multiple queries. PostgreSQL slows to a crawl — not because queries are slow, but because context switching between connections and locking overhead dominates.

```sql
postgres=# -- Check active connections:
postgres=# SELECT count(*) AS total_connections,
       count(*) FILTER (WHERE state = 'active') AS active,
       count(*) FILTER (WHERE state = 'idle') AS idle,
       count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_txn
postgres-# FROM pg_stat_activity
postgres-# WHERE backend_type = 'client backend';
 total_connections | active | idle | idle_in_txn
postgres=# ------------------+--------+------+------------
             347  |    23  |  280 |          44
postgres=# -- Problem: 347 connections but only 23 active!
postgres=# -- 280 idle connections waste server memory
postgres=# -- 44 idle in transaction BLOCK autovacuum
postgres=# -- Check max_connections:
postgres=# SHOW max_connections;  -- 100 (default)
postgres=# -- If total > max_connections, new connections fail
postgres=# -- Fix: use a connection pooler (pgBouncer)
postgres=# -- Set max_connections = 200 on PostgreSQL
postgres=# -- Set pgBouncer pool_size = 20-50
postgres=# -- Application connects to pgBouncer, not directly to PG
```

### Scenario 6: Stale Statistics — Index Ignored
**Explanation:** Scenario six: the missing statistics problem. You add an index but PostgreSQL still does a sequential scan. The most common reason? Stale statistics. After loading or changing lots of data, run ANALYZE before expecting the planner to use new indexes.

```sql
postgres=# -- Load 100,000 new rows:
postgres=# INSERT INTO orders (customer_id, amount, status, order_date)
postgres=# SELECT (random() * 999 + 1)::int,
       (random() * 500 + 1)::numeric(10,2),
       'rush',
       '2026-01-15'
postgres-# FROM generate_series(1, 100000);
postgres=# -- Index exists on status:
postgres=# -- CREATE INDEX idx_orders_status ON orders(status);
postgres=# -- But planner does NOT know about 'rush' status yet:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM orders WHERE status = 'rush';
 Seq Scan on orders  (actual time=0.023..45.678 rows=100000 loops=1)
   Filter: (status = 'rush')
postgres=# -- Planner thinks status='rush' returns 0 rows (no stats!)
postgres=# -- Fix: run ANALYZE
postgres=# ANALYZE orders;
postgres=# -- Now planner knows about 'rush':
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM orders WHERE status = 'rush';
postgres=# -- Planner now correctly estimates ~100,000 rows
postgres=# -- May still use Seq Scan because 100K rows = 67% of table
postgres=# -- That is actually the CORRECT choice!
```

### Scenario 7: Slow COUNT — The Problem & Fixes
**Explanation:** Scenario seven: the slow COUNT query. Your application shows 'Page 1 of 5000' and runs SELECT COUNT(*) FROM orders WHERE status = 'shipped' to get the total. On a large table, this scans millions of rows just to count them.

```sql
postgres=# -- Slow: exact count scans the whole filtered set
postgres=# EXPLAIN ANALYZE
postgres=# SELECT COUNT(*) FROM orders WHERE status = 'shipped';
 Aggregate  (actual time=18.456..18.457 rows=1 loops=1)
   -> Seq Scan on orders  (actual time=0.012..14.234 rows=10000 loops=1)
      Filter: (status = 'shipped')
postgres=# -- Fix Option A: use an index + Index Only Scan
postgres=# CREATE INDEX idx_orders_status ON orders(status);
postgres=# VACUUM orders;
postgres=# EXPLAIN ANALYZE
postgres=# SELECT COUNT(*) FROM orders WHERE status = 'shipped';
postgres=# -- Index Only Scan → much faster
postgres=# -- Fix Option B: approximate count (good enough for pagination)
postgres=# SELECT reltuples::bigint AS approximate_rows
postgres-# FROM pg_class WHERE relname = 'orders';
postgres=# -- Fix Option C: cache the count in a summary table
postgres=# -- UPDATE order_counts SET cnt = cnt + 1 WHERE status = 'shipped';
postgres=# -- (Updated by trigger or application code)
```

### Scenario 8: Correlated Subquery — Rewrite as JOIN
**Explanation:** Scenario eight: the correlated subquery. Your query uses a subquery in SELECT that runs once per row in the outer query. With 50,000 outer rows, the subquery runs 50,000 times.

```sql
postgres=# -- Slow: correlated subquery runs per row
postgres=# EXPLAIN ANALYZE
postgres=# SELECT c.name,
  (SELECT COUNT(*) FROM orders o
postgres-# WHERE o.customer_id = c.id) AS order_count
postgres-# FROM customers c;
postgres=# -- SubPlan runs 1000 times (once per customer)
postgres=# -- Even with index: 1000 × 0.1ms = 100ms total
postgres=# -- Fast: rewrite as LEFT JOIN + GROUP BY
postgres=# EXPLAIN ANALYZE
postgres=# SELECT c.name, COUNT(o.id) AS order_count
postgres-# FROM customers c
postgres-# LEFT JOIN orders o ON o.customer_id = c.id
postgres-# GROUP BY c.id, c.name;
postgres=# -- Single Hash Join + HashAggregate
postgres=# -- Execution Time: ~35 ms vs ~100 ms
postgres=# -- Rule of thumb:
postgres=# -- If subquery references outer table → correlated
postgres=# -- Correlated subqueries in SELECT → rewrite as JOIN
postgres=# -- Correlated subqueries in WHERE → use EXISTS or JOIN
```

### Scenario 10: Long Transactions — Detection & Prevention
**Explanation:** Scenario ten: long transactions blocking autovacuum and other queries. A developer left a transaction open while debugging. That idle in transaction session prevents autovacuum from cleaning dead tuples, and can cause lock contention for other queries.

```sql
postgres=# -- Find long-running transactions:
postgres=# SELECT pid,
       now() - xact_start AS transaction_age,
       state,
       left(query, 50) AS last_query
postgres-# FROM pg_stat_activity
postgres-# WHERE state = 'idle in transaction'
postgres-# AND xact_start < now() - '10 min'::interval
postgres-# ORDER BY xact_start;
  pid  | transaction_age |        state         | last_query
postgres=# -------+-----------------+----------------------+-----------
 12345 | 02:34:15        | idle in transaction  | UPDATE orders SET ...
postgres=# -- This transaction has been open for 2.5 HOURS!
postgres=# -- It blocks autovacuum on any table it touched
postgres=# -- Prevention: set statement and idle timeouts
postgres=# -- postgresql.conf:
postgres=# -- idle_in_transaction_session_timeout = '5min'
postgres=# -- statement_timeout = '60s' (for web apps)
postgres=# -- Emergency: terminate the session
postgres=# -- SELECT pg_terminate_backend(12345);
```

### Scenario 11: SELECT DISTINCT Hiding a Bad JOIN
**Explanation:** Scenario eleven: SELECT DISTINCT on a large result. DISTINCT works like UNION — it must sort or hash all rows to remove duplicates. Often, DISTINCT is a sign that the JOIN is wrong — it is producing duplicate rows because of a missing condition or a many-to-many relationship.

```sql
postgres=# -- Slow: DISTINCT hiding duplicate rows from bad join
postgres=# EXPLAIN ANALYZE
postgres=# SELECT DISTINCT c.name
postgres-# FROM customers c
postgres-# JOIN orders o ON o.customer_id = c.id;
 HashAggregate  (actual time=45.678..46.234 rows=1000 loops=1)
   -> Hash Join  (actual time=0.456..28.901 rows=50000 loops=1)
postgres=# -- The JOIN produces 50,000 rows (one per order)
postgres=# -- Then DISTINCT removes 49,000 duplicates to get 1,000
postgres=# -- This is a waste of work!
postgres=# -- Better: use EXISTS (no duplicates produced)
postgres=# EXPLAIN ANALYZE
postgres=# SELECT c.name
postgres-# FROM customers c
postgres-# WHERE EXISTS (
postgres=# SELECT 1 FROM orders o WHERE o.customer_id = c.id
);
postgres=# -- Only 1,000 rows processed, no deduplication needed
postgres=# -- If you need DISTINCT, ask: why am I getting duplicates?
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your final summary for Phase 20. Always measure before optimizing — use pg_stat_statements to find the real bottlenecks. EXPLAIN ANALYZE is your diagnostic tool. The most common fixes are: adding the right index, updating statistics with ANALYZE, increasing work_mem for heavy sorts and hashes, and rewriting queries to avoid anti-patterns. Never guess — measure, fix, verify. In the next phase, we move to Performance Tuning — configuring PostgreSQL itself for maximum performance.

- **EXPLAIN ANALYZE: your primary diagnostic tool**
- **pg_stat_statements: find what is ACTUALLY slow**
- **Scan types: Seq, Index, Bitmap — planner picks based on selectivity**
- **Join algorithms: Nested Loop, Hash, Merge — planner picks based on size**
- **Index strategy: composite, covering, expression, partial**
- **Keyset pagination: constant speed vs OFFSET degradation**
- **Index Only Scan: skip heap, keep visibility map fresh with VACUUM**
- **Parallel queries: split large work across workers**
- **JIT: compile expressions for CPU-heavy queries**
- **Workflow: Measure → Diagnose → Fix → Verify → Monitor**
- **Next Phase: Performance Tuning (postgresql.conf & system config)**


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
