# UNION, INTERSECT & EXCEPT — Combining Query Results
**Series:** PostgreSQL Mastery | **Phase:** Phase 10: Advanced SQL | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn how to combine the results of two or more queries into a single result set. You will use UNION to stack results together, INTERSECT to find common rows, and EXCEPT to find rows in one query but not the other. These are called set operations — they treat query results like mathematical sets. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Set Operations Overview
Before this class, you should be comfortable writing SELECT queries with WHERE, JOIN, GROUP BY, and ORDER BY. Set operations are a different way to combine data — instead of joining columns sideways, they STACK rows vertically. UNION puts all rows from both queries together. INTERSECT keeps only rows that appear in BOTH queries. EXCEPT keeps rows from the first query that do NOT appear in the second. The key rule: both queries must return the SAME number of columns with compatible data types.

| Term | Meaning / Explanation |
| :--- | :--- |
| **UNION** | All rows from both queries (duplicates removed) |
| **UNION ALL** | All rows from both queries (duplicates kept) |
| **INTERSECT** | Only rows that appear in BOTH queries |
| **EXCEPT** | Rows from first query NOT in second query |
| **Rule** | Both queries must have same number of columns, compatible types |

**Notes:**
- Column names come from the FIRST query

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Common Mistakes & Performance
Common mistakes: Column count mismatch gives an error — each SELECT must have the same number of columns. Type mismatch also fails — you cannot UNION a text column with an integer column unless you cast it. And remember: UNION without ALL is slower because it must sort and remove duplicates. If you know there are no duplicates, always use UNION ALL for better performance.

| Common Errors | Performance Tips |
| :--- | :--- |
| Column count mismatch → ERROR | UNION ALL is faster than UNION (no dedup) |
| Incompatible types → ERROR | Use UNION ALL when duplicates are impossible |
| Using UNION when UNION ALL is correct | Put selective WHERE in each query, not after |
| Forgetting ORDER BY applies to final result | EXPLAIN shows Append + Sort Unique for UNION |

### Decision Framework: Which Set Operation?
When should you use each set operation? Here is the decision framework. UNION ALL when combining results from different tables or queries and duplicates are fine or impossible. UNION when you need guaranteed unique rows — but consider if the data already has no duplicates. INTERSECT when you need rows that exist in both data sources. EXCEPT when you need rows missing from another set, like finding customers who have not placed orders.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | When should you use each set operation? |
| **Point 2** | UNION ALL when combining results from different tables or queries and duplicates are fine or impossible |
| **Point 3** | UNION when you need guaranteed unique rows — but consider if the data already has no duplicates |
| **Point 4** | INTERSECT when you need rows that exist in both data sources |
| **Point 5** | EXCEPT when you need rows missing from another set, like finding customers who have not placed orders |

### Practice Exercises
Practice exercises: try UNION, UNION ALL, INTERSECT, and EXCEPT with the customers and suppliers tables. Add source labels, chain multiple operations, check EXPLAIN to compare UNION versus UNION ALL, and try combining set operations with WHERE filters.

- 1. UNION customers and suppliers (no duplicates)
- 2. UNION ALL — see the duplicates
- 3. INTERSECT — who is in both tables?
- 4. EXCEPT — customers not in suppliers
- 5. EXCEPT reversed — suppliers not in customers
- 6. Add 'customer'/'supplier' source label with UNION ALL
- 7. EXPLAIN a UNION query — see Append and Sort Unique nodes


---

## 3. Hands-On Commands & psql Output

### Setup — Customers and Suppliers
**Explanation:** Let us set up some tables to practice with. We will create a customers table and a suppliers table. Some names appear in both — these are people who are both customers and suppliers. This is a realistic scenario in many businesses.

```sql
CREATE TABLE customers (
    id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  VARCHAR(50),
    city  VARCHAR(50)
);

CREATE TABLE suppliers (
    id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  VARCHAR(50),
    city  VARCHAR(50)
);

INSERT INTO customers (name, city) VALUES
('Meera', 'Mumbai'), ('Ravi', 'Delhi'),
('Priya', 'Chennai'), ('Arjun', 'Mumbai'),
('Sonia', 'Bangalore');

INSERT INTO suppliers (name, city) VALUES
('Kiran', 'Pune'), ('Meera', 'Mumbai'),
('Deepak', 'Delhi'), ('Priya', 'Chennai'),
('Vikram', 'Hyderabad');
```

### UNION vs UNION ALL
**Explanation:** UNION combines results from two queries and removes duplicates. Notice that Meera and Priya appear in both tables, but in the UNION result they appear only ONCE. UNION ALL keeps all rows including duplicates — Meera and Priya appear TWICE. Use UNION ALL when you know there are no duplicates or when you WANT duplicates. It is faster because PostgreSQL does not need to sort and deduplicate.

