# Materialized Views — Cached Results with REFRESH
**Series:** PostgreSQL Mastery | **Phase:** Phase 11: Views | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn about materialized views — views that actually store data on disk. Unlike regular views that run the query every time, a materialized view stores the result and serves it like a table. You can even create indexes on it for fast lookups. The tradeoff: the data can become stale, so you need to REFRESH it. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Regular View vs Materialized View
The problem: your dashboard runs a query that joins five tables, aggregates millions of rows, and takes 30 seconds. Ten users open the dashboard every minute — that is 300 seconds of CPU per minute for the same result. A materialized view runs the query once, stores the result, and serves it in milliseconds. Ten users, 10 milliseconds total. You refresh it on a schedule — say, every hour.

| Regular View | Materialized View |
| :--- | :--- |
| No data stored on disk | Data stored on disk (like a table) |
| Query runs EVERY time you SELECT | Query runs only on CREATE/REFRESH |
| Always shows current data | Data can be STALE until refreshed |
| Cannot add indexes to it | CAN add indexes for fast lookups |
| Fast to create, slow to query | Slow to create/refresh, fast to query |

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Refresh Strategies
Refresh strategies for production. Manual refresh works for development. For production, schedule refreshes with pg_cron — a PostgreSQL extension — or use crontab on the server. You can also refresh from your application code after a batch data load. The key question: how stale can your data be? If 1 hour is acceptable, refresh every hour. If 5 minutes, refresh every 5 minutes.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Manual** | Run REFRESH from psql — good for development |
| **pg_cron** | Schedule inside PostgreSQL: SELECT cron.schedule(...) |
| **OS crontab** | psql -c 'REFRESH MATERIALIZED VIEW ...' on a schedule |
| **App-driven** | Refresh after batch data loads or ETL jobs |
| **Key Question** | How stale can data be? That determines refresh interval |

**Notes:**
- Always use CONCURRENTLY in production (with unique index)
- Log refresh times for monitoring

### View Decision Framework
Here is a decision framework for choosing between regular views, materialized views, direct queries, and application caching. The main factors are query cost, freshness requirement, and read frequency. Expensive queries read by many users with acceptable staleness are the sweet spot for materialized views.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a decision framework for choosing between regular views, materialized views, direct queries, and application caching |
| **The main factors are query cost** | freshness requirement, and read frequency |
| **Point 3** | Expensive queries read by many users with acceptable staleness are the sweet spot for materialized views |

### Practice Exercises
Practice exercises: create a materialized view, add indexes, refresh it both ways, try WITH NO DATA, check pg_matviews, track staleness, and set up the full production pattern with a unique index and concurrent refresh.

- 1. CREATE MATERIALIZED VIEW with GROUP BY
- 2. SELECT from it — verify it's pre-computed
- 3. CREATE UNIQUE INDEX on the matview
- 4. REFRESH MATERIALIZED VIEW (normal)
- 5. REFRESH MATERIALIZED VIEW CONCURRENTLY
- 6. CREATE ... WITH NO DATA, then REFRESH
- 7. Try INSERT into matview (observe error)
- 8. Check pg_matviews and pg_relation_size
- 9. Create a refresh_log table and track staleness


---

## 3. Hands-On Commands & psql Output

### CREATE MATERIALIZED VIEW
**Explanation:** Creating a materialized view uses CREATE MATERIALIZED VIEW. The query runs immediately and the result is stored on disk. After creation, SELECT reads the stored data — no re-computation. The output shows SELECT followed by the row count, confirming how many rows were stored.

```sql
practice=# CREATE MATERIALIZED VIEW mv_sales_summary AS
SELECT
  product,
  DATE_TRUNC('month', month) AS sale_month,
  SUM(revenue) AS total_revenue,
  COUNT(*) AS record_count
FROM monthly_sales
GROUP BY product, DATE_TRUNC('month', month)
ORDER BY product, sale_month;
SELECT 12

-- Query it — reads stored data instantly
practice=# SELECT * FROM mv_sales_summary WHERE product = 'Widget';
 product | sale_month  | total_revenue | record_count
---------+-------------+---------------+--------------
 Widget  | 2024-01-01  |         10000 |            1
 Widget  | 2024-02-01  |         12000 |            1
 Widget  | 2024-03-01  |         11500 |            1

-- No query re-execution! Reads from stored data.
```

### Indexes on Materialized Views
**Explanation:** A major advantage of materialized views: you can add indexes. Create indexes on the columns you query most. This makes SELECT from the materialized view as fast as querying an indexed table. A unique index is also required for REFRESH CONCURRENTLY — which we will cover shortly.

```sql
-- Index for fast lookups by product
practice=# CREATE INDEX idx_mv_sales_product
ON mv_sales_summary (product);
CREATE INDEX

-- Unique index (needed for CONCURRENTLY refresh)
practice=# CREATE UNIQUE INDEX idx_mv_sales_unique
ON mv_sales_summary (product, sale_month);
CREATE INDEX

-- EXPLAIN shows index usage
practice=# EXPLAIN SELECT * FROM mv_sales_summary
WHERE product = 'Widget';
               QUERY PLAN
------------------------------------------
 Index Scan using idx_mv_sales_product
   on mv_sales_summary
   Index Cond: (product = 'Widget')
```

