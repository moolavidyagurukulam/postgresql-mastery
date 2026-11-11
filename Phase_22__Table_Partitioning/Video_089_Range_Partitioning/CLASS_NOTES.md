# Range Partitioning — Splitting Tables by Date
**Series:** PostgreSQL Mastery | **Phase:** Phase 22: Table Partitioning | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! We now enter Phase 22 — Table Partitioning. Imagine your orders table has 500 million rows. Queries that filter by date scan the entire table even with indexes. VACUUM takes hours. Backups are enormous. Partitioning solves all of this by splitting one logical table into many physical pieces. Each piece holds a subset of the data — for example, one month per partition. PostgreSQL automatically routes queries to the right partition and skips the rest. Let us begin with the most common type — range partitioning.


---

## 2. Core Technical Concepts & Mechanisms

### Before vs After Partitioning
Before partitioning, your orders table is one giant file on disk. Every query must potentially scan all 500 million rows. With monthly range partitions, the table is split into 12 smaller tables per year — orders_2025_01, orders_2025_02, and so on. A query for January only scans the January partition. The other 11 months are never touched.

| Without Partitioning | With Monthly Partitions |
| :--- | :--- |
| orders: 500M rows in ONE table | orders_2025_01: ~40M rows |
| Query for Jan scans all 500M rows | orders_2025_02: ~40M rows |
| VACUUM processes all 500M rows | ... 12 partitions per year ... |
| Index on date: huge B-tree (12GB+) | Query for Jan: scans only 40M rows |
| Backup: one massive table | VACUUM: processes one partition at a time |
| DROP old data: DELETE + VACUUM (slow) | DROP old data: DROP TABLE partition (instant) |

### Three Partitioning Methods
PostgreSQL supports three partitioning methods: Range, List, and Hash. Range partitioning splits data by a continuous range — dates, IDs, timestamps. List partitioning splits by specific values — status, country, category. Hash partitioning splits evenly across N partitions using a hash function. In this class we focus on range partitioning, which is by far the most common.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Range Partitioning** | Split by continuous range (dates, IDs, timestamps) — most common |
| **List Partitioning** | Split by specific discrete values (status, country, region) |
| **Hash Partitioning** | Split evenly across N partitions using hash of a column value |

**Notes:**
- All methods use PARTITION BY in CREATE TABLE
- Each partition is a regular table with constraints
- Partitioning is declarative in PG 10+ (no triggers needed)

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Range Partitioning Rules
Here are the key rules and syntax for range partitioning.

| Rule | Detail |
| :--- | :--- |
| Range is half-open | FROM (inclusive) TO (exclusive): [FROM, TO) |
| No gaps allowed | Ranges must be contiguous or use DEFAULT partition |
| No overlaps | Two partitions cannot cover the same range |
| Partition key in PK | Primary key and unique constraints must include partition key |
| Parent holds no data | All rows live in child partitions |
| Indexes are per-partition | CREATE INDEX on parent creates per-partition indexes |
| Foreign keys TO partitions | Not supported — FK must reference unpartitioned table |
| MINVALUE / MAXVALUE | FROM (MINVALUE) TO (100) or FROM (100) TO (MAXVALUE) |


---

## 3. Hands-On Commands & psql Output

### Creating a Range-Partitioned Table
**Explanation:** Here is how to create a range-partitioned table. The parent table defines the schema and the partition key. Then you create individual partitions with specific ranges. The parent table holds no data itself — all data lives in the partitions.

