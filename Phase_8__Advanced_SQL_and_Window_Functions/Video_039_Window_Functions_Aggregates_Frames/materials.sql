-- =============================================
-- PostgreSQL Mastery: Window Functions Part 2
-- Phase 10: Advanced SQL | Classes 78-79
-- =============================================
-- LAG, LEAD, FIRST_VALUE, LAST_VALUE, running
-- totals, moving averages, and frame clauses.
-- =============================================

-- === SETUP ===

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

-- === LAG — Look at Previous Row ===

-- Previous month revenue
SELECT month, product, revenue,
  LAG(revenue) OVER(PARTITION BY product ORDER BY month) AS prev_month
FROM monthly_sales;

-- Month-over-month change
SELECT month, product, revenue,
  LAG(revenue) OVER(PARTITION BY product ORDER BY month) AS prev,
  revenue - LAG(revenue) OVER(PARTITION BY product ORDER BY month) AS change
FROM monthly_sales;

-- LAG with offset and default
-- LAG(column, offset, default_value)
SELECT month, revenue,
  LAG(revenue, 1, 0) OVER(ORDER BY month) AS prev_1,  -- 1 month back, default 0
  LAG(revenue, 2, 0) OVER(ORDER BY month) AS prev_2   -- 2 months back, default 0
FROM monthly_sales WHERE product = 'Widget';

-- Percentage change
SELECT month, revenue,
  LAG(revenue) OVER(ORDER BY month) AS prev,
  ROUND((revenue - LAG(revenue) OVER(ORDER BY month)) * 100.0
    / LAG(revenue) OVER(ORDER BY month), 1) AS pct_change
FROM monthly_sales WHERE product = 'Widget';

-- === LEAD — Look at Next Row ===

-- Next month revenue
SELECT month, product, revenue,
  LEAD(revenue) OVER(PARTITION BY product ORDER BY month) AS next_month
FROM monthly_sales;

-- LEAD with offset and default
SELECT month, revenue,
  LEAD(revenue, 1, 0) OVER(ORDER BY month) AS next_1
FROM monthly_sales WHERE product = 'Widget';

-- === FIRST_VALUE and LAST_VALUE ===

-- First month revenue in each product
SELECT month, product, revenue,
  FIRST_VALUE(revenue) OVER(
    PARTITION BY product ORDER BY month
  ) AS first_month_rev,
  revenue - FIRST_VALUE(revenue) OVER(
    PARTITION BY product ORDER BY month
  ) AS growth_from_start
FROM monthly_sales;

