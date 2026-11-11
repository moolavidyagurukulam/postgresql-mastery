# Join Algorithms & Query Planner
**Series:** PostgreSQL Mastery | **Phase:** Phase 20: Query Optimization & Performance | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we learned to read EXPLAIN output and understand scan types. Now we tackle the next layer — how PostgreSQL joins tables together. There are three join algorithms: Nested Loop, Hash Join, and Merge Join. Each has strengths and weaknesses. Then we look at how the query planner makes its decisions — why it picks one algorithm over another. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand EXPLAIN, EXPLAIN ANALYZE, and the three scan types from the previous class. Recap: Sequential Scan reads the whole table, Index Scan uses a B-tree for selective lookups, and Bitmap Index Scan batches index results. Now we add joins — combining rows from two or more tables.

- Prerequisite: EXPLAIN & EXPLAIN ANALYZE (previous class)
- Prerequisite: Scan types — Seq Scan, Index Scan, Bitmap Scan
- Recap: Cost = arbitrary units, lower is better
- Recap: Read plans bottom to top, check estimated vs actual rows
- Now: How PostgreSQL physically joins two tables

### Three Join Algorithms
When you write a JOIN in SQL, PostgreSQL needs to physically combine rows from two tables. Imagine matching students to their enrolled courses. You could go through each student one by one and look up their courses — that is Nested Loop. You could build a lookup table from one side and quickly match the other — that is Hash Join. Or you could sort both sides first and merge them like a zipper — that is Merge Join.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Nested Loop Join** | For each row in the outer table, scan the inner table for matches |
| **Hash Join** | Build a hash table from the smaller table, probe it with the larger table |
| **Merge Join** | Sort both tables on the join key, then merge them in one pass |

**Notes:**
- The planner picks the cheapest algorithm based on table sizes and statistics
- You rarely need to force a join type — trust the planner (with accurate stats)

### Join Algorithm Comparison
Here is a comparison table showing when each join algorithm wins.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a comparison table showing when each join algorithm wins |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Plan Search Strategies
The planner uses two strategies for finding the best plan. For queries joining up to about 8 tables, it tries ALL possible join orders — this is called exhaustive search. For queries joining more than geqo_threshold tables (default 12), it switches to GEQO — the Genetic Query Optimizer — which uses a probabilistic search to find a good plan without trying every combination.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Exhaustive Search (< 12 tables)** | Tries ALL possible join orders and methods — guaranteed optimal plan |
| **GEQO (>= 12 tables)** | Genetic algorithm — finds a GOOD plan without trying every combination |
| **join_collapse_limit = 8** | Planner considers reordering up to 8 tables in a FROM clause |
| **from_collapse_limit = 8** | Subqueries with <= 8 tables are flattened into the main query |

**Notes:**
- With 10 tables: 10! = 3.6 million possible join orders
- With 15 tables: GEQO avoids trying 1.3 trillion combinations

### Beginner Trap: Forcing Plans with enable_ Flags
A very common beginner trap is disabling planner options to force a plan. You read online that Hash Join is slow, so you SET enable_hashjoin = off. This forces the planner to use a different algorithm that might be much worse for your query. Never disable planner options in production. Fix the root cause instead — update statistics, add proper indexes, or tune cost parameters.

| The Wrong Way | The Right Way |
| :--- | :--- |
| SET enable_hashjoin = off; | Run ANALYZE to update statistics |
| SET enable_seqscan = off; | Add or adjust indexes |
| SET enable_nestloop = off; | Tune random_page_cost for SSD |
| Forces planner into suboptimal plans | Increase work_mem if hash spills to disk |
| Works for ONE query, breaks others | Increase effective_cache_size |
| Never use in production! | Only use enable_ flags for DEBUGGING |


---

## 3. Hands-On Commands & psql Output

### Nested Loop Join — Small Outer + Indexed Inner
**Explanation:** Nested Loop Join is the simplest. For each row in the outer table, it scans the inner table for matching rows. If the inner table has an index on the join column, this is very fast — it becomes an indexed nested loop. Nested Loop works best when the outer table is small and the inner table has an index.

```sql
postgres=# EXPLAIN ANALYZE
postgres=# SELECT o.id, o.amount, c.name
postgres-# FROM orders o
postgres-# JOIN customers c ON o.customer_id = c.id
postgres-# WHERE o.id < 10;
                                    QUERY PLAN
postgres=# ---------------------------------------------------------------------------
 Nested Loop  (cost=0.57..68.95 rows=9 width=44)
              (actual time=0.032..0.089 rows=9 loops=1)
   -> Index Scan using orders_pkey on orders o
      (cost=0.29..36.37 rows=9 width=16)
      (actual time=0.018..0.032 rows=9 loops=1)
      Index Cond: (id < 10)
   -> Index Scan using customers_pkey on customers c
      (cost=0.28..3.30 rows=1 width=36)
      (actual time=0.005..0.005 rows=1 loops=9)
      Index Cond: (id = o.customer_id)
 Planning Time: 0.215 ms
 Execution Time: 0.118 ms
postgres=# -- Outer: 9 rows from orders (via index)
postgres=# -- Inner: for EACH of those 9, look up 1 customer (via index)
postgres=# -- loops=9 on customers — the inner ran 9 times
```

