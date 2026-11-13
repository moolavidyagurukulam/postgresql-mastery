# Subqueries — WHERE, FROM, SELECT, EXISTS, ANY & ALL
**Series:** PostgreSQL Mastery | **Phase:** Phase 8: Subqueries & CTEs | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn subqueries — queries inside queries. We will use them in WHERE, FROM, and SELECT clauses. We will learn EXISTS, IN, ANY, and ALL operators. And we will understand the difference between correlated and non-correlated subqueries. Let us get started.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should know SELECT, WHERE, JOINs, and aggregate functions — all covered in previous phases. In the Aggregation class, we learned to compute averages and counts. But what if you want to find employees who earn MORE than the average? You need the average first, then compare each employee to it. That is a query that depends on another query — a subquery.

- You know SELECT, WHERE, JOINs, GROUP BY, HAVING
- You know aggregate functions: COUNT, SUM, AVG
- Previous class: GROUPING SETS, ROLLUP, CUBE
- New problem: queries that depend on other queries
- Example: employees earning more than the average
- Solution: subqueries — a query INSIDE another query

### What Is a Subquery?
A subquery is simply a SELECT statement placed inside another SQL statement — wrapped in parentheses. The inner query runs first and produces a result. The outer query then uses that result. Think of it like this: you ask one question to get a number, then use that number to ask a bigger question. Subqueries can go in three places: in WHERE to filter, in FROM as a virtual table, and in SELECT to compute a value per row.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Subquery** | A SELECT inside another SQL statement, wrapped in parentheses |
| **In WHERE** | Filter rows based on another query's result |
| **In FROM** | Use a query result as a virtual table (derived table) |
| **In SELECT** | Compute a value per row from another query |

**Notes:**
- Inner query runs first → outer query uses the result

### Correlated vs Non-Correlated Subqueries
What is the difference between a correlated and non-correlated subquery? A non-correlated subquery is independent — it runs ONCE, produces a result, and the outer query uses it. Like the average salary example. A correlated subquery references the outer query — it runs ONCE FOR EACH ROW of the outer query. Like the EXISTS example — for each employee, it checks if orders exist. Correlated subqueries can be slower because they run many times.

| Non-Correlated | Correlated |
| :--- | :--- |
| Independent of outer query | References the outer query's row |
| Runs ONCE, result reused | Runs ONCE PER ROW of outer query |
| WHERE salary > (SELECT AVG(salary)...) | WHERE EXISTS (... WHERE o.emp_id = e.id) |
| Fast — single execution | Can be slower on large tables |
| Inner query has NO reference to outer | Inner query uses e.id from outer |

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. You can download today's class materials and practice files from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Every bit helps us keep creating. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Subquery vs JOIN — When to Use Each
When should you use a subquery versus a JOIN? If you need to filter based on existence — use EXISTS or IN with a subquery. If you need to combine columns from both tables — use a JOIN. If you need aggregation first then filtering — a derived table subquery or CTE works well. EXISTS is usually faster than IN for large tables because it stops at the first match. NOT IN has a dangerous NULL trap — if the subquery returns ANY NULL value, the entire NOT IN returns empty. Always prefer NOT EXISTS over NOT IN.

| Use Subquery | Use JOIN |
| :--- | :--- |
| Existence check: EXISTS / NOT EXISTS | Need columns from BOTH tables |
| Scalar comparison: salary > (SELECT AVG...) | Multiple matches per row needed |
| ANY / ALL comparisons | Better for large result sets |
| Derived tables for pre-aggregation | Easier to read for simple combinations |
| NOT EXISTS safer than NOT IN with NULLs | Optimizer handles JOINs very well |

### Practice Exercises
Practice time! Exercise one: find employees earning above the company average. Exercise two: use IN to find employees who placed orders. Exercise three: use EXISTS for the same. Exercise four: NOT EXISTS to find employees without orders. Exercise five: ANY to compare against a department. Exercise six: derived table to find the top earner per department. Exercise seven: scalar subquery in SELECT showing department average. Try these yourself!

- 1. Scalar: employees earning above company AVG
- 2. IN: employees who have placed at least one order
- 3. EXISTS: same as #2 but using EXISTS
- 4. NOT EXISTS: employees with zero orders
- 5. ALL: salary > ALL Sales salaries
- 6. Derived table: top earner per department
- 7. Scalar in SELECT: each row with dept AVG and difference


---

## 3. Hands-On Commands & psql Output

### Setup: Employees and Orders Tables
**Explanation:** Let us set up our practice tables. We have employees with departments and salaries, and orders linked to customers. These will demonstrate every subquery pattern.

