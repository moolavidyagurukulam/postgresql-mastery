# List & Hash Partitioning — Splitting by Category and Even Distribution
**Series:** PostgreSQL Mastery | **Phase:** Phase 22: Table Partitioning | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class we covered range partitioning — splitting tables by a continuous range like dates. But what if you want to split by country, region, or status? That is list partitioning. And what if you just want even distribution with no natural grouping column? That is hash partitioning. Let us master both in this class.


---

## 2. Core Technical Concepts & Mechanisms

### Choosing a Partitioning Method
Here is when you use each partitioning method. Range partitioning is for continuous data — dates, IDs, timestamps — where you query by range. List partitioning is for discrete categories — country, region, status, department — where you query by specific values. Hash partitioning is for even distribution when there is no natural grouping — you just want to split a huge table into N equal-sized chunks.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Here** | when you use each partitioning method |
| **Range partitioning** | for continuous data — dates, IDs, timestamps — where you query by range |
| **List partitioning** | for discrete categories — country, region, status, department — where you query by specific values |
| **Hash partitioning** | for even distribution when there is no natural grouping — you just want to split a huge table into N equal-sized chunks |

### Hash Partitioning
Now let us move to hash partitioning. Hash partitioning distributes rows evenly across N partitions using a hash function on the partition key. You do not choose which rows go where — PostgreSQL hashes the value and assigns it to a partition. This is useful when no column has a natural grouping but you want smaller, more manageable chunks.

| Term | Meaning / Explanation |
| :--- | :--- |
| **How It Works** | PostgreSQL hashes the partition key value and assigns it to partition N where N = hash(value) % modulus |
| **Syntax** | PARTITION BY HASH (column), partitions use FOR VALUES WITH (MODULUS m, REMAINDER r) |
| **Distribution** | Roughly equal rows per partition (not perfectly even, but close) |

**Notes:**
- Modulus = total number of partitions
- Remainder = 0 to (modulus - 1) for each partition
- You cannot control which rows go where
- Hash partitioning does NOT help with range queries

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Hash Partitioning — Key Limitations
Here are the critical differences between hash partitioning and the other methods. Hash partitioning gives you even distribution but no pruning on range queries. You cannot add or remove partitions easily — changing the modulus requires recreating all partitions.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are the critical differences between hash partitioning and the other methods |
| **Point 2** | Hash partitioning gives you even distribution but no pruning on range queries |
| **Point 3** | You cannot add or remove partitions easily — changing the modulus requires recreating all partitions |

### Partitioning Decision Framework
Let us compare all three methods side by side with a practical decision framework. Ask yourself these questions when choosing a partitioning strategy.

- Step 1: Do you filter by a date or timestamp range? -- YES → Range partitioning (monthly/quarterly partitions)
- Step 2: Do you filter by a specific category value? -- YES → List partitioning (one partition per value or group)
- Step 3: Do you need to DROP old data by time period? -- YES → Range partitioning (DROP TABLE partition = instant)
- Step 4: Is this multi-tenant where queries always filter by tenant? -- YES → List partitioning (one partition per tenant)
- Step 5: No natural grouping, just need to split a huge table? -- YES → Hash partitioning (even distribution, parallel queries)
- Step 6: Table is under 10-50 million rows? -- Probably don't partition — indexes are often enough

### Beginner Trap: Partitioning Too Early
A common beginner trap is partitioning too early. Partitioning adds complexity — every primary key and unique constraint must include the partition key, foreign keys referencing partitioned tables are limited, and you must manage partition creation. For tables under about 10 million rows, a regular index usually performs just as well.

| When to Partition | When NOT to Partition |
| :--- | :--- |
| Table is 50M+ rows and growing | Table is under 10M rows |
| Queries always filter by the partition key | Queries don't filter by any good partition key |
| You need to DROP old data regularly | You rarely delete old data |
| VACUUM on the full table takes too long | Indexes already give good performance |
| Parallel scans would help your workload | Adding partition key to PK is too disruptive |