### Hash Join — Medium to Large Tables
**Explanation:** Hash Join is the workhorse for medium-to-large joins. PostgreSQL builds a hash table from the smaller table, then scans the larger table and probes the hash for matches. Building the hash has startup cost, but once built, each lookup is nearly instant.

```sql
postgres=# EXPLAIN ANALYZE
postgres=# SELECT o.id, o.amount, c.name
postgres-# FROM orders o
postgres-# JOIN customers c ON o.customer_id = c.id;
                                    QUERY PLAN
postgres=# ---------------------------------------------------------------------------
 Hash Join  (cost=34.50..2118.50 rows=50000 width=44)
            (actual time=0.452..35.678 rows=50000 loops=1)
   Hash Cond: (o.customer_id = c.id)
   -> Seq Scan on orders o
      (cost=0.00..1834.00 rows=50000 width=16)
      (actual time=0.008..8.234 rows=50000 loops=1)
   -> Hash  (cost=22.00..22.00 rows=1000 width=36)
            (actual time=0.398..0.399 rows=1000 loops=1)
      Buckets: 1024  Batches: 1  Memory Usage: 72kB
      -> Seq Scan on customers c
         (cost=0.00..22.00 rows=1000 width=36)
         (actual time=0.005..0.158 rows=1000 loops=1)
postgres=# -- Step 1: Build hash from customers (1,000 rows, 72kB)
postgres=# -- Step 2: Scan orders (50,000 rows), probe hash for each
postgres=# -- Batches: 1 = fits in memory (good)
postgres=# -- Batches: >1 = hash spilled to disk (increase work_mem)
```

### Merge Join — Both Inputs Pre-Sorted
**Explanation:** Merge Join sorts both inputs on the join key, then merges them in a single pass — like a zipper. It is very efficient when both inputs are already sorted, for example when using an index that provides sorted output. Merge Join can also handle very large tables that do not fit in work_mem for a hash table.

```sql
postgres=# -- Force merge join for demonstration:
postgres=# SET enable_hashjoin = off;
postgres=# SET enable_nestloop = off;
postgres=# EXPLAIN ANALYZE
postgres=# SELECT o.id, o.amount, c.name
postgres-# FROM orders o
postgres-# JOIN customers c ON o.customer_id = c.id;
                                    QUERY PLAN
postgres=# ---------------------------------------------------------------------------
 Merge Join  (cost=4459.50..5459.50 rows=50000 width=44)
             (actual time=42.567..78.234 rows=50000 loops=1)
   Merge Cond: (o.customer_id = c.id)
   -> Sort  (cost=4337.00..4462.00 rows=50000 width=16)
            (actual time=30.456..38.789 rows=50000 loops=1)
      Sort Key: o.customer_id
      Sort Method: external merge  Disk: 1200kB
      -> Seq Scan on orders o  ...
   -> Sort  (cost=122.50..125.00 rows=1000 width=36)
            (actual time=0.789..0.856 rows=1000 loops=1)
      Sort Key: c.id
      Sort Method: quicksort  Memory: 102kB
      -> Seq Scan on customers c  ...
postgres=# -- Both inputs sorted, then merged
postgres=# -- orders sort spilled to disk (external merge) — needs more work_mem
postgres=# -- Re-enable defaults:
RESET enable_hashjoin;
RESET enable_nestloop;
```

### What the Planner Knows — pg_stats
**Explanation:** The planner relies on statistics stored in pg_statistic and exposed through the pg_stats view. These include the number of distinct values, the most common values and their frequencies, histogram bounds for range queries, and the correlation between physical and logical row order. All of these are updated by ANALYZE.

```sql
postgres=# SELECT attname,
       n_distinct,
       most_common_vals,
       most_common_freqs,
       correlation
postgres-# FROM pg_stats
postgres-# WHERE tablename = 'orders' AND attname = 'status';
 attname | n_distinct | most_common_vals          | most_common_freqs           | correlation
postgres=# ---------+------------+---------------------------+-----------------------------+------------
 status  |          5 | {pending,shipped,          | {0.2015,0.1998,             |    0.0021
         |            |  delivered,cancelled,      |  0.2008,0.1990,             |
         |            |  returned}                 |  0.1989}                    |
postgres=# -- n_distinct = 5: five different status values
postgres=# -- most_common_vals: the actual values
postgres=# -- most_common_freqs: ~20% each (evenly distributed)
postgres=# -- correlation ≈ 0: physical order is unrelated to status order
postgres=# --   (high correlation → index scan is cheaper due to sequential reads)
```

