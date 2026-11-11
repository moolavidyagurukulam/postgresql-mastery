# COPY, CASE WHEN, COALESCE & NULLIF
**Series:** PostgreSQL Mastery | **Phase:** General | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Today we cover three essential tools. COPY for importing and exporting CSV files — the fastest way to load bulk data. CASE WHEN for conditional logic inside queries. And COALESCE, NULLIF, GREATEST, and LEAST for handling nulls and picking values. Let's start with COPY.


---

## 2. Core Technical Concepts & Mechanisms

### COPY: Bulk Import & Export
COPY is PostgreSQL's bulk data tool. COPY TO exports data to a file. COPY FROM imports from a file. Both are ten to a hundred times faster than individual inserts for large datasets. Important distinction: COPY accesses files on the server, which needs server file permissions. Backslash copy accesses files on your local machine through psql — no server permissions needed. In practice, you'll use backslash copy most often.

| Term | Meaning / Explanation |
| :--- | :--- |
| **COPY TO** | Export table data to a CSV file on the SERVER |
| **COPY FROM** | Import data from a CSV file on the SERVER into a table |
| **\copy** | Same but file is on the CLIENT machine (psql command) |
| **Speed** | 10-100x faster than INSERT for bulk data loading |

**Notes:**
- COPY = server-side file access (needs server file permissions)
- \copy = client-side file access (runs through psql, no server permissions needed)

### NULL-Handling Functions — Cheat Sheet
Your null-handling cheat sheet. COALESCE for default values and fallback chains. NULLIF to turn specific values into null — mainly for division by zero. GREATEST to enforce minimums. LEAST to cap maximums. And CASE WHEN for anything more complex. These five tools handle every null scenario you'll encounter.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Your null** | handling cheat sheet |
| **Point 2** | COALESCE for default values and fallback chains |
| **NULLIF to turn specific values into null** | mainly for division by zero |
| **Point 4** | GREATEST to enforce minimums |
| **Point 5** | LEAST to cap maximums |
| **Point 6** | And CASE WHEN for anything more complex |
| **Point 7** | These five tools handle every null scenario you'll encounter |


---

## 3. Hands-On Commands & psql Output

### \copy TO — Export Data to CSV
**Explanation:** Backslash copy TO exports data. We export the full employees table to a CSV with headers. You can also export a query result — just specific columns or filtered rows. The WITH options control the format: CSV format, include HEADER row, and custom DELIMITER like tab for TSV files. The file lands on your local machine — wherever you're running psql from.

```sql
-- Setup
CREATE TABLE employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    hire_date  DATE
);

INSERT INTO employees (name, department, salary, hire_date) VALUES
('Ravi',  'Engineering', 95000, '2022-03-15'),
('Priya', 'Engineering', 88000, '2023-06-01'),
('Arjun', 'Marketing',   72000, '2021-11-20'),
('Meera', 'HR',          82000, '2020-01-10');

-- Export to CSV (from psql)
\copy employees TO '/tmp/employees.csv' WITH (FORMAT CSV, HEADER);

-- Export specific columns
\copy (SELECT name, salary FROM employees)
  TO '/tmp/salaries.csv' WITH (FORMAT CSV, HEADER);

-- Custom delimiter
\copy employees TO '/tmp/employees.tsv'
  WITH (FORMAT CSV, HEADER, DELIMITER E'\t');
```

### \copy FROM — Import Data from CSV
**Explanation:** Backslash copy FROM imports data. Specify the target columns, the file path, and the format options. HEADER tells PostgreSQL to skip the first row. NULL defines what string represents null in the CSV. The server-side COPY command reads files from the server's filesystem — useful for automated imports but requires the postgres user to have read access to the file.

