# Managing Partitions — ADD, DROP, ATTACH, DETACH
**Series:** PostgreSQL Mastery | **Phase:** Phase 22: Table Partitioning | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! We now know how to create range, list, and hash partitions, and how pruning skips irrelevant partitions. But in production, partitions are not static — you add new ones for incoming data, drop old ones you no longer need, attach existing tables as partitions, and detach partitions for archival. Let us master the day-to-day management of partitions.


---

## 2. Core Technical Concepts & Mechanisms

### Four Partition Management Operations
Here are the four partition management operations. Adding creates a new empty partition for future data. Dropping removes a partition and all its data instantly. Attaching turns an existing regular table into a partition. Detaching removes a partition from the hierarchy but keeps the table and its data.

| Term | Meaning / Explanation |
| :--- | :--- |
| **ADD (CREATE TABLE ... PARTITION OF)** | Create a new empty partition for a new range or value |
| **DROP (DROP TABLE partition_name)** | Remove partition + all its data instantly (no DELETE needed) |
| **ATTACH (ALTER TABLE ... ATTACH PARTITION)** | Convert an existing table into a partition of the parent |
| **DETACH (ALTER TABLE ... DETACH PARTITION)** | Remove from partition hierarchy but keep as standalone table |

**Notes:**
- ADD and DROP are the most common operations
- ATTACH and DETACH are used for migrations and archival

### Lock-Free ATTACH — The CHECK Constraint Trick
The validation scan during ATTACH takes an ACCESS EXCLUSIVE lock on the parent table, blocking all reads and writes. For large production tables, you can avoid this by adding a CHECK constraint first — then PostgreSQL skips the validation scan because it trusts the constraint.

- Step 1: Add a CHECK constraint matching the partition bounds -- ALTER TABLE orders_new ADD CONSTRAINT chk_dates CHECK (order_date >= '2025-06-01' AND order_date < '2025-07-01') NOT VALID;
- Step 2: Validate the constraint (allows concurrent reads/writes) -- ALTER TABLE orders_new VALIDATE CONSTRAINT chk_dates; — scans table but only takes SHARE UPDATE EXCLUSIVE lock
- Step 3: ATTACH the partition -- ALTER TABLE orders ATTACH PARTITION orders_new FOR VALUES FROM ('2025-06-01') TO ('2025-07-01'); — skips scan because CHECK already guarantees bounds
- Step 4: Drop the constraint (partition bounds enforce it now) -- ALTER TABLE orders_new DROP CONSTRAINT chk_dates; — optional cleanup

### DETACH vs DETACH CONCURRENTLY
DETACH CONCURRENTLY is important for production. The regular DETACH takes an ACCESS EXCLUSIVE lock on the parent table, blocking all queries. DETACH CONCURRENTLY uses a two-phase approach that avoids blocking readers. Use CONCURRENTLY whenever possible in production.

| DETACH (Regular) | DETACH CONCURRENTLY |
| :--- | :--- |
| Takes ACCESS EXCLUSIVE lock | Two-phase: mark pending → complete |
| Blocks ALL reads and writes on parent | Does NOT block reads or writes |
| Instant once lock acquired | Safe for production with live traffic |
| Safe in maintenance windows | Cannot run inside a transaction |
| Works in transactions | Available since PostgreSQL 14 |
|  | Use this in production! |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Migrating to a Partitioned Table
Migrating an existing unpartitioned table to partitioned is a common real-world task. PostgreSQL does not support ALTER TABLE to add partitioning to an existing table. You must create a new partitioned table, copy the data, and swap the names. Here is the complete workflow.

- Step 1: Create the new partitioned table -- CREATE TABLE orders_new (...) PARTITION BY RANGE (order_date); — same schema, add partition key to PK
- Step 2: Create all needed partitions -- One partition per range (monthly, quarterly, yearly) plus DEFAULT
- Step 3: Copy all data -- INSERT INTO orders_new SELECT * FROM orders; — may take minutes for large tables
- Step 4: Recreate indexes, constraints, grants -- CREATE INDEX on parent → auto-created per partition
- Step 5: Swap table names in a transaction -- BEGIN; ALTER TABLE orders RENAME TO orders_old; ALTER TABLE orders_new RENAME TO orders; COMMIT;
- Step 6: Update application (if FK references changed) -- Test thoroughly, then DROP TABLE orders_old;

