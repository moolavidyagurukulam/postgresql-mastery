# Window Functions Part 1 — ROW_NUMBER, RANK, DENSE_RANK & NTILE
**Series:** PostgreSQL Mastery | **Phase:** Phase 10: Advanced SQL | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! Window functions are one of the most powerful features in SQL. They let you perform calculations ACROSS related rows without collapsing them into groups like GROUP BY does. In this class, we focus on ranking functions — ROW_NUMBER, RANK, DENSE_RANK, and NTILE. You will learn how OVER, PARTITION BY, and ORDER BY work together to create windows. Let us dive in.


---

## 2. Core Technical Concepts & Mechanisms

### GROUP BY vs Window Functions
Here is the problem window functions solve. With GROUP BY, you get ONE row per group — the individual rows disappear. But what if you want to see EVERY row AND also see how each row compares to its group? For example, you want each employee's salary AND their salary rank within their department — without losing any rows. Window functions do exactly this: they compute a value for each row based on a set of related rows called a window.

| GROUP BY (collapses rows) | Window Function (keeps rows) |
| :--- | :--- |
| SELECT dept, AVG(salary) | SELECT name, dept, salary, |
| FROM employees GROUP BY dept; | AVG(salary) OVER(PARTITION BY dept) |
| → ONE row per department | → ALL rows preserved |
| → Individual employees gone | → Each row shows dept average too |
| → Can't see who earns what | → Compare individual to group |

### Window Function Syntax
The syntax of a window function has three parts. The function name — like ROW_NUMBER or RANK. Then the OVER clause which defines the window. Inside OVER, PARTITION BY divides rows into groups, and ORDER BY sorts rows within each group. PARTITION BY is optional — without it, the entire result set is one window. ORDER BY inside OVER defines the ranking or calculation order.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Function** | ROW_NUMBER(), RANK(), DENSE_RANK(), NTILE(n) |
| **OVER()** | Defines the window — required for every window function |
| **PARTITION BY** | Divides rows into groups (like GROUP BY but keeps rows) |
| **ORDER BY** | Sorts rows WITHIN each partition for ranking |
| **Full Form** | RANK() OVER(PARTITION BY dept ORDER BY salary DESC) |

**Notes:**
- PARTITION BY is optional; ORDER BY is required for ranking functions

### ROW_NUMBER vs RANK vs DENSE_RANK with Ties
Let me show you the difference with actual ties. If we add employees with the same salary, RANK skips numbers but DENSE_RANK does not. This is the most commonly tested interview question about window functions — know the difference between ROW_NUMBER, RANK, and DENSE_RANK.

| Term | Meaning / Explanation |
| :--- | :--- |
| **If we add employees with the same salary** | RANK skips numbers but DENSE_RANK does not |
| **Point 2** | This is the most commonly tested interview question about window functions — know the difference between ROW_NUMBER, RANK, and DENSE_RANK |

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Window Function Processing Order
Important rule: you CANNOT use a window function in WHERE. Window functions run AFTER WHERE and GROUP BY in query processing. To filter by a window function result, wrap the query in a subquery or CTE, then filter in the outer query. This is why the top-N pattern uses a subquery.

| SQL Evaluation Order | Consequence |
| :--- | :--- |
| 1. FROM / JOIN | WHERE runs BEFORE window functions |
| 2. WHERE | Cannot filter by ROW_NUMBER() in WHERE |
| 3. GROUP BY | Cannot use RANK() in HAVING |
| 4. HAVING | Solution: subquery or CTE |
| 5. Window Functions ← here! | Wrap query, then filter outer WHERE |
| 6. SELECT | This is NOT a PostgreSQL limitation |
| 7. DISTINCT | It is part of the SQL standard |
| 8. ORDER BY / LIMIT | Every database works this way |

### Practice Exercises
Practice exercises: use ROW_NUMBER with PARTITION BY, compare RANK and DENSE_RANK with ties, use NTILE for quartiles, and implement the top-N per group pattern. These are the building blocks for more advanced window functions in the next class.

- 1. ROW_NUMBER() OVER(ORDER BY salary DESC) — rank all employees
- 2. ROW_NUMBER() with PARTITION BY department — rank within dept
- 3. Compare RANK vs DENSE_RANK (add duplicate salaries first)
- 4. NTILE(4) — split into quartiles by salary
- 5. Top 2 per department using subquery + ROW_NUMBER
- 6. Top 1 per department using CTE + ROW_NUMBER
- 7. EXPLAIN a window function query — see WindowAgg node


---

## 3. Hands-On Commands & psql Output

