# INNER JOIN, LEFT JOIN, RIGHT JOIN, FULL OUTER JOIN & CROSS JOIN
**Series:** PostgreSQL Mastery | **Phase:** Phase 6: JOINs | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn every JOIN type — INNER, LEFT, RIGHT, FULL OUTER, and CROSS JOIN. By the end, you will know exactly which JOIN to pick for any situation.

### The Problem: Data Lives in Separate Tables
Imagine you run an online store. You have a customers table with names and cities, and an orders table with products and amounts. A customer calls and asks: 'Show me all my orders.' The customer info is in one table, the order info is in another. You need to COMBINE them. Without JOINs, you would have to run two separate queries and manually match the results. JOINs do this matching for you — automatically, efficiently, in a single query.

### WHY JOINs Exist
Why do we store data in separate tables instead of one big table? Because of normalization — we covered this in the Normalization class. Separate tables avoid duplicate data. But when we QUERY, we often need data from multiple tables together. That is exactly why SQL has JOIN. Think of it like a zipper — two separate sides that lock together using a shared key.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should be comfortable with SELECT, WHERE, and basic filtering — topics we covered in the SELECT and WHERE class. In the previous class on COPY and CASE WHEN, we worked with single tables. But real databases have MANY tables. How do we combine them? That is what JOINs solve.

- You know SELECT, WHERE, ORDER BY, LIMIT
- You know INSERT, UPDATE, DELETE
- Previous class: COPY, CASE WHEN, COALESCE
- So far: all queries hit ONE table at a time
- Real databases have many related tables
- JOINs let us combine rows from multiple tables

### The Problem: Data Lives in Separate Tables
Imagine you run an online store. You have a customers table with names and cities, and an orders table with products and amounts. A customer calls and asks: 'Show me all my orders.' The customer info is in one table, the order info is in another. You need to COMBINE them. Without JOINs, you would have to run two separate queries and manually match the results. JOINs do this matching for you — automatically, efficiently, in a single query.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Customers Table** | id, name, city — who the customer is |
| **Orders Table** | id, customer_id, product, amount — what they bought |
| **The Question** | Show me each customer with their orders |
| **The Solution** | JOIN combines rows from both tables using a matching column |

### WHY JOINs Exist
Why do we store data in separate tables instead of one big table? Because of normalization — we covered this in the Normalization class. Separate tables avoid duplicate data. But when we QUERY, we often need data from multiple tables together. That is exactly why SQL has JOIN. Think of it like a zipper — two separate sides that lock together using a shared key.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Normalization** | We split data into tables to avoid duplication |
| **Querying** | We need to recombine them when reading data |
| **JOIN** | SQL command that combines rows from two or more tables |
| **Join Condition** | The matching rule — usually a foreign key relationship |

**Notes:**
- Think of JOIN as a zipper — two sides locking together on a shared key

### Five JOIN Types at a Glance
There are five main JOIN types. Each one controls what happens with rows that DO match and rows that DO NOT match between the two tables. Let us see them all.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | There are five main JOIN types |
| **Point 2** | Each one controls what happens with rows that DO match and rows that DO NOT match between the two tables |

### When to Use Each JOIN
When should you use each JOIN? INNER JOIN is your default — use it when you only want rows that have matches on both sides. LEFT JOIN when you want ALL items from the left table even if they have no match. RIGHT JOIN is the mirror — all items from the right table. FULL OUTER JOIN when you need everything from both sides, matched or not. CROSS JOIN is rare — use it for generating combinations like sizes times colors.

| Most Common | Less Common |
| :--- | :--- |
| INNER JOIN — only matching data (default choice) | RIGHT JOIN — same as LEFT but reversed (rarely needed) |
| LEFT JOIN — keep all from main table, even without matches | FULL OUTER JOIN — find gaps in both tables |
| Example: all customers, even those with no orders | CROSS JOIN — generate all combinations (sizes × colors) |

