# TOAST & Capacity Planning
**Series:** PostgreSQL Mastery | **Phase:** Phase 17: Database Sizing & Capacity Planning | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we tackle two essential topics. First, TOAST — how PostgreSQL handles values too large to fit in a regular page. Second, capacity planning — how to predict your database's growth and plan disk space before you run out. Every production DBA needs both of these skills. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### TOAST — The Oversized-Attribute Storage Technique
Here is the problem. PostgreSQL stores data in 8KB pages. A single row cannot span multiple pages. So what happens when you store a large TEXT value — say a 50KB document? It will not fit in one page. PostgreSQL solves this with TOAST — The Oversized-Attribute Storage Technique. TOAST automatically compresses and slices large values into chunks stored in a separate TOAST table. You never interact with TOAST directly — it is completely transparent.

| Term | Meaning / Explanation |
| :--- | :--- |
| **The Problem** | PostgreSQL pages are 8KB — a single row cannot span pages |
| **TOAST Threshold** | Values > ~2KB trigger TOAST compression or out-of-line storage |
| **TOAST Table** | Separate hidden table (pg_toast.pg_toast_NNNNN) stores chunks |
| **Transparent** | You SELECT normally — PostgreSQL reassembles automatically |
| **TOAST-able Types** | TEXT, BYTEA, JSONB, XML, arrays, composite — variable-length types |

**Notes:**
- Fixed-size types (INT, BOOLEAN, DATE) are never TOASTed
- Each TOAST chunk is ~2000 bytes

### TOAST Storage Strategies
TOAST has four storage strategies. PLAIN means no TOAST at all — the value must fit in the page. EXTENDED is the default for variable-length types — it first tries compression, then moves out-of-line if still too big. EXTERNAL stores out-of-line without compression — useful for pre-compressed data like images. MAIN tries compression only and keeps the value in the main table if possible — it moves out-of-line only as a last resort.

| Term | Meaning / Explanation |
| :--- | :--- |
| **TOAST** | four storage strategies |
| **PLAIN** | no TOAST at all — the value must fit in the page |
| **EXTENDED** | the default for variable-length types — it first tries compression, then moves out-of-line if still too big |
| **EXTERNAL** | out-of-line without compression — useful for pre-compressed data like images |

### Beginner Trap: SELECT * with TOASTed Columns
Here is a beginner trap with TOAST. When you SELECT a table with large TOASTed columns but your query does not reference those columns, PostgreSQL does NOT read the TOAST data. This is a performance win. But many beginners write SELECT star on tables with big TEXT or JSONB columns. That forces PostgreSQL to detoast every row — reading from the TOAST table, decompressing, and reassembling. On a table with millions of rows and large documents, SELECT star can be 100 times slower than selecting only the columns you need.

| Slow (detoasts everything) | Fast (skips TOAST) |
| :--- | :--- |
| SELECT * FROM articles; | SELECT id, title FROM articles; |
| Reads TOAST table for every row | Reads ONLY the heap |
| Decompresses body column | TOAST data never touched |
| On 1M rows with 50KB body: | On 1M rows: |
|   ~50GB of TOAST I/O! |   ~80MB of heap I/O only |

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too. Now let us move to capacity planning.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Capacity Planning — The Core Formula
Capacity planning means predicting how much disk space your database will use in 3 months, 6 months, or a year. You need this to budget for storage, schedule maintenance windows, and avoid emergencies. The formula is simple: current size plus daily growth rate times number of days. But measuring daily growth accurately is the tricky part.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Future Size** | Current Size + (Daily Growth × Days) |
| **Daily Growth** | Measure over at least 7-14 days for a reliable average |
| **Headroom** | Always keep 30-40% free disk — VACUUM and WAL need room |
| **Growth Spikes** | Factor in batch jobs, migrations, seasonal peaks |

**Notes:**
- A 100GB database growing 500MB/day hits 280GB in one year
- VACUUM FULL temporarily needs 2x the table's current size

### Manual Row Size Estimation
Let us estimate row size manually. This is how you predict the size of a new table before it has any data. Add up the column sizes, add the 23-byte header, round up for alignment. For our big_orders table: id is 4 bytes, customer_id is 4, product averages 10, amount is 8, order_date is 4, notes averages 27, plus 23 bytes header, plus 4 bytes item pointer. That is about 84 bytes per row. Multiply by expected row count for the estimated table size.

