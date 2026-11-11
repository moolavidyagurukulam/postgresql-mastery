# Database & Table Sizing
**Series:** PostgreSQL Mastery | **Phase:** Phase 17: Database Sizing & Capacity Planning | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn how to measure the size of everything in PostgreSQL — databases, tables, indexes, and individual columns. Knowing your database size is not optional in production. If you do not monitor it, you will wake up at 3 AM to a disk full error and a crashed database. We will also learn about table bloat — dead rows that waste disk space — and how to detect it. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Size Functions — What Each Measures
PostgreSQL provides built-in functions to measure size at every level. pg_database_size gives you the total size of a database including all its tables, indexes, and TOAST data. pg_total_relation_size gives the total size of one table including its indexes and TOAST data. pg_table_size gives just the table itself — data plus TOAST but without indexes. pg_indexes_size gives just the indexes for a table. And pg_relation_size gives the raw main fork of the table — no TOAST, no indexes, just the heap.

| Term | Meaning / Explanation |
| :--- | :--- |
| **pg_database_size('dbname')** | Entire database — all tables, indexes, TOAST, FSM, VM |
| **pg_total_relation_size('table')** | Table + all indexes + TOAST (everything for that table) |
| **pg_table_size('table')** | Table data + TOAST + FSM + VM (no indexes) |
| **pg_indexes_size('table')** | All indexes on the table combined |
| **pg_relation_size('table')** | Raw main fork only — heap data, no TOAST, no indexes |

**Notes:**
- All return bytes — use pg_size_pretty() for human-readable
- pg_total_relation_size = pg_table_size + pg_indexes_size

### Beginner Trap: VACUUM FULL in Production
Here is a beginner trap: you see a table is 75 MB with 40 percent dead rows and immediately run VACUUM FULL. Bad idea. VACUUM FULL takes an exclusive lock — no reads, no writes — for the entire duration. On a large table, this can be minutes or hours. In production, the correct approach is: let autovacuum handle regular cleanup, and if you need to reclaim space without locking, use pg_repack — a third-party extension that rebuilds the table without an exclusive lock.

| VACUUM FULL (Dangerous) | Safe Alternatives |
| :--- | :--- |
| Exclusive lock — blocks ALL access | Regular VACUUM: reuse dead space |
| Rewrites entire table to new file | Autovacuum: automatic cleanup |
| Duration: minutes to hours | pg_repack: rebuild without lock |
| Needs 2x disk space temporarily | Accept moderate bloat (10-20%) |
| NEVER use on live prod tables | Only VACUUM FULL during maintenance |

### Row Overhead: The 23-Byte Header
Every row in PostgreSQL has a 23-byte header called the heap tuple header. This stores the transaction IDs for MVCC, null bitmap, and tuple metadata. This means even a table with a single boolean column uses at least 31 bytes per row — 23 bytes for the header plus 8 bytes minimum for alignment. This is important for capacity planning: a table with 100 million rows has at least 2.3 GB just in headers.

| Term | Meaning / Explanation |
| :--- | :--- |
| **HeapTupleHeader** | 23 bytes per row — transaction IDs, command ID, null bitmap pointer |
| **Alignment padding** | Rows are padded to 8-byte boundaries — a BOOLEAN row uses 24 bytes of data |
| **Item pointer** | 4 bytes per row in the page header — points to row within the 8KB page |
| **Page overhead** | Each 8KB page has 24 bytes of page header |

**Notes:**
- 100M rows × 23 bytes header = 2.3 GB of pure overhead
- Empty table with 0 rows still uses 8KB (one page)

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too. Now let us look at disk monitoring.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Sizing Action Decision Framework
Here is a decision framework for sizing actions. When you see different levels of bloat or disk usage, here is what to do.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a decision framework for sizing actions. When you see different levels of bloat or disk usage, here is what to do |

### Practice Exercises
Time to practice. First, run the table size report query to see all tables in your database sorted by size. Second, create a table with 100,000 rows, then UPDATE half of them and check dead row percentage. Third, run VACUUM VERBOSE and confirm the file size does not shrink. Fourth, query pg_stat_user_indexes to find indexes with zero scans. Fifth, measure your total database size and WAL directory size.

- 1 -- Run the pg_stat_user_tables query sorted by pg_total_relation_size DESC
- 2 -- INSERT 100k rows, UPDATE 50k, check n_dead_tup in pg_stat_user_tables
- 3 -- VACUUM VERBOSE, check pg_table_size before and after — same!
- 4 -- pg_stat_user_indexes WHERE idx_scan = 0 — exclude pkey
- 5 -- pg_database_size for all DBs, pg_ls_waldir() for WAL


