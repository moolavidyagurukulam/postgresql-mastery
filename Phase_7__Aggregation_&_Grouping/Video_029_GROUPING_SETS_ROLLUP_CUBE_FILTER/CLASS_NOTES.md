# GROUPING SETS, ROLLUP, CUBE & FILTER
**Series:** PostgreSQL Mastery | **Phase:** Phase 7: Aggregation & Grouping | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn advanced grouping — GROUPING SETS for custom grouping combinations, ROLLUP for hierarchical subtotals, CUBE for all possible combinations, and the FILTER clause for conditional aggregation. These turn PostgreSQL into a reporting powerhouse.

### The Problem: Multiple Groupings in One Report
Imagine you are building a sales report. Your boss wants: sales by department, sales by region, sales by department AND region, AND a grand total — all in ONE result. Without advanced grouping, you would need four separate queries UNIONed together. With GROUPING SETS, you do it in a single, clean query. ROLLUP adds subtotals automatically. CUBE gives you every possible combination. Let us see how.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should know COUNT, SUM, AVG, GROUP BY, and HAVING — all covered in the previous class on Aggregation. In that class, GROUP BY gave us one summary per group. But what if you want subtotals? What if you need a grand total row at the bottom? What if you want to group by department AND by region AND by both together — all in one query? That is what GROUPING SETS, ROLLUP, and CUBE solve.

- You know COUNT, SUM, AVG, MIN, MAX
- You know GROUP BY and HAVING
- Previous class: one summary per group
- Problem: subtotals, grand totals, multiple groupings
- Solution: GROUPING SETS, ROLLUP, CUBE
- Bonus: FILTER clause replaces CASE WHEN in aggregates

### The Problem: Multiple Groupings in One Report
Imagine you are building a sales report. Your boss wants: sales by department, sales by region, sales by department AND region, AND a grand total — all in ONE result. Without advanced grouping, you would need four separate queries UNIONed together. With GROUPING SETS, you do it in a single, clean query. ROLLUP adds subtotals automatically. CUBE gives you every possible combination. Let us see how.

| Term | Meaning / Explanation |
| :--- | :--- |
| **GROUPING SETS** | Specify EXACTLY which groupings you want |
| **ROLLUP** | Hierarchical subtotals — like a drill-down report |
| **CUBE** | ALL possible combinations — like a pivot table |
| **FILTER** | Conditional aggregation without CASE WHEN |

### GROUPING SETS vs ROLLUP vs CUBE — Comparison
Let us compare all three side by side so you can see exactly which groupings each one produces. GROUPING SETS lets you pick exactly what you want. ROLLUP peels columns from right to left — great for drill-down reports. CUBE gives every combination — great for pivot tables. Column order in ROLLUP matters because it peels from the right. In CUBE, order does not matter.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Let us compare all three side by side so you can see exactly which groupings each one produces |
| **Point 2** | GROUPING SETS lets you pick exactly what you want |
| **ROLLUP peels columns from right to left** | great for drill-down reports |
| **CUBE gives every combination** | great for pivot tables |
| **Point 5** | Column order in ROLLUP matters because it peels from the right |
| **Point 6** | In CUBE, order does not matter |

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. You can download today's class materials and practice files from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Every bit helps us keep creating. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### FILTER vs CASE WHEN — Conditional Aggregation
Now the FILTER clause — a cleaner way to do conditional aggregation. In the Aggregation class, we used CASE WHEN inside SUM or COUNT. FILTER is the modern PostgreSQL way. Instead of SUM CASE WHEN is_online THEN revenue ELSE zero END, you write SUM revenue FILTER WHERE is_online. Same result, much cleaner. FILTER was added in PostgreSQL 9.4 and works in PG 16.

| Old Way: CASE WHEN | Modern: FILTER |
| :--- | :--- |
| SUM(CASE WHEN is_online | SUM(revenue) |
|     THEN revenue ELSE 0 END) |   FILTER (WHERE is_online) |
| AS online_revenue | AS online_revenue |
|  |  |
| COUNT(CASE WHEN region='North' | COUNT(*) |
|     THEN 1 END) |   FILTER (WHERE region='North') |
| AS north_count | AS north_count |