### INNER JOIN — Venn Diagram
Let us visualize INNER JOIN. Think of two circles overlapping — a Venn diagram. The left circle is customers, the right circle is orders. INNER JOIN returns ONLY the overlapping part — rows that exist in BOTH tables. Customers without orders? Gone. Orders without customers? Gone. Only the matches survive.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Left Circle** | Customers table (5 rows) |
| **Right Circle** | Orders table (7 rows) |
| **Overlap (returned)** | Rows where customer.id = order.customer_id |
| **Result** | 5 rows — only matching pairs |

**Notes:**
- Meera and Kiran excluded (no orders)
- Orders 106, 107 excluded (no matching customer)
- INNER JOIN = intersection of both tables

### RIGHT JOIN vs LEFT JOIN — Same Result!
In practice, RIGHT JOIN is rarely used. Why? Because you can always rewrite it as a LEFT JOIN by swapping the table order. Instead of customers RIGHT JOIN orders, write orders LEFT JOIN customers. The result is identical. Most developers prefer LEFT JOIN because it reads more naturally — your main table comes first. So you will see LEFT JOIN a hundred times for every one RIGHT JOIN.

| RIGHT JOIN | Equivalent LEFT JOIN |
| :--- | :--- |
| FROM customers c | FROM orders o |
| RIGHT JOIN orders o | LEFT JOIN customers c |
| ON c.id = o.customer_id | ON c.id = o.customer_id |
| All orders + matching customers | Same result, more readable |
|  | Convention: main table comes first |

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. You can download today's class materials and practice files from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Every bit helps us keep creating. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Row Count Comparison — Same Tables, Different JOINs
Let us compare row counts across all JOIN types so you can see the pattern clearly. INNER JOIN gives you only the matches — the smallest result. LEFT and RIGHT each add their unmatched rows. FULL OUTER gives you everything. CROSS gives you the multiplication — always the largest. The row count difference is the key to choosing the right JOIN.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Let us compare row counts across all JOIN types so you can see the pattern clearly |
| **INNER JOIN gives you only the matches** | the smallest result |
| **Point 3** | LEFT and RIGHT each add their unmatched rows |
| **Point 4** | FULL OUTER gives you everything |
| **CROSS gives you the multiplication** | always the largest |
| **Point 6** | The row count difference is the key to choosing the right JOIN |

### Practice Exercises
Let us do some practice. Exercise one: INNER JOIN customers and orders. Exercise two: LEFT JOIN to find all customers including those without orders. Exercise three: find customers who have NEVER ordered using LEFT JOIN plus IS NULL. Exercise four: FULL OUTER JOIN to see all gaps. Exercise five: CROSS JOIN to generate a size-color grid. Try each one on your own first, then check the solutions in the class materials.

- 1. INNER JOIN: show each customer with their orders
- 2. LEFT JOIN: all customers, including those without orders
- 3. LEFT JOIN + IS NULL: find customers with zero orders
- 4. FULL OUTER JOIN: show all unmatched rows from both tables
- 5. CROSS JOIN: generate all size × color combinations
- 6. Count rows from each JOIN type — verify the numbers match
- 7. RIGHT JOIN: rewrite it as an equivalent LEFT JOIN


---

## 3. Hands-On Commands & psql Output

### Setup: Create Customers and Orders Tables
**Explanation:** Let us set up our practice tables. We create a customers table with five customers, and an orders table with seven orders. Notice: customers four and five — Meera and Kiran — have NO orders. And orders one-oh-six and one-oh-seven have customer IDs six and seven, which do NOT exist in the customers table. This mismatch is intentional — it will show us exactly how each JOIN type handles unmatched rows.

```sql
practice=# CREATE TABLE customers (
    id   INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    city VARCHAR(50)
);
CREATE TABLE

practice=# INSERT INTO customers VALUES
(1,'Ravi','Mumbai'),(2,'Priya','Delhi'),
(3,'Arjun','Chennai'),(4,'Meera','Pune'),
(5,'Kiran','Hyderabad');
INSERT 0 5
```