---

## 3. Hands-On Commands & psql Output

### Measuring Database Size
**Explanation:** Let us measure a real database. First, the database itself. pg_size_pretty converts raw bytes into human-readable format like megabytes and gigabytes. Then we measure each table. Let us set up a practice database with some real data to work with.

```sql
postgres=# SELECT pg_size_pretty(pg_database_size('trigger_lab')) AS db_size;
 db_size
---------
 12 MB
(1 row)
postgres=# -- All databases with sizes:
postgres=# SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database ORDER BY pg_database_size(datname) DESC;
   datname    |  size
--------------+--------
 trigger_lab  | 12 MB
 postgres     | 8585 kB
 template1    | 8401 kB
 template0    | 8385 kB
(4 rows)
```

### Setup: Creating a Large Table
**Explanation:** Now let us create a large table to make size measurements meaningful. We will use generate_series to insert 500,000 rows with realistic data — an orders table with random products, amounts, and dates. This gives us a table big enough to show real size differences.

```sql
postgres=# \c trigger_lab
You are now connected to database "trigger_lab".
trigger_lab=# CREATE TABLE big_orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    product     TEXT NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    order_date  DATE NOT NULL,
    notes       TEXT
);
CREATE TABLE
trigger_lab=# INSERT INTO big_orders (customer_id, product, amount, order_date, notes)
SELECT
    (random() * 10000)::int,
    (ARRAY['Widget','Gadget','Doohickey','Thingamajig','Gizmo'])[1 + (random()*4)::int],
    (random() * 999 + 1)::numeric(10,2),
    '2025-01-01'::date + (random() * 365)::int,
    'Order notes for item ' || g
FROM generate_series(1, 500000) AS g;
INSERT 0 500000
```

### Measuring Table Size — Every Angle
**Explanation:** Now let us measure this table from every angle. pg_total_relation_size includes the table data, TOAST, and indexes. pg_table_size is just the data plus TOAST. pg_indexes_size is just the indexes. Notice that the primary key index alone takes significant space. The difference between total and table plus indexes should be zero — they should add up exactly.

```sql
trigger_lab=# SELECT
  pg_size_pretty(pg_total_relation_size('big_orders')) AS total,
  pg_size_pretty(pg_table_size('big_orders'))          AS table_only,
  pg_size_pretty(pg_indexes_size('big_orders'))        AS indexes,
  pg_size_pretty(pg_relation_size('big_orders'))       AS heap;
  total  | table_only | indexes | heap
---------+------------+---------+-------
  65 MB  | 54 MB      | 11 MB   | 42 MB
(1 row)
-- -- total (65MB) = table_only (54MB) + indexes (11MB)
-- -- table_only (54MB) = heap (42MB) + TOAST + FSM + VM
-- -- heap = raw data, TOAST = large values, FSM = free space map
```

### Table Size Report — The Essential Query
**Explanation:** Let us build the most useful query: a table size report showing every table in the database, sorted by total size. This is the first query you should run when investigating disk usage on any PostgreSQL server.

```sql
SELECT
    schemaname || '.' || relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total,
    pg_size_pretty(pg_table_size(relid)) AS data,
    pg_size_pretty(pg_indexes_size(relid)) AS indexes,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    CASE WHEN n_live_tup > 0
         THEN round(100.0 * n_dead_tup / n_live_tup, 1)
         ELSE 0 END AS dead_pct
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;
```

### Running the Table Size Report
**Explanation:** Let us run that query and see the results. This shows every table with its total size, data size, index size, live row count, dead row count, and dead row percentage. The dead row percentage tells you about bloat — if a table has 30 percent dead rows, it is 30 percent bigger than it needs to be.

```sql
trigger_lab=# SELECT schemaname || '.' || relname AS table_name,
  pg_size_pretty(pg_total_relation_size(relid)) AS total,
  pg_size_pretty(pg_table_size(relid)) AS data,
  pg_size_pretty(pg_indexes_size(relid)) AS indexes,
  n_live_tup AS live, n_dead_tup AS dead
FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 10;
      table_name       | total  |  data  | indexes |  live  | dead
-----------------------+--------+--------+---------+--------+------
 public.big_orders     | 65 MB  | 54 MB  | 11 MB   | 500000 |    0
 public.employees      | 48 kB  | 16 kB  | 32 kB   |      6 |    3
 public.audit_log      | 32 kB  | 16 kB  | 16 kB   |      5 |    0
 public.products       | 24 kB  | 8192 b | 16 kB   |      1 |    0
 public.orders         | 24 kB  | 8192 b | 16 kB   |      6 |    0
(5 rows)
```