### When to Use Each Grouping Feature
When should you use which? Use regular GROUP BY for simple per-category summaries. Use GROUPING SETS when you need a few specific groupings in one query. Use ROLLUP for hierarchical reports with subtotals — department then region then grand total. Use CUBE for full cross-tab analysis — every combination. Use FILTER for conditional counts and sums within a group. Avoid CUBE on more than three or four columns — the number of combinations explodes exponentially.

| Use This | Watch Out |
| :--- | :--- |
| GROUP BY: simple per-category summary | CUBE on 4+ columns = huge results |
| GROUPING SETS: specific custom groupings | CUBE(A,B,C,D) = 16 groupings |
| ROLLUP: hierarchical drill-down reports | CUBE(A,B,C,D,E) = 32 groupings |
| CUBE: full pivot tables (2-3 columns max) | NULL in results = subtotal (use GROUPING()) |
| FILTER: conditional aggregation (clean syntax) | FILTER not available before PG 9.4 |

### Practice Exercises
Practice time! Exercise one: write a GROUPING SETS query with department, quarter, and grand total. Exercise two: ROLLUP with department and region to get subtotals. Exercise three: CUBE for all combinations. Exercise four: use GROUPING function to label subtotal rows. Exercise five: FILTER to count online versus offline sales. Try these on your own!

- 1. GROUPING SETS: by department, by quarter, grand total
- 2. ROLLUP(department, region): drill-down with subtotals
- 3. CUBE(department, region): full cross-tab
- 4. GROUPING() labels: replace NULL with 'ALL' in subtotal rows
- 5. FILTER: online_revenue vs offline_revenue per department
- 6. FILTER with COUNT: active vs inactive staff per department
- 7. ROLLUP with 3 levels: department, region, quarter


---

## 3. Hands-On Commands & psql Output

### Setup: Sales Data by Department and Region
**Explanation:** Let us set up a sales table with department, region, and revenue data. This gives us a nice dataset to demonstrate all the grouping features.

```sql
practice=# CREATE TABLE sales (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department VARCHAR(50),
    region     VARCHAR(50),
    quarter    VARCHAR(10),
    revenue    NUMERIC(12,2),
    is_online  BOOLEAN DEFAULT false
);
CREATE TABLE

practice=# INSERT INTO sales (department,region,quarter,revenue,is_online) VALUES
('Electronics','North','Q1',50000,true),
('Electronics','North','Q2',65000,false),
('Electronics','South','Q1',45000,true),
('Electronics','South','Q2',55000,false),
('Clothing','North','Q1',30000,false),
('Clothing','North','Q2',40000,true),
('Clothing','South','Q1',25000,false),
('Clothing','South','Q2',35000,true);
INSERT 0 8
```

### The Problem: Multiple Groupings Need Multiple Queries
**Explanation:** First, let us understand the problem. With regular GROUP BY, we can group by department OR by region — but not both groupings in the same query. Watch: GROUP BY department gives two rows. GROUP BY region gives two rows. But what if we want BOTH groupings AND a grand total — all in one result? We would have to UNION ALL three separate queries. That is ugly and slow. GROUPING SETS does this in one shot.

```sql
-- Grouping 1: by department
practice=# SELECT department, SUM(revenue) FROM sales GROUP BY department;
 department  |   sum
-------------+---------
 Electronics | 215000.00
 Clothing    | 130000.00

-- Grouping 2: by region
practice=# SELECT region, SUM(revenue) FROM sales GROUP BY region;
 region |   sum
--------+---------
 North  | 185000.00
 South  | 160000.00

-- Grouping 3: grand total
practice=# SELECT SUM(revenue) AS grand_total FROM sales;
 grand_total
-------------
   345000.00

-- Three queries! GROUPING SETS does all three in ONE.
```