```sql
-- Import CSV into table (from psql)
\copy employees (name, department, salary, hire_date)
  FROM '/tmp/new_employees.csv'
  WITH (FORMAT CSV, HEADER);

-- Options:
-- FORMAT CSV     → CSV format (default delimiter: comma)
-- HEADER         → first row is column names (skip it)
-- DELIMITER ','  → field separator
-- NULL 'NULL'    → treat string 'NULL' as SQL NULL
-- QUOTE '"'      → quoting character
-- ESCAPE '\\'   → escape character

-- Server-side COPY (needs server file access):
COPY employees FROM '/var/data/employees.csv'
  WITH (FORMAT CSV, HEADER);

-- COPY is 10-100x faster than INSERT for bulk loads!
-- 1 million rows: INSERT = minutes, COPY = seconds
```

### Common COPY Errors
**Explanation:** Three common COPY errors. Permission denied — server-side COPY needs the postgres user to access the file. Fix: use backslash copy instead. Extra data after last column — the CSV has more columns than the table. Fix: specify the column list to match. Invalid input syntax — a text value where a number should be. Fix: clean your CSV data before importing.

```sql
-- Error 1: Permission denied (server-side COPY)
essilor=#COPY employees FROM '/home/user/data.csv' CSV HEADER;
ERROR:  could not open file "/home/user/data.csv"
        for reading: Permission denied
-- Fix: use \copy (client-side) instead

-- Error 2: Column count mismatch
essilor=#\copy employees FROM '/tmp/bad.csv' CSV HEADER;
ERROR:  extra data after last expected column
-- Fix: specify columns to match CSV:
-- \copy employees (name, salary) FROM ...

-- Error 3: Data type mismatch
ERROR:  invalid input syntax for type numeric: "abc"
-- Fix: clean CSV data before importing
```

### CASE WHEN — Conditional Logic in Queries
**Explanation:** CASE WHEN adds conditional logic to queries. The searched form tests each WHEN condition and returns the first match. Salary over a hundred thousand gets Senior, over eighty gets Mid-Level, and so on. The simple form compares one value — department equals Engineering returns Tech. CASE evaluates top to bottom and returns the first match. ELSE catches everything that didn't match.

```sql
-- Searched CASE (most common)
SELECT name, salary,
  CASE
    WHEN salary >= 100000 THEN 'Senior'
    WHEN salary >= 80000  THEN 'Mid-Level'
    WHEN salary >= 60000  THEN 'Junior'
    ELSE 'Intern'
  END AS level
FROM employees;

-- Simple CASE (compare one value)
SELECT name, department,
  CASE department
    WHEN 'Engineering' THEN 'Tech'
    WHEN 'Marketing'   THEN 'Business'
    WHEN 'Sales'       THEN 'Business'
    WHEN 'HR'          THEN 'Operations'
    ELSE 'Other'
  END AS division
FROM employees;

-- CASE evaluates top to bottom, returns first match
```

### CASE WHEN — Practical Uses
**Explanation:** CASE WHEN works everywhere — not just in SELECT. In WHERE, apply different conditions per department. In ORDER BY, create custom sort orders. In UPDATE, apply different raise percentages per department — Engineering gets ten percent, Sales five, everyone else three. And in aggregation, count high earners per department by converting the condition to one or zero and summing.

```sql
-- In WHERE clause
SELECT name, salary FROM employees
WHERE CASE
    WHEN department = 'Engineering' THEN salary > 90000
    ELSE salary > 75000
  END;

-- In ORDER BY
SELECT name, department FROM employees
ORDER BY CASE department
    WHEN 'Engineering' THEN 1
    WHEN 'HR'          THEN 2
    WHEN 'Marketing'   THEN 3
    ELSE 4
  END;

-- In UPDATE
UPDATE employees
SET salary = CASE
    WHEN department = 'Engineering' THEN salary * 1.10
    WHEN department = 'Sales'       THEN salary * 1.05
    ELSE salary * 1.03
  END;

-- Pivot-style aggregation
SELECT department,
  COUNT(*) AS total,
  SUM(CASE WHEN salary > 80000 THEN 1 ELSE 0 END) AS high_earners
FROM employees GROUP BY department;
```

