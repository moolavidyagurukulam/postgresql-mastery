# SELECT, WHERE, ORDER BY & LIMIT
**Series:** PostgreSQL Mastery | **Phase:** General | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> SELECT is the most used SQL command. Every time you view data, run a report, or build a dashboard — it's a SELECT. Today we cover everything: column selection, aliases, DISTINCT, the WHERE clause with every operator, AND OR NOT precedence, ORDER BY, LIMIT, OFFSET, and pagination pitfalls.


---

## 2. Core Technical Concepts & Mechanisms

### Pagination Pitfall: OFFSET Gets Slow on Large Tables!
Pagination pitfall. OFFSET doesn't jump to the right place — it reads and throws away rows. OFFSET a hundred thousand means PostgreSQL processes a hundred thousand rows before returning yours. Page one is fast. Page ten thousand is painfully slow. The fix is keyset pagination — instead of OFFSET, use WHERE id is greater than the last id you saw. This is always fast because it uses the index directly.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Problem** | OFFSET 100000 means PostgreSQL reads and throws away 100,000 rows before returning yours |
| **Page 1** | OFFSET 0 → fast (reads 10 rows) |
| **Page 100** | OFFSET 990 → still OK |
| **Page 10000** | OFFSET 99990 → SLOW (reads 100K rows, returns 10) |

**Notes:**
- Fix: use keyset pagination — WHERE id > last_seen_id ORDER BY id LIMIT 10

### SQL Execution Order (Why Alias Fails in WHERE)
Understanding execution order explains why aliases don't work in WHERE. SQL doesn't run top to bottom. First it reads FROM. Then it filters with WHERE — before SELECT runs, so aliases don't exist. Then GROUP BY, HAVING, then SELECT creates the aliases. DISTINCT removes duplicates. ORDER BY sorts — and here aliases DO work because SELECT already ran. Finally LIMIT returns a subset. Know this order and SQL errors make sense.

- FROM — which table to read
- WHERE — filter rows (aliases NOT available yet!)
- GROUP BY — group rows (covered in later class)
- HAVING — filter groups (covered in later class)
- SELECT — choose columns, create aliases
- DISTINCT — remove duplicates
- ORDER BY — sort results (aliases ARE available here!)
- LIMIT / OFFSET — return subset


---

## 3. Hands-On Commands & psql Output

### Setup: Sample Data for This Class
**Explanation:** First, our sample data. Ten employees across four departments — Engineering, Marketing, Sales, and HR. Salaries from sixty-eight thousand to a hundred and five thousand. Some hired recently, some years ago. Anita has a null email. Anita and Vikram are inactive. This variety gives us lots to query against.

```sql
CREATE TABLE employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(150) UNIQUE,
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    hire_date  DATE,
    is_active  BOOLEAN DEFAULT true
);

INSERT INTO employees (name, email, department, salary, hire_date, is_active) VALUES
('Ravi',  'ravi@co.com',  'Engineering', 95000, '2022-03-15', true),
('Priya', 'priya@co.com', 'Engineering', 88000, '2023-06-01', true),
('Arjun', 'arjun@co.com', 'Marketing',   72000, '2021-11-20', true),
('Meera', 'meera@co.com', 'Engineering', 105000, '2020-01-10', true),
('Kiran', 'kiran@co.com', 'Sales',       68000, '2024-02-14', true),
('Anita', NULL,            'Marketing',   75000, '2023-09-05', false),
('Deepak','deepak@co.com','Sales',       71000, '2022-07-22', true),
('Sonia', 'sonia@co.com', 'HR',          82000, '2021-04-30', true),
('Vikram','vikram@co.com','Engineering', 92000, '2023-01-18', false),
('Neha',  'neha@co.com',  'HR',          78000, '2024-08-01', true);
```

### SELECT — Column Selection & Aliases
**Explanation:** SELECT star returns all columns. But in production, always select specific columns — it's faster and more explicit. Aliases rename columns in the output — AS employee name makes the result clearer. AS is optional but use it for readability. You can compute expressions — divide salary by twelve for monthly, multiply by one point one for a hypothetical raise. The database computes these on the fly.

