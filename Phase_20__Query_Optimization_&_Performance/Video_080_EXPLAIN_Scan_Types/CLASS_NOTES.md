# EXPLAIN, EXPLAIN ANALYZE & Scan Types
**Series:** PostgreSQL Mastery | **Phase:** Phase 20: Query Optimization & Performance | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! We are now entering Phase 20 — Query Optimization and Performance. This is where you learn to make slow queries fast. The most important skill in this phase is reading EXPLAIN output — the query plan that PostgreSQL shows you before or after executing a query. Once you can read a query plan, you can diagnose any performance problem. In this class, we cover EXPLAIN, EXPLAIN ANALYZE, and the three main scan types. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should be comfortable writing SELECT queries with WHERE, JOIN, GROUP BY, and ORDER BY. You should also understand indexes from our earlier phases. Recap from Phase 19 — we learned how to keep the database healthy with VACUUM, AUTOVACUUM, ANALYZE, and REINDEX. Now we shift focus from maintenance to speed — making queries run as fast as possible.

- Prerequisite: SELECT with WHERE, JOIN, GROUP BY, ORDER BY
- Prerequisite: B-tree indexes (CREATE INDEX)
- Recap: Phase 19 covered VACUUM, AUTOVACUUM, ANALYZE, REINDEX, pg_repack
- Now: Reading query plans and understanding how PostgreSQL accesses data

### EXPLAIN — See the Query Plan
Imagine you ask for directions to a restaurant. There are many routes — highway, back roads, shortcuts. Your GPS picks the fastest route based on traffic, distance, and road conditions. PostgreSQL does the same thing with queries. When you write a SELECT, there are many ways to find your data — scan the whole table, use an index, combine multiple indexes. The query planner picks the cheapest path. EXPLAIN shows you what path it chose and why.

| Term | Meaning / Explanation |
| :--- | :--- |
| **EXPLAIN** | Shows the plan PostgreSQL WOULD use — does NOT execute the query |
| **EXPLAIN ANALYZE** | Actually EXECUTES the query and shows real timing + row counts |
| **Cost** | Estimated effort — lower is better (arbitrary units, not milliseconds) |
| **Rows** | Estimated number of rows the node will produce |
| **Width** | Average row width in bytes |

**Notes:**
- EXPLAIN is safe — it only plans, never executes
- EXPLAIN ANALYZE actually runs the query — careful with UPDATE/DELETE!

### Understanding Cost Numbers
Now let us understand the cost numbers. Cost is measured in arbitrary units — not milliseconds. The startup cost is the work needed before the first row can be returned. The total cost is the work to return ALL rows. A sequential scan has zero startup cost because it can return the first row immediately. A sort has high startup cost because it must read ALL rows before producing any output. The planner compares total costs of different plans and picks the cheapest.

| Term | Meaning / Explanation |
| :--- | :--- |
| **cost=0.00..1834.00** | Startup cost = 0.00 (can start returning rows immediately) |
| **Total cost = 1834.00** | Estimated total work to complete (arbitrary units, NOT milliseconds) |
| **seq_page_cost = 1.0** | Base unit: cost of reading one sequential page from disk |
| **random_page_cost = 4.0** | Random I/O is 4x more expensive (seeking to non-adjacent pages) |
| **cpu_tuple_cost = 0.01** | Processing one row costs 0.01 (much cheaper than I/O) |

**Notes:**
- Lower cost = planner thinks this plan is faster
- Cost comparison only works within the SAME query — not across queries

### Three Main Scan Types
Now let us move to scan types — the ways PostgreSQL accesses table data. The three main scans are Sequential Scan, Index Scan, and Bitmap Index Scan. Understanding when PostgreSQL chooses each one is the key to optimization.

- 1. Sequential Scan (Seq Scan) — reads EVERY row in the table
- 2. Index Scan — uses an index to jump directly to matching rows
- 3. Bitmap Index Scan — combines index lookup with batch heap access
- Each scan type is optimal for different situations
- The planner picks the cheapest based on statistics and cost settings

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description. If you want to support this free course, the donation link is also in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Scan Type Selection — Selectivity Thresholds
Here is the key question: when does PostgreSQL choose each scan type? It all depends on selectivity — what percentage of rows match your WHERE condition. This table shows the general thresholds, but the exact cutoff depends on your data, your indexes, and the cost parameters.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Here is the key question** | when does PostgreSQL choose each scan type? |
| **It all depends on selectivity** | what percentage of rows match your WHERE condition |
| **This table shows the general thresholds** | but the exact cutoff depends on your data, your indexes, and the cost parameters |

### Beginner Trap: Index Exists but Not Used!
Here is a common beginner trap. You create an index and expect PostgreSQL to use it, but EXPLAIN shows a Sequential Scan instead. You think the index is broken. It is not — the planner decided that Seq Scan is actually cheaper for your query. This happens when the query returns a large portion of the table, when the table is very small, or when the statistics are stale.