- 1 -- id INT=4B, customer_id INT=4B, product TEXT≈10B, amount NUMERIC≈8B, date DATE=4B, notes TEXT≈27B
- 2 -- 23 bytes for HeapTupleHeader (xmin, xmax, cid, null bitmap)
- 3 -- 4 bytes per row in the page header
- 4 -- Rows padded to MAXALIGN (8 bytes) — add ~4 bytes avg
- 5 -- 4+4+10+8+4+27+23+4+4 ≈ 88 bytes per row
- 6 -- 1 million rows × 88 bytes = ~84 MB heap + indexes + TOAST

### Capacity Planning Decision Framework
Here is the complete decision framework for capacity planning. Different usage levels require different actions.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is the complete decision framework for capacity planning |
| **Point 2** | Different usage levels require different actions |

### Hidden Disk Space Consumers
A few more things that eat disk space unexpectedly. WAL files accumulate during heavy writes or when replication slots are not consumed. Temporary files from large sorts or hash joins can spike disk usage. pg_stat_statements stores query statistics. And do not forget: VACUUM FULL on a large table temporarily doubles its disk usage because it writes the new copy before deleting the old one.

| Term | Meaning / Explanation |
| :--- | :--- |
| **WAL Accumulation** | Replication slots + wal_keep_size hold WAL files — check pg_replication_slots |
| **Temp Files** | Large sorts/hash joins spill to disk — track via pg_stat_database.temp_bytes |
| **VACUUM FULL** | Needs 2x table size temporarily — 50GB table needs 50GB free |
| **Abandoned Replication Slots** | Inactive slot prevents WAL cleanup — WAL grows forever |

**Notes:**
- Check: SELECT slot_name, active FROM pg_replication_slots;
- Drop inactive: SELECT pg_drop_replication_slot('slot_name');

### Practice Exercises
Time to practice. First, create a table with a TEXT column and insert rows with different-sized values — 100 bytes, 5KB, and 50KB — then compare pg_relation_size versus pg_table_size to see TOAST in action. Second, query pg_attribute to check the TOAST storage strategy for each column. Third, build the db_size_log table and insert a snapshot. Fourth, run the per-table growth estimation query on your database. Fifth, calculate your current disk usage percentage.

- 1 -- INSERT different sizes, compare pg_relation_size vs pg_table_size
- 2 -- SELECT attname, attstorage FROM pg_attribute WHERE attrelid = 'table'::regclass
- 3 -- CREATE TABLE db_size_log, INSERT pg_database_size snapshot
- 4 -- Per-table: n_tup_ins / days since stats_reset
- 5 -- Sum all pg_database_size + pg_ls_waldir, calculate percentage of disk


---

## 3. Hands-On Commands & psql Output

### Seeing TOAST in Action
**Explanation:** Let us see TOAST in action. We will create a table with a TEXT column and insert values of different sizes. Then we will measure the main table size versus the TOAST table size to see when values get moved out-of-line.

```sql
trigger_lab=# CREATE TABLE toast_demo (
    id    SERIAL PRIMARY KEY,
    label TEXT,
    doc   TEXT
);
CREATE TABLE
trigger_lab=# -- Insert 1000 rows with small values (100 bytes):
trigger_lab=# INSERT INTO toast_demo (label, doc)
SELECT 'small_' || g, repeat('x', 100) FROM generate_series(1,1000) g;
INSERT 0 1000
trigger_lab=# -- Insert 1000 rows with large values (10KB each):
trigger_lab=# INSERT INTO toast_demo (label, doc)
SELECT 'large_' || g, repeat('A', 10240) FROM generate_series(1,1000) g;
INSERT 0 1000
trigger_lab=# SELECT
  pg_size_pretty(pg_relation_size('toast_demo')) AS heap,
  pg_size_pretty(pg_table_size('toast_demo'))    AS table_with_toast;
  heap   | table_with_toast
---------+------------------
 200 kB  | 872 kB
-- -- heap is only 200KB but total is 872KB
-- -- The difference (672KB) is in the TOAST table!
```