### REFRESH — Normal (With Lock)
**Explanation:** The data in a materialized view is stale — it was correct when you last refreshed it. REFRESH MATERIALIZED VIEW re-runs the query and replaces the stored data. But during a normal refresh, the view is LOCKED — no one can read from it until refresh completes. For production systems, this lock is unacceptable if the refresh takes minutes.

```sql
-- Add new data to the base table
practice=# INSERT INTO monthly_sales VALUES ('Widget', '2024-07-01', 15000);
INSERT 0 1

-- Matview still shows OLD data
practice=# SELECT * FROM mv_sales_summary WHERE product = 'Widget'
  AND sale_month = '2024-07-01';
(0 rows)  -- July not there yet!

-- Refresh it (LOCKS the matview during refresh!)
practice=# REFRESH MATERIALIZED VIEW mv_sales_summary;
REFRESH MATERIALIZED VIEW

-- Now July appears
practice=# SELECT * FROM mv_sales_summary WHERE product = 'Widget'
  AND sale_month = '2024-07-01';
 product | sale_month  | total_revenue | record_count
---------+-------------+---------------+--------------
 Widget  | 2024-07-01  |         15000 |            1
```

### REFRESH CONCURRENTLY — No Lock
**Explanation:** REFRESH CONCURRENTLY solves the locking problem. It builds the new data alongside the old data and swaps them atomically — readers continue using the old data during refresh, then switch to the new data seamlessly. But CONCURRENTLY requires a unique index on the materialized view. Without it, PostgreSQL gives an error.

```sql
-- Concurrent refresh: no lock, readers unblocked
practice=# REFRESH MATERIALIZED VIEW CONCURRENTLY mv_sales_summary;
REFRESH MATERIALIZED VIEW

-- Without unique index: ERROR
practice=# CREATE MATERIALIZED VIEW mv_no_idx AS
SELECT department, COUNT(*) FROM employees GROUP BY 1;
SELECT 5

practice=# REFRESH MATERIALIZED VIEW CONCURRENTLY mv_no_idx;
ERROR:  cannot refresh materialized view "public.mv_no_idx"
        concurrently
HINT:  Create a unique index with no WHERE clause on one
or more columns of the materialized view.

-- Fix: add a unique index, then retry CONCURRENTLY
-- CONCURRENTLY is slower but production-safe
```

### WITH NO DATA — Define Now, Populate Later
**Explanation:** CREATE WITH NO DATA defines the materialized view without running the query. This is useful for deployment scripts where you want to set up the structure first and populate later. Querying an unpopulated matview gives a clear error — you must REFRESH it first.

```sql
practice=# CREATE MATERIALIZED VIEW mv_empty AS
SELECT department, COUNT(*) AS cnt FROM employees
GROUP BY department
WITH NO DATA;
CREATE MATERIALIZED VIEW

-- Query fails: not populated yet
practice=# SELECT * FROM mv_empty;
ERROR:  materialized view "mv_empty" has not been populated
HINT:  Use the REFRESH MATERIALIZED VIEW command.

practice=# REFRESH MATERIALIZED VIEW mv_empty;
REFRESH MATERIALIZED VIEW

practice=# SELECT * FROM mv_empty;
 department  | cnt
-------------+-----
 Engineering |   4
 HR          |   2
 Executive   |   1
```

### Tracking Staleness
**Explanation:** How do you know if a materialized view is stale? PostgreSQL does not track when a matview was last refreshed automatically, but you can build this yourself. One approach: create a helper table that records the last refresh time. Another: check pg_stat_user_tables for the last analyze time, which gets updated after refresh.

```sql
-- Approach 1: Helper table to track refresh times
practice=# CREATE TABLE matview_refresh_log (
  view_name TEXT PRIMARY KEY,
  last_refresh TIMESTAMP DEFAULT NOW()
);

-- After every REFRESH, update the log
practice=# REFRESH MATERIALIZED VIEW mv_sales_summary;
practice=# INSERT INTO matview_refresh_log VALUES
  ('mv_sales_summary', NOW())
ON CONFLICT (view_name) DO UPDATE
  SET last_refresh = NOW();

-- Check staleness
practice=# SELECT view_name,
  last_refresh,
  AGE(NOW(), last_refresh) AS staleness
FROM matview_refresh_log;
     view_name      |     last_refresh      | staleness
-------------------+-----------------------+-----------
 mv_sales_summary  | 2024-01-15 10:30:00   | 00:15:22
```

### Size, Metadata, and DROP
**Explanation:** Materialized views use disk space just like tables. You can check the size with pg_relation_size or the backslash dt-plus command. Large materialized views can use significant storage. DROP MATERIALIZED VIEW removes the view and frees the disk space. Always use IF EXISTS to avoid errors if the view does not exist.