```sql
postgres=# -- Step 1: Create the PARENT table (holds no data):
postgres=# CREATE TABLE orders (
    id          BIGSERIAL,
    customer_id INTEGER NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    status      TEXT NOT NULL DEFAULT 'pending',
    order_date  DATE NOT NULL,
    PRIMARY KEY (id, order_date)  -- partition key MUST be in PK
) PARTITION BY RANGE (order_date);
postgres=# -- Step 2: Create PARTITIONS for each month:
postgres=# CREATE TABLE orders_2025_01 PARTITION OF orders
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
postgres=# CREATE TABLE orders_2025_02 PARTITION OF orders
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
postgres=# CREATE TABLE orders_2025_03 PARTITION OF orders
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
postgres=# -- Range is [FROM, TO) — FROM is inclusive, TO is exclusive
postgres=# -- '2025-02-01' belongs to orders_2025_02, NOT orders_2025_01
```

### Partition Key in Primary Key — Required!
**Explanation:** A critical rule: the partition key must be part of the primary key and any unique constraint. PostgreSQL cannot enforce uniqueness across partitions without the partition key. If your primary key is just id, you must change it to (id, order_date).

```sql
postgres=# -- This FAILS:
postgres=# CREATE TABLE bad_orders (
    id          BIGSERIAL PRIMARY KEY,
    order_date  DATE NOT NULL
) PARTITION BY RANGE (order_date);
postgres=# -- ERROR: unique constraint on partitioned table must include
postgres=# --        all partitioning columns
postgres=# -- DETAIL: PRIMARY KEY constraint on table "bad_orders"
postgres=# --         lacks column "order_date" which is part of the
postgres=# --         partition key.
postgres=# -- This WORKS:
postgres=# CREATE TABLE good_orders (
    id          BIGSERIAL,
    order_date  DATE NOT NULL,
    PRIMARY KEY (id, order_date)  -- partition key included!
) PARTITION BY RANGE (order_date);
postgres=# -- Same rule applies to UNIQUE constraints:
postgres=# -- UNIQUE (email, order_date) → OK
postgres=# -- UNIQUE (email)              → ERROR
```

### Inserting Data — Automatic Routing
**Explanation:** Now let us insert data and see how PostgreSQL routes rows to the correct partition automatically. You insert into the parent table — orders — and PostgreSQL finds the right partition based on the order_date value.

```sql
postgres=# -- Insert into the PARENT table:
postgres=# INSERT INTO orders (customer_id, amount, status, order_date)
VALUES
  (1, 99.99, 'pending', '2025-01-15'),
  (2, 149.50, 'shipped', '2025-02-20'),
  (3, 75.00, 'delivered', '2025-03-10');
postgres=# -- Check which partition each row landed in:
postgres=# SELECT tableoid::regclass AS partition, *
postgres-# FROM orders;
    partition     | id | customer_id | amount | status    | order_date
postgres=# ------------------+----+-------------+--------+-----------+------------
 orders_2025_01   |  1 |           1 |  99.99 | pending   | 2025-01-15
 orders_2025_02   |  2 |           2 | 149.50 | shipped   | 2025-02-20
 orders_2025_03   |  3 |           3 |  75.00 | delivered | 2025-03-10
postgres=# -- Each row went to the correct monthly partition!
postgres=# -- tableoid::regclass shows the actual partition name
```

### Beginner Trap: Missing Partition
**Explanation:** What happens when you insert a row with a date that has no matching partition? PostgreSQL raises an error. This is the most common partitioning mistake — forgetting to create partitions for future months.

```sql
postgres=# -- Try inserting a row for April (no partition exists):
postgres=# INSERT INTO orders (customer_id, amount, status, order_date)
postgres-# VALUES (4, 200.00, 'pending', '2025-04-05');
postgres=# -- ERROR: no partition of relation "orders" found for row
postgres=# -- DETAIL: Partition key of the failing row contains
postgres=# --         (order_date) = (2025-04-05).
postgres=# -- Fix: create the missing partition:
postgres=# CREATE TABLE orders_2025_04 PARTITION OF orders
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
postgres=# -- Now the insert works:
postgres=# INSERT INTO orders (customer_id, amount, status, order_date)
postgres-# VALUES (4, 200.00, 'pending', '2025-04-05');
postgres=# -- INSERT 0 1
postgres=# -- LESSON: Always create partitions AHEAD of time
postgres=# -- Automate partition creation for future months!
```

