# Window Functions Part 2 — LAG, LEAD, Running Totals & Frames
**Series:** PostgreSQL Mastery | **Phase:** Phase 10: Advanced SQL | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we continue window functions with LAG and LEAD — accessing previous and next rows — FIRST_VALUE and LAST_VALUE, running totals with SUM OVER, moving averages, and frame clauses which control exactly WHICH rows the function sees. These are the tools that make time-series analysis and reporting queries elegant. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Frame Clauses — Which Rows to Include
The frame clause is the most advanced part of window functions. It defines EXACTLY which rows the window function considers for each row. The default frame when you have ORDER BY is RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW — from the start of the partition to the current row. You can change this to ROWS BETWEEN to get a fixed-size sliding window. For example, ROWS BETWEEN 2 PRECEDING AND CURRENT ROW gives you a three-row moving average.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Default (with ORDER BY)** | RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW |
| **ROWS** | Physical row count (exact number of rows) |
| **RANGE** | Logical value range (groups ties together) |
| **UNBOUNDED PRECEDING** | Start of the partition |
| **CURRENT ROW** | The current row |
| **N PRECEDING** | N rows before current |
| **UNBOUNDED FOLLOWING** | End of the partition |

**Notes:**
- ROWS BETWEEN 2 PRECEDING AND CURRENT ROW = 3-row window

### Frame Clause Quick Reference
Here is a quick reference for all frame clause options. The most common are UNBOUNDED PRECEDING to CURRENT ROW for running totals, N PRECEDING to CURRENT ROW for moving averages, and UNBOUNDED PRECEDING to UNBOUNDED FOLLOWING for the whole partition. Remember: the default frame with ORDER BY is from the start to the current row, which is perfect for running totals but wrong for LAST_VALUE.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Here** | a quick reference for all frame clause options |
| **The most common** | UNBOUNDED PRECEDING to CURRENT ROW for running totals, N PRECEDING to CURRENT ROW for moving averages, and UNBOUNDED ... |
| **ORDER BY** | from the start to the current row, which is perfect for running totals but wrong for LAST_VALUE |

### Practice Exercises
Practice exercises: use LAG for month-over-month comparison, LEAD for lookahead, SUM OVER for running totals, AVG with a frame for moving averages, and combine multiple window functions in a single query. Try named windows to keep your code clean.

- 1. LAG(revenue) — previous month comparison
- 2. LEAD(revenue) — next month preview
- 3. SUM(revenue) OVER(ORDER BY month) — running total
- 4. AVG with ROWS BETWEEN 2 PRECEDING — moving average
- 5. FIRST_VALUE and LAST_VALUE (with full frame!)
- 6. Combine LAG + SUM + AVG in one query
- 7. Use WINDOW w AS (...) for named windows


---

## 3. Hands-On Commands & psql Output

### Setup — Monthly Sales Data
**Explanation:** From the previous class, you know OVER, PARTITION BY, ORDER BY, and ranking functions. Now we learn value functions — LAG and LEAD let you peek at other rows. And aggregate window functions — SUM, AVG, COUNT with OVER give you running totals and moving averages. The frame clause controls the window of rows the aggregate sees — from the start of the partition to the current row, or a sliding window of the last three rows. Let us set up a monthly sales table.

```sql
CREATE TABLE monthly_sales (
    month    DATE,
    product  VARCHAR(50),
    revenue  NUMERIC(10,2)
);

INSERT INTO monthly_sales VALUES
('2024-01-01', 'Widget', 10000),
('2024-02-01', 'Widget', 12000),
('2024-03-01', 'Widget', 11500),
('2024-04-01', 'Widget', 14000),
('2024-05-01', 'Widget', 13000),
('2024-06-01', 'Widget', 15500),
('2024-01-01', 'Gadget',  8000),
('2024-02-01', 'Gadget',  8500),
('2024-03-01', 'Gadget',  9200),
('2024-04-01', 'Gadget', 10000),
('2024-05-01', 'Gadget', 11000),
('2024-06-01', 'Gadget', 12500);
```

### LAG and LEAD — Access Previous/Next Row
**Explanation:** LAG looks at a previous row. LEAD looks at a next row. Both take three arguments: the column to look at, how many rows back or forward — default is one — and a default value if there is no previous or next row. These are incredibly useful for comparing current values to previous periods — month over month, year over year, or calculating differences between consecutive rows.

