# Denormalization
**Series:** PostgreSQL Mastery | **Phase:** General | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> In the last class, we normalized our tables to eliminate redundancy. But sometimes, normalized tables are too slow. Today, we learn when and how to break those rules on purpose. This is Denormalization.

### The Problem: Normalized Queries Can Be Slow
Imagine an e-commerce dashboard. Your data is perfectly normalized across four tables — orders, customers, products, and order items. But every time someone opens the dashboard, the database runs a four-table JOIN across a hundred thousand rows. The page takes seconds to load. Normalization is correct, but slow.


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Normalized Queries Can Be Slow
Imagine an e-commerce dashboard. Your data is perfectly normalized across four tables — orders, customers, products, and order items. But every time someone opens the dashboard, the database runs a four-table JOIN across a hundred thousand rows. The page takes seconds to load. Normalization is correct, but slow.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Scenario** | An e-commerce dashboard showing orders with customer names, product names, and totals |
| **Normalized Design** | Data split across 4 tables: orders, customers, products, order_items |
| **Dashboard Query** | Every page load needs a 4-table JOIN just to show basic info |
| **Result** | 100,000 orders × 4 JOINs = slow page load for users |

### What Is Denormalization?
Think of normalization versus denormalization like a supermarket warehouse versus the express checkout counter! ... The warehouse organizes every product neatly into separate aisles (normalized—zero duplicates). The express counter puts best-selling batteries right beside the register for fast grabs (denormalized—a smart shortcut on purpose!). ... Denormalization means intentionally copying a little data for read speed, ONLY AFTER you build a clean normalized foundation.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Definition** | Intentionally adding redundancy back into tables to speed up reads |
| **Key Word** | INTENTIONALLY — you know the rules, you break them on purpose |
| **Trade-off** | Faster reads, but harder writes (must update multiple places) |
| **When** | Read-heavy workloads where JOIN performance is a bottleneck |

### When to Denormalize — Decision Framework
So when should you actually denormalize versus keep tables cleanly normalized? Use this quick checklist before adding duplicate columns. ... If one hot screen repeats the same customer name JOIN millions of times, copying customer_name can help. ... If executive dashboards run heavy SUM or COUNT queries, use a daily summary table or even safer—a Materialized View! ... When NOT to denormalize: if your app is write-heavy or your tables have under a hundred thousand rows, regular indexed JOINs are already milliseconds fast.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Redundant Cols** | Copy 1–2 heavily joined fields onto huge read-hot tables |
| **Summary Tables** | Pre-compute daily/monthly revenue totals instead of scanning rows |
| **Mat. Views** | Safest option — fast snapshots while base tables stay 3NF clean |
| **Stay 3NF When** | Write-heavy OLTP apps or small/medium datasets (<100K rows) |

### Normalization vs Denormalization Trade-offs
Here's the full picture. Normalized is the default — no redundancy, clean operations, smaller storage, but needs JOINs. Denormalized is strategic — faster reads, fewer JOINs, but updates are harder and storage is larger. OLTP systems that process many small transactions stay normalized. OLAP systems that run big analytical queries denormalize. Most real applications use both — normalized core tables with denormalized views for dashboards.

| Normalized (Default) | Denormalized (Strategic) |
| :--- | :--- |
| No redundancy | Redundant data added |
| Clean INSERT, UPDATE, DELETE | Updates touch multiple places |
| Smaller storage | Larger storage |
| Needs JOINs for queries | Fewer JOINs, faster reads |
| Best for write-heavy (OLTP) | Best for read-heavy (OLAP) |


---

## 3. Hands-On Commands & psql Output

### The Slow Normalized Query (4 JOINs)
**Explanation:** Here's what the normalized query looks like. Four tables joined together just to show basic order information. With a hundred thousand orders, this runs every single time someone opens the dashboard page. Customers, order items, products — all joined on the fly. It works, but it's slow.

```sql
-- Dashboard needs: order info + customer + products
-- Normalized: 4-table JOIN every time

SELECT o.id AS order_id,
       c.name AS customer,
       c.city,
       p.name AS product,
       oi.qty,
       oi.qty * p.price AS line_total,
       o.order_date
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
ORDER BY o.order_date DESC
LIMIT 50;

-- With 100K orders → this runs every page load!
```

### Strategy 1: Add Redundant Columns
**Explanation:** Strategy one — add redundant columns. We store the customer name directly in the orders table. Now the dashboard query doesn't need a JOIN to the customers table at all. The trade-off? If a customer changes their name, you must update it in both the customers table AND the orders table. That's the cost of denormalization.