| Why the Planner Ignores Your Index | How to Fix It |
| :--- | :--- |
| Query returns too many rows (> 15%) | Check selectivity — is index actually faster? |
| Table is very small (fits in 1-2 pages) | Run ANALYZE to update statistics |
| Statistics are stale (run ANALYZE) | Use expression index: CREATE INDEX ON t(upper(name)) |
| Function on column: WHERE upper(name) = ... | Match data types in WHERE clause |
| Data type mismatch: WHERE id = '123' | Consider a composite index for multi-column WHERE |
| OR condition without proper index | Use UNION ALL instead of OR for different indexes |

### Common EXPLAIN Plan Nodes
Here is a quick reference for the most common plan nodes you will see in EXPLAIN output.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a quick reference for the most common plan nodes you will see in EXPLAIN output |


---

## 3. Hands-On Commands & psql Output

### Your First EXPLAIN
**Explanation:** Let us run our first EXPLAIN. We will query a table and see what PostgreSQL tells us about its plan.

```sql
postgres=# EXPLAIN SELECT * FROM orders WHERE status = 'shipped';
                         QUERY PLAN
postgres=# -------------------------------------------------------------
 Seq Scan on orders  (cost=0.00..1834.00 rows=5420 width=64)
   Filter: (status = 'shipped'::text)
postgres=# -- Reading the output:
postgres=# -- "Seq Scan on orders" → scanning the ENTIRE table row by row
postgres=# -- "cost=0.00..1834.00" → startup cost..total cost
postgres=# -- "rows=5420" → planner ESTIMATES 5,420 rows will match
postgres=# -- "width=64" → each row is ~64 bytes wide
postgres=# -- "Filter: ..." → which rows are kept after scanning
```

### EXPLAIN ANALYZE — Real Execution Stats
**Explanation:** Now let us use EXPLAIN ANALYZE to see what ACTUALLY happened when the query ran. Notice the difference — we get actual time, actual rows, and loops.

```sql
postgres=# EXPLAIN ANALYZE SELECT * FROM orders WHERE status = 'shipped';
                                    QUERY PLAN
postgres=# ---------------------------------------------------------------------------
 Seq Scan on orders  (cost=0.00..1834.00 rows=5420 width=64)
                     (actual time=0.025..12.450 rows=5318 loops=1)
   Filter: (status = 'shipped'::text)
   Rows Removed by Filter: 44682
 Planning Time: 0.085 ms
 Execution Time: 13.102 ms
postgres=# -- New information:
postgres=# -- "actual time=0.025..12.450" → first row at 0.025ms, last row at 12.45ms
postgres=# -- "rows=5318" → ACTUAL rows returned (vs 5420 estimated)
postgres=# -- "loops=1" → this node ran once
postgres=# -- "Rows Removed by Filter: 44682" → rows scanned but rejected
postgres=# -- Planning Time + Execution Time = total wall clock time
```

### EXPLAIN Options — BUFFERS, FORMAT, COSTS
**Explanation:** There are several useful options you can add to EXPLAIN. BUFFERS shows how many disk pages were read from cache versus disk. FORMAT JSON or YAML makes the output machine-readable. COSTS can be turned off for a cleaner view. Let us see BUFFERS — this is the most useful option for diagnosing I/O problems.

```sql
postgres=# EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE status = 'shipped';
                                    QUERY PLAN
postgres=# ---------------------------------------------------------------------------
 Seq Scan on orders  (cost=0.00..1834.00 rows=5420 width=64)
                     (actual time=0.022..11.834 rows=5318 loops=1)
   Filter: (status = 'shipped'::text)
   Rows Removed by Filter: 44682
   Buffers: shared hit=834
 Planning Time: 0.078 ms
 Execution Time: 12.456 ms
postgres=# -- "Buffers: shared hit=834" → 834 pages read from shared_buffers (cache)
postgres=# -- "shared read=N" would mean pages read from DISK (slower)
postgres=# -- All hits = table is fully cached in memory → fast
postgres=# -- Many reads = data coming from disk → slower
```

### EXPLAIN Syntax Reference
**Explanation:** Here is a complete reference of EXPLAIN syntax and options.

```sql
-- Basic EXPLAIN (plan only, no execution):
EXPLAIN SELECT ...;

-- EXPLAIN ANALYZE (executes the query!):
EXPLAIN ANALYZE SELECT ...;

-- With buffer statistics:
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;

-- JSON output (for tools like pgAdmin, explain.dalibo.com):
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) SELECT ...;

-- Hide costs for cleaner output:
EXPLAIN (COSTS OFF) SELECT ...;

-- Show WAL usage (PG 13+):
EXPLAIN (ANALYZE, BUFFERS, WAL) INSERT ...;

-- IMPORTANT: EXPLAIN ANALYZE on UPDATE/DELETE
-- ACTUALLY modifies data! Wrap in a transaction:
BEGIN;
EXPLAIN ANALYZE DELETE FROM orders WHERE id < 10;
ROLLBACK;  -- undo the delete
```