### Default Partition — Safety Net
**Explanation:** You can use a DEFAULT partition as a safety net. Any row that does not match an existing partition goes into the default partition instead of raising an error. This prevents application crashes from missing partitions. But you should still create proper partitions — the default is a catch-all, not a replacement.

```sql
postgres=# -- Create a default partition:
postgres=# CREATE TABLE orders_default PARTITION OF orders DEFAULT;
postgres=# -- Now rows with no matching partition go here:
postgres=# INSERT INTO orders (customer_id, amount, status, order_date)
postgres-# VALUES (5, 50.00, 'pending', '2025-12-25');
postgres=# -- Check:
postgres=# SELECT tableoid::regclass AS partition, id, order_date
postgres-# FROM orders WHERE order_date = '2025-12-25';
    partition     | id | order_date
postgres=# ------------------+----+------------
 orders_default   |  5 | 2025-12-25
postgres=# -- WARNING: When you later create orders_2025_12,
postgres=# -- PostgreSQL must check that the default partition
postgres=# -- has no rows that belong in the new partition.
postgres=# -- With many rows in default, this check is SLOW.
postgres=# -- Best practice: create partitions ahead, use default
postgres=# -- only as emergency catch-all.
```

### Indexes on Partitioned Tables
**Explanation:** Indexes on partitioned tables work differently. When you create an index on the parent table, PostgreSQL creates a matching index on EVERY existing partition — and any future partition you create also gets the index automatically. Each partition index is independent, which makes them smaller and faster than one giant index.

```sql
postgres=# -- Create index on the PARENT table:
postgres=# CREATE INDEX idx_orders_customer
postgres-# ON orders(customer_id);
postgres=# -- PostgreSQL automatically creates per-partition indexes:
postgres=# \di orders*
                 List of relations
 Schema |            Name              | Type  | Table
postgres=# --------+------------------------------+-------+-----------------
 public | orders_2025_01_customer_id_idx| index | orders_2025_01
 public | orders_2025_02_customer_id_idx| index | orders_2025_02
 public | orders_2025_03_customer_id_idx| index | orders_2025_03
 public | orders_2025_04_customer_id_idx| index | orders_2025_04
 public | orders_default_customer_id_idx| index | orders_default
postgres=# -- Each partition has its own smaller index
postgres=# -- Future partitions inherit the index automatically
postgres=# -- Index sizes are smaller per partition:
postgres=# -- One big index on 500M rows: ~12 GB
postgres=# -- 12 monthly indexes on ~40M rows each: ~1 GB each
postgres=# -- Same total, but each scan is faster
```

### Creating a Full Year of Monthly Partitions
**Explanation:** Let us create a full year of monthly partitions using a loop. In production, you would automate this with a script or cron job that creates partitions several months ahead.

```sql
-- Generate 12 monthly partitions for 2026:
DO $$
DECLARE
    month_start DATE;
    month_end   DATE;
    part_name   TEXT;
BEGIN
    FOR m IN 1..12 LOOP
        month_start := make_date(2026, m, 1);
        month_end   := month_start + '1 month'::interval;
        part_name   := 'orders_' ||
                       to_char(month_start, 'YYYY_MM');

        EXECUTE format(
            'CREATE TABLE %I PARTITION OF orders
             FOR VALUES FROM (%L) TO (%L)',
            part_name, month_start, month_end
        );

        RAISE NOTICE 'Created partition: %', part_name;
    END LOOP;
END $$;

-- Output:
-- NOTICE: Created partition: orders_2026_01
-- NOTICE: Created partition: orders_2026_02
-- ... through orders_2026_12
```

### Performance Demo — Partitioned vs Unpartitioned
**Explanation:** Let us load some test data and see how much faster queries become with partitioning.