### CASE WHEN in Action
**Explanation:** CASE WHEN in action. Each employee gets a tier based on salary — High, Mid, or Low. The output shows the computed tier alongside the real salary. This is purely display — no data is changed. CASE WHEN transforms how you see the data, not the data itself.

```sql
essilor=#SELECT name, salary,
  CASE WHEN salary >= 90000 THEN 'High'
       WHEN salary >= 70000 THEN 'Mid'
       ELSE 'Low' END AS tier
FROM employees ORDER BY salary DESC;
  name  |  salary   | tier
--------+-----------+------
 Ravi   | 104500.00 | High
 Priya  |  96800.00 | High
 Meera  |  84460.00 | Mid
 Arjun  |  74160.00 | Mid
(4 rows)
```

### COALESCE — First Non-NULL Value
**Explanation:** COALESCE returns the first non-null value from its arguments. It's the most useful null-handling function. Replace null department with Unassigned. Chain fallbacks — try email, then phone, then a default string. In calculations, convert null bonus to zero so salary plus bonus doesn't become null. COALESCE takes any number of arguments and returns the first one that isn't null.

```sql
-- COALESCE returns the first non-NULL argument
SELECT COALESCE(NULL, NULL, 'hello', 'world');
-- 'hello' (first non-null)

-- Practical: default value for NULL columns
SELECT name,
       COALESCE(department, 'Unassigned') AS dept
FROM employees;
-- NULL department → 'Unassigned'

-- With multiple fallbacks
SELECT name,
       COALESCE(email, phone, 'No contact info') AS contact
FROM users;
-- Try email first, then phone, then default text

-- In calculations
SELECT name,
       salary + COALESCE(bonus, 0) AS total_pay
FROM employees;
-- NULL bonus becomes 0 (avoids NULL result)
```

### NULLIF — Return NULL If Values Match
**Explanation:** NULLIF returns null if two values are equal, otherwise returns the first value. Its killer use case — preventing division by zero. Wrap the divisor in NULLIF with zero. If orders is zero, NULLIF returns null, and dividing by null gives null instead of an error. Another pattern — combine NULLIF with COALESCE to handle empty strings. NULLIF turns empty string to null, then COALESCE provides the default.

```sql
-- NULLIF(a, b): returns NULL if a = b, else returns a
SELECT NULLIF(10, 10);  -- NULL (values match)
SELECT NULLIF(10, 20);  -- 10   (values don't match)

-- Practical: prevent division by zero
SELECT name,
       total_revenue / NULLIF(total_orders, 0)
       AS avg_order_value
FROM sales_summary;
-- If total_orders = 0, NULLIF returns NULL
-- division by NULL = NULL (not error!)
-- Without NULLIF: ERROR: division by zero

-- Clean up empty strings
SELECT name,
       COALESCE(NULLIF(phone, ''), 'No phone')
       AS phone_display
FROM users;
-- Empty string '' → NULL → 'No phone'
```

### GREATEST & LEAST — Pick Max/Min From Values
**Explanation:** GREATEST picks the largest value from a list. LEAST picks the smallest. Use GREATEST to enforce a minimum — nobody shows below fifty thousand. Use LEAST to cap a maximum — twenty percent discount but no more than a hundred. Combine them to clamp a value to a range — GREATEST of LEAST of value and a hundred, and zero — keeps the value between zero and a hundred.

