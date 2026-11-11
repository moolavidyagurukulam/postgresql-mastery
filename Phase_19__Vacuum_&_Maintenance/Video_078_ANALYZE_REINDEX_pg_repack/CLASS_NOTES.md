# ANALYZE, REINDEX & pg_repack
**Series:** PostgreSQL Mastery | **Phase:** Phase 19: Vacuum & Maintenance | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous classes, we covered VACUUM for cleaning dead tuples and AUTOVACUUM for running cleanup automatically. Now we tackle three more essential maintenance tools. ANALYZE updates the statistics the query planner uses to choose execution plans. REINDEX rebuilds bloated or corrupted indexes. And pg_repack does what VACUUM FULL does — shrinks tables — but without locking them. Let us begin.

### ANALYZE — Why Statistics Matter
Imagine you are driving with a GPS that has a map from 5 years ago. New roads exist, old roads are closed, but the GPS does not know. It gives you terrible directions. That is what happens when PostgreSQL's statistics are stale. The query planner is like a GPS — it uses statistics to choose the best path to your data. If the statistics say a table has 100 rows but it actually has 10 million, the planner will choose a sequential scan when an index scan would be a thousand times faster.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand VACUUM, VACUUM FULL, and AUTOVACUUM from the previous two classes. Recap: VACUUM cleans dead tuples and marks space reusable. VACUUM FULL rewrites the table and shrinks it but locks it. AUTOVACUUM does both automatically. Now we need to understand: even if the table is clean, the query planner might still make bad decisions if its statistics are stale.

- Prerequisite: VACUUM, VACUUM FULL, AUTOVACUUM
- Recap: VACUUM cleans dead tuples, VACUUM FULL shrinks on disk
- Recap: AUTOVACUUM runs both automatically in the background
- Now: Statistics (ANALYZE), Index maintenance (REINDEX), Online rewrite (pg_repack)

### ANALYZE — Why Statistics Matter
Imagine you are driving with a GPS that has a map from 5 years ago. New roads exist, old roads are closed, but the GPS does not know. It gives you terrible directions. That is what happens when PostgreSQL's statistics are stale. The query planner is like a GPS — it uses statistics to choose the best path to your data. If the statistics say a table has 100 rows but it actually has 10 million, the planner will choose a sequential scan when an index scan would be a thousand times faster.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What ANALYZE does** | Samples rows from the table and updates planner statistics in pg_statistic |
| **What statistics include** | Row count, data distribution, most common values, NULL fraction, correlation |
| **Who uses them** | The query planner — to estimate row counts and choose scan/join methods |
| **Stale statistics =** | Bad query plans → wrong scan type, wrong join order → slow queries |

**Notes:**
- AUTOVACUUM runs ANALYZE automatically (autovacuum_analyze_scale_factor)
- Manual ANALYZE after bulk loads, major schema changes, or data migrations

### Index Bloat — The Silent Performance Killer
Now let us talk about index bloat. Tables are not the only things that get bloated — indexes do too. When rows are updated or deleted, the index entries pointing to them become dead. B-tree indexes in PostgreSQL cannot efficiently reclaim space from deleted entries in the middle of the tree. Over time, an index can become much larger than it needs to be, making index scans slower and wasting memory.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What causes it** | UPDATE/DELETE removes rows but leaves dead entries in the B-tree index |
| **Why it matters** | Bloated index = more pages to scan = slower index lookups + wasted RAM |
| **VACUUM helps partially** | VACUUM marks dead index entries reusable, but cannot shrink the index file |
| **REINDEX fixes it** | Builds a brand new index from scratch, compact and efficient |

**Notes:**
- Check index bloat: pgstattuple extension or compare actual vs estimated size
- Heavily updated columns (status fields, timestamps) bloat indexes most

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description. If you want to support this free course, the donation link is also in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### pg_repack — Online Table Reorganization
Now for the star of this class — pg_repack. Remember, VACUUM FULL shrinks tables but takes an ACCESS EXCLUSIVE lock. For a large production table, that is unacceptable. pg_repack solves this problem — it reorganizes tables and indexes online, without locking them. It works by creating a new copy of the table, applying changes through a trigger, then swapping the tables at the end with a very brief lock.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What it does** | Rewrites tables/indexes like VACUUM FULL — but WITHOUT long locks |
| **How it works** | Creates new table copy → trigger captures changes → brief lock to swap |
| **Lock duration** | Very brief exclusive lock at the very end (milliseconds to swap) |
| **Requirements** | Separate extension — not built into PostgreSQL core |