```sql
-- Select all columns
SELECT * FROM employees;

-- Select specific columns
SELECT name, department, salary FROM employees;

-- Column aliases (rename in output)
SELECT name AS employee_name,
       salary AS annual_salary
FROM employees;

-- AS is optional (but recommended)
SELECT name employee_name, salary annual_salary
FROM employees;

-- Expressions in SELECT
SELECT name,
       salary AS annual,
       salary / 12 AS monthly,
       salary * 1.10 AS after_raise
FROM employees;
```

### DISTINCT — Remove Duplicate Rows
**Explanation:** DISTINCT removes duplicate rows. Without it, querying department returns ten rows with repeats. With DISTINCT, you get four unique departments. DISTINCT on multiple columns returns unique combinations — Engineering plus active, Engineering plus inactive, and so on. You can count distinct values too — four unique departments.

```sql
-- All departments (with duplicates)
SELECT department FROM employees;
-- Engineering, Engineering, Marketing, Engineering,
-- Sales, Marketing, Sales, HR, Engineering, HR

-- Unique departments only
SELECT DISTINCT department FROM employees;
-- Engineering, Marketing, Sales, HR

-- DISTINCT on multiple columns
SELECT DISTINCT department, is_active
FROM employees;
-- Shows unique department+active combinations

-- Count unique values
SELECT COUNT(DISTINCT department) AS dept_count
FROM employees;
-- 4
```

### WHERE — Comparison Operators
**Explanation:** WHERE filters rows. Comparison operators work like you'd expect. Equal finds Engineering employees. Not equal — use angle bracket or exclamation mark, both work but angle bracket is the SQL standard. Greater than, less than, and their or-equal variants all work on numbers, dates, and text. Dates compare chronologically — here we find everyone hired in twenty twenty-three or later.

```sql
-- Equal
SELECT name, salary FROM employees
WHERE department = 'Engineering';

-- Not equal (both work, <> is SQL standard)
SELECT name FROM employees
WHERE department <> 'Sales';
-- or: WHERE department != 'Sales'

-- Greater than / Less than
SELECT name, salary FROM employees
WHERE salary > 90000;

SELECT name, salary FROM employees
WHERE salary <= 75000;

-- Greater/Less than or equal
SELECT name, hire_date FROM employees
WHERE hire_date >= '2023-01-01';
```

### WHERE — BETWEEN, IN, NOT IN
**Explanation:** BETWEEN checks a range — salary between seventy-five and ninety-five thousand. Important: BETWEEN is inclusive on both ends. It works for dates too — all hires from twenty twenty-two through twenty twenty-three. IN matches any value in a list — Engineering or HR. It's cleaner than writing multiple OR conditions. NOT IN excludes values — everyone except Sales and Marketing.

```sql
-- BETWEEN (inclusive on both ends!)
SELECT name, salary FROM employees
WHERE salary BETWEEN 75000 AND 95000;
-- Same as: salary >= 75000 AND salary <= 95000

-- Date range with BETWEEN
SELECT name, hire_date FROM employees
WHERE hire_date BETWEEN '2022-01-01' AND '2023-12-31';

-- IN: match any value in a list
SELECT name, department FROM employees
WHERE department IN ('Engineering', 'HR');
-- Same as: department = 'Eng' OR department = 'HR'

-- NOT IN: exclude values
SELECT name, department FROM employees
WHERE department NOT IN ('Sales', 'Marketing');
```

### WHERE — LIKE & ILIKE (Pattern Matching)
**Explanation:** LIKE does pattern matching. Percent matches any number of characters. Underscore matches exactly one. R percent finds names starting with R. Percent a finds names ending with a. Percent ir percent finds names containing ir. Underscore e percent finds names where the second character is e. ILIKE is PostgreSQL's case-insensitive version — it matches both uppercase and lowercase. Use ILIKE for user-facing searches.

```sql
-- LIKE: case-sensitive pattern matching
-- %  = any number of characters
-- _  = exactly one character

-- Starts with 'R'
SELECT name FROM employees WHERE name LIKE 'R%';
-- Ravi

-- Ends with 'a'
SELECT name FROM employees WHERE name LIKE '%a';
-- Priya, Meera, Anita, Sonia, Neha

-- Contains 'ir'
SELECT name FROM employees WHERE name LIKE '%ir%';
-- Kiran

-- Second character is 'e'
SELECT name FROM employees WHERE name LIKE '_e%';
-- Meera, Deepak, Neha

-- ILIKE: case-INSENSITIVE (PostgreSQL extension)
SELECT name FROM employees WHERE name ILIKE 'r%';
-- Ravi (matches R or r)
-- ILIKE is slower but safer for user input
```

