# Index Only Scans, Parallel Queries & JIT
**Series:** PostgreSQL Mastery | **Phase:** Phase 20: Query Optimization & Performance | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In this class we dive deeper into three advanced execution features: Index Only Scans — how they work and why the visibility map matters, parallel query execution — where PostgreSQL uses multiple CPU cores, and JIT compilation — where PostgreSQL compiles query expressions into machine code. These three features can dramatically improve performance when used correctly. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Index Types for Index Only Scans
There are three ways to create an index that supports Index Only Scans. A regular B-tree index covers only its columns. An INCLUDE index adds non-key columns to the leaf pages. A multi-column index covers all its columns. Choose based on whether the extra columns need to be searchable or just readable.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | There are three ways to create an index that supports Index Only Scans |
| **A regular B** | tree index covers only its columns |
| **An INCLUDE index adds non** | key columns to the leaf pages |
| **A multi** | column index covers all its columns |
| **Point 5** | Choose based on whether the extra columns need to be searchable or just readable |

### Parallel Query Execution
Now let us talk about parallel queries. Starting in PostgreSQL 9.6, PostgreSQL can use multiple worker processes to speed up a single query. A leader process coordinates the work and one or more worker processes handle portions of the scan, join, or aggregation. This is especially powerful for large sequential scans and aggregations.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Leader Process** | Coordinates the query, gathers results from workers |
| **Worker Processes** | Each handles a portion of the scan or computation |
| **Parallel-Safe** | Only operations marked parallel-safe can run in workers |
| **Gather / Gather Merge** | Plan nodes that collect results from workers |

**Notes:**
- Not all queries benefit — overhead of coordination can exceed savings
- Best for: large scans, aggregations, hash joins on big tables

### What Can Be Parallelized (PG 16)
Not all operations can run in parallel. Here is what can and cannot be parallelized in PostgreSQL 16.

| Parallel-Safe (Can Use Workers) | Not Parallel-Safe |
| :--- | :--- |
| Sequential Scans (Parallel Seq Scan) | Writing data (INSERT/UPDATE/DELETE) |
| B-tree Index Scans | Cursors (DECLARE CURSOR) |
| Bitmap Heap Scans | User-defined functions not marked PARALLEL SAFE |
| Hash Joins | Functions using temporary tables |
| Merge Joins | Queries inside a serializable transaction |
| Nested Loop Joins | CTEs with side effects |
| Aggregations (Partial + Finalize) | Queries with LIMIT (sometimes serial is faster) |
| Append (UNION ALL) |  |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### JIT Compilation (Just-In-Time)
Now let us talk about JIT compilation — Just-In-Time compilation. Normally, PostgreSQL interprets query expressions row by row. With JIT enabled, PostgreSQL compiles hot expressions — WHERE filters, aggregations, tuple projections — into native machine code using LLVM. This can significantly speed up CPU-bound queries that process many rows.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Without JIT** | PostgreSQL interprets expressions row by row (general-purpose executor) |
| **With JIT** | LLVM compiles expressions into native machine code at query time |
| **What Gets JIT-Compiled** | WHERE clause evaluation, aggregate functions, tuple deforming (column extraction) |
| **When It Helps** | CPU-bound queries processing millions of rows with complex expressions |

**Notes:**
- JIT has startup cost — compiling takes time
- Only worth it when compilation cost < interpretation savings
- The planner uses jit_above_cost threshold to decide

### Beginner Trap: JIT on Small Queries
A beginner trap with JIT: it can actually make small queries slower. The compilation overhead — typically 5 to 50 milliseconds — is wasted on a query that would run in 2 milliseconds without JIT. If you notice small queries getting slower, check if JIT is being triggered unnecessarily. The fix is to raise jit_above_cost, not to disable JIT entirely.

| JIT Hurts (Small Query) | JIT Helps (Large Query) |
| :--- | :--- |
| Query cost: 50 (below threshold) | Query cost: 500,000 (above threshold) |
| Without JIT: 2ms execution | Without JIT: 800ms execution |
| With JIT forced: 2ms + 15ms compile = 17ms | With JIT: 12ms compile + 300ms execution = 312ms |
| JIT overhead > query savings | JIT saves 488ms net |
| Fix: leave jit_above_cost at 100000 | Best for: large scans, complex aggregations |

### When to Use Each Feature
Here is a decision framework for when to use each of these three features. Index Only Scans are always beneficial — make sure your indexes cover your queries and keep VACUUM running. Parallel queries help with large scans and aggregations. JIT helps with CPU-heavy processing of many rows.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a decision framework for when to use each of these three features |
| **Index Only Scans are always beneficial** | make sure your indexes cover your queries and keep VACUUM running |
| **Point 3** | Parallel queries help with large scans and aggregations |
| **JIT helps with CPU** | heavy processing of many rows |