```sql
practice=# CREATE TABLE employees (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    department VARCHAR(50),
    salary     NUMERIC(10,2)
);
CREATE TABLE
practice=# INSERT INTO employees (name,department,salary) VALUES
('Ravi','Engineering',95000),('Priya','Engineering',88000),
('Arjun','Marketing',72000),('Meera','Engineering',105000),
('Kiran','Sales',68000),('Anita','Marketing',75000),
('Deepak','Sales',71000),('Sonia','HR',82000),
('Vikram','Engineering',92000),('Neha','HR',78000);
INSERT 0 10

practice=# CREATE TABLE orders (
    id          INT PRIMARY KEY,
    employee_id INT REFERENCES employees(id),
    product     VARCHAR(50),
    amount      NUMERIC(10,2)
);
CREATE TABLE
practice=# INSERT INTO orders VALUES
(1,1,'Laptop',75000),(2,1,'Mouse',1500),(3,2,'Keyboard',3000),
(4,3,'Monitor',25000),(5,5,'Headphones',4000),(6,8,'Webcam',2500);
INSERT 0 6
```

### Subquery in WHERE — Scalar (One Value)
**Explanation:** The most common subquery: in WHERE with a scalar value. A scalar subquery returns exactly ONE value — one row, one column. Here we find employees earning more than the average salary. The inner query calculates the average — eighty-two thousand six hundred. The outer query compares each employee's salary to that number. Four employees earn above average.

```sql
-- Find employees earning more than average
practice=# SELECT name, salary
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees);
  name  |  salary
--------+-----------
 Ravi   |  95000.00
 Priya  |  88000.00
 Meera  | 105000.00
 Vikram |  92000.00
(4 rows)

-- Inner query: SELECT AVG(salary) → 82600.00
-- Outer query: WHERE salary > 82600.00
```

### Subquery in WHERE — IN (Multiple Values)
**Explanation:** Subquery in WHERE with IN — when the inner query returns MULTIPLE values. Here we find employees who have placed at least one order. The inner query gets all employee IDs from the orders table. The outer query finds employees whose ID is IN that list. This is similar to a JOIN, but sometimes reads more naturally.

```sql
-- Employees who have placed orders
practice=# SELECT name, department
FROM employees
WHERE id IN (SELECT DISTINCT employee_id FROM orders);
  name  | department
--------+-------------
 Ravi   | Engineering
 Priya  | Engineering
 Arjun  | Marketing
 Kiran  | Sales
 Sonia  | HR
(5 rows)

-- NOT IN: employees who have NOT placed any order
practice=# SELECT name FROM employees
WHERE id NOT IN (SELECT employee_id FROM orders);
  name
--------
 Meera
 Anita
 Deepak
 Vikram
 Neha
(5 rows)
```

### EXISTS — Does At Least One Match Exist?
**Explanation:** EXISTS is a powerful alternative to IN. EXISTS returns true if the subquery returns ANY rows at all — it does not care about the actual values. It is a yes-or-no check: does at least one matching row exist? EXISTS is typically FASTER than IN for large datasets because it can stop as soon as it finds the first match. The subquery inside EXISTS is usually a CORRELATED subquery — it references the outer query's row.

```sql
-- EXISTS: employees who have at least one order
practice=# SELECT e.name, e.department
FROM employees e
WHERE EXISTS (
  SELECT 1 FROM orders o WHERE o.employee_id = e.id
);
  name  | department
--------+-------------
 Ravi   | Engineering
 Priya  | Engineering
 Arjun  | Marketing
 Kiran  | Sales
 Sonia  | HR
(5 rows)

-- NOT EXISTS: employees with ZERO orders
practice=# SELECT e.name FROM employees e
WHERE NOT EXISTS (
  SELECT 1 FROM orders o WHERE o.employee_id = e.id);
(5 rows)  -- Meera, Anita, Deepak, Vikram, Neha
```

### ANY and ALL — Compare Against a Set
**Explanation:** ANY and ALL let you compare a value against a SET of values from a subquery. ANY means: is this true for AT LEAST ONE value in the set? ALL means: is this true for EVERY value in the set? Salary greater than ANY subquery means: greater than the SMALLEST value. Salary greater than ALL subquery means: greater than the LARGEST value. Think of ANY as 'at least one' and ALL as 'every single one'.

```sql
-- ANY: salary > at least one Marketing salary
practice=# SELECT name, salary FROM employees
WHERE salary > ANY (
  SELECT salary FROM employees WHERE department = 'Marketing'
);
  name   |  salary
---------+-----------
 Ravi    |  95000.00
 Priya   |  88000.00
 Meera   | 105000.00
 Anita   |  75000.00
 Sonia   |  82000.00
 Vikram  |  92000.00
 Neha    |  78000.00
(7 rows)

-- Marketing salaries: 72000, 75000
-- > ANY means > 72000 (the smallest)
-- > ALL would mean > 75000 (the largest)
```