```sql
-- Check matview size
practice=# SELECT pg_size_pretty(pg_relation_size('mv_sales_summary'));
 pg_size_pretty
----------------
 8192 bytes

-- List all materialized views
practice=# SELECT schemaname, matviewname, ispopulated
FROM pg_matviews WHERE schemaname = 'public';
 schemaname |    matviewname    | ispopulated
------------+-------------------+-------------
 public     | mv_sales_summary  | t
 public     | mv_empty          | t

-- Drop a materialized view
practice=# DROP MATERIALIZED VIEW IF EXISTS mv_empty;
DROP MATERIALIZED VIEW

-- CASCADE drops dependent objects too
```

### Beginner Trap: Matview is Read-Only
**Explanation:** Beginner trap: you cannot INSERT, UPDATE, or DELETE on a materialized view — it is read-only. The only way to change its contents is REFRESH. Also, you cannot use REFRESH inside a transaction if you use CONCURRENTLY. And if the underlying query changes schema, you must DROP and recreate — there is no CREATE OR REPLACE for materialized views.

```sql
-- Cannot INSERT into a materialized view
practice=# INSERT INTO mv_sales_summary VALUES ('New', '2024-08-01', 5000, 1);
ERROR:  cannot change materialized view "mv_sales_summary"

-- Cannot UPDATE either
practice=# UPDATE mv_sales_summary SET total_revenue = 0;
ERROR:  cannot change materialized view "mv_sales_summary"

-- Only REFRESH can update the contents
-- REFRESH re-runs the full query and replaces ALL data

-- No CREATE OR REPLACE for matviews:
-- Must DROP and CREATE again to change the query
-- DROP MATERIALIZED VIEW mv_sales_summary;
-- CREATE MATERIALIZED VIEW mv_sales_summary AS ...;
```

### Real-World Pattern: Dashboard Matview
**Explanation:** Let us see a real-world pattern: a dashboard matview with scheduled refresh. Create the matview, add a unique index, set up concurrent refresh, and log the refresh time. This is the standard production pattern for materialized views.

```sql
-- Step 1: Create the materialized view
CREATE MATERIALIZED VIEW mv_dashboard AS
SELECT
  department,
  COUNT(*) AS headcount,
  ROUND(AVG(salary), 2) AS avg_salary,
  SUM(salary) AS total_payroll
FROM employees
GROUP BY department;

-- Step 2: Add unique index (required for CONCURRENTLY)
CREATE UNIQUE INDEX ON mv_dashboard (department);

-- Step 3: Refresh script (run via cron)
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard;
-- INSERT INTO matview_refresh_log ...

-- Step 4: Query from your app
-- SELECT * FROM mv_dashboard ORDER BY headcount DESC;

-- Result: 30-second query → 1ms reads
-- Refresh every hour via pg_cron or OS crontab
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Matview is Read-Only
Beginner trap: you cannot INSERT, UPDATE, or DELETE on a materialized view — it is read-only. The only way to change its contents is REFRESH. Also, you cannot use REFRESH inside a transaction if you use CONCURRENTLY. And if the underlying query changes schema, you must DROP and recreate — there is no CREATE OR REPLACE for materialized views.

```sql
-- Cannot INSERT into a materialized view
INSERT INTO mv_sales_summary VALUES ('New', '2024-08-01', 5000, 1);
ERROR:  cannot change materialized view "mv_sales_summary"

-- Cannot UPDATE either
UPDATE mv_sales_summary SET total_revenue = 0;
ERROR:  cannot change materialized view "mv_sales_summary"

-- Only REFRESH can update the contents
-- REFRESH re-runs the full query and replaces ALL data

-- No CREATE OR REPLACE for matviews:
-- Must DROP and CREATE again to change the query
-- DROP MATERIALIZED VIEW mv_sales_summary;
-- CREATE MATERIALIZED VIEW mv_sales_summary AS ...;
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. Materialized views store query results on disk — they are pre-computed snapshots. Run the query once at creation or refresh, then serve stored data instantly. Add indexes for even faster lookups. REFRESH re-runs the query. Use CONCURRENTLY in production — it needs a unique index but does not block readers. WITH NO DATA defines the structure without populating. Materialized views are read-only — no INSERT, UPDATE, or DELETE. There is no CREATE OR REPLACE — must DROP and recreate. Track staleness with a helper table. Use for dashboards, reports, and expensive analytics where slightly stale data is acceptable. This completes the Views phase! In the next phase, we start Indexes. See you there!

- **CREATE MATERIALIZED VIEW name AS SELECT ...**
- **Stores result on disk — fast reads, stale data**
- **REFRESH MATERIALIZED VIEW: re-run and replace**
- **CONCURRENTLY: no-lock refresh (needs unique index)**
- **WITH NO DATA: define now, populate later**
- **Read-only: no INSERT/UPDATE/DELETE**
- **No CREATE OR REPLACE: must DROP and recreate**
- **Add indexes for fast queries**
- **Track staleness with refresh_log table**


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