### Setup: Orders Table with Mismatched IDs
**Explanation:** Now the orders table. Seven orders — five linked to existing customers, and two with customer IDs that do NOT exist. This setup gives us a perfect playground to see how each JOIN handles matches and mismatches.

```sql
practice=# CREATE TABLE orders (
    id          INT PRIMARY KEY,
    customer_id INT,
    product     VARCHAR(50),
    amount      NUMERIC(10,2)
);
CREATE TABLE

practice=# INSERT INTO orders VALUES
(101,1,'Laptop',75000),(102,1,'Mouse',1500),
(103,2,'Keyboard',3000),(104,3,'Monitor',25000),
(105,3,'Headphones',4000),
(106,6,'Webcam',2500),(107,7,'Speaker',8000);
INSERT 0 7

-- Customers 4,5 have NO orders
-- Orders 106,107 have customer_id 6,7 (no matching customer)
```

### INNER JOIN — Only Matching Rows
**Explanation:** INNER JOIN returns ONLY the rows where both tables have a match. If a customer has no orders, they are excluded. If an order has no matching customer, it is also excluded. This is the most common JOIN type — it gives you the intersection. The syntax is: SELECT columns FROM table_one INNER JOIN table_two ON the matching condition. The ON clause tells PostgreSQL which columns to match.

```sql
-- INNER JOIN: only rows with matches in BOTH tables
practice=# SELECT c.name, c.city, o.product, o.amount
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;
  name  |  city   |  product   |  amount
--------+---------+------------+----------
 Ravi   | Mumbai  | Laptop     | 75000.00
 Ravi   | Mumbai  | Mouse      |  1500.00
 Priya  | Delhi   | Keyboard   |  3000.00
 Arjun  | Chennai | Monitor    | 25000.00
 Arjun  | Chennai | Headphones |  4000.00
(5 rows)

-- Meera, Kiran: no orders → excluded
-- Orders 106, 107: no customer → excluded
```

### LEFT JOIN — All Customers, Even Without Orders
**Explanation:** LEFT JOIN returns ALL rows from the left table — the one listed FIRST — and matching rows from the right table. If a left-side row has no match, the right-side columns are filled with NULL. So every customer appears — even Meera and Kiran who have no orders. Their product and amount columns show NULL. But orders with non-existent customers are still excluded — because orders is the RIGHT table.

```sql
-- LEFT JOIN: ALL from left (customers) + matching from right
practice=# SELECT c.name, c.city, o.product, o.amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id;
  name  |   city    |  product   |  amount
--------+-----------+------------+----------
 Ravi   | Mumbai    | Laptop     | 75000.00
 Ravi   | Mumbai    | Mouse      |  1500.00
 Priya  | Delhi     | Keyboard   |  3000.00
 Arjun  | Chennai   | Monitor    | 25000.00
 Arjun  | Chennai   | Headphones |  4000.00
 Meera  | Pune      |            |         
 Kiran  | Hyderabad |            |         
(7 rows)

-- Meera and Kiran appear with NULL product/amount
-- Orders 106,107 still excluded (right side unmatched)
```

### LEFT JOIN + IS NULL — Find Customers Without Orders
**Explanation:** A powerful trick with LEFT JOIN: finding rows that have NO match. Add a WHERE clause checking that the right-side key IS NULL. This gives you all customers who have NEVER placed an order. This pattern is used all the time in real applications — find inactive users, products never ordered, employees not assigned to any project.

```sql
-- Find customers who have ZERO orders
practice=# SELECT c.name, c.city
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.id IS NULL;
 name  |   city
-------+-----------
 Meera | Pune
 Kiran | Hyderabad
(2 rows)

-- Pattern: LEFT JOIN + WHERE right.key IS NULL
-- Finds rows in left table with NO match in right table
```