### Foreign Keys & Partitioned Tables (PG 16)
Foreign keys and partitioned tables have specific limitations. You can have a foreign key FROM a partitioned table referencing a regular table. But you cannot have a foreign key TO a partitioned table — the referenced table must be unpartitioned. This is a limitation in PostgreSQL 16.

| Works (FK FROM partitioned) | Does NOT Work (FK TO partitioned) |
| :--- | :--- |
| Partitioned table → Regular table | Regular table → Partitioned table |
| orders.customer_id REFERENCES customers(id) | line_items.order_id REFERENCES orders(id) |
| FK created on parent, enforced per partition | ERROR: cannot reference partitioned table |
| Each partition gets its own FK constraint | Workaround: reference partition directly |
| ON DELETE CASCADE works normally | Or use application-level FK enforcement |
|  | This limitation may be removed in future PG |

### Partitioned Table Features
Let us look at what happens to indexes, triggers, and row-level security on partitioned tables. Each of these has specific behavior you should know.

| Feature | Behavior |
| :--- | :--- |
| Indexes | Created on parent → inherited by all partitions |
| Triggers BEFORE ROW | Defined on parent, fires on each partition's rows |
| Triggers AFTER STATEMENT | Fires once per statement on the parent |
| Row Level Security | Policies on parent apply to all partitions |
| VACUUM | Runs per-partition (auto or manual) |
| ANALYZE | Runs per-partition; parent stats computed from children |
| GRANT/REVOKE | Set on parent; partitions inherit permissions |
| pg_dump | Dumps parent definition + partition definitions |


---

## 3. Hands-On Commands & psql Output

### Adding New Partitions
**Explanation:** Adding partitions is straightforward — you create a new partition with the range or values it should cover. This is what you do every month, quarter, or year to prepare for incoming data. Always create partitions AHEAD of time so inserts never fail.

```sql
postgres=# -- Add new monthly partitions for 2027:
postgres=# CREATE TABLE orders_2027_01 PARTITION OF orders
    FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');
postgres=# CREATE TABLE orders_2027_02 PARTITION OF orders
    FOR VALUES FROM ('2027-02-01') TO ('2027-03-01');
postgres=# -- Automate for the whole year:
postgres=# DO $$
DECLARE
    m_start DATE; m_end DATE; p_name TEXT;
postgres=# BEGIN
    FOR m IN 3..12 LOOP
        m_start := make_date(2027, m, 1);
        m_end   := m_start + '1 month'::interval;
        p_name  := 'orders_' || to_char(m_start, 'YYYY_MM');
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF orders
             FOR VALUES FROM (%L) TO (%L)',
            p_name, m_start, m_end
        );
    END LOOP;
END $$;
postgres=# -- Verify:
postgres=# SELECT child.relname
postgres-# FROM pg_inherits i
postgres-# JOIN pg_class child ON i.inhrelid = child.oid
postgres-# JOIN pg_class parent ON i.inhparent = parent.oid
postgres-# WHERE parent.relname = 'orders'
postgres-# AND child.relname LIKE 'orders_2027%'
postgres-# ORDER BY child.relname;
```

### Dropping Old Partitions — Instant Data Removal
**Explanation:** Dropping a partition is the fastest way to delete old data. Instead of running DELETE on millions of rows and waiting for VACUUM, you simply drop the partition table. It is instant because it removes the file from disk — no row-by-row deletion.

```sql
postgres=# -- Check data before dropping:
postgres=# SELECT COUNT(*) FROM orders_2025_01;
  count
postgres=# --------
  84521
postgres=# -- DELETE approach (slow):
postgres=# -- DELETE FROM orders WHERE order_date < '2025-02-01';
postgres=# -- Would scan, log WAL, need VACUUM — takes minutes
postgres=# -- DROP approach (instant):
postgres=# DROP TABLE orders_2025_01;
postgres=# -- DROP TABLE
postgres=# -- Time: 3.456 ms  ← instant!
postgres=# -- The data is gone. The parent table no longer routes
postgres=# -- to that partition. No VACUUM needed.
postgres=# -- Compare: DELETE 84K rows ≈ 5-15 seconds + VACUUM
postgres=# --          DROP TABLE       ≈ 3 milliseconds
postgres=# -- WARNING: DROP TABLE is irreversible!
postgres=# -- Consider DETACH first if you might need the data later
```