```sql
-- Compare each month to the previous month
practice=# SELECT month, product, revenue,
  LAG(revenue) OVER(PARTITION BY product ORDER BY month) AS prev_month,
  revenue - LAG(revenue) OVER(PARTITION BY product ORDER BY month)
    AS change
FROM monthly_sales WHERE product = 'Widget';
   month    | product | revenue | prev_month | change
------------+---------+---------+------------+--------
 2024-01-01 | Widget  | 10000   |     NULL   |  NULL
 2024-02-01 | Widget  | 12000   |    10000   |  2000
 2024-03-01 | Widget  | 11500   |    12000   |  -500
 2024-04-01 | Widget  | 14000   |    11500   |  2500
 2024-05-01 | Widget  | 13000   |    14000   | -1000
 2024-06-01 | Widget  | 15500   |    13000   |  2500

-- LAG(revenue, 1, 0) → default 0 instead of NULL
-- LEAD(revenue) → looks at NEXT row instead
```

### FIRST_VALUE and LAST_VALUE
**Explanation:** FIRST_VALUE and LAST_VALUE return the first or last value in the window. FIRST_VALUE is straightforward — it gives you the first row's value in the partition. LAST_VALUE has a gotcha — by default the frame goes from the start to the current row, NOT the end of the partition. To get the actual last value, you need to set the frame to ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING. We will cover frames in detail shortly.

```sql
-- First month's revenue alongside every row
practice=# SELECT month, product, revenue,
  FIRST_VALUE(revenue) OVER(
    PARTITION BY product ORDER BY month
  ) AS first_month_rev
FROM monthly_sales WHERE product = 'Widget';
   month    | revenue | first_month_rev
------------+---------+-----------------
 2024-01-01 |  10000  |          10000
 2024-02-01 |  12000  |          10000
 2024-03-01 |  11500  |          10000
 ...

-- LAST_VALUE needs frame clause to see whole partition!
-- LAST_VALUE(revenue) OVER(... ROWS BETWEEN
--   UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
```

### Running Total with SUM OVER
**Explanation:** Running totals are one of the most common uses of window functions. SUM with OVER and ORDER BY gives you a cumulative sum — each row shows the total up to that point. Without ORDER BY inside OVER, SUM gives the grand total on every row. With ORDER BY, it accumulates row by row. The same works for COUNT and AVG — running count, running average.

```sql
-- Running total of revenue by product
practice=# SELECT month, product, revenue,
  SUM(revenue) OVER(
    PARTITION BY product ORDER BY month
  ) AS running_total
FROM monthly_sales WHERE product = 'Widget';
   month    | revenue | running_total
------------+---------+---------------
 2024-01-01 |  10000  |        10000
 2024-02-01 |  12000  |        22000
 2024-03-01 |  11500  |        33500
 2024-04-01 |  14000  |        47500
 2024-05-01 |  13000  |        60500
 2024-06-01 |  15500  |        76000

-- Each row = sum of all rows up to this point
-- ORDER BY makes it cumulative
```

### Moving Average with Frame Clause
**Explanation:** A three-month moving average is a classic use of frame clauses. For each row, we average the current month and the two preceding months. The first row only has itself. The second row averages two values. From the third row onward, we get a true three-month average. This is how analysts smooth out noisy data to see trends.

```sql
-- 3-month moving average
practice=# SELECT month, revenue,
  ROUND(AVG(revenue) OVER(
    ORDER BY month
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ), 2) AS moving_avg_3m
FROM monthly_sales WHERE product = 'Widget';
   month    | revenue | moving_avg_3m
------------+---------+---------------
 2024-01-01 |  10000  |     10000.00  ← only 1 row
 2024-02-01 |  12000  |     11000.00  ← avg of 2
 2024-03-01 |  11500  |     11166.67  ← avg of 3
 2024-04-01 |  14000  |     12500.00
 2024-05-01 |  13000  |     12833.33
 2024-06-01 |  15500  |     14166.67

-- ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
-- = current row + 2 rows before = 3-row window
```

### Combining Multiple Window Functions
**Explanation:** You can combine multiple window functions in a single query. Here we calculate the running total, month-over-month change, and moving average all at once. Named windows help keep the query clean — define the window once with the WINDOW keyword and reference it by name. This avoids repeating the same PARTITION BY and ORDER BY in every function.