### WHERE — IS NULL / IS NOT NULL (The NULL Trap!)
**Explanation:** This is the null trap — the most common beginner mistake. WHERE email equals NULL returns zero rows. Always. Because in SQL, null means unknown, and unknown equals unknown is still unknown — not true. You must use IS NULL and IS NOT NULL. This applies to every comparison. Null equals null is not true. Null not-equals null is not true either. Always use IS NULL.

```sql
-- WRONG: = NULL returns NOTHING!
SELECT name FROM employees WHERE email = NULL;
-- (0 rows)  ← WRONG! This never works!

-- RIGHT: use IS NULL
SELECT name FROM employees WHERE email IS NULL;
-- Anita

-- IS NOT NULL
SELECT name FROM employees WHERE email IS NOT NULL;
-- Everyone except Anita (9 rows)

-- WHY: In SQL, NULL = NULL is NOT true.
-- NULL means "unknown". Unknown = unknown? Unknown!
-- NULL = NULL  → NULL (not true, not false)
-- NULL <> NULL → NULL (not true, not false)
-- Only IS NULL and IS NOT NULL work correctly.
```

### AND, OR, NOT — Combining Conditions
**Explanation:** AND requires both conditions true. OR requires either. NOT negates. But watch the precedence trap — AND binds tighter than OR. Without parentheses, Sales OR HR AND salary over eighty thousand means all Sales employees OR HR employees with high salary. That's probably not what you meant. Always use parentheses when mixing AND and OR. Explicit parentheses make your intent clear.

```sql
-- AND: both conditions must be true
SELECT name, department, salary FROM employees
WHERE department = 'Engineering' AND salary > 90000;
-- Ravi (95k), Meera (105k), Vikram (92k)

-- OR: either condition can be true
SELECT name, department FROM employees
WHERE department = 'HR' OR department = 'Sales';

-- NOT: negate a condition
SELECT name FROM employees
WHERE NOT is_active;
-- Anita, Vikram (inactive employees)

-- PRECEDENCE TRAP: AND before OR!
SELECT name, department, salary FROM employees
WHERE department = 'Sales' OR department = 'HR'
  AND salary > 80000;
-- This means: Sales OR (HR AND salary>80k)
-- NOT: (Sales OR HR) AND salary>80k

-- FIX: use parentheses!
WHERE (department = 'Sales' OR department = 'HR')
  AND salary > 80000;
```

### WHERE Operators in Action
**Explanation:** BETWEEN returns six employees with salaries from seventy-five to ninety-five thousand — both ends included. IS NULL finds Anita, the only employee without an email. Every operator returns exactly what you expect when you use it correctly.

```sql
essilor=#SELECT name, salary FROM employees WHERE salary BETWEEN 75000 AND 95000;
  name  | salary
--------+---------
 Ravi   | 95000.00
 Priya  | 88000.00
 Anita  | 75000.00
 Sonia  | 82000.00
 Vikram | 92000.00
 Neha   | 78000.00
(6 rows)

essilor=#SELECT name FROM employees WHERE email IS NULL;
 name
-------
 Anita
(1 row)
```

### ORDER BY — Sorting Results
**Explanation:** ORDER BY sorts results. ASC is ascending — low to high, A to Z. DESC is descending — high to low. Multiple columns sort by the first, then break ties with the second — here, by department ascending then salary descending within each department. NULLS FIRST puts nulls at the top, NULLS LAST at the bottom. By default, ASC puts nulls last, DESC puts nulls first — you can override this.

```sql
-- Ascending (default)
SELECT name, salary FROM employees
ORDER BY salary;
-- 68000, 71000, 72000... (low to high)

-- Descending
SELECT name, salary FROM employees
ORDER BY salary DESC;
-- 105000, 95000, 92000... (high to low)

-- Multiple columns
SELECT name, department, salary FROM employees
ORDER BY department ASC, salary DESC;
-- Engineering: 105k, 95k, 92k, 88k
-- HR: 82k, 78k
-- Marketing: 75k, 72k
-- Sales: 71k, 68k

-- NULLS FIRST / NULLS LAST
SELECT name, email FROM employees
ORDER BY email NULLS FIRST;
-- Anita (NULL) first, then alphabetical

SELECT name, email FROM employees
ORDER BY email DESC NULLS LAST;
-- Vikram first, ... Anita (NULL) last
```