### ATTACH PARTITION — Adding an Existing Table
**Explanation:** What if you have an existing table full of data and want to make it a partition? ATTACH PARTITION does exactly this. But there is a catch — PostgreSQL must verify that every row in the table matches the partition bounds. For large tables, this scan can take a long time and lock the parent table.

```sql
postgres=# -- Create a standalone table with data:
postgres=# CREATE TABLE orders_2025_05_standalone (
    id          BIGINT,
    customer_id INTEGER NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    status      TEXT NOT NULL,
    order_date  DATE NOT NULL
);
postgres=# INSERT INTO orders_2025_05_standalone
postgres=# SELECT id, customer_id, amount, status, order_date
postgres-# FROM generate_series(1, 50000) AS id,
     LATERAL (
postgres=# SELECT (random()*999+1)::int AS customer_id,
                (random()*500)::numeric(10,2) AS amount,
                'pending' AS status,
                '2025-05-01'::date + (random()*30)::int AS order_date
     ) sub;
postgres=# -- Attach it as a partition:
postgres=# ALTER TABLE orders
    ATTACH PARTITION orders_2025_05_standalone
    FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
postgres=# -- PostgreSQL validates ALL rows match the bounds
postgres=# -- If ANY row has order_date outside May 2025:
postgres=# -- ERROR: partition constraint of relation
postgres=# --        "orders_2025_05_standalone" is violated by
postgres=# --        some row
```

### DETACH PARTITION — Archiving Old Data
**Explanation:** DETACH PARTITION is the opposite of ATTACH. It removes a partition from the hierarchy but keeps it as a standalone table with all its data intact. This is perfect for archiving old data — you detach the partition, then move or compress the table at your leisure.

```sql
postgres=# -- Detach a partition (keeps data as standalone table):
postgres=# ALTER TABLE orders
    DETACH PARTITION orders_2025_02;
postgres=# -- orders_2025_02 is now a regular table:
postgres=# SELECT COUNT(*) FROM orders_2025_02;
  count
postgres=# --------
  72345
postgres=# -- But it's no longer part of the partitioned table:
postgres=# SELECT * FROM orders
postgres-# WHERE order_date >= '2025-02-01'
postgres-# AND order_date < '2025-03-01';
postgres=# -- Returns 0 rows (partition no longer connected)
postgres=# -- Now you can archive it:
postgres=# -- pg_dump -t orders_2025_02 partition_lab > archive.sql
postgres=# -- Or move to cheap storage, compress, etc.
postgres=# -- Then drop when you're sure:
postgres=# -- DROP TABLE orders_2025_02;
postgres=# -- DETACH CONCURRENTLY (PG 14+) avoids blocking:
postgres=# ALTER TABLE orders
    DETACH PARTITION orders_2025_03 CONCURRENTLY;
postgres=# -- Does NOT take ACCESS EXCLUSIVE lock on parent
```

### Automated Partition Lifecycle
**Explanation:** Let us build a complete partition lifecycle automation. This script creates partitions 3 months ahead and drops partitions older than 2 years. In production, you would run this monthly via a cron job or pg_cron.

```sql
-- Run monthly via pg_cron or system cron:
DO $$
DECLARE
    m_start DATE;
    m_end   DATE;
    p_name  TEXT;
    cutoff  DATE := current_date - interval '2 years';
BEGIN
    -- CREATE partitions 3 months ahead:
    FOR i IN 0..2 LOOP
        m_start := date_trunc('month',
            current_date + (i || ' month')::interval);
        m_end   := m_start + '1 month'::interval;
        p_name  := 'orders_' ||
                   to_char(m_start, 'YYYY_MM');

        IF NOT EXISTS (
            SELECT 1 FROM pg_class
            WHERE relname = p_name
        ) THEN
            EXECUTE format(
                'CREATE TABLE %I PARTITION OF orders
                 FOR VALUES FROM (%L) TO (%L)',
                p_name, m_start, m_end);
            RAISE NOTICE 'Created: %', p_name;
        END IF;
    END LOOP;

    -- DROP partitions older than 2 years:
    FOR p_name IN
        SELECT child.relname
        FROM pg_inherits i
        JOIN pg_class child ON i.inhrelid = child.oid
        JOIN pg_class parent ON i.inhparent = parent.oid
        WHERE parent.relname = 'orders'
          AND child.relname ~ '^orders_\d{4}_\d{2}$'
          AND to_date(
              substring(child.relname from '\d{4}_\d{2}'),
              'YYYY_MM') < cutoff
    LOOP
        EXECUTE 'DROP TABLE ' || p_name;
        RAISE NOTICE 'Dropped: %', p_name;
    END LOOP;
END $$;
```

