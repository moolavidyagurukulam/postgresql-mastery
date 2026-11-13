# SELF JOIN, NATURAL JOIN, USING, Multi-table Joins & Performance
**Series:** PostgreSQL Mastery | **Phase:** Phase 6: JOINs | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn SELF JOIN — joining a table to itself, NATURAL JOIN and the USING clause, joining three or more tables together, and how to check join performance with EXPLAIN. Let us get started.

### The Problem: Manager Hierarchy in One Table
Imagine you have an employees table. Each employee has a manager. But the manager is ALSO an employee in the same table. The manager_id column points to another row in the SAME table. How do you show each employee next to their manager's name? You cannot join employees to a different table — the data is all in one table. You need to join the employees table to ITSELF. That is a SELF JOIN.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should know INNER JOIN, LEFT JOIN, RIGHT JOIN, FULL OUTER JOIN, and CROSS JOIN — all covered in the previous class on JOIN Types. You also need to understand table aliases. In the previous class, we joined two separate tables. Now we go further — joining a table to ITSELF, joining with less typing, and joining three or more tables in a single query.

- You know INNER, LEFT, RIGHT, FULL OUTER, CROSS JOIN
- You know table aliases (c.id, o.product)
- Previous class: joined two tables using ON condition
- This class: SELF JOIN, NATURAL JOIN, USING, multi-table
- Plus: how to check join performance with EXPLAIN

### The Problem: Manager Hierarchy in One Table
Imagine you have an employees table. Each employee has a manager. But the manager is ALSO an employee in the same table. The manager_id column points to another row in the SAME table. How do you show each employee next to their manager's name? You cannot join employees to a different table — the data is all in one table. You need to join the employees table to ITSELF. That is a SELF JOIN.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Employees Table** | id, name, department, manager_id |
| **manager_id** | Points to another employee's id in the SAME table |
| **The Question** | Show each employee with their manager's name |
| **The Solution** | SELF JOIN — join the table to itself using two aliases |

**Notes:**
- The CEO has manager_id = NULL (no one above them)

### NATURAL JOIN — Auto-Match by Column Name
Now let us talk about NATURAL JOIN. It automatically matches columns that have the SAME NAME in both tables. No ON clause needed. Sounds convenient, right? But it is DANGEROUS. If someone adds a column to a table and it happens to share a name with a column in the other table, your query silently changes behavior. You get wrong results with no error. That is why most teams BAN NATURAL JOIN in production code.

| Term | Meaning / Explanation |
| :--- | :--- |
| **How It Works** | Automatically joins on ALL columns with the same name |
| **No ON Clause** | PostgreSQL figures out the join condition itself |
| **The Danger** | Adding a column can silently break the query |
| **Recommendation** | AVOID in production — use explicit ON or USING instead |

**Notes:**
- NATURAL JOIN = invisible, fragile join condition
- Schema changes silently break queries — hard to debug

### ON vs USING vs NATURAL — When to Use Each
When do you use ON versus USING? ON is the most flexible — it works with any condition, even complex ones. USING is shorter when both tables have a column with the same name. NATURAL JOIN should be avoided. Here is the rule: if the join columns have the same name, use USING for cleaner syntax. If they have different names, or you need a complex condition, use ON.

| Use This | Avoid This |
| :--- | :--- |
| ON: any join condition, most flexible | NATURAL JOIN: auto-match, fragile |
| ON c.id = o.customer_id (different names) | Schema changes silently break it |
| USING (col): same-named columns, cleaner | No way to know what it matches on |
| USING (department) — explicit and safe | Banned in most production codebases |

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. You can download today's class materials and practice files from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Every bit helps us keep creating. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Join Algorithms — How PostgreSQL Executes JOINs
Let us talk about join performance. How does PostgreSQL actually execute a JOIN? It picks one of three algorithms: Nested Loop, Hash Join, or Merge Join. You can see which one it picks using EXPLAIN. Nested Loop works like two nested for-loops — good for small tables or indexed lookups. Hash Join builds a hash table from one side — great for medium tables without indexes. Merge Join sorts both sides and merges — efficient for large pre-sorted datasets.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | How does PostgreSQL actually execute a JOIN? |
| **It picks one of three algorithms** | Nested Loop, Hash Join, or Merge Join |
| **Point 3** | You can see which one it picks using EXPLAIN |
| **Nested Loop works like two nested for** | loops — good for small tables or indexed lookups |
| **Point 5** | Hash Join builds a hash table from one side — great for medium tables without indexes |
| **Merge Join sorts both sides and merges** | efficient for large pre-sorted datasets |