```sql
-- UNION: combines + removes duplicates
practice=# SELECT name, city FROM customers
UNION
SELECT name, city FROM suppliers;
  name  |   city
--------+-----------
 Arjun  | Mumbai
 Deepak | Delhi
 Kiran  | Pune
 Meera  | Mumbai
 Priya  | Chennai
 Ravi   | Delhi
 Sonia  | Bangalore
 Vikram | Hyderabad
(8 rows)  ← Meera & Priya appear once

-- UNION ALL: combines + keeps duplicates
practice=# SELECT name, city FROM customers
UNION ALL
SELECT name, city FROM suppliers;
(10 rows)  ← Meera & Priya appear twice
```

### INTERSECT — Common Rows Only
**Explanation:** INTERSECT returns only rows that appear in BOTH queries. Here, Meera from Mumbai and Priya from Chennai are in both the customers and suppliers tables. INTERSECT checks ALL columns — both name AND city must match. If Meera were in Mumbai in one table and Delhi in the other, she would NOT appear in the INTERSECT result.

```sql
-- INTERSECT: rows in BOTH queries
practice=# SELECT name, city FROM customers
INTERSECT
SELECT name, city FROM suppliers;
  name | city
-------+---------
 Meera | Mumbai
 Priya | Chennai
(2 rows)

-- These people are BOTH customers AND suppliers
-- ALL columns must match (name AND city)

-- INTERSECT ALL keeps duplicate counts
-- (rarely used, but exists)
```

### EXCEPT — Rows in First But Not Second
**Explanation:** EXCEPT returns rows from the first query that do NOT appear in the second query. Order matters! Customers EXCEPT suppliers gives customers who are NOT suppliers. Suppliers EXCEPT customers gives suppliers who are NOT customers. Swapping the order gives completely different results. This is like set subtraction in mathematics.

```sql
-- Customers who are NOT suppliers
practice=# SELECT name, city FROM customers
EXCEPT
SELECT name, city FROM suppliers;
  name  |   city
--------+-----------
 Arjun  | Mumbai
 Ravi   | Delhi
 Sonia  | Bangalore
(3 rows)

-- Suppliers who are NOT customers (reversed!)
practice=# SELECT name, city FROM suppliers
EXCEPT
SELECT name, city FROM customers;
  name  |   city
--------+-----------
 Deepak | Delhi
 Kiran  | Pune
 Vikram | Hyderabad
(3 rows)  ← completely different!
```

### Column Matching, ORDER BY, and Labels
**Explanation:** The column matching rule is strict. Both queries must return the SAME number of columns, and the types must be compatible. The column NAMES come from the first query — the second query's column names are ignored. You can ORDER BY at the end, but it applies to the COMBINED result. You can also add a label column to tell which source each row came from.

```sql
-- Add a source label to identify which table
practice=# SELECT name, city, 'customer' AS source FROM customers
UNION ALL
SELECT name, city, 'supplier' AS source FROM suppliers
ORDER BY name;
  name  |   city    |  source
--------+-----------+----------
 Arjun  | Mumbai    | customer
 Deepak | Delhi     | supplier
 Kiran  | Pune      | supplier
 Meera  | Mumbai    | customer
 Meera  | Mumbai    | supplier
 Priya  | Chennai   | customer
 Priya  | Chennai   | supplier
 ...

-- ORDER BY applies to the final combined result
-- Column names come from the FIRST query
```

### Chaining Set Operations
**Explanation:** You can chain multiple set operations. For example, UNION three different tables. You can also combine UNION with WHERE and other clauses. Each individual query can have its own WHERE, JOIN, or GROUP BY. Just remember: the number and types of columns must match across ALL queries in the chain.

```sql
-- Combine with WHERE clauses
practice=# SELECT name, city FROM customers WHERE city = 'Mumbai'
UNION
SELECT name, city FROM suppliers WHERE city = 'Mumbai';
  name | city
-------+--------
 Arjun | Mumbai
 Meera | Mumbai
(2 rows)

-- Chain three or more UNIONs
-- SELECT ... FROM table_a
-- UNION ALL
-- SELECT ... FROM table_b
-- UNION ALL
-- SELECT ... FROM table_c
-- ORDER BY column;
```

### Beginner Trap: UNION Hides a Sort
**Explanation:** Beginner trap: UNION silently sorts and deduplicates the entire result set. With EXPLAIN, you can see the difference. UNION shows an Append node followed by a Sort and Unique step — that sort is expensive on large result sets. UNION ALL shows only the Append node — no sort, no dedup, much faster. On a million-row result, UNION can be ten times slower than UNION ALL. Always ask yourself: do I actually need deduplication? If not, use UNION ALL.

