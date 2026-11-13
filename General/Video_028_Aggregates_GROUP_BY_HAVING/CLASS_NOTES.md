# COUNT, SUM, AVG, MIN, MAX, GROUP BY & HAVING
**Series:** PostgreSQL Mastery | **Phase:** Phase 7: Aggregation & Grouping | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn aggregate functions — COUNT, SUM, AVG, MIN, MAX — and how to use GROUP BY to summarize data by category, and HAVING to filter those groups. By the end, you will be writing summary reports from raw data.

### The Problem: Summarizing Raw Data
Imagine your boss asks: 'How many orders did we get last month? What was the total revenue? What is the average order value? Which department spends the most?' These are all aggregation questions. You cannot answer them by looking at individual rows — you need to SUMMARIZE. Aggregate functions take many rows and return ONE value. GROUP BY lets you get one summary PER category — per department, per month, per product.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should know SELECT, WHERE, ORDER BY, and JOINs — all covered in the previous phases. In the JOINs class, we combined rows from multiple tables. Now we go in the other direction — instead of expanding rows, we COLLAPSE them. We take many rows and produce a single summary: total sales, average salary, number of orders. That is what aggregation does.

- You know SELECT, WHERE, ORDER BY, LIMIT
- You know INNER JOIN, LEFT JOIN, and multi-table joins
- Previous class: combining rows from multiple tables
- This class: COLLAPSING rows into summaries
- COUNT, SUM, AVG, MIN, MAX — the five core aggregates
- GROUP BY: split rows into groups, summarize each group

### The Problem: Summarizing Raw Data
Imagine your boss asks: 'How many orders did we get last month? What was the total revenue? What is the average order value? Which department spends the most?' These are all aggregation questions. You cannot answer them by looking at individual rows — you need to SUMMARIZE. Aggregate functions take many rows and return ONE value. GROUP BY lets you get one summary PER category — per department, per month, per product.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Aggregate Function** | Takes many rows, returns one value (COUNT, SUM, AVG...) |
| **Without GROUP BY** | One summary for the ENTIRE table |
| **With GROUP BY** | One summary PER group (per department, per month...) |
| **HAVING** | Filter groups AFTER aggregation (like WHERE for groups) |

### WHERE vs HAVING — When Each Runs
Here is the key difference between WHERE and HAVING. WHERE runs BEFORE grouping — it filters which rows enter the groups. HAVING runs AFTER grouping — it filters which groups appear in the result. You can use both in the same query: WHERE to exclude inactive employees, then HAVING to keep only departments with more than one person. The execution order is: FROM, WHERE, GROUP BY, HAVING, SELECT, ORDER BY.

| WHERE (Before Grouping) | HAVING (After Grouping) |
| :--- | :--- |
| Filters individual ROWS | Filters GROUPS |
| Runs before GROUP BY | Runs after GROUP BY |
| Cannot use aggregate functions | CAN use aggregate functions |
| WHERE salary > 70000 | HAVING AVG(salary) > 80000 |
| WHERE is_active = true | HAVING COUNT(*) >= 2 |

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. You can download today's class materials and practice files from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Every bit helps us keep creating. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### SQL Execution Order — Why Aliases Work Where They Do
Here is the complete SQL execution order — this explains everything about what works where. FROM picks the table. WHERE filters rows. GROUP BY creates groups. HAVING filters groups. SELECT calculates columns and aliases. ORDER BY sorts — aliases work here because SELECT already ran. LIMIT returns a subset. Understanding this order is the key to debugging every GROUP BY error.

- 1. FROM — pick the table(s)
- 2. WHERE — filter individual rows (no aggregates!)
- 3. GROUP BY — split rows into groups
- 4. HAVING — filter groups (aggregates OK here)
- 5. SELECT — compute columns, create aliases
- 6. DISTINCT — remove duplicate rows
- 7. ORDER BY — sort results (aliases work here!)
- 8. LIMIT/OFFSET — return subset