### RIGHT JOIN — All Orders, Even Without Customers
**Explanation:** RIGHT JOIN is the mirror image of LEFT JOIN. It returns ALL rows from the RIGHT table — orders — and matching rows from the left table — customers. If an order has no matching customer, the customer columns show NULL. So now orders one-oh-six and one-oh-seven appear — with NULL for the customer name and city. But Meera and Kiran disappear because they are on the LEFT side with no match.

```sql
-- RIGHT JOIN: ALL from right (orders) + matching from left
practice=# SELECT c.name, c.city, o.product, o.amount
FROM customers c
RIGHT JOIN orders o ON c.id = o.customer_id;
  name  |  city   |  product   |  amount
--------+---------+------------+----------
 Ravi   | Mumbai  | Laptop     | 75000.00
 Ravi   | Mumbai  | Mouse      |  1500.00
 Priya  | Delhi   | Keyboard   |  3000.00
 Arjun  | Chennai | Monitor    | 25000.00
 Arjun  | Chennai | Headphones |  4000.00
        |         | Webcam     |  2500.00
        |         | Speaker    |  8000.00
(7 rows)

-- Orders 106,107 appear with NULL name/city
-- Meera, Kiran excluded (left side unmatched)
```

### FULL OUTER JOIN — Everything from Both Tables
**Explanation:** FULL OUTER JOIN returns EVERYTHING from BOTH tables. If a customer has no order — they still appear with NULLs on the order side. If an order has no customer — it still appears with NULLs on the customer side. Nothing is dropped. This is the union of both tables. Notice we get nine rows: five matches, plus two unmatched customers, plus two unmatched orders.

```sql
-- FULL OUTER JOIN: ALL from both, NULLs where no match
practice=# SELECT c.name, c.city, o.product, o.amount
FROM customers c
FULL OUTER JOIN orders o ON c.id = o.customer_id;
  name  |   city    |  product   |  amount
--------+-----------+------------+----------
 Ravi   | Mumbai    | Laptop     | 75000.00
 Ravi   | Mumbai    | Mouse      |  1500.00
 Priya  | Delhi     | Keyboard   |  3000.00
 Arjun  | Chennai   | Monitor    | 25000.00
 Arjun  | Chennai   | Headphones |  4000.00
 Meera  | Pune      |            |         
 Kiran  | Hyderabad |            |         
        |           | Webcam     |  2500.00
        |           | Speaker    |  8000.00
(9 rows)
```

### CROSS JOIN — Every Possible Combination
**Explanation:** CROSS JOIN is completely different. It has NO join condition — no ON clause. It returns every possible combination of rows from both tables. Five customers times seven orders equals thirty-five rows. This is called a Cartesian product. It is rarely useful, but has specific use cases: generating all combinations like product sizes times colors, or creating test data grids.

```sql
-- CROSS JOIN: every row × every row (no ON clause!)
practice=# SELECT c.name, o.product
FROM customers c
CROSS JOIN orders o
ORDER BY c.name, o.product;
  name  |  product
--------+------------
 Arjun  | Headphones
 Arjun  | Keyboard
 Arjun  | Laptop
 Arjun  | Monitor
 Arjun  | Mouse
 Arjun  | Speaker
 Arjun  | Webcam
 ...    | ...
(35 rows)

-- 5 customers × 7 orders = 35 rows
-- WARNING: 1000 × 1000 = 1,000,000 rows! Be careful.
```

### CROSS JOIN — Practical Example: Sizes × Colors
**Explanation:** Here is a practical CROSS JOIN example. Say you sell T-shirts in three sizes and four colors. CROSS JOIN generates all twelve combinations automatically — no manual INSERT needed. This is the perfect use case for CROSS JOIN.

```sql
-- Generate all product variants
practice=# SELECT s.size, c.color
FROM (VALUES ('S'),('M'),('L')) AS s(size)
CROSS JOIN (VALUES ('Red'),('Blue'),('Green'),('Black')) AS c(color);
 size | color
------+-------
 S    | Red
 S    | Blue
 S    | Green
 S    | Black
 M    | Red
 M    | Blue
 M    | Green
 M    | Black
 L    | Red
 L    | Blue
 L    | Green
 L    | Black
(12 rows)
```