### Finding and Measuring the TOAST Table
**Explanation:** Let us find the actual TOAST table and measure it directly. Every TOASTable table has a hidden companion table in the pg_toast schema. You can find it through pg_class. The TOAST table stores the out-of-line chunks, and it has its own index for looking up chunks by value ID.

```sql
trigger_lab=# -- Find the TOAST table OID:
trigger_lab=# SELECT relname, reltoastrelid
FROM pg_class WHERE relname = 'toast_demo';
  relname   | reltoastrelid
------------+---------------
 toast_demo |         16542
trigger_lab=# -- Measure the TOAST table directly:
trigger_lab=# SELECT pg_size_pretty(pg_relation_size(16542)) AS toast_data,
  pg_size_pretty(pg_total_relation_size(16542)) AS toast_total;
 toast_data | toast_total
------------+-------------
 624 kB     | 672 kB
-- -- 624KB data + 48KB index = 672KB TOAST total
-- -- Large 10KB values compressed to ~624 bytes avg each!
-- -- repeat('A',10240) compresses extremely well
```

### Changing TOAST Strategy
**Explanation:** You can change a column's TOAST strategy using ALTER TABLE SET STORAGE. For example, if you store pre-compressed images in a BYTEA column, set it to EXTERNAL to skip double-compression. If you have a TEXT column that is always read and never too large, set it to MAIN to keep it in-line for faster access.

```sql
trigger_lab=# -- Check current storage strategy:
trigger_lab=# SELECT attname, attstorage
FROM pg_attribute WHERE attrelid = 'toast_demo'::regclass
AND attnum > 0;
 attname | attstorage
---------+------------
 id      | p            -- PLAIN (integer, no TOAST)
 label   | x            -- EXTENDED (default for TEXT)
 doc     | x            -- EXTENDED
trigger_lab=# -- Change doc to EXTERNAL (no compression):
trigger_lab=# ALTER TABLE toast_demo ALTER COLUMN doc SET STORAGE EXTERNAL;
ALTER TABLE
-- -- p = PLAIN,  x = EXTENDED,  e = EXTERNAL,  m = MAIN
-- -- Change only affects NEW rows, not existing data
-- -- To rewrite existing: UPDATE toast_demo SET doc = doc;
```

### TOAST Compression Methods
**Explanation:** Another important point: TOAST compression is per-value, not per-column. Each individual value is compressed independently using pglz — PostgreSQL's built-in compression algorithm. In PostgreSQL 14 and later, you can also choose LZ4 compression, which is faster but compresses slightly less. In PostgreSQL 16, you set the default with the default_toast_compression parameter.

```sql
trigger_lab=# SHOW default_toast_compression;
 default_toast_compression
---------------------------
 pglz
trigger_lab=# -- Change default for new columns:
trigger_lab=# SET default_toast_compression = 'lz4';
SET
trigger_lab=# -- Or set per column:
trigger_lab=# ALTER TABLE toast_demo ALTER COLUMN doc SET COMPRESSION lz4;
ALTER TABLE
-- -- pglz: better compression ratio, slower
-- -- lz4:  faster compression/decompression, slightly larger
-- -- Per-value: old rows keep pglz, new rows use lz4
-- -- lz4 requires PostgreSQL compiled with --with-lz4
```

### Growth Tracking — Snapshot and Project
**Explanation:** Now let us build a growth tracking query. By recording database sizes at regular intervals, you can calculate the daily growth rate and project future sizes. This query creates a snapshot table and shows how to use it for projections.

```sql
-- Step 1: Create snapshot table
CREATE TABLE db_size_log (
    snapshot_date DATE PRIMARY KEY DEFAULT CURRENT_DATE,
    db_size_bytes BIGINT NOT NULL
);

-- Step 2: Record daily (run via cron/pg_cron)
INSERT INTO db_size_log (db_size_bytes)
VALUES (pg_database_size(current_database()))
ON CONFLICT (snapshot_date) DO UPDATE
    SET db_size_bytes = EXCLUDED.db_size_bytes;

-- Step 3: Calculate growth rate and project
SELECT
    pg_size_pretty(max(db_size_bytes)) AS current_size,
    pg_size_pretty(
        (max(db_size_bytes) - min(db_size_bytes))
        / GREATEST(max(snapshot_date) - min(snapshot_date), 1)
    ) AS avg_daily_growth,
    pg_size_pretty(
        max(db_size_bytes) + (
            (max(db_size_bytes) - min(db_size_bytes))
            / GREATEST(max(snapshot_date) - min(snapshot_date), 1)
        ) * 90
    ) AS projected_90_days
FROM db_size_log;
```