### Hash Partition Count Guidelines
For hash partitioning, choosing the right number of partitions matters. Too few partitions give little benefit. Too many create overhead. A good starting point is 2 to 4 times the number of CPU cores, rounded up to a power of 2 for easy math. And always use a power of 2 for the modulus — it makes future re-partitioning cleaner.

| Term | Meaning / Explanation |
| :--- | :--- |
| **For hash partitioning** | choosing the right number of partitions matters |
| **Point 2** | Too few partitions give little benefit |
| **Point 3** | Too many create overhead |
| **Point 4** | A good starting point is 2 to 4 times the number of CPU cores, rounded up to a power of 2 for easy math |
| **Point 5** | And always use a power of 2 for the modulus — it makes future re-partitioning cleaner |


---

## 3. Hands-On Commands & psql Output

### Creating a List-Partitioned Table
**Explanation:** List partitioning splits a table by specific values in a column. Each partition holds rows where the partition key matches one or more values from a defined list. Let us create a sales table partitioned by region.

```sql
postgres=# -- Create parent table partitioned by LIST:
postgres=# CREATE TABLE sales (
    id          BIGSERIAL,
    product     TEXT NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    region      TEXT NOT NULL,
    sale_date   DATE NOT NULL,
    PRIMARY KEY (id, region)  -- partition key in PK!
) PARTITION BY LIST (region);
postgres=# -- Create one partition per region:
postgres=# CREATE TABLE sales_north PARTITION OF sales
    FOR VALUES IN ('north');
postgres=# CREATE TABLE sales_south PARTITION OF sales
    FOR VALUES IN ('south');
postgres=# CREATE TABLE sales_east PARTITION OF sales
    FOR VALUES IN ('east');
postgres=# CREATE TABLE sales_west PARTITION OF sales
    FOR VALUES IN ('west');
postgres=# -- One partition can hold MULTIPLE values:
postgres=# CREATE TABLE sales_overseas PARTITION OF sales
    FOR VALUES IN ('europe', 'asia', 'africa');
```

### List Partitioning — Data Routing
**Explanation:** Now let us insert data and see automatic routing, just like range partitioning. Each row goes to the partition whose list matches the region value.

```sql
postgres=# INSERT INTO sales (product, amount, region, sale_date)
VALUES
  ('Widget A', 100.00, 'north', '2026-01-15'),
  ('Widget B', 250.00, 'south', '2026-02-20'),
  ('Widget C', 175.00, 'europe', '2026-03-10'),
  ('Widget D', 300.00, 'east', '2026-04-05');
postgres=# -- Check routing:
postgres=# SELECT tableoid::regclass AS partition,
       id, product, region
postgres-# FROM sales;
    partition     | id | product  | region
postgres=# ------------------+----+----------+--------
 sales_north      |  1 | Widget A | north
 sales_south      |  2 | Widget B | south
 sales_overseas   |  3 | Widget C | europe
 sales_east       |  4 | Widget D | east
postgres=# -- 'europe' went to sales_overseas (matches IN list)
postgres=# -- Query for one region — only that partition scanned:
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT * FROM sales WHERE region = 'north';
 Append
   -> Seq Scan on sales_north sales_1
         Filter: (region = 'north')
```

### List Partitioning — Missing Values & Default
**Explanation:** Just like range partitioning, if you insert a value that does not match any partition, you get an error. A DEFAULT partition catches unmatched values.