### ROW_NUMBER — Unique Sequential Number
**Explanation:** ROW_NUMBER assigns a unique sequential number to each row within its partition. No ties — every row gets a different number. If two employees have the same salary, which one gets the lower number is arbitrary unless you add a tiebreaker to ORDER BY. Let us see it in action.

```sql
-- Rank employees by salary within each department
practice=# SELECT name, department, salary,
  ROW_NUMBER() OVER(
    PARTITION BY department ORDER BY salary DESC
  ) AS row_num
FROM employees;
  name  | department  | salary  | row_num
--------+-------------+---------+---------
 Ravi   | Engineering |  95000  |       1
 Arjun  | Engineering |  92000  |       2
 Priya  | Engineering |  88000  |       3
 Vikram | Engineering |  82000  |       4
 Meera  | Executive   | 120000  |       1
 Sonia  | HR          |  85000  |       1
 Kiran  | HR          |  78000  |       2

-- Each department restarts at 1
-- Every row gets a UNIQUE number
```

### RANK vs DENSE_RANK — Handling Ties
**Explanation:** RANK and DENSE_RANK handle ties differently. RANK gives the same number to tied rows but then SKIPS numbers. If two people are tied at rank two, the next person gets rank four — rank three is skipped. DENSE_RANK also gives tied rows the same number, but does NOT skip. After a tie at rank two, the next person gets rank three. Use RANK when you care about positional rank, DENSE_RANK when you care about distinct rank values.

```sql
-- Compare all three ranking functions
practice=# SELECT name, salary,
  ROW_NUMBER() OVER(ORDER BY salary DESC) AS row_num,
  RANK()       OVER(ORDER BY salary DESC) AS rank,
  DENSE_RANK() OVER(ORDER BY salary DESC) AS dense_rank
FROM employees;
  name  | salary  | row_num | rank | dense_rank
--------+---------+---------+------+------------
 Meera  | 120000  |       1 |    1 |          1
 Ravi   |  95000  |       2 |    2 |          2
 Arjun  |  92000  |       3 |    3 |          3
 Priya  |  88000  |       4 |    4 |          4
 Sonia  |  85000  |       5 |    5 |          5
 Vikram |  82000  |       6 |    6 |          6
 Kiran  |  78000  |       7 |    7 |          7

-- No ties here, so all three are identical
-- Ties make the difference (see materials.sql)
```

### NTILE — Divide Rows into Buckets
**Explanation:** NTILE divides rows into a specified number of equal buckets. NTILE four splits rows into four groups — quartiles. NTILE three splits into three. If rows do not divide evenly, earlier groups get one extra row. NTILE is useful for creating percentile buckets, splitting data for parallel processing, or assigning balanced workloads.

```sql
-- Split employees into salary quartiles
practice=# SELECT name, salary,
  NTILE(4) OVER(ORDER BY salary DESC) AS quartile
FROM employees;
  name  | salary  | quartile
--------+---------+----------
 Meera  | 120000  |        1  ← top 25%
 Ravi   |  95000  |        1
 Arjun  |  92000  |        2
 Priya  |  88000  |        2
 Sonia  |  85000  |        3
 Vikram |  82000  |        3
 Kiran  |  78000  |        4  ← bottom 25%

-- NTILE(4) = quartiles
-- NTILE(3) = terciles
-- NTILE(100) = percentiles
```

### Top N Per Group — Classic Pattern
**Explanation:** A common use case: get the top N per group. For example, the top two highest-paid employees per department. You cannot do this easily with GROUP BY, but with ROW_NUMBER and a subquery it is straightforward. Assign row numbers within each partition, then filter for row_num less than or equal to two.

```sql
-- Top 2 earners per department
practice=# SELECT * FROM (
  SELECT name, department, salary,
    ROW_NUMBER() OVER(
      PARTITION BY department ORDER BY salary DESC
    ) AS rn
  FROM employees
) ranked
WHERE rn <= 2;
  name  | department  | salary  | rn
--------+-------------+---------+----
 Ravi   | Engineering |  95000  |  1
 Arjun  | Engineering |  92000  |  2
 Meera  | Executive   | 120000  |  1
 Sonia  | HR          |  85000  |  1
 Kiran  | HR          |  78000  |  2

-- Can't filter directly: use subquery or CTE
-- WHERE ROW_NUMBER() <= 2 is NOT allowed!
```


---

## 6. Hands-On Practice Exercises & Verified Answer Key

### Practice Challenges