### Sequential Scan — When It's Actually Fast
**Explanation:** Sequential Scan reads every single row in the table from start to finish. It is the simplest scan — no index needed. It checks each row against the WHERE condition and returns matches. Sequential Scan is actually the FASTEST method when you need a large percentage of the table — say 20 percent or more. Reading sequentially from disk is much faster than random jumps to scattered index entries.

```sql
postgres=# -- Query that returns ~50% of rows → Seq Scan is optimal
postgres=# EXPLAIN ANALYZE SELECT * FROM orders WHERE amount > 50;
                                    QUERY PLAN
postgres=# ---------------------------------------------------------------------------
 Seq Scan on orders  (cost=0.00..1834.00 rows=25142 width=64)
                     (actual time=0.018..15.234 rows=24987 loops=1)
   Filter: (amount > 50)
   Rows Removed by Filter: 25013
 Planning Time: 0.092 ms
 Execution Time: 17.456 ms
postgres=# -- Returning ~50% of 50K rows
postgres=# -- Seq Scan is CORRECT here — an index would be slower
postgres=# -- Sequential disk I/O is faster than 25,000 random index lookups
```

### Index Scan — Fast for Selective Queries
**Explanation:** Index Scan uses a B-tree index to find exactly the rows that match your WHERE condition. It reads the index to find row locations, then jumps to each location in the table heap to fetch the full row. Index Scan is fast when you need a small number of rows — typically less than 5 to 10 percent of the table.

```sql
postgres=# -- Create an index on order_date
postgres=# CREATE INDEX idx_orders_date ON orders(order_date);
postgres=# -- Query that returns a small percentage → Index Scan
postgres=# EXPLAIN ANALYZE SELECT * FROM orders
postgres-# WHERE order_date = '2026-01-15';
                                    QUERY PLAN
postgres=# ---------------------------------------------------------------------------
 Index Scan using idx_orders_date on orders
   (cost=0.29..8.31 rows=1 width=64)
   (actual time=0.028..0.030 rows=1 loops=1)
   Index Cond: (order_date = '2026-01-15'::date)
 Planning Time: 0.115 ms
 Execution Time: 0.052 ms
postgres=# -- cost=8.31 vs 1834.00 for Seq Scan = 220x cheaper!
postgres=# -- Execution: 0.052ms vs 17ms = 327x faster!
postgres=# -- Index jumped directly to the matching row
```

### Bitmap Index Scan — The Middle Ground
**Explanation:** Bitmap Index Scan is the middle ground. When a query matches too many rows for Index Scan but too few for Seq Scan, PostgreSQL uses a two-step process. First, it scans the index and builds a bitmap — a map of which table pages contain matching rows. Second, it reads those pages sequentially. This avoids random I/O while still skipping pages with no matches.

```sql
postgres=# -- Create index on status
postgres=# CREATE INDEX idx_orders_status ON orders(status);
postgres=# -- Query returning ~10% of rows → Bitmap Scan
postgres=# EXPLAIN ANALYZE SELECT * FROM orders WHERE status = 'shipped';
                                    QUERY PLAN
postgres=# ---------------------------------------------------------------------------
 Bitmap Heap Scan on orders
   (cost=62.45..1025.30 rows=5318 width=64)
   (actual time=0.542..5.123 rows=5318 loops=1)
   Recheck Cond: (status = 'shipped'::text)
   Heap Blocks: exact=834
   -> Bitmap Index Scan on idx_orders_status
      (cost=0.00..61.12 rows=5318 width=0)
      (actual time=0.385..0.386 rows=5318 loops=1)
      Index Cond: (status = 'shipped'::text)
 Planning Time: 0.098 ms
 Execution Time: 5.890 ms
postgres=# -- Two steps: 1) Bitmap Index Scan builds the bitmap
postgres=# --            2) Bitmap Heap Scan reads pages in order
```

### Combining Indexes — BitmapAnd & BitmapOr
**Explanation:** Multiple indexes can be combined using BitmapAnd and BitmapOr. If you have two separate indexes and your WHERE clause uses both columns, PostgreSQL can scan each index separately, build a bitmap from each, and combine them with AND or OR logic before reading the heap.