### Join Performance Tips
Here are the join performance rules to remember. First — always join on indexed columns. Foreign keys should have indexes. Second — put the smaller table first in joins when possible, though PostgreSQL's optimizer usually handles this. Third — avoid joining on expressions or functions — they prevent index use. Fourth — for complex multi-table queries, check EXPLAIN to make sure PostgreSQL is not doing something expensive.

- 1. Index your foreign key columns (PostgreSQL does NOT auto-index FK)
- 2. Join on simple columns, not expressions: ON c.id = o.cid (good)
- 3. Avoid functions in ON: ON LOWER(a.name) = LOWER(b.name) (slow)
- 4. Check EXPLAIN for Seq Scans on large tables → add index
- 5. PostgreSQL picks the join algorithm — trust the optimizer
- 6. For multi-table joins, the optimizer tries different orders
- 7. Deep dive on EXPLAIN comes in the Query Optimization class

### Practice Exercises
Practice time! Exercise one: write a SELF JOIN to show each employee with their manager. Exercise two: find employees who have NO manager using SELF JOIN plus IS NULL. Exercise three: join three tables to show customers with their orders and product details. Exercise four: rewrite a NATURAL JOIN as USING. Exercise five: use EXPLAIN to see the join algorithm. Try these yourself, then check the class materials for solutions.

- 1. SELF JOIN: show each employee with their manager's name
- 2. SELF JOIN + IS NULL: find employees with no manager (CEO)
- 3. Three-table JOIN: customers + orders + products
- 4. Rewrite ON join as USING where columns share a name
- 5. EXPLAIN a join query — identify the algorithm used
- 6. Find all colleague pairs in the same department
- 7. Add an index on a FK column and compare EXPLAIN output


---

## 3. Hands-On Commands & psql Output

### Setup: Employee-Manager Hierarchy
**Explanation:** Let us create an employees table with a manager hierarchy. Meera is the CEO with no manager. Ravi and Sonia report to Meera. Priya and Arjun report to Ravi. Kiran reports to Sonia. This gives us a tree structure — all stored in a single table.

```sql
practice=# CREATE TABLE employees (
    id          INT PRIMARY KEY,
    name        VARCHAR(50) NOT NULL,
    department  VARCHAR(50),
    manager_id  INT REFERENCES employees(id)
);
CREATE TABLE

practice=# INSERT INTO employees VALUES
(1, 'Meera', 'Executive', NULL),
(2, 'Ravi',  'Engineering', 1),
(3, 'Sonia', 'HR', 1),
(4, 'Priya', 'Engineering', 2),
(5, 'Arjun', 'Engineering', 2),
(6, 'Kiran', 'HR', 3);
INSERT 0 6
```

### SELF JOIN — Employee with Manager Name
**Explanation:** Here is the SELF JOIN. We join employees to itself by giving it TWO different aliases — e for employee and m for manager. The ON clause says: match e dot manager_id to m dot id. This links each employee row to their manager's row. We use LEFT JOIN so that Meera — the CEO with no manager — still appears with NULL for the manager name.

```sql
-- SELF JOIN: same table, two aliases
practice=# SELECT e.name AS employee,
       e.department,
       m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;
 employee | department  | manager
----------+-------------+---------
 Meera    | Executive   |
 Ravi     | Engineering | Meera
 Sonia    | HR          | Meera
 Priya    | Engineering | Ravi
 Arjun    | Engineering | Ravi
 Kiran    | HR          | Sonia
(6 rows)

-- Meera has NULL manager (CEO, no one above)
-- LEFT JOIN keeps her in the result
```

### SELF JOIN — Find Colleagues in Same Department
**Explanation:** Another SELF JOIN use case: find employees in the same department. We join the table to itself on department but exclude matching the employee to themselves. This gives us every pair of colleagues. SELF JOINs are also useful for comparing rows within the same table — like finding products with the same price, or orders placed on the same day.

```sql
-- Find pairs of employees in the same department
practice=# SELECT e1.name AS employee1,
       e2.name AS employee2,
       e1.department
FROM employees e1
INNER JOIN employees e2
  ON e1.department = e2.department
  AND e1.id < e2.id;
 employee1 | employee2 | department
-----------+-----------+-------------
 Ravi      | Priya     | Engineering
 Ravi      | Arjun     | Engineering
 Priya     | Arjun     | Engineering
 Sonia     | Kiran     | HR
(4 rows)

-- e1.id < e2.id avoids duplicates (Ravi-Priya = Priya-Ravi)
-- and avoids self-pairs (Ravi-Ravi)
```

### NATURAL JOIN — Works Until It Breaks
**Explanation:** Let me show you NATURAL JOIN in action, and then show you why it breaks. We create two small tables that share a 'department' column. NATURAL JOIN automatically matches on department. It works. But now watch — we add a 'name' column to the second table. Suddenly NATURAL JOIN matches on BOTH department AND name. The result changes silently. No error, no warning. Just wrong data.