1. **Global Ranking:** Assign a unique sequential integer ranking from 1 to N across all employees ordered by `salary DESC` using `ROW_NUMBER()`.
2. **Departmental Partitioning:** Reset ranking for each department using `PARTITION BY department ORDER BY salary DESC`.
3. **Tie Resolution Comparison:** Query the `salary_demo` table to simultaneously compute `ROW_NUMBER()`, `RANK()`, and `DENSE_RANK()` ordered by `salary DESC` to observe how ties (duplicate salaries) are handled.
4. **Quartile Segmentation:** Divide all employees into 4 equal compensation buckets (quartiles) using `NTILE(4)` ordered by `salary ASC`.
5. **Top-N Per Group Filter:** Write a Common Table Expression (CTE) to find the top 2 highest-paid employees in each department. (Explain why `WHERE ROW_NUMBER() <= 2` fails in a single query).

---

### Verified Solutions & Explanations

#### Exercise 1: Global Sequential Ranking
```sql
SELECT name, department, salary,
  ROW_NUMBER() OVER(ORDER BY salary DESC) AS rank
FROM employees;
```
*Explanation:* `ROW_NUMBER()` guarantees unique sequential numbers from 1 to N without gaps or ties, even if two rows share identical salaries.

#### Exercise 2: Departmental Partitioning
```sql
SELECT name, department, salary,
  ROW_NUMBER() OVER(
    PARTITION BY department ORDER BY salary DESC
  ) AS dept_rank
FROM employees;
```
*Explanation:* `PARTITION BY department` divides the rows into separate evaluation windows. The row counter restarts at 1 for each new department.

#### Exercise 3: Tie Comparison (ROW_NUMBER vs RANK vs DENSE_RANK)
```sql
SELECT name, salary,
  ROW_NUMBER() OVER(ORDER BY salary DESC) AS rn,
  RANK()       OVER(ORDER BY salary DESC) AS rnk,
  DENSE_RANK() OVER(ORDER BY salary DESC) AS drnk
FROM salary_demo;
```
*Result Breakdown:*
| name  | salary | rn | rnk | drnk |
| :---  | :---   | :- | :-- | :--- |
| Alice | 90000  | 1  | 1   | 1    |
| Bob   | 85000  | 2  | 2   | 2    |
| Carol | 85000  | 3  | 2   | 2    |
| Dave  | 80000  | 4  | 4   | 3    |
| Eve   | 75000  | 5  | 5   | 4    |
*Notice:* `RANK()` skips rank 3 after two rows tie at rank 2 (`1, 2, 2, 4`), while `DENSE_RANK()` continues without skipping (`1, 2, 2, 3`).

#### Exercise 4: Compensation Quartiles
```sql
SELECT name, salary,
  NTILE(4) OVER(ORDER BY salary ASC) AS quartile
FROM employees;
```
*Explanation:* `NTILE(4)` splits sorted rows into 4 equal buckets. If row count is not evenly divisible by 4, extra rows are distributed to the first buckets.

#### Exercise 5: Top 2 Per Department via CTE
```sql
WITH ranked AS (
  SELECT name, department, salary,
    ROW_NUMBER() OVER(
      PARTITION BY department ORDER BY salary DESC
    ) AS rn
  FROM employees
)
SELECT department, name, salary, rn
FROM ranked
WHERE rn <= 2
ORDER BY department, rn;
```
*Explanation:* In PostgreSQL query execution order, `WHERE` is evaluated before window functions in `SELECT`. To filter by rank, compute the rank inside a CTE or subquery first, then filter the outer query with `WHERE rn <= 2`.


## 7. Key Takeaways & Cheat Sheet

Let us recap. Window functions compute values across related rows without collapsing groups. OVER defines the window, PARTITION BY divides into groups, ORDER BY sorts within partitions. ROW_NUMBER gives unique sequential numbers. RANK handles ties by skipping numbers. DENSE_RANK handles ties without skipping. NTILE divides rows into equal buckets. For top-N per group, use ROW_NUMBER in a subquery. Window functions cannot be used in WHERE — use a subquery instead. In the next class, we cover LAG, LEAD, running totals, and frame clauses. See you there!

- **OVER() required for every window function**
- **PARTITION BY: divide into groups (optional)**
- **ORDER BY inside OVER: sort within partitions**
- **ROW_NUMBER: unique 1,2,3... (no ties)**
- **RANK: ties get same number, then skip (1,2,2,4)**
- **DENSE_RANK: ties same, no skip (1,2,2,3)**
- **NTILE(n): divide into n equal buckets**
- **Top-N per group: ROW_NUMBER + subquery + WHERE rn <= N**


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