### ATTACH Error — Rows Violate Partition Bounds
**Explanation:** Let us demonstrate the ATTACH validation error. This error happens when you try to attach a table that contains rows outside the partition bounds. Every row must match the bounds, or the ATTACH fails.

```sql
postgres=# -- Create a table with mixed dates:
postgres=# CREATE TABLE bad_attach (
    id          BIGINT,
    customer_id INTEGER,
    amount      NUMERIC(10,2),
    status      TEXT DEFAULT 'pending',
    order_date  DATE NOT NULL
);
postgres=# INSERT INTO bad_attach VALUES
    (1, 100, 50.00, 'pending', '2025-07-15'),  -- July
    (2, 101, 75.00, 'pending', '2025-08-20');   -- August!
postgres=# -- Try to attach as July partition:
postgres=# ALTER TABLE orders
    ATTACH PARTITION bad_attach
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
postgres=# -- ERROR: partition constraint of relation "bad_attach"
postgres=# --        is violated by some row
postgres=# -- Fix: remove the offending rows first:
postgres=# DELETE FROM bad_attach
postgres-# WHERE order_date < '2025-07-01'
postgres-# OR order_date >= '2025-08-01';
postgres=# -- Now it works:
postgres=# ALTER TABLE orders
    ATTACH PARTITION bad_attach
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
```

### DEFAULT Partition vs New Partitions
**Explanation:** A DEFAULT partition requires special handling when adding new partitions. If you have rows in the default partition that belong to the range of a new partition you are creating, PostgreSQL checks the default and raises an error. You must move those rows first.

```sql
postgres=# -- Assume orders_default has rows for August 2025:
postgres=# SELECT COUNT(*) FROM orders_default
postgres-# WHERE order_date >= '2025-08-01'
postgres-# AND order_date < '2025-09-01';
  count
postgres=# --------
    156
postgres=# -- Try creating August partition:
postgres=# CREATE TABLE orders_2025_08 PARTITION OF orders
    FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
postgres=# -- ERROR: updated partition constraint for default
postgres=# --        partition "orders_default" would be violated
postgres=# --        by some row
postgres=# -- Fix: move rows out of default first:
postgres=# BEGIN;
postgres=# -- Save rows to temp:
postgres=# CREATE TEMP TABLE aug_rows AS
postgres=# SELECT * FROM orders_default
postgres-# WHERE order_date >= '2025-08-01'
postgres-# AND order_date < '2025-09-01';
postgres=# -- Delete from default:
postgres=# DELETE FROM orders_default
postgres-# WHERE order_date >= '2025-08-01'
postgres-# AND order_date < '2025-09-01';
postgres=# -- Create partition:
postgres=# CREATE TABLE orders_2025_08 PARTITION OF orders
      FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
postgres=# -- Move rows into new partition:
postgres=# INSERT INTO orders SELECT * FROM aug_rows;
postgres=# DROP TABLE aug_rows;
postgres=# COMMIT;
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. ADD partitions ahead of time with CREATE TABLE PARTITION OF. DROP partitions for instant data removal — thousands of times faster than DELETE. ATTACH existing tables as partitions, using a CHECK constraint trick to avoid locking. DETACH CONCURRENTLY for production archival without blocking queries. Automate partition lifecycle with a monthly script. Always create partitions before data arrives and keep a DEFAULT as a safety net. This completes Phase 22 — Table Partitioning. Next we begin Phase 23 — Monitoring and Troubleshooting.

- **ADD: CREATE TABLE ... PARTITION OF (always ahead of time)**
- **DROP: instant data removal vs slow DELETE + VACUUM**
- **ATTACH: add existing table; CHECK constraint avoids lock**
- **DETACH CONCURRENTLY: production-safe archival (PG 14+)**
- **DEFAULT partition: catches unmatched rows as safety net**
- **Move rows from DEFAULT before creating overlapping partition**
- **Automate: monthly cron for create-ahead + drop-old**
- **Migration: create new partitioned table → copy → rename swap**
- **FK FROM partitioned works; FK TO partitioned does NOT (PG 16)**
- **Phase 22 Complete! Next: Monitoring & Troubleshooting**


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