```sql
practice=# CREATE TABLE dept_info (department VARCHAR(50), budget INT);
CREATE TABLE
practice=# INSERT INTO dept_info VALUES ('Engineering', 500000), ('HR', 200000);
INSERT 0 2

-- NATURAL JOIN: auto-matches on 'department'
practice=# SELECT name, department, budget
FROM employees NATURAL JOIN dept_info;
  name  | department  | budget
--------+-------------+--------
 Ravi   | Engineering | 500000
 Priya  | Engineering | 500000
 Arjun  | Engineering | 500000
 Sonia  | HR          | 200000
 Kiran  | HR          | 200000
(5 rows)

-- Looks fine... but ADD a 'name' column to dept_info:
-- ALTER TABLE dept_info ADD COLUMN name VARCHAR(50);
-- Now NATURAL JOIN matches on department AND name → 0 rows!
```

### USING Clause — Safe Alternative to NATURAL JOIN
**Explanation:** The safe alternative to NATURAL JOIN is the USING clause. Instead of ON, you write USING and the column name in parentheses. It matches on that specific column — just like NATURAL JOIN — but it is EXPLICIT. You control which column is used. If someone adds a new column, your query does not change. USING also has a bonus: the matched column appears only ONCE in the result, not twice.

```sql
-- USING: explicit column match (safe!)
practice=# SELECT name, department, budget
FROM employees JOIN dept_info USING (department);
  name  | department  | budget
--------+-------------+--------
 Ravi   | Engineering | 500000
 Priya  | Engineering | 500000
 Arjun  | Engineering | 500000
 Sonia  | HR          | 200000
 Kiran  | HR          | 200000
(5 rows)

-- USING (department) = ON e.department = d.department
-- But: USING shows 'department' once, ON shows it twice
-- USING works with any JOIN type: LEFT JOIN ... USING (col)
```

### Setup: Three Tables — Customers, Products, Orders
**Explanation:** Now let us join THREE tables in a single query. This is something you do constantly in real applications. We will set up customers, orders, and products tables. An order references a customer and a product. To show customer name, product name, and order amount together, we need to join all three.

```sql
practice=# CREATE TABLE shop_customers (
    id   INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL
);
CREATE TABLE
practice=# CREATE TABLE products (
    id    INT PRIMARY KEY,
    name  VARCHAR(50),
    price NUMERIC(10,2)
);
CREATE TABLE
practice=# CREATE TABLE shop_orders (
    id          INT PRIMARY KEY,
    customer_id INT REFERENCES shop_customers(id),
    product_id  INT REFERENCES products(id),
    quantity    INT,
    order_date  DATE DEFAULT CURRENT_DATE
);
CREATE TABLE
```

### Insert Sample Data for Multi-table Join
**Explanation:** Insert some sample data. Three customers, four products, and six orders linking them together.

```sql
practice=# INSERT INTO shop_customers VALUES
(1,'Ravi'),(2,'Priya'),(3,'Arjun');
INSERT 0 3

practice=# INSERT INTO products VALUES
(1,'Laptop',75000),(2,'Mouse',1500),
(3,'Keyboard',3000),(4,'Monitor',25000);
INSERT 0 4

practice=# INSERT INTO shop_orders VALUES
(1,1,1,1,'2024-01-15'),(2,1,2,2,'2024-01-15'),
(3,2,3,1,'2024-02-01'),(4,2,1,1,'2024-02-10'),
(5,3,4,2,'2024-03-05'),(6,3,2,3,'2024-03-05');
INSERT 0 6
```

### Three-Table JOIN — Orders + Customers + Products
**Explanation:** Here is the three-table JOIN. We start with shop_orders, JOIN to shop_customers on customer_id, then JOIN to products on product_id. Each JOIN adds one more table. You can chain as many JOINs as needed. The query reads naturally: take orders, attach the customer name, attach the product name and price, then calculate the total.

```sql
-- Join 3 tables: orders → customers → products
practice=# SELECT c.name AS customer,
       p.name AS product,
       o.quantity,
       p.price,
       o.quantity * p.price AS total
FROM shop_orders o
INNER JOIN shop_customers c ON o.customer_id = c.id
INNER JOIN products p ON o.product_id = p.id
ORDER BY c.name, o.order_date;
 customer | product  | quantity |  price   |  total
----------+----------+----------+----------+----------
 Arjun    | Monitor  |        2 | 25000.00 | 50000.00
 Arjun    | Mouse    |        3 |  1500.00 |  4500.00
 Priya    | Keyboard |        1 |  3000.00 |  3000.00
 Priya    | Laptop   |        1 | 75000.00 | 75000.00
 Ravi     | Laptop   |        1 | 75000.00 | 75000.00
 Ravi     | Mouse    |        2 |  1500.00 |  3000.00
(6 rows)
```