### ALL — Greater Than Every Value in the Set
**Explanation:** Now ALL — salary greater than ALL Marketing salaries means greater than the HIGHEST Marketing salary, which is seventy-five thousand. Only employees above seventy-five thousand qualify. ALL is stricter than ANY.

```sql
-- ALL: salary > every Marketing salary (> 75000)
practice=# SELECT name, salary FROM employees
WHERE salary > ALL (
  SELECT salary FROM employees WHERE department = 'Marketing'
)
ORDER BY salary DESC;
  name  |  salary
--------+-----------
 Meera  | 105000.00
 Ravi   |  95000.00
 Vikram |  92000.00
 Priya  |  88000.00
 Sonia  |  82000.00
 Neha   |  78000.00
(6 rows)

-- > ALL (72000, 75000) means > 75000
-- Kiran(68000), Arjun(72000), Anita(75000) excluded
```

### Subquery in FROM — Derived Table
**Explanation:** Subquery in FROM — also called a derived table. You write a SELECT in the FROM clause and give it an alias. The outer query treats it like a regular table. This is useful when you need to aggregate first, then filter or join the results. Here we find the highest-paid employee in each department by first computing max salary per department, then joining back.

```sql
-- Derived table: aggregate first, then join
practice=# SELECT e.name, e.department, e.salary
FROM employees e
INNER JOIN (
  SELECT department, MAX(salary) AS max_sal
  FROM employees GROUP BY department
) dept_max ON e.department = dept_max.department
           AND e.salary = dept_max.max_sal
ORDER BY e.salary DESC;
  name  | department  |  salary
--------+-------------+-----------
 Meera  | Engineering | 105000.00
 Sonia  | HR          |  82000.00
 Anita  | Marketing   |  75000.00
 Deepak | Sales       |  71000.00
(4 rows)

-- Inner query: max salary per department
-- Outer query: find employees matching that max
```

### Subquery in SELECT — Per-Row Calculation
**Explanation:** Subquery in SELECT — a scalar subquery that computes one value per row. Here we show each employee's salary alongside the department average. The subquery runs for each row, computing the average for THAT employee's department. This is a correlated subquery — it uses e dot department from the outer query.

```sql
-- Scalar subquery in SELECT: department avg per row
practice=# SELECT name, department, salary,
  ROUND((SELECT AVG(salary) FROM employees e2
         WHERE e2.department = e.department), 2) AS dept_avg,
  salary - (SELECT AVG(salary) FROM employees e2
            WHERE e2.department = e.department) AS diff
FROM employees e
ORDER BY diff DESC;
  name   | department  |  salary   | dept_avg  |    diff
---------+-------------+-----------+-----------+-----------
 Meera   | Engineering | 105000.00 |  95000.00 |  10000.00
 Sonia   | HR          |  82000.00 |  80000.00 |   2000.00
 Anita   | Marketing   |  75000.00 |  73500.00 |   1500.00
 Deepak  | Sales       |  71000.00 |  69500.00 |   1500.00
 Ravi    | Engineering |  95000.00 |  95000.00 |      0.00
(10 rows)

-- Correlated: e2.department = e.department (references outer)
```

### The NOT IN NULL Trap — Critical Gotcha!
**Explanation:** The NOT IN NULL trap is a critical beginner mistake. If the subquery in NOT IN returns even ONE NULL value, the entire result is EMPTY — zero rows. Why? Because 'value NOT IN a list containing NULL' is UNKNOWN in SQL, not true. The fix: always use NOT EXISTS instead of NOT IN, or add WHERE column IS NOT NULL inside the subquery.

```sql
-- Add an order with NULL employee_id
practice=# INSERT INTO orders VALUES (7, NULL, 'Cable', 500);
INSERT 0 1

-- NOT IN with NULL in subquery = EMPTY RESULT!
practice=# SELECT name FROM employees
WHERE id NOT IN (SELECT employee_id FROM orders);
(0 rows)  -- WRONG! Should return 5 employees!

-- FIX 1: NOT EXISTS (always safe)
practice=# SELECT e.name FROM employees e
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.employee_id = e.id);
(5 rows)  -- correct!

-- FIX 2: exclude NULLs in subquery
-- WHERE id NOT IN (SELECT employee_id FROM orders WHERE employee_id IS NOT NULL)
```

### Practical Subquery Patterns
**Explanation:** Let us look at a few more practical patterns. Employees earning more than the average of their own department — a correlated scalar subquery. And finding the department with the highest total salary — a subquery using ORDER BY and LIMIT inside another query. These patterns come up constantly in real applications.

```sql
-- Employees above their department's average
practice=# SELECT name, department, salary FROM employees e
WHERE salary > (
  SELECT AVG(salary) FROM employees
  WHERE department = e.department)
ORDER BY salary DESC;
  name  | department  |  salary
--------+-------------+-----------
 Meera  | Engineering | 105000.00
 Ravi   | Engineering |  95000.00
 Sonia  | HR          |  82000.00
 Anita  | Marketing   |  75000.00
 Deepak | Sales       |  71000.00
(5 rows)

-- Correlated: WHERE department = e.department
-- Each row compared against its OWN department's average
```