```sql
-- Store customer_name directly in orders table
ALTER TABLE orders
  ADD COLUMN customer_name VARCHAR(100);

-- Fill it from the customers table
UPDATE orders o
SET customer_name = c.name
FROM customers c
WHERE o.customer_id = c.id;

-- Now: simple query, no JOIN needed
SELECT id, customer_name, order_date
FROM orders
ORDER BY order_date DESC LIMIT 50;

-- Trade-off: if customer renames,
-- must update BOTH tables!
```

### Strategy 2: Summary / Aggregate Table
**Explanation:** Strategy two — summary tables. Instead of computing daily sales totals every time, we pre-compute them into a dedicated table. The dashboard reads from this summary table — instant results. But you need to keep this table updated whenever new orders come in. You can update it with a trigger, a scheduled job, or by refreshing it periodically.

```sql
-- Pre-compute daily sales totals
CREATE TABLE daily_sales (
    sale_date   DATE PRIMARY KEY,
    total_orders INT,
    total_revenue NUMERIC(12,2)
);

-- Populate from normalized tables
INSERT INTO daily_sales
SELECT o.order_date,
       COUNT(*),
       SUM(oi.qty * p.price)
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
GROUP BY o.order_date;

-- Dashboard reads this — instant!
SELECT * FROM daily_sales
ORDER BY sale_date DESC LIMIT 30;
```

### Strategy 3: Materialized View (Best of Both)
**Explanation:** Strategy three — materialized views. This is the best of both worlds. A materialized view stores the result of a complex query as a physical table. Your dashboard reads from it — fast, no JOINs. But unlike a regular denormalized table, the original normalized data stays untouched. You just refresh the view when you need updated data.

```sql
-- Materialized view = cached query result
CREATE MATERIALIZED VIEW mv_order_dashboard AS
SELECT o.id AS order_id,
       c.name AS customer,
       c.city,
       p.name AS product,
       oi.qty,
       oi.qty * p.price AS line_total,
       o.order_date
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id;

-- Query the view — reads cached data!
SELECT * FROM mv_order_dashboard
ORDER BY order_date DESC LIMIT 50;
```

### Refreshing Materialized Views
**Explanation:** To update a materialized view with fresh order numbers, run REFRESH MATERIALIZED VIEW. ... Here is the beginner trap: plain REFRESH grabs an exclusive table lock, freezing your live dashboard for every user until it finishes! ... Instead, add one UNIQUE index on the view first, then run REFRESH MATERIALIZED VIEW CONCURRENTLY. PostgreSQL quietly builds the updated snapshot behind the scenes while customers keep reading nonstop.

```sql
-- Refresh: re-runs the query, updates stored data
REFRESH MATERIALIZED VIEW mv_order_dashboard;

-- Problem: REFRESH locks the view (reads blocked)

-- Solution: CONCURRENTLY (no lock, needs unique index)
CREATE UNIQUE INDEX idx_mv_order_id
  ON mv_order_dashboard (order_id, product);

REFRESH MATERIALIZED VIEW CONCURRENTLY
  mv_order_dashboard;
-- Reads continue while refresh happens!

-- Check when it was last refreshed:
SELECT relname, last_refresh
FROM pg_catalog.pg_matviews
CROSS JOIN LATERAL (
  SELECT pg_stat_get_last_analyze_time(oid)
) AS t(last_refresh)
WHERE schemaname = 'public';
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Time to practice. First, create four normalized tables with sample data. Write a four-table JOIN for a dashboard. Then create a materialized view from it, add a unique index, and refresh it concurrently. Compare the speed of querying base tables versus the view. Finally, create a summary table for daily sales. All the SQL is in your downloadable class materials.

1. Create 4 normalized tables: customers, products, orders, order_items with sample data
2. Write a 4-table JOIN query for a dashboard view
3. CREATE MATERIALIZED VIEW from that JOIN query
4. Add a UNIQUE INDEX on the materialized view
5. REFRESH MATERIALIZED VIEW CONCURRENTLY
6. Compare query speed: SELECT from base tables vs materialized view
7. Create a daily_sales summary table and populate it


---

## 7. Key Takeaways & Cheat Sheet

Let's recap. Denormalization means intentionally adding redundancy to speed up reads. Your three strategies are redundant columns, summary tables, and materialized views. Materialized views are the safest because the original normalized data stays clean. Always start normalized and denormalize only when JOINs are proven slow. Most real applications use normalized core tables with denormalized views for dashboards and reports.

- **Denormalization = intentionally adding redundancy for read speed**
- **Three strategies: redundant columns, summary tables, materialized views**
- **Materialized views are the safest — original data stays normalized**
- **REFRESH CONCURRENTLY avoids locking reads during updates**
- **Stay normalized by default — denormalize only when JOINs are proven slow**
- **Most real apps: normalized core + denormalized views for dashboards**


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