### LIMIT & OFFSET — Paging Through Results
**Explanation:** LIMIT returns only N rows. Top three earners with LIMIT three. OFFSET skips rows — OFFSET three skips the first three and returns the next batch. Together they do pagination. Page one is LIMIT five OFFSET zero. Page two is LIMIT five OFFSET five. The formula is OFFSET equals page minus one times page size. PostgreSQL also supports the SQL standard FETCH FIRST syntax — same result, more verbose.

```sql
-- LIMIT: return only N rows
SELECT name, salary FROM employees
ORDER BY salary DESC
LIMIT 3;
-- Top 3 earners: Meera, Ravi, Vikram

-- OFFSET: skip N rows, then return
SELECT name, salary FROM employees
ORDER BY salary DESC
LIMIT 3 OFFSET 3;
-- Next 3: Priya, Sonia, Neha

-- Page 1: LIMIT 5 OFFSET 0
-- Page 2: LIMIT 5 OFFSET 5
-- Page 3: LIMIT 5 OFFSET 10
-- Pattern: LIMIT page_size OFFSET (page - 1) * page_size

-- SQL standard syntax (also works):
SELECT name, salary FROM employees
ORDER BY salary DESC
FETCH FIRST 3 ROWS ONLY;
-- FETCH FIRST ... is the SQL standard for LIMIT
```

### Keyset Pagination (The Fast Way)
**Explanation:** Keyset pagination in action. First page — just LIMIT three, no offset. Remember the last id — three. Next page — WHERE id greater than three, LIMIT three. Remember the last id — six. Next page — WHERE id greater than six. Each query uses the index and returns instantly, no matter how deep you go. The trade-off: you can't jump to page five hundred directly. But for infinite scroll and API pagination, keyset is the standard.

```sql
-- SLOW: offset-based pagination
SELECT id, name, salary FROM employees
ORDER BY id
LIMIT 3 OFFSET 6;
-- Reads 9 rows, returns last 3

-- FAST: keyset pagination
-- Page 1: get first 3
SELECT id, name, salary FROM employees
ORDER BY id
LIMIT 3;
-- Returns id: 1, 2, 3. Last id = 3.

-- Page 2: get next 3 after last id
SELECT id, name, salary FROM employees
WHERE id > 3
ORDER BY id
LIMIT 3;
-- Returns id: 4, 5, 6. Last id = 6.

-- Page 3: next 3 after id 6
SELECT id, name, salary FROM employees
WHERE id > 6
ORDER BY id
LIMIT 3;
-- Always fast — uses the index!
```

### Common SELECT Errors
**Explanation:** Three common errors. First — using an alias in WHERE. SQL processes WHERE before SELECT, so aliases don't exist yet. Repeat the expression instead. Second — null comparison with equals. Returns zero rows silently. Always use IS NULL. Third — LIMIT without ORDER BY. You get three rows, but which three? It's undefined and can change between runs. Always sort before limiting.

```sql
-- Error 1: Alias not usable in WHERE
essilor=#SELECT name, salary * 12 AS annual FROM employees WHERE annual > 1000000;
ERROR:  column "annual" does not exist
-- Fix: repeat the expression in WHERE:
-- WHERE salary * 12 > 1000000

-- Error 2: NULL comparison
essilor=#SELECT name FROM employees WHERE email = NULL;
(0 rows)
-- Not an error, just empty! Use IS NULL instead.

-- Error 3: Missing ORDER BY with LIMIT
essilor=#SELECT name FROM employees LIMIT 3;
-- Returns 3 rows, but WHICH 3? Undefined!
-- Fix: always ORDER BY before LIMIT
```


---

## 5. Common Beginner Traps & How to Fix Them

### WHERE — IS NULL / IS NOT NULL (The NULL Trap!)
This is the null trap — the most common beginner mistake. WHERE email equals NULL returns zero rows. Always. Because in SQL, null means unknown, and unknown equals unknown is still unknown — not true. You must use IS NULL and IS NOT NULL. This applies to every comparison. Null equals null is not true. Null not-equals null is not true either. Always use IS NULL.

### Pagination Pitfall: OFFSET Gets Slow on Large Tables!
Pagination pitfall. OFFSET doesn't jump to the right place — it reads and throws away rows. OFFSET a hundred thousand means PostgreSQL processes a hundred thousand rows before returning yours. Page one is fast. Page ten thousand is painfully slow. The fix is keyset pagination — instead of OFFSET, use WHERE id is greater than the last id you saw. This is always fast because it uses the index directly.