**Notes:**
- pg_repack needs free disk space equal to the table size + indexes
- The table must have a PRIMARY KEY or a UNIQUE NOT NULL constraint

### Maintenance Tool Decision Guide
Here is when to use each tool. Regular VACUUM for routine cleanup — run it often or let autovacuum handle it. VACUUM FULL when you need disk space back and can afford table downtime. pg_repack when you need disk space back but cannot afford downtime. REINDEX for bloated indexes. ANALYZE after bulk data changes. This decision framework will guide your daily maintenance.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Regular VACUUM for routine cleanup** | run it often or let autovacuum handle it |
| **Point 2** | VACUUM FULL when you need disk space back and can afford table downtime |
| **Point 3** | pg_repack when you need disk space back but cannot afford downtime |
| **Point 4** | REINDEX for bloated indexes |
| **Point 5** | ANALYZE after bulk data changes |
| **Point 6** | This decision framework will guide your daily maintenance |

### Beginner Trap: VACUUM FULL in Production
Here is a common beginner trap. You have a 200-gigabyte table with heavy bloat. You run VACUUM FULL during business hours without telling anyone. The entire table locks — every query hitting that table hangs. The application starts timing out. Users see errors. It takes 3 hours to complete. Meanwhile, pg_repack would have done the same job with only a millisecond lock at the end.

| The Disaster | The Right Way |
| :--- | :--- |
| 200 GB table is bloated | Use pg_repack instead |
| Run VACUUM FULL at 2 PM | pg_repack -t big_table runs online |
| ACCESS EXCLUSIVE LOCK activates | Table stays fully accessible |
| All queries queue up and timeout | Brief lock only at final swap |
| Application errors for 3 hours | Zero downtime for users |
| Users cannot access the system | Schedule VACUUM FULL only in maintenance windows |

### REINDEX vs REINDEX CONCURRENTLY
One more important topic — REINDEX CONCURRENTLY versus regular REINDEX. Regular REINDEX takes a lock that blocks writes to the table. REINDEX CONCURRENTLY builds the new index alongside the old one without blocking writes, then swaps them. Always use CONCURRENTLY in production. The only downside is it takes longer and uses more disk space during the rebuild.

| REINDEX (regular) | REINDEX CONCURRENTLY |
| :--- | :--- |
| Blocks INSERT/UPDATE/DELETE | Does NOT block writes |
| Faster — exclusive access | Slower — must track concurrent changes |
| Less disk space needed | Needs extra disk space for temp index |
| Use during maintenance windows | Use in production (24/7 systems) |
| Required for system catalog indexes | Cannot be used inside a transaction block |


---

## 3. Hands-On Commands & psql Output

### Stale Statistics — Bad Query Plans
**Explanation:** Let us see ANALYZE in action. We will create a table, check what the planner thinks about it, then load data and see how stale statistics lead to bad plans.

```sql
postgres=# -- Create a table and insert data
postgres=# CREATE TABLE stats_test (
    id SERIAL PRIMARY KEY,
    category TEXT,
    amount NUMERIC
);
postgres=# INSERT INTO stats_test (category, amount)
SELECT
    CASE (random() * 3)::int
      WHEN 0 THEN 'electronics'
      WHEN 1 THEN 'clothing'
      WHEN 2 THEN 'food'
      ELSE 'other'
    END,
    (random() * 1000)::numeric(10,2)
postgres-# FROM generate_series(1, 100000);
postgres=# CREATE INDEX idx_stats_category ON stats_test(category);
postgres=# -- Check planner's estimate WITHOUT analyze:
postgres=# EXPLAIN SELECT * FROM stats_test WHERE category = 'electronics';
                            QUERY PLAN
postgres=# ----------------------------------------------------------
 Seq Scan on stats_test  (cost=0.00..2084.00 rows=1 ...)
   Filter: (category = 'electronics'::text)
postgres=# -- Planner estimates 1 row! (stats are empty)
postgres=# -- Chooses Seq Scan because it thinks the table is tiny
```