```sql
-- GREATEST: returns the largest value
SELECT GREATEST(10, 20, 5, 30);  -- 30

-- LEAST: returns the smallest value
SELECT LEAST(10, 20, 5, 30);  -- 5

-- Practical: enforce minimum/maximum
SELECT name,
       GREATEST(salary, 50000) AS effective_salary
FROM employees;
-- Nobody shows below 50000

-- Cap a discount
SELECT name, price,
       LEAST(price * 0.20, 100.00) AS max_discount
FROM products;
-- 20% discount, but capped at 100

-- Clamp value to a range
SELECT GREATEST(LEAST(input_value, 100), 0)
       AS clamped;
-- Value between 0 and 100
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common COPY Errors
Three common COPY errors. Permission denied — server-side COPY needs the postgres user to access the file. Fix: use backslash copy instead. Extra data after last column — the CSV has more columns than the table. Fix: specify the column list to match. Invalid input syntax — a text value where a number should be. Fix: clean your CSV data before importing.

```sql
-- Error 1: Permission denied (server-side COPY)
COPY employees FROM '/home/user/data.csv' CSV HEADER;
ERROR:  could not open file "/home/user/data.csv"
        for reading: Permission denied
-- Fix: use \copy (client-side) instead

-- Error 2: Column count mismatch
\copy employees FROM '/tmp/bad.csv' CSV HEADER;
ERROR:  extra data after last expected column
-- Fix: specify columns to match CSV:
-- \copy employees (name, salary) FROM ...

-- Error 3: Data type mismatch
ERROR:  invalid input syntax for type numeric: "abc"
-- Fix: clean CSV data before importing
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time. Export employees to CSV and check the file. Import a CSV into a staging table. Use CASE WHEN for salary tiers. Apply per-department raises with CASE in UPDATE. Replace null emails with COALESCE. Safely compute averages with NULLIF. And clamp salary ranges with GREATEST and LEAST.

1. Export employees to CSV with \copy TO, verify the file content
2. Create a staging table, import a CSV with \copy FROM
3. Use CASE WHEN to assign salary tiers: High (>90k), Mid (>70k), Low
4. Use CASE in UPDATE to apply different raises per department
5. Use COALESCE to replace NULL emails with 'no-email@company.com'
6. Use NULLIF to safely compute avg order value (avoid divide by zero)
7. Use GREATEST/LEAST to clamp salaries between 50k and 150k


---

## 7. Key Takeaways & Cheat Sheet

Let's recap. Backslash copy TO exports and FROM imports CSV data at high speed. Use backslash copy for client-side files, server COPY for server-side. CASE WHEN adds conditional logic anywhere in your queries. COALESCE returns the first non-null value — your go-to for defaults. NULLIF prevents division by zero. GREATEST and LEAST enforce ranges. These tools complete your DML toolkit.

- **\copy TO exports data to CSV on your local machine**
- **\copy FROM imports CSV data — 10-100x faster than INSERT**
- **Server COPY needs file permissions; \copy (psql) doesn't**
- **CASE WHEN: conditional logic anywhere — SELECT, WHERE, UPDATE, ORDER BY**
- **COALESCE(a, b, c): first non-NULL — perfect for defaults**
- **NULLIF(a, b): NULL if equal — prevents division by zero**
- **GREATEST/LEAST: pick max/min from values — enforce ranges**

Phase 5 is complete. You now know every DML command. INSERT in all its variants. SELECT with filtering, sorting, and pagination. UPDATE and DELETE with joins and safety patterns. UPSERT for atomic insert-or-update. COPY for high-speed CSV operations. CASE for conditional logic. And COALESCE and NULLIF for null handling. You can now fully create, read, update, and delete data.

- **INSERT: single, multi-row, SELECT, RETURNING, CTE, DEFAULT VALUES**
- **SELECT: columns, aliases, DISTINCT, WHERE, operators, ORDER BY, LIMIT**
- **UPDATE: SET, FROM (join), RETURNING, expression-based**
- **DELETE: WHERE, USING (join), RETURNING, CTE archive pattern**
- **UPSERT: ON CONFLICT DO NOTHING / DO UPDATE + EXCLUDED**
- **COPY: bulk CSV import/export (\copy for client-side)**
- **CASE WHEN: conditional logic | COALESCE: NULL defaults | NULLIF: safe division**


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
