# Partition Pruning & Sub-Partitioning — Skipping What You Don't Need
**Series:** PostgreSQL Mastery | **Phase:** Phase 22: Table Partitioning | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the last two classes we created range, list, and hash partitions. But how does PostgreSQL decide which partitions to scan and which to skip? That mechanism is called partition pruning. And what if you need to combine two partitioning strategies — for example, partition by year AND by region? That is sub-partitioning. Let us master both.


---

## 2. Core Technical Concepts & Mechanisms

### Partition Pruning — Two Stages
Partition pruning is the process where PostgreSQL eliminates partitions from a query plan before or during execution. If your WHERE clause filters on the partition key, PostgreSQL knows which partitions can contain matching rows and skips all others. This happens at two stages — plan time and execution time.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Plan-Time Pruning** | Before execution — WHERE has literal values (order_date = '2026-03-15'). Pruned partitions never appear in EXPLAIN. |
| **Execution-Time Pruning** | During execution — WHERE uses parameters, subqueries, or joins. Partitions appear in EXPLAIN but show (never executed). |

**Notes:**
- enable_partition_pruning = on (default, rarely change this)
- Pruning works with =, <, >, <=, >=, BETWEEN, IN, IS NULL
- Pruning does NOT work with functions on the partition key
- WHERE EXTRACT(month FROM order_date) = 3 → no pruning!

### Beginner Trap: Functions Kill Pruning
The biggest beginner trap with partition pruning: applying a function to the partition key destroys pruning. If you write WHERE EXTRACT(month FROM order_date) equals 3, PostgreSQL cannot match that to a partition range. Always write conditions directly on the partition key column.

| BAD — No Pruning | GOOD — Pruning Works |
| :--- | :--- |
| WHERE EXTRACT(month FROM order_date) = 3 | WHERE order_date >= '2026-03-01' AND order_date < '2026-04-01' |
| WHERE date_trunc('month', order_date) = ... | WHERE order_date BETWEEN '2026-03-01' AND '2026-03-31' |
| WHERE order_date::text LIKE '2026-03%' | WHERE order_date = '2026-03-15' |
| WHERE order_date + 1 = '2026-03-02' | WHERE order_date IN ('2026-03-01', '2026-03-15') |
| Any function/cast on the partition key | Direct comparison on the column |
| Result: scans ALL partitions (slow!) | Result: scans only matching partitions |

### Sub-Partitioning — Two-Level Hierarchy
Now let us move to sub-partitioning. Sub-partitioning means a partition itself is partitioned. For example, you partition orders by year using range, and then each yearly partition is further partitioned by region using list. This creates a two-level hierarchy.

```
[orders
(RANGE by year)]
[orders_2025
(LIST by region)]
[orders_2026
(LIST by region)]
[orders_2025
_north]
[orders_2025
_south]
[orders_2025
_east]
[orders_2026
_north]
[orders_2026
_south]
[orders_2026
_east]
```

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Sub-Partitioning Rules
The partition key for sub-partitioned tables must include ALL partitioning columns. In our example, the primary key is (id, order_date, region) because order_date is the level-1 key and region is the level-2 key. Both must be in any unique constraint.

| Rule | Detail |
| :--- | :--- |
| PK includes ALL partition keys | (id, order_date, region) — both levels |
| Methods can mix | Range + List, Range + Hash, List + Hash, etc. |
| Leaf partitions hold data | Mid-level partitions are routing layers only |
| Indexes cascade | CREATE INDEX on parent → all leaf partitions |
| Max depth | No hard limit but 2-3 levels is practical max |
| DEFAULT at each level | Each mid-level can have its own default partition |
| Naming convention | parent_level1_level2 (e.g., orders_2026_north) |

### When to Use Sub-Partitioning
When should you use sub-partitioning versus single-level partitioning? Sub-partitioning is worth it when queries regularly filter on two dimensions AND the table is large enough that single-level partitioning still leaves partitions too big. For most tables, single-level partitioning is sufficient.