### After ANALYZE — Correct Query Plans
**Explanation:** The planner estimated only 1 row because it has no statistics yet. It chose a sequential scan because it thinks the table is basically empty. Now let us run ANALYZE and see the difference.

```sql
postgres=# -- Run ANALYZE to collect statistics
postgres=# ANALYZE stats_test;
postgres=# -- Same query, now with accurate statistics:
postgres=# EXPLAIN SELECT * FROM stats_test WHERE category = 'electronics';
                               QUERY PLAN
postgres=# ------------------------------------------------------------------------
 Bitmap Heap Scan on stats_test  (cost=287.50..1425.00 rows=25012 ...)
   Recheck Cond: (category = 'electronics'::text)
   -> Bitmap Index Scan on idx_stats_category
         (cost=0.00..281.25 rows=25012 ...)
postgres=# -- Now it estimates ~25,000 rows (correct!)
postgres=# -- Chooses Bitmap Index Scan — much faster than Seq Scan
postgres=# -- Check collected statistics:
postgres=# SELECT attname, n_distinct, most_common_vals, most_common_freqs
postgres-# FROM pg_stats
postgres-# WHERE tablename = 'stats_test' AND attname = 'category';
 attname  | n_distinct | most_common_vals           | most_common_freqs
postgres=# ----------+------------+----------------------------+-------------------
 category |          4 | {food,clothing,electronics,other} | {0.2507,0.2504,...}
```

### ANALYZE Syntax & Options
**Explanation:** Here are all the ANALYZE variations you should know. You can analyze the entire database, a single table, or specific columns. VERBOSE shows exactly which columns were analyzed and how many rows were sampled. The default statistics target controls how many values PostgreSQL samples — higher means more accurate statistics but slower ANALYZE.

```sql
-- Analyze entire database:
ANALYZE;

-- Analyze a specific table:
ANALYZE stats_test;

-- Analyze specific columns:
ANALYZE stats_test (category, amount);

-- Verbose output:
ANALYZE (VERBOSE) stats_test;

-- Increase statistics target for a column (more accurate):
ALTER TABLE stats_test
  ALTER COLUMN category SET STATISTICS 500;
-- Default: 100, Max: 10000
-- Higher = more accurate stats, slower ANALYZE
-- Use for columns with many distinct values or skewed data

-- Then re-analyze to apply:
ANALYZE stats_test;

-- Check current stats target:
SELECT attname, attstattarget
FROM pg_attribute
WHERE attrelid = 'stats_test'::regclass
  AND attnum > 0;
```

### Detecting & Fixing Index Bloat with REINDEX
**Explanation:** Let us check for index bloat and then rebuild with REINDEX.

```sql
postgres=# -- Check index sizes vs table size
postgres=# SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
       idx_scan,
       idx_tup_read
postgres-# FROM pg_stat_user_indexes
postgres-# WHERE schemaname = 'public'
postgres-# ORDER BY pg_relation_size(indexrelid) DESC;
 indexrelname         | index_size | idx_scan | idx_tup_read
postgres=# ----------------------+------------+----------+-------------
 stats_test_pkey      | 2208 kB    |        0 |            0
 idx_stats_category   | 2032 kB    |        2 |        50024
postgres=# -- Install pgstattuple for detailed bloat analysis:
postgres=# CREATE EXTENSION IF NOT EXISTS pgstattuple;
postgres=# -- Check bloat ratio:
postgres=# SELECT * FROM pgstatindex('idx_stats_category');
 version | tree_level | index_size | root_block_no | ...
postgres=# ---------+------------+------------+---------------+----
       4 |          2 |    2080768 |             3 | ...
postgres=# -- leaf_fragmentation shows how much is wasted
```

### REINDEX Syntax & Options
**Explanation:** Here are the REINDEX commands. You can rebuild a single index, all indexes on a table, an entire schema, or the whole database. In PostgreSQL 16, REINDEX CONCURRENTLY rebuilds the index without locking the table — this is the production-safe way.