### Practice Exercises
Practice time! Exercise one: count employees per department. Exercise two: find total and average salary per department. Exercise three: use HAVING to show only departments with more than two employees. Exercise four: compare COUNT star versus COUNT bonus. Exercise five: combine WHERE and HAVING — only active employees, only departments averaging above seventy-five thousand. Try these yourself first!

- 1. COUNT employees per department, ordered by count
- 2. SUM and AVG salary per department
- 3. HAVING: departments with 3+ employees only
- 4. COUNT(*) vs COUNT(email) vs COUNT(bonus) — compare
- 5. WHERE active + GROUP BY dept + HAVING AVG(salary) > 75000
- 6. MIN and MAX hire_date per department (oldest/newest hire)
- 7. Department bonus report: total, average, percentage with bonus


---

## 3. Hands-On Commands & psql Output

### Setup: Sales and Employee Data
**Explanation:** Let us set up a sales table with realistic data. We have ten employees across four departments, with salaries, bonuses, emails, and hire dates. Some emails and bonuses are NULL — this will help us see how aggregates handle NULLs.

```sql
practice=# CREATE TABLE employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    email      VARCHAR(100),
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    bonus      NUMERIC(10,2),
    hire_date  DATE,
    is_active  BOOLEAN DEFAULT true
);
CREATE TABLE

practice=# INSERT INTO employees (name,email,department,salary,bonus,hire_date,is_active) VALUES
('Ravi','ravi@co.com','Engineering',95000,10000,'2022-03-15',true),
('Priya','priya@co.com','Engineering',88000,8000,'2023-06-01',true),
('Arjun','arjun@co.com','Marketing',72000,NULL,'2021-11-20',true),
('Meera','meera@co.com','Engineering',105000,15000,'2020-01-10',true),
('Kiran','kiran@co.com','Sales',68000,5000,'2024-02-14',true),
('Anita',NULL,'Marketing',75000,NULL,'2023-09-05',false),
('Deepak','deepak@co.com','Sales',71000,3000,'2022-07-22',true),
('Sonia','sonia@co.com','HR',82000,6000,'2021-04-30',true),
('Vikram','vikram@co.com','Engineering',92000,NULL,'2023-01-18',false),
('Neha','neha@co.com','HR',78000,4000,'2024-08-01',true);
INSERT 0 10
```

### Aggregate Functions — Whole Table Summary
**Explanation:** Let us start with the five core aggregate functions — without GROUP BY first. COUNT star counts ALL rows. SUM adds up a column. AVG calculates the average. MIN finds the smallest. MAX finds the largest. When used without GROUP BY, they summarize the ENTIRE table into a single row.

```sql
-- Aggregate the entire table into ONE row
practice=# SELECT
  COUNT(*)         AS total_employees,
  SUM(salary)      AS total_salary,
  ROUND(AVG(salary),2) AS avg_salary,
  MIN(salary)      AS lowest_salary,
  MAX(salary)      AS highest_salary
FROM employees;
 total_employees | total_salary | avg_salary | lowest_salary | highest_salary
-----------------+--------------+------------+---------------+----------------
              10 |    826000.00 |   82600.00 |      68000.00 |      105000.00
(1 row)
```

### COUNT(*) vs COUNT(column) vs COUNT(DISTINCT)
**Explanation:** Now the critical difference: COUNT star versus COUNT column. COUNT star counts ALL rows — including rows where a column is NULL. COUNT column counts only NON-NULL values in that column. COUNT DISTINCT counts unique non-null values. Watch: we have ten employees, but only nine have emails — Anita's email is NULL. COUNT star gives ten, COUNT email gives nine, COUNT DISTINCT department gives four.