### Common SELECT Errors
Three common errors. First — using an alias in WHERE. SQL processes WHERE before SELECT, so aliases don't exist yet. Repeat the expression instead. Second — null comparison with equals. Returns zero rows silently. Always use IS NULL. Third — LIMIT without ORDER BY. You get three rows, but which three? It's undefined and can change between runs. Always sort before limiting.

```sql
-- Error 1: Alias not usable in WHERE
SELECT name, salary * 12 AS annual FROM employees WHERE annual > 1000000;
ERROR:  column "annual" does not exist
-- Fix: repeat the expression in WHERE:
-- WHERE salary * 12 > 1000000

-- Error 2: NULL comparison
SELECT name FROM employees WHERE email = NULL;
(0 rows)
-- Not an error, just empty! Use IS NULL instead.

-- Error 3: Missing ORDER BY with LIMIT
SELECT name FROM employees LIMIT 3;
-- Returns 3 rows, but WHICH 3? Undefined!
-- Fix: always ORDER BY before LIMIT
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time. Find all Engineering employees earning over ninety thousand. Use LIKE for pattern matching on names. Find the null email. Get distinct departments sorted. Get the top five earners. Page through employees three at a time. And write a complex WHERE with AND, OR, BETWEEN, and parentheses. All the SQL is in your downloadable materials.

1. SELECT all employees in Engineering with salary > 90000
2. Find employees whose name starts with 'M' or ends with 'a' (use LIKE)
3. Find the employee with NULL email (use IS NULL)
4. SELECT DISTINCT departments, sorted alphabetically
5. Top 5 highest-paid employees (ORDER BY + LIMIT)
6. Page 2 of employees sorted by hire_date, 3 per page
7. Find active employees in Engineering OR HR with salary BETWEEN 80k and 100k (use parentheses!)


---


### Answer Key — SELECT, WHERE, ORDER BY & LIMIT Solutions

```sql
-- 1. Find Engineering employees earning over $90,000
-- Note: AND requires both conditions to evaluate to true.
SELECT id, name, department, salary
FROM employees
WHERE department = 'Engineering' AND salary > 90000
ORDER BY salary DESC;

-- 2. Pattern matching with LIKE / ILIKE
-- Note: ILIKE is PostgreSQL-specific case-insensitive matching.
SELECT id, name, email
FROM customers
WHERE name ILIKE 'john%'
ORDER BY name ASC;

-- 3. BETWEEN and IN filters
-- Note: BETWEEN is inclusive of both boundary endpoints.
SELECT id, title, price
FROM products
WHERE price BETWEEN 20.00 AND 100.00
  AND category IN ('Electronics', 'Accessories')
ORDER BY price ASC;

-- 4. Handling NULL values cleanly
-- Note: Always use IS NOT NULL (never != NULL).
SELECT id, name, phone
FROM clients
WHERE phone IS NOT NULL;

-- 5. Pagination with LIMIT and OFFSET
-- Note: Fetches page 3 of 10 items per page.
SELECT id, name, created_at
FROM audit_logs
ORDER BY created_at DESC
LIMIT 10 OFFSET 20;

```

---

## 7. Key Takeaways & Cheat Sheet

Let's recap. Select specific columns with aliases. DISTINCT removes duplicates. WHERE has many operators — equals, between, in, like, is null. AND binds tighter than OR so use parentheses. Null equals null is not true — always use IS NULL. Always ORDER BY before LIMIT. OFFSET gets slow on deep pages — use keyset pagination instead. And remember the execution order — FROM, WHERE, SELECT, ORDER BY, LIMIT.

- **SELECT specific columns, not * — use aliases for clarity**
- **DISTINCT removes duplicate rows**
- **WHERE operators: =, <>, >, <, BETWEEN, IN, LIKE, ILIKE, IS NULL**
- **AND binds tighter than OR — always use parentheses when mixing**
- **NULL = NULL is NOT true — always use IS NULL / IS NOT NULL**
- **ORDER BY before LIMIT — undefined order without it**
- **OFFSET gets slow on deep pages — use keyset pagination (WHERE id > last_id)**
- **Execution order: FROM → WHERE → SELECT → ORDER BY → LIMIT**


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