```sql
postgres=# -- Insert 1 million rows spanning 12 months:
postgres=# INSERT INTO orders (customer_id, amount, status, order_date)
SELECT
    (random() * 999 + 1)::int,
    (random() * 500 + 1)::numeric(10,2),
    (ARRAY['pending','shipped','delivered'])[floor(random()*3+1)::int],
    '2026-01-01'::date + (random() * 365)::int
postgres-# FROM generate_series(1, 1000000);
postgres=# -- Query for one month:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT COUNT(*), SUM(amount)
postgres-# FROM orders
postgres-# WHERE order_date >= '2026-03-01'
postgres-# AND order_date < '2026-04-01';
 Aggregate (actual time=15.234..15.235 rows=1 loops=1)
   -> Seq Scan on orders_2026_03 orders
      (actual time=0.012..10.456 rows=84521 loops=1)
postgres=# -- ONLY orders_2026_03 was scanned!
postgres=# -- 11 other partitions completely skipped
postgres=# -- Without partitioning: would scan all 1,000,000 rows
```

### Range Partitioning by Integer ID
**Explanation:** You can also partition by a range of integers — not just dates. For example, partitioning a users table by ID range. Each partition holds 1 million users. This is useful when data grows linearly and you want even distribution.

```sql
postgres=# -- Partition by user ID range:
postgres=# CREATE TABLE users (
    id      BIGINT NOT NULL,
    name    TEXT NOT NULL,
    email   TEXT,
    PRIMARY KEY (id)
) PARTITION BY RANGE (id);
postgres=# CREATE TABLE users_0_1m PARTITION OF users
    FOR VALUES FROM (0) TO (1000000);
postgres=# CREATE TABLE users_1m_2m PARTITION OF users
    FOR VALUES FROM (1000000) TO (2000000);
postgres=# CREATE TABLE users_2m_3m PARTITION OF users
    FOR VALUES FROM (2000000) TO (3000000);
postgres=# -- Insert:
postgres=# INSERT INTO users (id, name, email)
postgres-# VALUES (500000, 'Alice', 'alice@example.com');
postgres=# SELECT tableoid::regclass, * FROM users WHERE id = 500000;
   tableoid   |   id   | name  |      email
postgres=# --------------+--------+-------+-------------------
 users_0_1m   | 500000 | Alice | alice@example.com
```

### MINVALUE & MAXVALUE — Open-Ended Ranges
**Explanation:** MINVALUE and MAXVALUE let you create open-ended ranges. This is useful for a catch-all first or last partition. For example, everything before 2025 goes into an archive partition, and everything from 2027 onward goes into a future partition.

```sql
postgres=# -- Archive partition (everything before 2025):
postgres=# CREATE TABLE orders_archive PARTITION OF orders
    FOR VALUES FROM (MINVALUE) TO ('2025-01-01');
postgres=# -- Future partition (2027 onward):
postgres=# CREATE TABLE orders_future PARTITION OF orders
    FOR VALUES FROM ('2027-01-01') TO (MAXVALUE);
postgres=# -- Now inserting old or far-future dates works:
postgres=# INSERT INTO orders (customer_id, amount, status, order_date)
postgres-# VALUES (10, 25.00, 'delivered', '2020-06-15');
postgres=# -- → goes to orders_archive
postgres=# INSERT INTO orders (customer_id, amount, status, order_date)
postgres-# VALUES (11, 300.00, 'pending', '2028-01-01');
postgres=# -- → goes to orders_future
postgres=# -- NOTE: if you also have a DEFAULT partition, you cannot
postgres=# -- use both MINVALUE/MAXVALUE and DEFAULT
postgres=# -- Choose one approach: open ranges OR default partition
```

### Inspecting Partition Structure
**Explanation:** You can query the system catalogs to see your partition structure. The pg_partitioned_table and pg_inherits views show the parent-child relationships. And you can list all partitions with their range bounds using pg_catalog.