| Good Candidates | Bad Candidates |
| :--- | :--- |
| Billions of rows across two dimensions | Table under 100M rows |
| Queries always filter on BOTH keys | Queries rarely filter on second key |
| IoT: date + device_type | Too many leaf partitions (1000+) |
| Global SaaS: date + tenant | Adds management complexity |
| E-commerce: date + region | Single-level partitions already small |
| Need DROP by both dimensions | Better to index the second column |

### Partition Count — Performance Impact
A practical warning about too many partitions. Each partition is a separate table with its own files, statistics, and locks. Having thousands of partitions slows down planning, ANALYZE, and pg_dump. A good rule: keep total partitions under 500 for most workloads, and ideally under 200.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | A practical warning about too many partitions |
| **Point 2** | Each partition is a separate table with its own files, statistics, and locks |
| **Point 3** | Having thousands of partitions slows down planning, ANALYZE, and pg_dump |
| **A good rule** | keep total partitions under 500 for most workloads, and ideally under 200 |

### Verifying Partition Pruning
Let us look at how to verify that pruning is actually happening. Use EXPLAIN ANALYZE with the COSTS option and look for three things: which partitions appear in the plan, whether any show 'never executed', and the actual time.

- Step 1: Run EXPLAIN (ANALYZE, COSTS OFF) on your query -- Look at which partitions appear under the Append node
- Step 2: Count the partitions listed -- If only 1-2 of 12 monthly partitions appear → plan-time pruning worked
- Step 3: Look for '(never executed)' lines -- These partitions were pruned at execution time (prepared statements)
- Step 4: Check 'Subplans Removed' in Append -- Shows how many partitions were pruned at plan time
- Step 5: Compare actual times -- Pruned query should be proportionally faster (1/12 for monthly)

### Partition Pruning vs Constraint Exclusion
One more important feature: constraint exclusion. This is an older mechanism that also skips partitions, but it works differently from partition pruning. In PostgreSQL 16, partition pruning is the primary mechanism and handles partitioned tables. Constraint exclusion handles inheritance-based partitioning — the old manual approach. You do not need to use constraint exclusion for declarative partitioning.

| Partition Pruning (Modern) | Constraint Exclusion (Legacy) |
| :--- | :--- |
| enable_partition_pruning = on | constraint_exclusion = partition |
| Works with declarative partitioning | Works with inheritance partitioning |
| Plan-time AND execution-time | Plan-time ONLY |
| Handles prepared statements | Does NOT handle parameters |
| Default mechanism in PG 10+ | Pre-PG10 mechanism |
| Use THIS for new tables | Only for legacy systems |


---

## 3. Hands-On Commands & psql Output

### Plan-Time Pruning — Literal Values in WHERE
**Explanation:** Let us see partition pruning in action with EXPLAIN. We will query our orders table that has monthly partitions and see exactly which partitions are scanned.

```sql
postgres=# -- Query for March 2026 (literal date):
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT * FROM orders
postgres-# WHERE order_date >= '2026-03-01'
postgres-# AND order_date < '2026-04-01';
 Append
   -> Seq Scan on orders_2026_03 orders_1
         Filter: (order_date >= '2026-03-01' AND
                  order_date < '2026-04-01')
postgres=# -- ONLY orders_2026_03 appears!
postgres=# -- All other monthly partitions were pruned at PLAN time
postgres=# -- They don't even show in the EXPLAIN output
postgres=# -- Compare with a query spanning 3 months:
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT * FROM orders
postgres-# WHERE order_date >= '2026-03-01'
postgres-# AND order_date < '2026-06-01';
 Append
   -> Seq Scan on orders_2026_03 orders_1
   -> Seq Scan on orders_2026_04 orders_2
   -> Seq Scan on orders_2026_05 orders_3
postgres=# -- Three partitions scanned, rest pruned
```