### GROUPING SETS — Multiple Groupings in One Query
**Explanation:** GROUPING SETS lets you specify EXACTLY which groupings you want. Each set in the parentheses becomes a separate grouping. An empty set means the grand total. NULL appears in columns that are not part of that particular grouping level. So department shows NULL for the region-only and grand total rows. Region shows NULL for the department-only and grand total rows.

```sql
-- Three groupings in ONE query
practice=# SELECT department, region, SUM(revenue) AS total
FROM sales
GROUP BY GROUPING SETS (
  (department),     -- group by department
  (region),         -- group by region
  ()                -- grand total
)
ORDER BY department NULLS LAST, region NULLS LAST;
 department  | region |   total
-------------+--------+-----------
 Clothing    |        | 130000.00
 Electronics |        | 215000.00
             | North  | 185000.00
             | South  | 160000.00
             |        | 345000.00
(5 rows)

-- NULL = 'all values' for that column's grouping level
```

### ROLLUP — Hierarchical Subtotals
**Explanation:** ROLLUP is a shortcut for hierarchical subtotals. ROLLUP of department and region generates three groupings automatically: department plus region, then department alone, then the grand total. Think of it like drilling down in a spreadsheet — total, then department subtotals, then the detail. It removes one column from the right at each level. ROLLUP of A, B, C gives: A-B-C, A-B, A, and grand total.

```sql
-- ROLLUP: automatic subtotals from right to left
practice=# SELECT department, region, SUM(revenue) AS total
FROM sales
GROUP BY ROLLUP (department, region)
ORDER BY department NULLS LAST, region NULLS LAST;
 department  | region |   total
-------------+--------+-----------
 Clothing    | North  |  70000.00
 Clothing    | South  |  60000.00
 Clothing    |        | 130000.00
 Electronics | North  | 115000.00
 Electronics | South  | 100000.00
 Electronics |        | 215000.00
             |        | 345000.00
(7 rows)

-- ROLLUP(dept, region) generates:
--   (dept, region), (dept), () — 3 levels
```

### CUBE — All Possible Combinations
**Explanation:** CUBE goes further than ROLLUP — it generates ALL possible grouping combinations. CUBE of department and region gives FOUR groupings: department plus region, department alone, region alone, AND the grand total. ROLLUP only does three — it skips the 'region alone' grouping. Use CUBE when you need a full cross-tab report, like a pivot table in a spreadsheet.

```sql
-- CUBE: ALL grouping combinations
practice=# SELECT department, region, SUM(revenue) AS total
FROM sales
GROUP BY CUBE (department, region)
ORDER BY department NULLS LAST, region NULLS LAST;
 department  | region |   total
-------------+--------+-----------
 Clothing    | North  |  70000.00
 Clothing    | South  |  60000.00
 Clothing    |        | 130000.00
 Electronics | North  | 115000.00
 Electronics | South  | 100000.00
 Electronics |        | 215000.00
             | North  | 185000.00
             | South  | 160000.00
             |        | 345000.00
(9 rows)

-- CUBE(dept, region) generates:
--   (dept,region), (dept), (region), () — 4 levels
```

### GROUPING() — Identify Subtotal Rows
**Explanation:** The problem with ROLLUP and CUBE: NULL in the result means 'all values for this column' — a subtotal or grand total row. But what if your actual data has NULLs? How do you tell the difference between a real NULL and a subtotal NULL? That is what the GROUPING function solves. GROUPING returns one for a subtotal NULL and zero for a real data value. Use it to label your subtotal rows.