```sql
postgres=# -- Two separate indexes
postgres=# CREATE INDEX idx_orders_status ON orders(status);
postgres=# CREATE INDEX idx_orders_date ON orders(order_date);
postgres=# -- Query using both columns:
postgres=# EXPLAIN ANALYZE SELECT * FROM orders
postgres-# WHERE status = 'shipped' AND order_date > '2026-06-01';
                                    QUERY PLAN
postgres=# ---------------------------------------------------------------------------
 Bitmap Heap Scan on orders
   -> BitmapAnd
      -> Bitmap Index Scan on idx_orders_status
         Index Cond: (status = 'shipped'::text)
      -> Bitmap Index Scan on idx_orders_date
         Index Cond: (order_date > '2026-06-01'::date)
postgres=# -- BitmapAnd: intersects the two bitmaps
postgres=# -- Only pages matching BOTH conditions are read from heap
```

### Reading Multi-Node Plans
**Explanation:** Let us look at reading multi-node plans. Real queries have multiple steps — a scan, a sort, an aggregate. Each step is called a node. Nodes form a tree — the bottom nodes produce rows, and upper nodes consume them. Understanding this tree is essential for reading complex plans.

```sql
postgres=# EXPLAIN ANALYZE
postgres=# SELECT status, COUNT(*), AVG(amount)
postgres-# FROM orders
postgres-# GROUP BY status
postgres-# ORDER BY count DESC;
                                    QUERY PLAN
postgres=# ---------------------------------------------------------------------------
 Sort  (cost=2584.00..2584.03 rows=5 width=48)
       (actual time=28.123..28.125 rows=5 loops=1)
   Sort Key: (count(*)) DESC
   Sort Method: quicksort  Memory: 25kB
   -> HashAggregate  (cost=2083.50..2083.58 rows=5 width=48)
                     (actual time=28.089..28.094 rows=5 loops=1)
      Group Key: status
      Batches: 1  Memory Usage: 40kB
      -> Seq Scan on orders  (cost=0.00..1834.00 rows=50000 width=16)
                             (actual time=0.012..8.234 rows=50000 loops=1)
postgres=# -- Read BOTTOM to TOP:
postgres=# -- 1. Seq Scan: reads all 50,000 rows
postgres=# -- 2. HashAggregate: groups by status, computes COUNT/AVG
postgres=# -- 3. Sort: orders results by count DESC
```

### Spotting Bad Estimates
**Explanation:** Let us see one more important detail — when estimates are wrong. If the estimated rows differ significantly from the actual rows, the planner may have chosen a bad plan. This usually means statistics are stale. Run ANALYZE to fix it.

```sql
postgres=# -- Example of bad estimate:
postgres=# EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;
                                    QUERY PLAN
postgres=# ---------------------------------------------------------------------------
 Seq Scan on orders  (cost=0.00..1834.00 rows=1 width=64)
                     (actual time=0.015..12.345 rows=847 loops=1)
   Filter: (customer_id = 42)
postgres=# -- Estimated: 1 row  |  Actual: 847 rows!
postgres=# -- Planner chose Seq Scan thinking only 1 row matched
postgres=# -- With correct stats, it might choose Index Scan or Bitmap Scan
postgres=# -- FIX: Update statistics
postgres=# ANALYZE orders;
postgres=# -- Re-run — now the estimate should be accurate
postgres=# EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;
postgres=# -- Estimated: ~840 rows → Bitmap Index Scan (correct plan!)
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Index Exists but Not Used!
Here is a common beginner trap. You create an index and expect PostgreSQL to use it, but EXPLAIN shows a Sequential Scan instead. You think the index is broken. It is not — the planner decided that Seq Scan is actually cheaper for your query. This happens when the query returns a large portion of the table, when the table is very small, or when the statistics are stale.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. EXPLAIN shows the planned execution path without running the query. EXPLAIN ANALYZE actually runs it and shows real timing and row counts. Always use BUFFERS to see I/O details. Read plans bottom to top — each node feeds into the one above it. The three main scan types are Sequential Scan for large result sets, Index Scan for highly selective queries, and Bitmap Index Scan for the middle range. Bad estimates usually mean stale statistics — fix with ANALYZE. In the next class, we cover join algorithms and how the query planner makes decisions.

- **EXPLAIN: shows planned path (safe, no execution)**
- **EXPLAIN ANALYZE: executes query, shows real stats (careful with writes!)**
- **EXPLAIN (ANALYZE, BUFFERS): add I/O details — shared hit vs read**
- **Cost: arbitrary units, NOT milliseconds — lower is better**
- **Seq Scan: reads entire table — fast for > 15% selectivity**
- **Index Scan: B-tree lookup — fast for < 5% selectivity**
- **Bitmap Index Scan: batch reads — good for 1-15% selectivity**
- **Read plans bottom to top: scan → aggregate → sort**
- **Bad estimates (rows) → stale statistics → run ANALYZE**
- **Next: Join Algorithms & Query Planner Decisions**


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