### Execution-Time Pruning — Prepared Statements
**Explanation:** Execution-time pruning happens when the partition key value is not known at plan time — for example, with prepared statements, parameterized queries, or subqueries. The partitions appear in the EXPLAIN plan but show 'never executed' in EXPLAIN ANALYZE.

```sql
postgres=# -- Prepared statement (value unknown at plan time):
PREPARE get_month_orders(date, date) AS
postgres=# SELECT * FROM orders
postgres-# WHERE order_date >= $1 AND order_date < $2;
postgres=# EXPLAIN ANALYZE EXECUTE get_month_orders(
    '2026-06-01', '2026-07-01'
);
 Append (actual time=0.015..5.234 rows=83422 loops=1)
   -> Seq Scan on orders_2026_01 (never executed)
   -> Seq Scan on orders_2026_02 (never executed)
   -> Seq Scan on orders_2026_03 (never executed)
   -> Seq Scan on orders_2026_04 (never executed)
   -> Seq Scan on orders_2026_05 (never executed)
   -> Seq Scan on orders_2026_06
        (actual time=0.012..3.456 rows=83422 loops=1)
   -> Seq Scan on orders_2026_07 (never executed)
   ...
postgres=# -- All partitions listed but only orders_2026_06 executed!
postgres=# -- "(never executed)" = execution-time pruning
```

### Pruning Destroyed by Function — Proof
**Explanation:** Let us prove this with EXPLAIN. Watch what happens when we use EXTRACT versus a direct range comparison on the same data.

```sql
postgres=# -- BAD: function on partition key → all partitions scanned:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT COUNT(*) FROM orders
postgres-# WHERE EXTRACT(month FROM order_date) = 3
postgres-# AND EXTRACT(year FROM order_date) = 2026;
 Aggregate (actual time=245.678..245.679 rows=1)
   -> Append (actual time=0.015..220.123 rows=83422)
        -> Seq Scan on orders_2025_01  (actual rows=0)
        -> Seq Scan on orders_2025_02  (actual rows=0)
        ... ALL 18+ partitions scanned!
 Planning Time: 1.234 ms
 Execution Time: 246.012 ms
postgres=# -- GOOD: direct range → only 1 partition:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT COUNT(*) FROM orders
postgres-# WHERE order_date >= '2026-03-01'
postgres-# AND order_date < '2026-04-01';
 Aggregate (actual time=15.234..15.235 rows=1)
   -> Seq Scan on orders_2026_03
        (actual rows=83422)
 Planning Time: 0.456 ms
 Execution Time: 15.678 ms
postgres=# -- 246ms vs 15ms — 16x faster with pruning!
```

### Pruning with JOINs
**Explanation:** Partition pruning also works with JOINs. When you join a partitioned table with another table, and the join condition or WHERE clause filters the partition key, PostgreSQL prunes partitions just like a simple query.

```sql
postgres=# -- Create a small lookup table:
postgres=# CREATE TABLE promotions (
    id         SERIAL PRIMARY KEY,
    promo_name TEXT,
    start_date DATE,
    end_date   DATE
);
postgres=# INSERT INTO promotions VALUES
    (1, 'Spring Sale', '2026-03-01', '2026-04-01');
postgres=# -- Join with partition pruning:
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT o.id, o.amount, p.promo_name
postgres-# FROM orders o
postgres-# JOIN promotions p ON TRUE
postgres-# WHERE o.order_date >= p.start_date
postgres-# AND o.order_date < p.end_date
postgres-# AND p.id = 1;
postgres=# -- With execution-time pruning, PostgreSQL resolves
postgres=# -- p.start_date and p.end_date at runtime, then
postgres=# -- prunes to only orders_2026_03
postgres=# -- Also works with subqueries:
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT * FROM orders
postgres-# WHERE order_date = (
postgres=# SELECT MAX(start_date) FROM promotions WHERE id = 1
);
postgres=# -- Prunes at execution time after subquery resolves
```

### Creating Sub-Partitions
**Explanation:** Here is the SQL to create a sub-partitioned table. The parent is partitioned by range on year. Each yearly partition is itself partitioned by list on region. The leaf partitions — the bottom level — hold the actual data.