### Per-Table Growth Estimation
**Explanation:** For per-table growth estimation, this query shows the biggest tables and estimates their growth based on recent inserts. It uses pg_stat_user_tables to get the number of inserts since the last stats reset, then calculates the daily insert rate.

```sql
trigger_lab=# SELECT
  schemaname || '.' || relname AS table_name,
  pg_size_pretty(pg_total_relation_size(relid)) AS current_size,
  n_tup_ins AS total_inserts,
  CASE WHEN (now() - stats_reset) > '1 day'
    THEN round(n_tup_ins / EXTRACT(day FROM now() - stats_reset))
    ELSE n_tup_ins END AS inserts_per_day,
  stats_reset::date AS since
FROM pg_stat_user_tables
WHERE n_tup_ins > 0
ORDER BY pg_total_relation_size(relid) DESC LIMIT 5;
      table_name       | current_size | total_inserts | inserts_per_day | since
-----------------------+--------------+---------------+-----------------+--------
 public.big_orders     | 65 MB        |        500000 |          250000 | Nov 01
 public.toast_demo     | 1096 kB      |          2000 |            1000 | Nov 01
 public.audit_log      | 32 kB        |             5 |               3 | Nov 01
```

### Capacity Planning Worksheet
**Explanation:** Let us put it all together with a capacity planning worksheet. This is the query you run monthly to check whether you need to buy more disk. It shows current usage, growth rate, and how many days until you hit dangerous thresholds. The 70 percent threshold is your warning. The 85 percent threshold is your emergency.

```sql
-- Run this monthly on every production server
WITH disk_info AS (
    SELECT
        sum(pg_database_size(datname)) AS total_data,
        -- Estimate total disk from your provisioned size:
        500::bigint * 1024 * 1024 * 1024 AS disk_capacity
    FROM pg_database
),
wal_info AS (
    SELECT sum(size) AS wal_size FROM pg_ls_waldir()
)
SELECT
    pg_size_pretty(d.total_data) AS data_size,
    pg_size_pretty(w.wal_size) AS wal_size,
    pg_size_pretty(d.total_data + w.wal_size) AS total_used,
    pg_size_pretty(d.disk_capacity) AS disk_total,
    round(100.0 * (d.total_data + w.wal_size)
        / d.disk_capacity, 1) AS pct_used
FROM disk_info d, wal_info w;
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: SELECT * with TOASTed Columns
Here is a beginner trap with TOAST. When you SELECT a table with large TOASTed columns but your query does not reference those columns, PostgreSQL does NOT read the TOAST data. This is a performance win. But many beginners write SELECT star on tables with big TEXT or JSONB columns. That forces PostgreSQL to detoast every row — reading from the TOAST table, decompressing, and reassembling. On a table with millions of rows and large documents, SELECT star can be 100 times slower than selecting only the columns you need.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review what we covered. TOAST handles values over 2KB by compressing and storing them out-of-line in a hidden TOAST table. Four strategies: PLAIN, EXTENDED, EXTERNAL, MAIN. SELECT star on TOASTed tables forces expensive detoasting — always select only the columns you need. For capacity planning: track database size daily, calculate daily growth rate, project forward 90 days, keep 30 to 40 percent disk headroom. Monitor WAL accumulation, temp files, and replication slots. The 70 percent disk usage threshold is your warning to act.

- **TOAST: automatic for values > ~2KB (TEXT, JSONB, BYTEA, arrays)**
- **4 strategies: PLAIN, EXTENDED (default), EXTERNAL, MAIN**
- **TOAST table: pg_toast.pg_toast_NNNNN — hidden, automatic**
- **SELECT * forces detoasting — select only needed columns!**
- **Compression: pglz (default) or lz4 (PG14+, faster)**
- **Row size ≈ column bytes + 23B header + 4B pointer + padding**
- **Growth = daily inserts × avg row size × days**
- **Track sizes daily with db_size_log table + pg_cron**
- **Keep 30-40% disk free for VACUUM, WAL, temp files**
- **70% disk = warning, 85% = critical, 90% = emergency**


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