```sql
-- GROUPING() returns 1 for subtotal NULLs, 0 for real data
practice=# SELECT
  CASE WHEN GROUPING(department) = 1 THEN 'ALL DEPTS'
       ELSE department END AS department,
  CASE WHEN GROUPING(region) = 1 THEN 'ALL REGIONS'
       ELSE region END AS region,
  SUM(revenue) AS total
FROM sales
GROUP BY ROLLUP (department, region)
ORDER BY GROUPING(department), department, GROUPING(region), region;
 department  |   region    |   total
-------------+-------------+-----------
 Clothing    | North       |  70000.00
 Clothing    | South       |  60000.00
 Clothing    | ALL REGIONS | 130000.00
 Electronics | North       | 115000.00
 Electronics | South       | 100000.00
 Electronics | ALL REGIONS | 215000.00
 ALL DEPTS   | ALL REGIONS | 345000.00
(7 rows)
```

### FILTER Clause — Multiple Conditional Aggregates
**Explanation:** Let us see FILTER in action. We can compute multiple conditional aggregates in a single query — online revenue, offline revenue, north revenue, south revenue — all in one pass over the data. Each FILTER clause works independently. This is much more readable than nested CASE WHEN expressions.

```sql
-- FILTER: conditional aggregation per column
practice=# SELECT department,
  SUM(revenue) AS total,
  SUM(revenue) FILTER (WHERE is_online)    AS online_rev,
  SUM(revenue) FILTER (WHERE NOT is_online) AS offline_rev,
  COUNT(*) FILTER (WHERE region = 'North')  AS north_sales,
  COUNT(*) FILTER (WHERE region = 'South')  AS south_sales
FROM sales
GROUP BY department;
 department  |   total   | online_rev | offline_rev | north_sales | south_sales
-------------+-----------+------------+-------------+-------------+-------------
 Clothing    | 130000.00 |   75000.00 |    55000.00 |           2 |           2
 Electronics | 215000.00 |   95000.00 |   120000.00 |           2 |           2
(2 rows)
```

### FILTER with COUNT, AVG, MIN, MAX
**Explanation:** FILTER also works with COUNT DISTINCT, AVG, MIN, MAX — any aggregate function. Here is a practical example: counting active versus inactive employees and averaging their salaries, all in one query without any CASE WHEN.

```sql
-- Create a quick employees table for FILTER demo
practice=# CREATE TABLE staff (
    name VARCHAR(50), department VARCHAR(50),
    salary NUMERIC(10,2), is_active BOOLEAN);
CREATE TABLE
practice=# INSERT INTO staff VALUES
('Ravi','Eng',95000,true),('Priya','Eng',88000,true),
('Vikram','Eng',92000,false),('Sonia','HR',82000,true),
('Anita','Mktg',75000,false),('Arjun','Mktg',72000,true);
INSERT 0 6

practice=# SELECT
  COUNT(*) FILTER (WHERE is_active) AS active,
  COUNT(*) FILTER (WHERE NOT is_active) AS inactive,
  ROUND(AVG(salary) FILTER (WHERE is_active),2) AS active_avg,
  ROUND(AVG(salary) FILTER (WHERE NOT is_active),2) AS inactive_avg
FROM staff;
 active | inactive | active_avg | inactive_avg
--------+----------+------------+--------------
      4 |        2 |   84250.00 |     83500.00
(1 row)
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. GROUPING SETS lets you specify exactly which groupings to compute — mix and match as needed. ROLLUP generates hierarchical subtotals by peeling columns from right to left — perfect for drill-down reports. CUBE generates ALL possible combinations — like a pivot table. Use the GROUPING function to distinguish subtotal NULLs from real NULLs. FILTER is the modern way to do conditional aggregation — much cleaner than CASE WHEN inside an aggregate. In the next class, we move to Subqueries and CTEs — queries inside queries. See you there!

- **GROUPING SETS: custom list of groupings in one query**
- **ROLLUP(A,B): (A,B), (A), () — hierarchical subtotals**
- **CUBE(A,B): (A,B), (A), (B), () — all combinations**
- **GROUPING(col): 1 = subtotal NULL, 0 = real data**
- **FILTER (WHERE cond): conditional aggregation per column**
- **FILTER replaces CASE WHEN inside aggregates — cleaner**
- **Avoid CUBE on 4+ columns — exponential growth**
- **NULL in results = subtotal row (use GROUPING to label)**


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