```sql
postgres=# -- Try inserting an unknown region:
postgres=# INSERT INTO sales (product, amount, region, sale_date)
postgres-# VALUES ('Widget E', 50.00, 'australia', '2026-05-01');
postgres=# -- ERROR: no partition of relation "sales" found for row
postgres=# -- DETAIL: Partition key of the failing row contains
postgres=# --         (region) = (australia).
postgres=# -- Fix: add a default partition:
postgres=# CREATE TABLE sales_other PARTITION OF sales DEFAULT;
postgres=# INSERT INTO sales (product, amount, region, sale_date)
postgres-# VALUES ('Widget E', 50.00, 'australia', '2026-05-01');
postgres=# -- INSERT 0 1  → goes to sales_other
postgres=# -- Later, create a proper partition:
postgres=# -- (must first move rows out of default)
postgres=# CREATE TABLE sales_oceania PARTITION OF sales
    FOR VALUES IN ('australia', 'new_zealand');
postgres=# -- ERROR if sales_other contains 'australia' rows
postgres=# -- → must DELETE from default first, then create partition
```

### Multi-Tenant with List Partitioning
**Explanation:** A common real-world use case for list partitioning is multi-tenant SaaS. Each tenant gets its own partition. This gives you data isolation, per-tenant backups, and easy tenant removal — just drop the partition.

```sql
-- SaaS application — partition by tenant:
CREATE TABLE events (
    id          BIGSERIAL,
    tenant_id   TEXT NOT NULL,
    event_type  TEXT NOT NULL,
    payload     JSONB,
    created_at  TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (id, tenant_id)
) PARTITION BY LIST (tenant_id);

-- One partition per paying customer:
CREATE TABLE events_acme PARTITION OF events
    FOR VALUES IN ('acme');
CREATE TABLE events_globex PARTITION OF events
    FOR VALUES IN ('globex');
CREATE TABLE events_initech PARTITION OF events
    FOR VALUES IN ('initech');
CREATE TABLE events_default PARTITION OF events
    DEFAULT;

-- Benefits:
--   Queries always filter by tenant_id → one partition
--   VACUUM runs per-tenant (small, fast)
--   Offboard a tenant: DROP TABLE events_acme;
--   Backup one tenant: pg_dump -t events_acme
```

### Creating a Hash-Partitioned Table
**Explanation:** Let us create a hash-partitioned table. We partition a sessions table by user_id into 4 partitions. Each partition gets roughly 25 percent of the rows.

```sql
postgres=# -- Parent table:
postgres=# CREATE TABLE sessions (
    id         BIGSERIAL,
    user_id    INTEGER NOT NULL,
    ip_addr    INET,
    started_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (id, user_id)  -- partition key in PK
) PARTITION BY HASH (user_id);
postgres=# -- Create 4 partitions (modulus = 4):
postgres=# CREATE TABLE sessions_p0 PARTITION OF sessions
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);
postgres=# CREATE TABLE sessions_p1 PARTITION OF sessions
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);
postgres=# CREATE TABLE sessions_p2 PARTITION OF sessions
    FOR VALUES WITH (MODULUS 4, REMAINDER 2);
postgres=# CREATE TABLE sessions_p3 PARTITION OF sessions
    FOR VALUES WITH (MODULUS 4, REMAINDER 3);
postgres=# -- Remainders go from 0 to modulus-1
postgres=# -- All partitions must use the SAME modulus
```

### Hash Partitioning — Even Distribution
**Explanation:** Let us insert data and verify even distribution. The hash function distributes user IDs across the 4 partitions roughly equally.

```sql
postgres=# -- Insert 100,000 sessions:
postgres=# INSERT INTO sessions (user_id, ip_addr)
SELECT
    (random() * 9999 + 1)::int,
    ('192.168.' || (random()*254+1)::int || '.' ||
     (random()*254+1)::int)::inet
postgres-# FROM generate_series(1, 100000);
postgres=# -- Check distribution across partitions:
postgres=# SELECT tableoid::regclass AS partition,
       COUNT(*) AS rows
postgres-# FROM sessions
postgres-# GROUP BY tableoid
postgres-# ORDER BY partition;
   partition   | rows
postgres=# ---------------+-------
 sessions_p0   | 24892
 sessions_p1   | 25134
 sessions_p2   | 24987
 sessions_p3   | 24987
postgres=# -- Roughly 25% each — evenly distributed!
postgres=# -- Query for one user_id — hash locates the partition:
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT * FROM sessions WHERE user_id = 42;
 Seq Scan on sessions_p2 sessions_1
       Filter: (user_id = 42)
```