```sql
practice=# SELECT
  COUNT(*)              AS all_rows,
  COUNT(email)          AS has_email,
  COUNT(bonus)          AS has_bonus,
  COUNT(DISTINCT department) AS dept_count
FROM employees;
 all_rows | has_email | has_bonus | dept_count
----------+-----------+-----------+------------
       10 |         9 |         7 |          4
(1 row)

-- COUNT(*) = 10 (all rows, including NULLs)
-- COUNT(email) = 9  (Anita's email is NULL)
-- COUNT(bonus) = 7  (3 employees have NULL bonus)
-- COUNT(DISTINCT department) = 4 unique departments
```

### NULL Handling in Aggregates
**Explanation:** Important rule: aggregate functions SKIP NULL values. SUM of bonus adds only the seven non-null bonuses — it does not treat NULL as zero. AVG of bonus averages over seven values, not ten. This can give you unexpected results if you forget. If you want to treat NULL as zero, wrap the column in COALESCE first — we learned that in the COALESCE class.

```sql
-- Aggregates SKIP NULLs — they don't count as zero
practice=# SELECT
  SUM(bonus) AS total_bonus,
  AVG(bonus) AS avg_bonus_wrong,
  AVG(COALESCE(bonus, 0)) AS avg_bonus_correct
FROM employees;
 total_bonus | avg_bonus_wrong | avg_bonus_correct
-------------+-----------------+-------------------
    51000.00 |  7285.714285714 |           5100.00
(1 row)

-- SUM(bonus) = 51000 (only 7 non-NULL values added)
-- AVG(bonus) = 51000/7 = 7285.71 (divides by 7, not 10!)
-- AVG(COALESCE(bonus,0)) = 51000/10 = 5100 (treats NULL as 0)
```

### GROUP BY — One Summary Per Group
**Explanation:** Now GROUP BY. Instead of one summary for the whole table, GROUP BY splits rows into groups and aggregates EACH group separately. GROUP BY department gives you one row per department — with the count, sum, and average for THAT department only. This is how you write department reports, monthly summaries, product breakdowns — any per-category analysis.

```sql
-- Group by department: one summary row per department
practice=# SELECT department,
  COUNT(*)         AS employees,
  ROUND(AVG(salary),2) AS avg_salary,
  MIN(salary)      AS min_salary,
  MAX(salary)      AS max_salary
FROM employees
GROUP BY department
ORDER BY avg_salary DESC;
 department  | employees | avg_salary | min_salary | max_salary
-------------+-----------+------------+------------+------------
 Engineering |         4 |   95000.00 |   88000.00 |  105000.00
 HR          |         2 |   80000.00 |   78000.00 |   82000.00
 Marketing   |         2 |   73500.00 |   72000.00 |   75000.00
 Sales       |         2 |   69500.00 |   68000.00 |   71000.00
(4 rows)
```

### The GROUP BY Rule — Must Group or Aggregate
**Explanation:** The golden rule of GROUP BY: every column in your SELECT must either be in the GROUP BY list OR inside an aggregate function. If you try to select a column that is not grouped and not aggregated, PostgreSQL gives an error. Why? Because if you group by department, there are multiple names in each department — PostgreSQL does not know which name to show. You must either group by it or aggregate it.

```sql
-- ERROR: name is not in GROUP BY and not aggregated
practice=# SELECT department, name, COUNT(*)
FROM employees GROUP BY department;
ERROR:  column "employees.name" must appear in the GROUP BY
clause or be used in an aggregate function

-- FIX 1: add name to GROUP BY
practice=# SELECT department, name, COUNT(*)
FROM employees GROUP BY department, name;
(10 rows)  -- one row per department+name combo

-- FIX 2: aggregate the name column
practice=# SELECT department, STRING_AGG(name, ', ') AS members, COUNT(*)
FROM employees GROUP BY department;
(4 rows)  -- one row per department with all names listed
```

### GROUP BY Multiple Columns
**Explanation:** You can GROUP BY multiple columns. This creates groups for each unique COMBINATION. Grouping by department and is_active gives you active Engineering employees as one group, inactive Engineering employees as another, and so on. Each combination gets its own summary row.