```sql
postgres=# -- List all partitions and their bounds:
SELECT
    parent.relname AS parent_table,
    child.relname  AS partition,
    pg_get_expr(c.relpartbound, c.oid) AS bounds
postgres-# FROM pg_inherits i
postgres-# JOIN pg_class parent ON i.inhparent = parent.oid
postgres-# JOIN pg_class child  ON i.inhrelid  = child.oid
postgres-# JOIN pg_class c      ON c.oid       = child.oid
postgres-# WHERE parent.relname = 'orders'
postgres-# ORDER BY child.relname;
 parent_table |    partition     |              bounds
postgres=# --------------+-----------------+---------------------------------
 orders       | orders_2025_01  | FOR VALUES FROM ('2025-01-01')
              |                 |   TO ('2025-02-01')
 orders       | orders_2025_02  | FOR VALUES FROM ('2025-02-01')
              |                 |   TO ('2025-03-01')
 orders       | orders_archive  | FOR VALUES FROM (MINVALUE)
              |                 |   TO ('2025-01-01')
 orders       | orders_default  | DEFAULT
postgres=# -- Check partition row counts:
postgres=# SELECT tableoid::regclass AS partition,
       COUNT(*) AS row_count
postgres-# FROM orders
postgres-# GROUP BY tableoid
postgres-# ORDER BY partition;
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Missing Partition
What happens when you insert a row with a date that has no matching partition? PostgreSQL raises an error. This is the most common partitioning mistake — forgetting to create partitions for future months.

```sql
-- Try inserting a row for April (no partition exists):
INSERT INTO orders (customer_id, amount, status, order_date)
VALUES (4, 200.00, 'pending', '2025-04-05');
-- ERROR: no partition of relation "orders" found for row
-- DETAIL: Partition key of the failing row contains
--         (order_date) = (2025-04-05).
-- Fix: create the missing partition:
CREATE TABLE orders_2025_04 PARTITION OF orders
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
-- Now the insert works:
INSERT INTO orders (customer_id, amount, status, order_date)
VALUES (4, 200.00, 'pending', '2025-04-05');
-- INSERT 0 1
-- LESSON: Always create partitions AHEAD of time
-- Automate partition creation for future months!
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Range partitioning splits a table by a continuous range — most commonly dates. The parent table holds no data — it is a routing layer. Each partition is a regular table with its own storage, indexes, and VACUUM schedule. The partition key must be in all primary key and unique constraints. Use FROM and TO with half-open ranges. Create a DEFAULT partition as a safety net or use MINVALUE and MAXVALUE for open-ended ranges. Always create partitions ahead of time to avoid INSERT errors. In the next class, we cover List and Hash partitioning. Range partitioning splits a table by a continuous range — most commonly dates. The parent table holds no data — it is a routing layer. Each partition is a regular table with its own storage, indexes, and VACUUM schedule. The partition key must be in all primary key and unique constraints. Use FROM and TO with half-open ranges. Create a DEFAULT partition as a safety net or use MINVALUE and MAXVALUE for open-ended ranges. Always create partitions ahead of time to avoid INSERT errors. In the next class, we cover List and Hash partitioning.

- **PARTITION BY RANGE: split by dates, IDs, timestamps**
- **Parent table holds no data — all rows in child partitions**
- **Range is half-open: FROM (inclusive) TO (exclusive)**
- **Partition key MUST be in PRIMARY KEY and UNIQUE constraints**
- **Indexes on parent → auto-created on each partition**
- **INSERT into parent → auto-routed to correct partition**
- **Missing partition → ERROR (create partitions ahead!)**
- **DEFAULT partition: catch-all for unmatched rows**
- **MINVALUE/MAXVALUE: open-ended ranges for archive/future**
- **Automate partition creation with DO $$ loops or cron**
- **Next: List & Hash Partitioning**


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