---

## 3. Hands-On Commands & psql Output

### Index Only Scan — Before & After VACUUM
**Explanation:** Here is what an Index Only Scan looks like in practice. First without a recent VACUUM — notice the Heap Fetches. Then after VACUUM — Heap Fetches drop to zero.

```sql
postgres=# -- Create a covering index:
postgres=# CREATE INDEX idx_orders_cust_amount
postgres-# ON orders(customer_id) INCLUDE (amount);
postgres=# -- Update some rows to dirty the visibility map:
postgres=# UPDATE orders SET amount = amount + 0.01 WHERE id < 1000;
postgres=# -- BEFORE VACUUM:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT customer_id, amount FROM orders
postgres-# WHERE customer_id BETWEEN 1 AND 50;
 Index Only Scan using idx_orders_cust_amount on orders
   (actual time=0.045..1.234 rows=2500 loops=1)
   Index Cond: (customer_id >= 1 AND customer_id <= 50)
   Heap Fetches: 487      ← had to check 487 rows in heap
postgres=# -- Run VACUUM to update visibility map:
postgres=# VACUUM orders;
postgres=# -- AFTER VACUUM:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT customer_id, amount FROM orders
postgres-# WHERE customer_id BETWEEN 1 AND 50;
 Index Only Scan using idx_orders_cust_amount on orders
   (actual time=0.032..0.456 rows=2500 loops=1)
   Index Cond: (customer_id >= 1 AND customer_id <= 50)
   Heap Fetches: 0         ← pure index read!
```

### Parallel Sequential Scan
**Explanation:** Here is a parallel sequential scan in action. Notice the Gather node at the top — it collects results from the workers. Below it, the Parallel Seq Scan shows each worker scanning a portion of the table. The Workers Planned and Workers Launched show how many parallel workers were used.

```sql
postgres=# -- Large aggregation triggers parallel execution:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT status, COUNT(*), AVG(amount)
postgres-# FROM orders
postgres-# GROUP BY status;
                                    QUERY PLAN
postgres=# ---------------------------------------------------------------------------
 Finalize HashAggregate
   (actual time=15.234..15.248 rows=5 loops=1)
   Group Key: status
   -> Gather
      (actual time=5.123..15.189 rows=15 loops=1)
      Workers Planned: 2
      Workers Launched: 2
      -> Partial HashAggregate
         (actual time=3.456..3.478 rows=5 loops=3)
         Group Key: status
         -> Parallel Seq Scan on orders
            (actual time=0.012..1.890 rows=16667 loops=3)
postgres=# -- loops=3: leader + 2 workers each scanned ~16,667 rows
postgres=# -- Total: 16,667 × 3 = 50,000 rows (the full table)
postgres=# -- Each worker does partial aggregation, leader finalizes
```

### Per-Table Parallel Workers
**Explanation:** You can control parallelism per-table if some tables benefit more than others. This is useful when the global default of 2 workers is not enough for your largest tables.

```sql
postgres=# -- Check current table-level parallel setting:
postgres=# SELECT relname, reloptions
postgres-# FROM pg_class
postgres-# WHERE relname = 'orders';
postgres=# -- Set 4 workers for the orders table:
postgres=# ALTER TABLE orders SET (parallel_workers = 4);
postgres=# -- Verify:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT status, COUNT(*) FROM orders GROUP BY status;
 Gather
   Workers Planned: 4
   Workers Launched: 4
   -> Partial HashAggregate
      -> Parallel Seq Scan on orders
         (actual time=0.008..0.987 rows=10000 loops=5)
postgres=# -- loops=5 = leader + 4 workers
postgres=# -- Each processes ~10,000 of 50,000 rows
postgres=# -- Reset to default:
postgres=# ALTER TABLE orders RESET (parallel_workers);
```

### JIT in EXPLAIN ANALYZE Output
**Explanation:** Here is JIT in action. When the estimated cost exceeds jit_above_cost (default 100,000), PostgreSQL automatically JIT-compiles the query. You can see this in EXPLAIN ANALYZE output — it shows JIT timing for generation, inlining, optimization, and emission.

```sql
postgres=# -- Enable JIT and lower threshold for demo:
postgres=# SET jit = on;
postgres=# SET jit_above_cost = 10;
postgres=# EXPLAIN ANALYZE
postgres=# SELECT status, COUNT(*), AVG(amount)
postgres-# FROM orders
postgres-# WHERE amount > 100
postgres-# GROUP BY status;
 ...
 JIT:
   Functions: 12
   Options: Inlining true, Optimization true, Expressions true,
            Deforming true
   Timing:
     Generation  1.234 ms
     Inlining    5.678 ms
     Optimization 3.456 ms
     Emission     2.345 ms
     Total       12.713 ms
postgres=# -- JIT compiled 12 functions
postgres=# -- Total JIT overhead: 12.7ms
postgres=# -- For large datasets, this overhead is repaid many times over
RESET jit_above_cost;
```