```sql
-- Group by department AND active status
practice=# SELECT department, is_active,
  COUNT(*) AS employees,
  ROUND(AVG(salary),2) AS avg_salary
FROM employees
GROUP BY department, is_active
ORDER BY department, is_active;
 department  | is_active | employees | avg_salary
-------------+-----------+-----------+------------
 Engineering | f         |         1 |   92000.00
 Engineering | t         |         3 |   96000.00
 HR          | t         |         2 |   80000.00
 Marketing   | f         |         1 |   75000.00
 Marketing   | t         |         1 |   72000.00
 Sales       | t         |         2 |   69500.00
(6 rows)
```

### HAVING — Filter Groups After Aggregation
**Explanation:** Now HAVING. WHERE filters individual ROWS before grouping. HAVING filters GROUPS after aggregation. Think of it this way: WHERE says which rows to include. HAVING says which groups to keep. You cannot use aggregate functions in WHERE — that is what HAVING is for. Want only departments with average salary above eighty thousand? That is a HAVING condition.

```sql
-- HAVING filters groups (WHERE filters rows)
practice=# SELECT department,
  COUNT(*) AS employees,
  ROUND(AVG(salary),2) AS avg_salary
FROM employees
GROUP BY department
HAVING AVG(salary) > 80000
ORDER BY avg_salary DESC;
 department  | employees | avg_salary
-------------+-----------+------------
 Engineering |         4 |   95000.00
(1 row)

-- Only Engineering has avg_salary > 80000
-- HR (80000) doesn't pass > 80000 (it's equal, not greater)
```

### WHERE + GROUP BY + HAVING Together
**Explanation:** Let us combine WHERE and HAVING in one query. First WHERE filters to only active employees, then GROUP BY groups them by department, then HAVING keeps only departments with two or more active employees. This is a very common pattern in real reporting queries.

```sql
-- WHERE filters rows, HAVING filters groups
practice=# SELECT department,
  COUNT(*) AS active_employees,
  ROUND(AVG(salary),2) AS avg_salary,
  SUM(salary) AS total_salary
FROM employees
WHERE is_active = true
GROUP BY department
HAVING COUNT(*) >= 2
ORDER BY total_salary DESC;
 department  | active_employees | avg_salary | total_salary
-------------+------------------+------------+--------------
 Engineering |                3 |   96000.00 |    288000.00
 HR          |                2 |   80000.00 |    160000.00
 Sales       |                2 |   69500.00 |    139000.00
(3 rows)

-- Marketing excluded: only 1 active employee (Arjun)
-- Anita (Marketing, inactive) filtered out by WHERE
```

### Aggregation with JOINs — Real-World Report
**Explanation:** Let us combine aggregation with JOINs. This is extremely common in production — aggregate data across joined tables. Here we group by department and calculate how many employees got a bonus and the total bonus paid per department. The NULL bonuses are handled automatically — COUNT bonus skips NULLs, SUM uses COALESCE to treat NULL as zero.

```sql
-- Department summary with bonus analysis
practice=# SELECT department,
  COUNT(*) AS total,
  COUNT(bonus) AS with_bonus,
  COUNT(*) - COUNT(bonus) AS no_bonus,
  SUM(COALESCE(bonus,0)) AS total_bonus,
  ROUND(AVG(salary),0) AS avg_salary
FROM employees
GROUP BY department
ORDER BY total_bonus DESC;
 department  | total | with_bonus | no_bonus | total_bonus | avg_salary
-------------+-------+------------+----------+-------------+------------
 Engineering |     4 |          3 |        1 |       33000 |      95000
 HR          |     2 |          2 |        0 |       10000 |      80000
 Sales       |     2 |          2 |        0 |        8000 |      69500
 Marketing   |     2 |          0 |        2 |           0 |      73500
(4 rows)
```