```sql
-- Rebuild a single index:
REINDEX INDEX idx_stats_category;

-- Rebuild ALL indexes on a table:
REINDEX TABLE stats_test;

-- Rebuild all indexes in a schema:
REINDEX SCHEMA public;

-- Rebuild all indexes in the database:
REINDEX DATABASE trigger_lab;

-- CONCURRENTLY — no table lock! (production safe)
REINDEX INDEX CONCURRENTLY idx_stats_category;
REINDEX TABLE CONCURRENTLY stats_test;

-- REINDEX system catalogs (must be done in single-user mode
-- or with REINDEX SYSTEM):
REINDEX SYSTEM trigger_lab;

-- VERBOSE output:
REINDEX (VERBOSE) TABLE stats_test;
```

### Installing pg_repack
**Explanation:** Let us install pg_repack and see it in action. First, install the package on the operating system, then create the extension in your database.

```sql
# Install pg_repack (Ubuntu/Debian):
sudo apt install postgresql-16-repack
# Install pg_repack (RHEL/CentOS):
sudo dnf install pg_repack_16
# Create the extension in your database:
psql -U postgres -d trigger_lab
trigger_lab=# CREATE EXTENSION pg_repack;
postgres=# CREATE EXTENSION
# Verify:
trigger_lab=# SELECT extname, extversion
postgres-# FROM pg_extension
postgres-# WHERE extname = 'pg_repack';
  extname  | extversion
postgres=# -----------+------------
 pg_repack | 1.5.0
```

### Using pg_repack — Online Table Rewrite
**Explanation:** Now let us use pg_repack to reorganize a bloated table. Notice that it runs from the command line, not from inside psql. It connects to the database, creates a temporary copy, and swaps — all while the table stays fully accessible.

```sql
# Repack a single table:
pg_repack -U postgres -d trigger_lab -t bloat_test
INFO: repacking table "public.bloat_test"
# Repack with verbose output:
pg_repack -U postgres -d trigger_lab -t bloat_test --echo
# Repack ALL tables in the database:
pg_repack -U postgres -d trigger_lab
# Repack only indexes of a table:
pg_repack -U postgres -d trigger_lab -t bloat_test --only-indexes
# Repack a specific index:
pg_repack -U postgres -d trigger_lab -i idx_stats_category
# Dry run (show what would be done):
pg_repack -U postgres -d trigger_lab -t bloat_test --dry-run
# With parallelism:
pg_repack -U postgres -d trigger_lab -t bloat_test -j 4
```

### Complete Bloat Detection Query
**Explanation:** Let us look at a complete bloat detection query that shows you which tables and indexes need attention. This is the query you should run regularly to identify maintenance targets.

```sql
-- Table bloat report:
SELECT schemaname, relname,
       n_live_tup,
       n_dead_tup,
       ROUND(n_dead_tup::numeric /
         NULLIF(n_live_tup + n_dead_tup, 0) * 100, 1)
         AS bloat_pct,
       pg_size_pretty(pg_total_relation_size(relid))
         AS total_size,
       last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- Index bloat (estimated):
SELECT
    indexrelname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size,
    idx_scan AS scans,
    CASE WHEN idx_scan = 0 THEN 'UNUSED — consider dropping'
         ELSE 'Active' END AS status
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: VACUUM FULL in Production
Here is a common beginner trap. You have a 200-gigabyte table with heavy bloat. You run VACUUM FULL during business hours without telling anyone. The entire table locks — every query hitting that table hangs. The application starts timing out. Users see errors. It takes 3 hours to complete. Meanwhile, pg_repack would have done the same job with only a millisecond lock at the end.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. ANALYZE updates planner statistics — stale statistics lead to bad query plans. REINDEX rebuilds bloated or corrupted indexes — use CONCURRENTLY in production. pg_repack does online table reorganization without locks — use it instead of VACUUM FULL in production. Always check bloat levels before deciding which tool to use. In the next class, we put it all together with a complete routine maintenance checklist.

- **ANALYZE: updates planner statistics (row counts, distributions, common values)**
- **Stale statistics = bad query plans (wrong scan type, wrong join order)**
- **SET STATISTICS on columns with many distinct values for better accuracy**
- **REINDEX: rebuilds indexes from scratch — use CONCURRENTLY in production**
- **pg_repack: online VACUUM FULL — rewrites table without long locks**
- **pg_repack needs PRIMARY KEY and free disk space equal to table size**
- **Monitor bloat: pg_stat_user_tables, pgstattuple, pgstatindex**
- **Next: Routine Maintenance Checklist & Schedule**


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