```sql
-- UNION: Append → Sort → Unique (expensive!)
practice=# EXPLAIN SELECT name, city FROM customers
UNION
SELECT name, city FROM suppliers;
 Unique  (cost=2.34..2.38 rows=8)
   ->  Sort  (cost=2.34..2.36 rows=10)
         Sort Key: customers.name, customers.city
         ->  Append  (cost=0.00..2.10 rows=10)
               ->  Seq Scan on customers
               ->  Seq Scan on suppliers

-- UNION ALL: just Append (fast!)
practice=# EXPLAIN SELECT name, city FROM customers
UNION ALL
SELECT name, city FROM suppliers;
 Append  (cost=0.00..2.10 rows=10)
   ->  Seq Scan on customers
   ->  Seq Scan on suppliers

-- No Sort, no Unique → much faster on large data!
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common Mistakes & Performance
Common mistakes: Column count mismatch gives an error — each SELECT must have the same number of columns. Type mismatch also fails — you cannot UNION a text column with an integer column unless you cast it. And remember: UNION without ALL is slower because it must sort and remove duplicates. If you know there are no duplicates, always use UNION ALL for better performance.

### Beginner Trap: UNION Hides a Sort
Beginner trap: UNION silently sorts and deduplicates the entire result set. With EXPLAIN, you can see the difference. UNION shows an Append node followed by a Sort and Unique step — that sort is expensive on large result sets. UNION ALL shows only the Append node — no sort, no dedup, much faster. On a million-row result, UNION can be ten times slower than UNION ALL. Always ask yourself: do I actually need deduplication? If not, use UNION ALL.

```sql
-- UNION: Append → Sort → Unique (expensive!)
EXPLAIN SELECT name, city FROM customers
UNION
SELECT name, city FROM suppliers;
 Unique  (cost=2.34..2.38 rows=8)
   ->  Sort  (cost=2.34..2.36 rows=10)
         Sort Key: customers.name, customers.city
         ->  Append  (cost=0.00..2.10 rows=10)
               ->  Seq Scan on customers
               ->  Seq Scan on suppliers

-- UNION ALL: just Append (fast!)
EXPLAIN SELECT name, city FROM customers
UNION ALL
SELECT name, city FROM suppliers;
 Append  (cost=0.00..2.10 rows=10)
   ->  Seq Scan on customers
   ->  Seq Scan on suppliers

-- No Sort, no Unique → much faster on large data!
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. UNION stacks two query results and removes duplicates. UNION ALL keeps all rows including duplicates and is faster. INTERSECT returns only rows common to both queries. EXCEPT returns rows from the first query not in the second — order matters. All set operations require matching column counts and compatible types. Column names come from the first query. In the next class, we begin Window Functions — one of the most powerful features in SQL. See you there!

- **UNION: all rows, duplicates removed (slower)**
- **UNION ALL: all rows, duplicates kept (faster)**
- **INTERSECT: only common rows between both queries**
- **EXCEPT: rows in first query NOT in second (order matters!)**
- **Column count must match across all queries**
- **Types must be compatible; names come from first query**
- **ORDER BY at the end applies to the combined result**
- **Prefer UNION ALL when duplicates are impossible**


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

## 8. Practice Exercises & Verified Answer Key

### Exercise 1: Deduplicated Combination
```sql
SELECT name, city FROM customers
UNION
SELECT name, city FROM suppliers
ORDER BY name;
```
*Explanation:* `UNION` combines rows from both queries and removes duplicate tuples. In execution plans, this introduces an `Append` followed by a `Unique` or `HashAggregate` node.

### Exercise 2: High-Performance Append
```sql
SELECT name, city FROM customers
UNION ALL
SELECT name, city FROM suppliers;
```
*Explanation:* `UNION ALL` performs a pure append without memory sorting or deduplication overhead. In production, always default to `UNION ALL` unless duplicate suppression is explicitly required.

### Exercise 3: Set Intersection
```sql
SELECT name, city FROM customers
INTERSECT
SELECT name, city FROM suppliers;
```
*Explanation:* `INTERSECT` returns only distinct records that exist in both queries.

### Exercise 4: Set Difference
```sql
SELECT name, city FROM customers
EXCEPT
SELECT name, city FROM suppliers;
```
*Explanation:* `EXCEPT` returns distinct records that exist in the first query but do not exist in the second query.

### Exercise 5: Tagged Source Aggregation
```sql
SELECT name, city, 'Customer' AS source FROM customers
UNION ALL
SELECT name, city, 'Supplier' AS source FROM suppliers
ORDER BY source, name;
```
*Explanation:* Projecting literal constant columns (`'Customer'`, `'Supplier'`) allows applications to preserve lineage when aggregating heterogeneous datasets.