### List Partitioning by Status — Hot/Cold Split
**Explanation:** Let us look at another practical pattern — partitioning by status. An orders table might have millions of completed orders but only a few thousand active ones. List partitioning by status keeps the active partition small and fast.

```sql
-- Split active vs completed orders:
CREATE TABLE shop_orders (
    id          BIGSERIAL,
    customer_id INTEGER NOT NULL,
    amount      NUMERIC(10,2),
    status      TEXT NOT NULL,
    created_at  DATE NOT NULL,
    PRIMARY KEY (id, status)
) PARTITION BY LIST (status);

-- Hot partition (small, frequently queried):
CREATE TABLE shop_orders_active
    PARTITION OF shop_orders
    FOR VALUES IN ('pending', 'processing', 'shipped');

-- Cold partition (large, rarely queried):
CREATE TABLE shop_orders_done
    PARTITION OF shop_orders
    FOR VALUES IN ('delivered', 'completed');

-- Cancelled/refunded:
CREATE TABLE shop_orders_cancelled
    PARTITION OF shop_orders
    FOR VALUES IN ('cancelled', 'refunded');

-- Queries for active orders scan only the
-- small active partition — very fast!
```

### Partition Pruning — All Three Methods
**Explanation:** Here is a quick comparison of what partition pruning looks like for each method. Partition pruning means PostgreSQL skips partitions that cannot contain matching rows. This is the main performance benefit of partitioning.

```sql
postgres=# -- RANGE: pruning on date range:
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT * FROM orders
postgres-# WHERE order_date >= '2026-03-01'
postgres-# AND order_date < '2026-04-01';
postgres=# -- → scans ONLY orders_2026_03
postgres=# -- LIST: pruning on category:
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT * FROM sales WHERE region = 'north';
postgres=# -- → scans ONLY sales_north
postgres=# -- LIST with IN:
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT * FROM sales WHERE region IN ('north', 'south');
postgres=# -- → scans ONLY sales_north AND sales_south
postgres=# -- HASH: pruning on exact match:
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT * FROM sessions WHERE user_id = 42;
postgres=# -- → scans ONLY one partition (hash decides which)
postgres=# -- HASH: NO pruning on range:
postgres=# EXPLAIN (COSTS OFF)
postgres=# SELECT * FROM sessions WHERE user_id BETWEEN 1 AND 100;
postgres=# -- → scans ALL partitions (hash cannot do ranges)
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Partitioning Too Early
A common beginner trap is partitioning too early. Partitioning adds complexity — every primary key and unique constraint must include the partition key, foreign keys referencing partitioned tables are limited, and you must manage partition creation. For tables under about 10 million rows, a regular index usually performs just as well.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. List partitioning splits by specific values using FOR VALUES IN. It is ideal for categories, regions, tenants, and status-based hot/cold splits. Hash partitioning splits evenly using a hash function with MODULUS and REMAINDER. It guarantees even distribution but cannot prune range queries. Choose range for time-series, list for categories, hash for even distribution. Do not partition tables under 10 million rows — indexes are usually enough. In the next class, we cover partition pruning in detail and sub-partitioning.

- **LIST: FOR VALUES IN ('val1', 'val2', ...) per partition**
- **One partition can hold multiple values**
- **Great for multi-tenant, region-based, and status splits**
- **HASH: FOR VALUES WITH (MODULUS m, REMAINDER r)**
- **Even distribution — ~equal rows per partition**
- **Hash prunes on = but NOT on range queries**
- **Hash has no DEFAULT partition**
- **Changing hash modulus = recreate all partitions**
- **Decision: dates→Range, categories→List, even split→Hash**
- **Don't partition under 10M rows — indexes may suffice**
- **Next: Partition Pruning & Sub-Partitioning**


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