```sql
-- Multiple window functions in one query
practice=# SELECT month, product, revenue,
  SUM(revenue) OVER w AS running_total,
  LAG(revenue) OVER w AS prev_month,
  revenue - LAG(revenue) OVER w AS change,
  ROUND(AVG(revenue) OVER(
    PARTITION BY product ORDER BY month
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ), 0) AS moving_avg
FROM monthly_sales
WINDOW w AS (PARTITION BY product ORDER BY month)
ORDER BY product, month;

-- Named window 'w' reused for SUM, LAG, and change
-- Moving avg has its own frame clause
```


---

## 6. Hands-On Practice Exercises & Verified Answer Key

### Practice Challenges

1. **Month-over-Month Change:** Use `LAG(revenue)` to compute both the previous month's revenue and the net change for `product = 'Widget'`.
2. **Cumulative Running Total:** Calculate the running revenue total for `product = 'Gadget'` using `SUM(revenue) OVER(ORDER BY month)`.
3. **3-Month Rolling Average:** Build a moving average over a 3-month window using `AVG(revenue) OVER(ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)`.
4. **Window Boundaries with LAST_VALUE:** Explain and demonstrate why `LAST_VALUE(revenue)` requires `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` to see the actual end of the dataset.
5. **Percentage Growth Calculation:** Calculate month-over-month percentage growth formatted to 1 decimal place using `LAG()`.

---

### Verified Solutions & Explanations

#### Exercise 1: Month-over-Month Net Change
```sql
SELECT month, revenue,
  LAG(revenue) OVER(ORDER BY month) AS prev_rev,
  revenue - LAG(revenue) OVER(ORDER BY month) AS mom_change
FROM monthly_sales
WHERE product = 'Widget';
```
*Explanation:* `LAG(column, offset)` accesses the row preceding the current row in the sort order. For the first row, `LAG()` returns `NULL`.

#### Exercise 2: Cumulative Running Total
```sql
SELECT month, revenue,
  SUM(revenue) OVER(ORDER BY month) AS running_total
FROM monthly_sales
WHERE product = 'Gadget';
```
*Explanation:* When `ORDER BY` is specified inside `OVER()` without an explicit frame clause, PostgreSQL defaults to `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`, naturally computing a running total.

#### Exercise 3: 3-Month Moving Average
```sql
SELECT month, revenue,
  ROUND(AVG(revenue) OVER(
    ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ), 2) AS ma_3
FROM monthly_sales
WHERE product = 'Widget';
```
*Explanation:* `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` creates a physical window of 3 rows: the current month and the two previous months.

#### Exercise 4: FIRST_VALUE & LAST_VALUE with Full Window Frame
```sql
SELECT month, revenue,
  FIRST_VALUE(revenue) OVER(ORDER BY month) AS first_val,
  LAST_VALUE(revenue) OVER(
    ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS last_val
FROM monthly_sales
WHERE product = 'Widget';
```
*Explanation:* By default, the window frame terminates at `CURRENT ROW`. Without `UNBOUNDED FOLLOWING`, `LAST_VALUE()` will simply return the current row's value rather than the last row in the partition.

#### Exercise 5: Percentage Growth Rate
```sql
SELECT month, revenue,
  ROUND((revenue - LAG(revenue) OVER(ORDER BY month)) * 100.0
    / NULLIF(LAG(revenue) OVER(ORDER BY month), 0), 1) AS pct_growth
FROM monthly_sales
WHERE product = 'Gadget';
```
*Explanation:* Computes relative growth percentage. `NULLIF` prevents division by zero if a prior month had zero revenue.


## 7. Key Takeaways & Cheat Sheet

Let us recap. LAG looks back at previous rows; LEAD looks ahead. FIRST_VALUE and LAST_VALUE access partition boundaries — but LAST_VALUE needs the full frame. SUM, AVG, COUNT with OVER and ORDER BY give running aggregates. Frame clauses control which rows the function sees: ROWS for physical count, RANGE for logical grouping. Named windows with WINDOW avoid repetition. Window functions are the foundation of modern analytical SQL. In the next class, we cover String, Date, and Math functions. See you there!

- **LAG(col, n, default): value from n rows back**
- **LEAD(col, n, default): value from n rows ahead**
- **FIRST_VALUE/LAST_VALUE: first/last in window**
- **LAST_VALUE needs ROWS BETWEEN ... UNBOUNDED FOLLOWING**
- **SUM OVER(ORDER BY): running total (cumulative)**
- **ROWS BETWEEN N PRECEDING AND CURRENT ROW: moving window**
- **Default frame with ORDER BY: start → current row**
- **WINDOW w AS (...): named window for reuse**


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