```sql
-- Level 1: Parent partitioned by RANGE (year)
CREATE TABLE global_orders (
    id          BIGSERIAL,
    customer_id INTEGER NOT NULL,
    amount      NUMERIC(10,2),
    region      TEXT NOT NULL,
    order_date  DATE NOT NULL,
    PRIMARY KEY (id, order_date, region)
) PARTITION BY RANGE (order_date);

-- Level 2: Yearly partitions, each sub-partitioned by LIST
CREATE TABLE global_orders_2025
    PARTITION OF global_orders
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01')
    PARTITION BY LIST (region);

CREATE TABLE global_orders_2026
    PARTITION OF global_orders
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01')
    PARTITION BY LIST (region);

-- Level 3: Leaf partitions (hold actual data)
CREATE TABLE global_orders_2025_north
    PARTITION OF global_orders_2025
    FOR VALUES IN ('north');
CREATE TABLE global_orders_2025_south
    PARTITION OF global_orders_2025
    FOR VALUES IN ('south');
CREATE TABLE global_orders_2026_north
    PARTITION OF global_orders_2026
    FOR VALUES IN ('north');
CREATE TABLE global_orders_2026_south
    PARTITION OF global_orders_2026
    FOR VALUES IN ('south');
```

### Multi-Dimensional Pruning
**Explanation:** Sub-partitioning gives you multi-dimensional pruning. If a query filters by both year AND region, PostgreSQL prunes at both levels — first to the year, then to the region. Only the single leaf partition that matches both conditions is scanned.

```sql
postgres=# -- Insert test data:
postgres=# INSERT INTO global_orders
  (customer_id, amount, region, order_date)
VALUES
  (1, 100.00, 'north', '2025-06-15'),
  (2, 200.00, 'south', '2026-03-20'),
  (3, 150.00, 'north', '2026-08-10');
postgres=# -- Query both dimensions:
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT * FROM global_orders
postgres-# WHERE order_date >= '2026-01-01'
postgres-# AND order_date < '2027-01-01'
postgres-# AND region = 'north';
 Append
   -> Seq Scan on global_orders_2026_north
         Filter: (order_date >= '2026-01-01' AND
                  order_date < '2027-01-01' AND
                  region = 'north')
postgres=# -- Only ONE leaf partition scanned!
postgres=# -- Level 1 pruned: 2025 eliminated (wrong year)
postgres=# -- Level 2 pruned: south eliminated (wrong region)
postgres=# -- Result: only global_orders_2026_north
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Functions Kill Pruning
The biggest beginner trap with partition pruning: applying a function to the partition key destroys pruning. If you write WHERE EXTRACT(month FROM order_date) equals 3, PostgreSQL cannot match that to a partition range. Always write conditions directly on the partition key column.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Partition pruning eliminates partitions that cannot contain matching rows. It happens at plan time with literal values and at execution time with parameters. Never apply functions to the partition key — it destroys pruning. Sub-partitioning creates multi-level hierarchies for two-dimensional pruning. Keep total partition count under 200-500 for best performance. Use EXPLAIN ANALYZE to verify pruning is working. In the next class, we cover managing partitions — adding, dropping, attaching, and detaching.

- **Plan-time pruning: literal values → pruned partitions not in EXPLAIN**
- **Execution-time pruning: parameters → shows '(never executed)'**
- **Functions on partition key DESTROY pruning — use direct comparisons**
- **Pruning works with =, <, >, BETWEEN, IN, IS NULL**
- **Sub-partitioning: partition a partition (RANGE + LIST, etc.)**
- **All partition keys must be in PRIMARY KEY / UNIQUE constraints**
- **Multi-dimensional pruning: both levels pruned in one query**
- **Keep total partitions under 200-500 for manageable overhead**
- **EXPLAIN ANALYZE: verify pruning with actual execution**
- **Next: Managing Partitions (ADD, DROP, ATTACH, DETACH)**


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