### Join Reordering — Planner Picks the Best Order
**Explanation:** Here is a common scenario that confuses beginners. You write a multi-table join and the planner joins them in a different order than you wrote. This is normal — the planner reorders joins to minimize cost. If table A has 10 million rows, table B has 100 rows, and table C has 50,000 rows, the planner might start with B, join to C, then join to A — even though you wrote FROM A JOIN B JOIN C.

```sql
postgres=# -- You write:
EXPLAIN
postgres=# SELECT *
postgres-# FROM orders o                -- 50,000 rows
postgres-# JOIN customers c ON ...       -- 1,000 rows
postgres-# JOIN products p ON ...;       -- 200 rows
postgres=# -- Planner may reorder to:
postgres=# -- 1. Start with products (200 rows — smallest)
postgres=# -- 2. Join to orders (via index)
postgres=# -- 3. Join to customers (via index)
postgres=# -- The planner's order minimizes the number of
postgres=# -- rows flowing through each join step
postgres=# -- To see the actual order: read EXPLAIN bottom to top
postgres=# -- The deepest-nested scan runs first
```

### Spotting Disk Spills — work_mem Too Low
**Explanation:** One more critical detail: work_mem controls how much memory each sort and hash operation gets. When a hash or sort runs out of work_mem, it spills to disk — dramatically slower. In EXPLAIN output, you can spot this. For sorts, it says 'external merge Disk' instead of 'quicksort Memory'. For hashes, Batches is greater than 1. The fix is to increase work_mem.

```sql
postgres=# -- Sort spilling to disk:
   Sort Method: external merge  Disk: 5120kB   ← BAD
   Sort Method: quicksort  Memory: 1024kB      ← GOOD
postgres=# -- Hash spilling to disk:
   Buckets: 4096  Batches: 4  Memory Usage: 4096kB  ← BAD (Batches > 1)
   Buckets: 4096  Batches: 1  Memory Usage: 4096kB  ← GOOD (Batches = 1)
postgres=# -- Fix: increase work_mem
postgres=# SET work_mem = '64MB';
postgres=# -- Re-run query — sort/hash should now fit in memory
postgres=# -- CAUTION: work_mem is per-operation, not per-query
postgres=# -- A complex query with 5 sorts uses 5 × work_mem
postgres=# -- Set globally conservative, per-session when needed
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf — Planner Tuning` — Planner Cost Parameters
You can influence the planner with cost parameters. If your storage is SSD, lower random_page_cost from 4.0 to 1.1 — this tells the planner that random reads are almost as fast as sequential reads, making it more likely to choose index scans. If you have lots of RAM, adjust effective_cache_size to tell the planner how much data is likely cached. You can apply these parameters without downtime by executing SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `random_page_cost` | `4.0 → 1.1 (SSD)` | `[RELOAD]` (Live Reload `SIGHUP`) | Lower for SSD — makes index scans more likely (Default: 4.0) |
| `seq_page_cost` | `1.0` | `[RELOAD]` (Live Reload `SIGHUP`) | Base unit — usually leave at default (Default: 1.0) |
| `effective_cache_size` | `4GB → 75% of RAM` | `[RELOAD]` (Live Reload `SIGHUP`) | Tells planner how much data is likely cached by OS + PG (Default: 4GB) |
| `work_mem` | `4MB → 64MB` | `[RELOAD]` (Live Reload `SIGHUP`) | Memory per sort/hash operation — higher = less disk spill (Default: 4MB) |
| `default_statistics_target` | `100 → 200` | `[RELOAD]` (Live Reload `SIGHUP`) | More samples for ANALYZE — better estimates for skewed data (Default: 100) |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Forcing Plans with enable_ Flags
A very common beginner trap is disabling planner options to force a plan. You read online that Hash Join is slow, so you SET enable_hashjoin = off. This forces the planner to use a different algorithm that might be much worse for your query. Never disable planner options in production. Fix the root cause instead — update statistics, add proper indexes, or tune cost parameters.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Three join algorithms: Nested Loop for small outer plus indexed inner, Hash Join for medium-to-large equi-joins, Merge Join for pre-sorted or very large data. The planner generates candidate plans, estimates costs from statistics, and picks the cheapest. It freely reorders joins for efficiency. Key tuning: random_page_cost for SSD, work_mem for sort and hash memory, effective_cache_size for cache estimates, and always ANALYZE for accurate statistics. In the next class, we cover common optimization techniques and pg_stat_statements.

- **Nested Loop: for each outer row, scan inner (fast with small outer + index)**
- **Hash Join: build hash from smaller table, probe with larger (equi-join only)**
- **Merge Join: sort both inputs, merge in one pass (good if pre-sorted)**
- **Planner tries all combinations and picks lowest estimated cost**
- **Join order in SQL does NOT force join execution order**
- **GEQO: genetic optimizer kicks in at >= 12 joined tables**
- **work_mem: increase to avoid hash/sort disk spills**
- **random_page_cost: lower to 1.1 for SSD storage**
- **Never disable planner options in production — fix root causes instead**
- **Next: Optimization Techniques & pg_stat_statements**


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