### Common Subquery Errors
**Explanation:** Here are the common subquery errors. First: returning more than one row where a scalar is expected — this happens when your WHERE equals a subquery that returns multiple rows. Use IN instead of equals. Second: the NOT IN NULL trap we just saw. Third: forgetting the alias on a derived table in FROM — PostgreSQL requires it.

```sql
-- Error 1: Subquery returns more than one row
practice=# SELECT name FROM employees
WHERE salary = (SELECT salary FROM employees WHERE department = 'Engineering');
ERROR:  more than one row returned by a subquery
used as an expression

-- FIX: use IN instead of =
practice=# SELECT name FROM employees
WHERE salary IN (SELECT salary FROM employees WHERE department = 'Engineering');
(4 rows)  -- works!

-- Error 2: Missing alias on derived table
-- SELECT * FROM (SELECT department, COUNT(*) FROM employees GROUP BY department);
-- ERROR: subquery in FROM must have an alias
-- FIX: add AS dept_counts at the end
```


---

## 5. Common Beginner Traps & How to Fix Them

### The NOT IN NULL Trap — Critical Gotcha!
The NOT IN NULL trap is a critical beginner mistake. If the subquery in NOT IN returns even ONE NULL value, the entire result is EMPTY — zero rows. Why? Because 'value NOT IN a list containing NULL' is UNKNOWN in SQL, not true. The fix: always use NOT EXISTS instead of NOT IN, or add WHERE column IS NOT NULL inside the subquery.

```sql
-- Add an order with NULL employee_id
INSERT INTO orders VALUES (7, NULL, 'Cable', 500);
INSERT 0 1

-- NOT IN with NULL in subquery = EMPTY RESULT!
SELECT name FROM employees
WHERE id NOT IN (SELECT employee_id FROM orders);
(0 rows)  -- WRONG! Should return 5 employees!

-- FIX 1: NOT EXISTS (always safe)
SELECT e.name FROM employees e
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.employee_id = e.id);
(5 rows)  -- correct!

-- FIX 2: exclude NULLs in subquery
-- WHERE id NOT IN (SELECT employee_id FROM orders WHERE employee_id IS NOT NULL)
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. Subqueries are queries inside queries, wrapped in parentheses. In WHERE: scalar for comparisons, IN for lists, EXISTS for existence checks. In FROM: derived tables for pre-aggregation. In SELECT: scalar subqueries for per-row values. Non-correlated subqueries run once. Correlated subqueries run per row. EXISTS is faster than IN for large tables. NOT EXISTS is SAFER than NOT IN because of the NULL trap. In the next class, we learn CTEs — Common Table Expressions — the WITH clause that makes complex queries readable, plus recursive CTEs for hierarchies. See you there!

- **WHERE scalar: salary > (SELECT AVG(salary) ...)**
- **WHERE IN: id IN (SELECT emp_id FROM orders)**
- **WHERE EXISTS: checks if any row matches (fast)**
- **FROM derived table: pre-aggregate then join**
- **SELECT scalar: per-row calculation from subquery**
- **Non-correlated: runs once (fast, independent)**
- **Correlated: runs per row (uses outer query values)**
- **NOT EXISTS > NOT IN (NULL trap with NOT IN!)**


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

### Challenge 1: Scalar Baseline Filtering
```sql
SELECT name, salary
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees)
ORDER BY salary DESC;
```
*Why:* Evaluates inner aggregate once, returning an atomic scalar value compared against each outer row.

### Challenge 2: Membership Testing with IN
```sql
SELECT name
FROM employees
WHERE id IN (SELECT DISTINCT employee_id FROM orders);
```
*Why:* Checks whether the employee's primary key exists within the list of ordering staff.

### Challenge 3: Efficient Correlated Search with EXISTS
```sql
SELECT e.name
FROM employees e
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.employee_id = e.id);
```
*Why:* Binds outer employee row to inner order table; halts execution immediately upon finding first matching index tuple.

### Challenge 4: Safe Anti-Join with NOT EXISTS
```sql
SELECT e.name
FROM employees e
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.employee_id = e.id);
```
*Why:* Protects queries against the famous NOT IN NULL trap: if a subquery contains even one NULL, `NOT IN` returns nothing.

### Challenge 5: Universal Quantifier with > ALL
```sql
SELECT name, salary
FROM employees
WHERE salary > ALL (SELECT salary FROM employees WHERE department = 'Sales')
ORDER BY salary;
```
*Why:* Evaluates whether salary strictly exceeds the maximum scalar value in the Sales compensation set.