### Common Errors with GROUP BY and HAVING
**Explanation:** A common mistake is trying to use an alias in HAVING. Remember the SQL execution order — SELECT runs AFTER HAVING. So aliases defined in SELECT do not exist when HAVING runs. You must repeat the aggregate expression in HAVING. Another mistake is using HAVING where WHERE should go — if the condition does not involve an aggregate, use WHERE. It is faster because it filters before grouping.

```sql
-- Error 1: Using alias in HAVING
practice=# SELECT department, AVG(salary) AS avg_sal
FROM employees GROUP BY department HAVING avg_sal > 80000;
ERROR:  column "avg_sal" does not exist

-- FIX: repeat the expression
practice=# SELECT department, AVG(salary) AS avg_sal
FROM employees GROUP BY department HAVING AVG(salary) > 80000;
(1 row)  -- works!

-- Error 2: Using HAVING without aggregate (use WHERE instead!)
-- BAD:  ... GROUP BY dept HAVING dept = 'Engineering'
-- GOOD: ... WHERE dept = 'Engineering' GROUP BY dept
-- WHERE is faster — filters rows BEFORE grouping
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. COUNT, SUM, AVG, MIN, MAX are the five core aggregate functions. All aggregates skip NULL values — use COALESCE if you want to treat NULL as zero. GROUP BY splits rows into groups and aggregates each group separately. Every SELECT column must be in GROUP BY or inside an aggregate function. WHERE filters rows BEFORE grouping. HAVING filters groups AFTER aggregation. In the next class, we cover GROUPING SETS, ROLLUP, CUBE, and the FILTER clause for advanced grouping. See you there!

- **COUNT(*) counts all rows; COUNT(col) skips NULLs**
- **SUM, AVG, MIN, MAX all skip NULL values**
- **AVG(COALESCE(col,0)) to include NULLs as zero**
- **GROUP BY: one summary per group (department, month...)**
- **SELECT columns must be in GROUP BY or aggregated**
- **WHERE filters rows BEFORE grouping (no aggregates)**
- **HAVING filters groups AFTER aggregation (aggregates OK)**
- **Execution: FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY**


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


---

## 8. Answer Key — Verified Practice Solutions

### Challenge 1: Department Employee Count
```sql
SELECT department, COUNT(*) AS employees
FROM employees
GROUP BY department
ORDER BY employees DESC;
```
*Why:* Groups all rows sharing identical department values into single summary rows.

### Challenge 2: Total Payroll & Rounded Average
```sql
SELECT department,
       SUM(salary) AS total_payroll,
       ROUND(AVG(salary), 2) AS avg_salary
FROM employees
GROUP BY department
ORDER BY total_payroll DESC;
```
*Why:* Computes cumulative and arithmetic mean values, rounding decimals to avoid precision noise.

### Challenge 3: Post-Aggregation Filtering with HAVING
```sql
SELECT department, COUNT(*) AS employees
FROM employees
GROUP BY department
HAVING COUNT(*) >= 3;
```
*Why:* WHERE cannot filter aggregate outputs because it executes before grouping occurs; HAVING runs post-aggregation.

### Challenge 4: NULL Exclusion in Aggregate Counting
```sql
SELECT
  COUNT(*) AS all_rows,
  COUNT(email) AS has_email,
  COUNT(bonus) AS has_bonus
FROM employees;
```
*Why:* `COUNT(*)` counts physical records including NULLs; `COUNT(column)` ignores NULL values.

### Challenge 5: Full Execution Pipeline (WHERE + GROUP BY + HAVING)
```sql
SELECT department, ROUND(AVG(salary), 2) AS avg_salary
FROM employees
WHERE is_active = true
GROUP BY department
HAVING AVG(salary) > 75000
ORDER BY avg_salary DESC;
```
*Why:* Demonstrates logical execution order: rows are filtered first (`WHERE`), grouped second (`GROUP BY`), and groups filtered last (`HAVING`).