### Common Error: Ambiguous Column Reference
**Explanation:** The most common beginner mistake with JOINs is the ambiguous column error. When both tables have a column with the same name — like 'id' — PostgreSQL does not know which one you mean. The fix is simple: always use table aliases. Write c dot id or o dot id, not just id. Another common mistake is forgetting the ON clause — that turns your JOIN into a CROSS JOIN accidentally, returning millions of rows.

```sql
-- ERROR: both tables have 'id' column
practice=# SELECT id, name, product
FROM customers INNER JOIN orders ON customers.id = orders.customer_id;
ERROR:  column reference "id" is ambiguous

-- FIX: use table aliases
practice=# SELECT c.id, c.name, o.product
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;
 id |  name  |  product
----+--------+------------
  1 | Ravi   | Laptop
  1 | Ravi   | Mouse
  2 | Priya  | Keyboard
  3 | Arjun  | Monitor
  3 | Arjun  | Headphones
(5 rows)
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. INNER JOIN is your go-to — it returns only matching rows. LEFT JOIN keeps all rows from the left table and fills NULLs for the right. RIGHT JOIN is the mirror — same thing but from the right side. FULL OUTER returns everything from both sides. CROSS JOIN makes every possible combination. The LEFT JOIN plus IS NULL pattern finds missing matches — use it everywhere. Always use table aliases to avoid ambiguous column errors. In the next class, we will learn SELF JOIN — joining a table to itself — NATURAL JOIN, the USING clause, multi-table joins, and join performance. See you there!

- **INNER JOIN: only matching rows from both tables**
- **LEFT JOIN: all left rows + matching right (NULL if no match)**
- **RIGHT JOIN: all right rows + matching left (rarely needed)**
- **FULL OUTER: everything from both tables, NULLs where no match**
- **CROSS JOIN: every row × every row (Cartesian product)**
- **LEFT JOIN + WHERE IS NULL: find rows with no match**
- **Always use table aliases (c.id not just id)**
- **Forgetting ON = accidental CROSS JOIN = huge result**


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

### Challenge 1: INNER JOIN (Only Matching Records)
```sql
SELECT c.name, c.city, o.product, o.amount
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;
```
*Why:* INNER JOIN evaluates the join condition (`c.id = o.customer_id`) and retains only rows present in both relations.

### Challenge 2: LEFT JOIN (Retain All Left Rows)
```sql
SELECT c.name, c.city, o.product, o.amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id;
```
*Why:* LEFT JOIN ensures all customer entities appear. If a customer has no orders, order fields evaluate to `NULL`.

### Challenge 3: Anti-Join Pattern (Customers with Zero Orders)
```sql
SELECT c.name, c.city
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.id IS NULL;
```
*Why:* Performing a LEFT JOIN and checking for `WHERE o.id IS NULL` filters out all matching records, leaving only non-ordering customers.

### Challenge 4: FULL OUTER JOIN (Identify Relation Gaps)
```sql
SELECT
    COALESCE(c.name, 'Orphan Order') AS customer,
    COALESCE(o.product, 'No Order Placed') AS product
FROM customers c
FULL OUTER JOIN orders o ON c.id = o.customer_id
WHERE c.id IS NULL OR o.customer_id IS NULL;
```
*Why:* FULL OUTER JOIN surfaces mismatched rows from both tables simultaneously; COALESCE provides readable fallback text.

### Challenge 5: CROSS JOIN Matrix (Cartesian Product)
```sql
SELECT s.size, c.color
FROM (VALUES ('XS'),('S'),('M'),('L'),('XL')) AS s(size)
CROSS JOIN (VALUES ('Red'),('Blue'),('Black')) AS c(color)
ORDER BY s.size, c.color;
```
*Why:* CROSS JOIN matches each row of the first relation against every row of the second relation, generating complete combination sets.