### Measuring Individual Index Sizes
**Explanation:** Now let us measure individual index sizes. Each index on a table takes disk space. On tables with many indexes, the total index size can exceed the table data size. The pg_stat_user_indexes view combined with pg_relation_size gives you per-index sizes.

```sql
trigger_lab=# CREATE INDEX idx_big_orders_customer ON big_orders(customer_id);
CREATE INDEX
trigger_lab=# CREATE INDEX idx_big_orders_date ON big_orders(order_date);
CREATE INDEX
trigger_lab=# CREATE INDEX idx_big_orders_product ON big_orders(product);
CREATE INDEX
trigger_lab=# SELECT indexrelname AS index_name,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size,
  idx_scan AS scans
FROM pg_stat_user_indexes WHERE relname = 'big_orders'
ORDER BY pg_relation_size(indexrelid) DESC;
        index_name         |  size  | scans
---------------------------+--------+-------
 idx_big_orders_product    | 14 MB  |     0
 idx_big_orders_customer   | 11 MB  |     0
 big_orders_pkey           | 11 MB  |     0
 idx_big_orders_date       | 11 MB  |     0
(4 rows)
-- -- 4 indexes = 47MB total (almost as big as the 42MB heap!)
```

### Finding Unused Indexes
**Explanation:** Finding unused indexes is critical. An index that is never scanned wastes disk space, slows down writes, and adds vacuum overhead. Query pg_stat_user_indexes and look for indexes with zero scans. If an index has not been scanned since the last stats reset, it is a candidate for removal. Always check when stats were last reset before dropping — a newly created index might show zero scans simply because no queries have run yet.

```sql
trigger_lab=# -- When were stats last reset?
trigger_lab=# SELECT stats_reset FROM pg_stat_database WHERE datname = current_database();
          stats_reset
-------------------------------
 2026-11-01 08:00:00.123+05:30
(1 row)
trigger_lab=# -- Unused indexes (0 scans since reset):
trigger_lab=# SELECT schemaname, relname, indexrelname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND indexrelname NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;
 schemaname | relname    | indexrelname             | size  | idx_scan
------------+------------+--------------------------+-------+---------
 public     | big_orders | idx_big_orders_product   | 14 MB |       0
 public     | big_orders | idx_big_orders_customer  | 11 MB |       0
 public     | big_orders | idx_big_orders_date      | 11 MB |       0
-- -- These indexes are taking 36MB but never used!
```

### Creating and Measuring Table Bloat
**Explanation:** Now let us understand table bloat. When you UPDATE a row in PostgreSQL, it does not change the row in place — it creates a new version and marks the old one as dead. When you DELETE, the row is marked dead but not removed. These dead rows are called bloat. VACUUM reclaims dead rows for reuse but does not return space to the OS. Only VACUUM FULL reclaims space back to the OS, but it locks the entire table. Let us create some bloat and measure it.

```sql
trigger_lab=# -- Check size before updates:
trigger_lab=# SELECT pg_size_pretty(pg_table_size('big_orders')) AS before_size;
 before_size
-------------
 54 MB
trigger_lab=# -- Update 200,000 rows (creates 200k dead rows):
trigger_lab=# UPDATE big_orders SET amount = amount * 1.1 WHERE id <= 200000;
UPDATE 200000
trigger_lab=# SELECT pg_size_pretty(pg_table_size('big_orders')) AS after_size;
 after_size
------------
 75 MB
trigger_lab=# SELECT n_live_tup, n_dead_tup,
  round(100.0 * n_dead_tup / GREATEST(n_live_tup, 1), 1) AS dead_pct
FROM pg_stat_user_tables WHERE relname = 'big_orders';
 n_live_tup | n_dead_tup | dead_pct
------------+------------+----------
     500000 |     200000 |     40.0
-- -- 40% bloat! Table grew from 54MB to 75MB
```

### VACUUM vs VACUUM FULL
**Explanation:** Let us see what VACUUM does to this bloat. Regular VACUUM marks dead rows as reusable but does NOT shrink the file. The table stays at 75 MB, but future INSERTs will reuse the dead space instead of growing the file. VACUUM FULL rewrites the entire table and reclaims space — but it takes an exclusive lock. Let us run VACUUM with VERBOSE to see the details.