### EXPLAIN — See the Join Algorithm
**Explanation:** Let us use EXPLAIN to see which algorithm PostgreSQL picks. EXPLAIN shows the query plan WITHOUT running the query. For our small tables, PostgreSQL uses Hash Join or Nested Loop. The key thing to look for is the join type and the estimated cost. A Seq Scan means it reads the whole table — fine for small tables, but for large tables you want an Index Scan. We will cover EXPLAIN in much more depth in the Query Optimization class later.

```sql
-- EXPLAIN shows the query plan (does NOT run the query)
practice=# EXPLAIN SELECT c.name, o.product, o.amount
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;
                           QUERY PLAN
--------------------------------------------------------------
 Hash Join  (cost=1.11..2.27 rows=7 width=236)
   Hash Cond: (o.customer_id = c.id)
   ->  Seq Scan on orders o  (cost=0.00..1.07 rows=7 ...)
   ->  Hash
         ->  Seq Scan on customers c  (cost=0.00..1.05 ...)

-- Hash Join: PostgreSQL built a hash from customers
-- Then probed it for each order row
-- Seq Scan: table is small, no index needed yet
```

### Common Errors with JOINs
**Explanation:** A common beginner mistake with SELF JOINs: forgetting to use two different aliases. If you write employees JOIN employees, PostgreSQL does not know which one you mean. You MUST give them different names — e and m, or emp and mgr. Another mistake: forgetting that PostgreSQL does NOT automatically create indexes on foreign key columns. If your JOINs are slow, check that the foreign key column has an index.

```sql
-- Error 1: SELF JOIN without aliases
practice=# SELECT employees.name, employees.name
FROM employees JOIN employees ON employees.manager_id = employees.id;
ERROR:  table name "employees" specified more than once

-- FIX: use two different aliases
practice=# SELECT e.name, m.name AS manager
FROM employees e LEFT JOIN employees m ON e.manager_id = m.id;
(6 rows)  -- works!

-- Error 2: Slow JOIN (no index on FK column)
-- Fix: CREATE INDEX idx_orders_customer_id ON orders(customer_id);
-- PostgreSQL does NOT auto-create indexes on foreign keys!
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. SELF JOIN joins a table to itself using two aliases — perfect for hierarchies like employee-manager. NATURAL JOIN auto-matches by column name but is fragile and dangerous — avoid it. USING is the safe shorthand when columns share a name. Multi-table JOINs chain multiple JOIN clauses — just keep adding them. PostgreSQL uses three join algorithms: Nested Loop, Hash Join, and Merge Join — check with EXPLAIN. Always index your foreign key columns — PostgreSQL does not do this automatically. In the next class, we move to Aggregation — COUNT, SUM, AVG, GROUP BY, and HAVING. See you there!

- **SELF JOIN: same table, two aliases (e and m)**
- **LEFT JOIN for hierarchy (CEO has NULL manager)**
- **NATURAL JOIN: auto-match by name — AVOID in production**
- **USING (col): safe shorthand for same-named columns**
- **ON: most flexible, works with any condition**
- **Multi-table: chain JOINs — orders → customers → products**
- **EXPLAIN shows join algorithm: Nested Loop / Hash / Merge**
- **Always index FK columns — PG does NOT auto-index them**


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

### Challenge 1: Employee-Manager Hierarchy (SELF JOIN)
```sql
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;
```
*Why:* Self joins treat two instances of the same table as independent relations (`e` for employee, `m` for manager).

### Challenge 2: Identify Root Executive (CEO)
```sql
SELECT e.name AS employee
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id
WHERE m.id IS NULL;
```
*Why:* Left join surfaces individuals who report to nobody (`manager_id IS NULL`).

### Challenge 3: Three-Table Relational Synthesis
```sql
SELECT c.name, p.name AS product, o.quantity, p.price
FROM shop_orders o
JOIN shop_customers c ON o.customer_id = c.id
JOIN products p ON o.product_id = p.id;
```
*Why:* Chains normalized dimensions through transaction records seamlessly.

### Challenge 4: Safe Column Unification with USING
```sql
SELECT e.name, e.department, d.budget
FROM employees e
JOIN dept_info d USING (department);
```
*Why:* Explicitly names the shared join column, avoiding implicit breaking changes when common audit columns exist.

### Challenge 5: Colleague Pairing Without Duplication
```sql
SELECT e1.name, e2.name, e1.department
FROM employees e1
JOIN employees e2 ON e1.department = e2.department AND e1.id < e2.id;
```
*Why:* The strict inequality `e1.id < e2.id` eliminates self-matches (`A with A`) and mirror matches (`B with A`).