-- LAST_VALUE — needs full frame!
-- Default frame is start → current row, NOT start → end
SELECT month, product, revenue,
  LAST_VALUE(revenue) OVER(
    PARTITION BY product ORDER BY month
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS last_month_rev
FROM monthly_sales;

-- Without full frame: LAST_VALUE = current row (useless!)
-- With full frame: LAST_VALUE = last row in partition

-- NTH_VALUE — get Nth row value
SELECT month, revenue,
  NTH_VALUE(revenue, 3) OVER(
    PARTITION BY product ORDER BY month
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS third_month_rev
FROM monthly_sales WHERE product = 'Widget';

-- === RUNNING TOTALS — SUM OVER ===

-- Cumulative sum (running total)
SELECT month, product, revenue,
  SUM(revenue) OVER(
    PARTITION BY product ORDER BY month
  ) AS running_total
FROM monthly_sales;

-- Running count
SELECT month, product, revenue,
  COUNT(*) OVER(PARTITION BY product ORDER BY month) AS running_count,
  SUM(revenue) OVER(PARTITION BY product ORDER BY month) AS running_total
FROM monthly_sales;

-- Running average
SELECT month, product, revenue,
  ROUND(AVG(revenue) OVER(
    PARTITION BY product ORDER BY month
  ), 2) AS running_avg
FROM monthly_sales;

-- Grand total on every row (no ORDER BY = whole partition)
SELECT month, product, revenue,
  SUM(revenue) OVER(PARTITION BY product) AS product_total,
  ROUND(revenue * 100.0 / SUM(revenue) OVER(PARTITION BY product), 1)
    AS pct_of_total
FROM monthly_sales;

-- === MOVING AVERAGES — Frame Clauses ===

-- 3-month moving average
SELECT month, revenue,
  ROUND(AVG(revenue) OVER(
    ORDER BY month
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ), 2) AS moving_avg_3m
FROM monthly_sales WHERE product = 'Widget';

-- 3-month moving sum
SELECT month, revenue,
  SUM(revenue) OVER(
    ORDER BY month
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ) AS moving_sum_3m
FROM monthly_sales WHERE product = 'Widget';

-- Centered moving average (1 before, current, 1 after)
SELECT month, revenue,
  ROUND(AVG(revenue) OVER(
    ORDER BY month
    ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
  ), 2) AS centered_avg
FROM monthly_sales WHERE product = 'Widget';

-- === FRAME CLAUSE REFERENCE ===

-- ROWS: counts physical rows
-- RANGE: groups by value (ties counted together)
-- GROUPS: counts peer groups (PG 11+)

-- Common frames:
-- Default with ORDER BY:
--   RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW

-- Running total (explicit):
--   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW

-- Moving 3-row window:
--   ROWS BETWEEN 2 PRECEDING AND CURRENT ROW

-- Whole partition:
--   ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING

-- Reverse running total:
--   ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING

-- === ROWS vs RANGE ===

-- ROWS counts exact physical rows
-- RANGE groups tied values together

-- Example with ties: if two rows have the same date,
-- RANGE includes BOTH in the "current row" group
-- ROWS treats them as separate rows

-- For most uses, ROWS is more intuitive
-- RANGE is the default (which can surprise you!)

-- === NAMED WINDOWS ===

-- Define once, use many times
SELECT month, product, revenue,
  SUM(revenue) OVER w AS running_total,
  LAG(revenue) OVER w AS prev_month,
  revenue - LAG(revenue) OVER w AS change,
  ROUND(AVG(revenue) OVER w, 2) AS running_avg
FROM monthly_sales
WINDOW w AS (PARTITION BY product ORDER BY month)
ORDER BY product, month;

-- Named window with frame override
SELECT month, revenue,
  SUM(revenue) OVER w AS running_total,
  ROUND(AVG(revenue) OVER(
    w ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ), 2) AS moving_avg_3m
FROM monthly_sales WHERE product = 'Widget'
WINDOW w AS (ORDER BY month);
-- Moving avg adds its own frame to named window 'w'

-- === REAL-WORLD PATTERNS ===

-- Year-over-year comparison (if you had multi-year data)
-- SELECT month, revenue,
--   LAG(revenue, 12) OVER(ORDER BY month) AS same_month_last_year
-- FROM monthly_sales;

-- Running percentage of total
SELECT month, revenue,
  SUM(revenue) OVER(ORDER BY month) AS running_total,
  ROUND(SUM(revenue) OVER(ORDER BY month) * 100.0
    / SUM(revenue) OVER(), 1) AS pct_of_grand_total
FROM monthly_sales WHERE product = 'Widget';

-- Difference from partition max
SELECT month, product, revenue,
  MAX(revenue) OVER(PARTITION BY product) AS product_max,
  revenue - MAX(revenue) OVER(PARTITION BY product) AS diff_from_max
FROM monthly_sales;

-- === PRACTICE EXERCISES ===

-- Exercise 1: Month-over-month change with LAG
SELECT month, revenue,
  LAG(revenue) OVER(ORDER BY month) AS prev,
  revenue - LAG(revenue) OVER(ORDER BY month) AS change
FROM monthly_sales WHERE product = 'Widget';

-- Exercise 2: Running total
SELECT month, revenue,
  SUM(revenue) OVER(ORDER BY month) AS running_total
FROM monthly_sales WHERE product = 'Gadget';

-- Exercise 3: 3-month moving average
SELECT month, revenue,
  ROUND(AVG(revenue) OVER(
    ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ), 2) AS ma_3
FROM monthly_sales WHERE product = 'Widget';

-- Exercise 4: FIRST_VALUE and LAST_VALUE
SELECT month, revenue,
  FIRST_VALUE(revenue) OVER(ORDER BY month) AS first,
  LAST_VALUE(revenue) OVER(
    ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS last
FROM monthly_sales WHERE product = 'Widget';

-- Exercise 5: Percentage change with LAG
SELECT month, revenue,
  ROUND((revenue - LAG(revenue) OVER(ORDER BY month)) * 100.0
    / LAG(revenue) OVER(ORDER BY month), 1) AS pct
FROM monthly_sales WHERE product = 'Gadget';

-- Exercise 6: Named window
SELECT month, revenue,
  SUM(revenue) OVER w, LAG(revenue) OVER w
FROM monthly_sales WHERE product = 'Widget'
WINDOW w AS (ORDER BY month);

-- Exercise 7: Multiple window functions combined
SELECT month, product, revenue,
  SUM(revenue) OVER w AS total,
  LAG(revenue) OVER w AS prev,
  LEAD(revenue) OVER w AS next
FROM monthly_sales
WINDOW w AS (PARTITION BY product ORDER BY month);

-- === CLEANUP ===
-- DROP TABLE IF EXISTS monthly_sales;

-- =============================================
-- Next Class: String, Date & Math Functions
-- =============================================


-- =============================================
-- VERIFIED ANSWER KEY — WINDOW FUNCTIONS AGGREGATES & FRAMES
-- =============================================

-- 1. Month-over-Month Revenue Difference with LAG
SELECT month, revenue,
  LAG(revenue) OVER(ORDER BY month) AS prev_rev,
  revenue - LAG(revenue) OVER(ORDER BY month) AS mom_change
FROM monthly_sales
WHERE product = 'Widget';

-- 2. Running Total with SUM OVER()
SELECT month, revenue,
  SUM(revenue) OVER(ORDER BY month) AS running_total
FROM monthly_sales
WHERE product = 'Gadget';

-- 3. 3-Month Moving Average with Frame Clause
SELECT month, revenue,
  ROUND(AVG(revenue) OVER(
    ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ), 2) AS ma_3
FROM monthly_sales
WHERE product = 'Widget';

-- 4. FIRST_VALUE and LAST_VALUE across Entire Partition
SELECT month, revenue,
  FIRST_VALUE(revenue) OVER(ORDER BY month) AS first_val,
  LAST_VALUE(revenue) OVER(
    ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS last_val
FROM monthly_sales
WHERE product = 'Widget';

-- 5. Percentage Growth Rate Calculation
SELECT month, revenue,
  ROUND((revenue - LAG(revenue) OVER(ORDER BY month)) * 100.0
    / NULLIF(LAG(revenue) OVER(ORDER BY month), 0), 1) AS pct_growth
FROM monthly_sales
WHERE product = 'Gadget';