```sql
trigger_lab=# VACUUM VERBOSE big_orders;
INFO:  vacuuming "trigger_lab.public.big_orders"
INFO:  table "big_orders": found 200000 removable, 500000 nonremovable row versions
INFO:  table "big_orders": removed 200000 dead item identifiers
VACUUM
trigger_lab=# SELECT pg_size_pretty(pg_table_size('big_orders')) AS after_vacuum;
 after_vacuum
--------------
 75 MB
-- -- Still 75MB! VACUUM does NOT shrink the file.
-- -- Dead space is now REUSABLE for new rows.
-- 
-- -- VACUUM FULL rewrites table (exclusive lock!):
-- -- VACUUM FULL big_orders;
-- -- Would shrink back to ~54MB but locks the table
```

### Measuring Column Sizes
**Explanation:** Let us also measure column-level sizes. You can estimate how much space each column takes using pg_column_size on a sample of rows. This helps identify columns that are unexpectedly large — like a notes column storing entire documents instead of short strings.

```sql
trigger_lab=# SELECT
  avg(pg_column_size(id)) AS id_bytes,
  avg(pg_column_size(customer_id)) AS cust_bytes,
  avg(pg_column_size(product)) AS product_bytes,
  avg(pg_column_size(amount)) AS amount_bytes,
  avg(pg_column_size(order_date)) AS date_bytes,
  avg(pg_column_size(notes)) AS notes_bytes,
  avg(pg_column_size(big_orders.*)) AS row_total
FROM big_orders TABLESAMPLE SYSTEM(1);
 id_bytes | cust_bytes | product_bytes | amount_bytes | date_bytes | notes_bytes | row_total
----------+------------+---------------+--------------+------------+-------------+----------
        4 |          4 |            10 |            7 |          4 |          27 |       80
-- -- notes column averages 27 bytes per row
-- -- Total row: ~80 bytes + 23 bytes header = ~103 bytes
-- -- 500,000 rows × 103 bytes ≈ 49MB (matches heap size)
```

### Disk Monitoring Queries
**Explanation:** Disk monitoring is non-negotiable in production. PostgreSQL crashes hard when it runs out of disk — it cannot write WAL, it cannot checkpoint, and recovery may fail. You need to monitor three things: the data directory size, the WAL directory size, and the temp file usage. Let us query all of these.

```sql
trigger_lab=# -- Total size of all databases:
trigger_lab=# SELECT sum(pg_database_size(datname))::bigint AS total_bytes,
  pg_size_pretty(sum(pg_database_size(datname))::bigint) AS total
FROM pg_database;
 total_bytes |  total
-------------+--------
   104857600 | 100 MB
trigger_lab=# -- WAL directory size (approximate from pg_ls_waldir):
trigger_lab=# SELECT count(*) AS wal_files,
  pg_size_pretty(sum(size)) AS wal_total
FROM pg_ls_waldir();
 wal_files | wal_total
-----------+-----------
         5 | 80 MB
trigger_lab=# -- Temp file usage:
trigger_lab=# SELECT datname, temp_files, pg_size_pretty(temp_bytes) AS temp_size
FROM pg_stat_database WHERE temp_bytes > 0;
   datname   | temp_files | temp_size
-------------+------------+-----------
 trigger_lab |          2 | 256 MB
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: VACUUM FULL in Production
Here is a beginner trap: you see a table is 75 MB with 40 percent dead rows and immediately run VACUUM FULL. Bad idea. VACUUM FULL takes an exclusive lock — no reads, no writes — for the entire duration. On a large table, this can be minutes or hours. In production, the correct approach is: let autovacuum handle regular cleanup, and if you need to reclaim space without locking, use pg_repack — a third-party extension that rebuilds the table without an exclusive lock.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review what we covered. pg_database_size measures an entire database. pg_total_relation_size measures a table with all its indexes and TOAST. pg_table_size is data without indexes. pg_indexes_size is indexes only. Use pg_size_pretty for human-readable output. Dead rows are bloat — VACUUM marks them reusable but does not shrink files. VACUUM FULL shrinks but locks the table. Monitor disk usage, WAL, and temp files to prevent crashes. And always hunt for unused indexes wasting disk space.

- **pg_database_size(): total database size**
- **pg_total_relation_size(): table + indexes + TOAST**
- **pg_table_size(): table + TOAST (no indexes)**
- **pg_indexes_size(): all indexes on a table**
- **pg_size_pretty(): human-readable (MB, GB)**
- **Row overhead: 23-byte header + alignment padding per row**
- **Dead rows = bloat from UPDATE/DELETE — check n_dead_tup**
- **VACUUM: reclaims for reuse, does NOT shrink file**
- **VACUUM FULL: shrinks file but locks table — avoid in prod**
- **Monitor: disk space, WAL size, temp files**


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