### Monitoring Queries
**Explanation:** Here are common monitoring queries to check if these features are working correctly in your database.

```sql
-- Check Heap Fetches across all Index Only Scans:
SELECT relname,
       idx_scan,
       idx_tup_read,
       idx_tup_fetch  -- rows fetched from heap (lower = better)
FROM pg_stat_user_indexes
WHERE idx_scan > 0
ORDER BY idx_tup_fetch DESC;

-- Check visibility map coverage:
SELECT relname,
       n_live_tup,
       n_dead_tup,
       last_vacuum,
       last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000;

-- Check if parallel workers are being used:
-- (Run EXPLAIN ANALYZE and look for Workers Launched)

-- Check JIT availability:
SHOW jit;
SELECT pg_jit_available();
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf — Parallel Execution` — Parallel Query Configuration
The planner decides whether to use parallel execution based on cost estimates and these configuration parameters. The most important are max_parallel_workers_per_gather (how many workers per query) and min_parallel_table_scan_size (minimum table size to trigger parallel scan). Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `max_worker_processes` | `8` | **`[RESTART]`** (Postmaster Restart) | Total background workers across the server (default 8) (Default: 8) |
| `max_parallel_workers` | `8` | `[RELOAD]` (Live Reload `SIGHUP`) | Maximum workers available for parallel queries (Default: 8) |
| `max_parallel_workers_per_gather` | `2` | `[RELOAD]` (Live Reload `SIGHUP`) | Maximum workers per single query (default 2) (Default: 2) |
| `min_parallel_table_scan_size` | `8MB` | `[RELOAD]` (Live Reload `SIGHUP`) | Table must be >= this size to consider parallel scan (Default: 8MB) |
| `min_parallel_index_scan_size` | `512kB` | `[SETTING]` | Index must be >= this size for parallel index scan |
| `parallel_setup_cost` | `1000` | `[SETTING]` | Startup cost of launching workers (higher = less likely) |
| `parallel_tuple_cost` | `0.1` | `[SETTING]` | Cost of passing each tuple from worker to leader |


### File: `postgresql.conf — JIT Settings` — JIT Configuration
JIT configuration has four cost thresholds. Each one controls when a more expensive JIT optimization kicks in. The defaults are tuned for production — only queries expensive enough to benefit will trigger JIT.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `jit` | `on` | `[SETTING]` | Enable JIT compilation (default: on in PG 16) |
| `jit_above_cost` | `100000` | `[SETTING]` | Enable JIT when estimated cost exceeds this |
| `jit_inline_above_cost` | `500000` | `[SETTING]` | Inline small functions when cost exceeds this |
| `jit_optimize_above_cost` | `500000` | `[SETTING]` | Apply LLVM optimization passes when cost exceeds this |
| `jit_provider` | `llvmjit` | `[SETTING]` | JIT provider library (only LLVM supported) |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: JIT on Small Queries
A beginner trap with JIT: it can actually make small queries slower. The compilation overhead — typically 5 to 50 milliseconds — is wasted on a query that would run in 2 milliseconds without JIT. If you notice small queries getting slower, check if JIT is being triggered unnecessarily. The fix is to raise jit_above_cost, not to disable JIT entirely.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Index Only Scans read data purely from the index, skipping the table heap — VACUUM keeps the visibility map current so Heap Fetches stay at zero. Parallel queries split large scans and aggregations across multiple workers, controlled by max_parallel_workers_per_gather. JIT compiles query expressions into native machine code using LLVM, beneficial for CPU-bound queries on many rows but harmful for small queries. Together, these three features let PostgreSQL handle analytical workloads much faster. In the next class, we apply everything we have learned to real optimization scenarios.

- **Index Only Scan: reads all data from index, skips heap**
- **Heap Fetches: caused by dirty pages — VACUUM fixes them**
- **INCLUDE clause: adds non-key columns to index leaf pages**
- **Parallel query: splits work across leader + workers**
- **Gather / Gather Merge: nodes that collect worker results**
- **max_parallel_workers_per_gather = 2 (default, increase for big tables)**
- **ALTER TABLE SET (parallel_workers = N) for per-table control**
- **JIT: LLVM compiles expressions into native code**
- **JIT helps CPU-heavy queries on many rows (cost > 100,000)**
- **JIT hurts small queries — compilation overhead > savings**
- **All three features work together for analytical workloads**
- **Next: Real-World Optimization Scenarios**


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
