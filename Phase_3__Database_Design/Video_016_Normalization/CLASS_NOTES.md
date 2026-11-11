# Normalization (1NF, 2NF, 3NF, BCNF)
**Series:** PostgreSQL Mastery | **Phase:** Phase 3: Database Design | **Classes:** Class 20
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! We are now in Phase 3 ... Database Design. Before you build tables, you need to design them well. ... Today we learn normalization ... the process of organizing your tables to eliminate redundancy and avoid data anomalies. Normalization is one of the most important concepts in database design. Every DBA must understand it. ... Let us dive in!

### The Problem: Data Anomalies
Here is the problem. Imagine a single table that stores orders with customer details and product details all in one row. ... Customer name is repeated in every order they make. If the customer changes their address, you must update it in every single row. Miss one and your data is inconsistent. ... Delete the last order of a customer, and you lose the customer's information too. ... Insert a new customer who has not ordered yet? You cannot ... because order ID is required. ... These are called anomalies. Update anomaly, delete anomaly, and insert anomaly. Normalization fixes all three.

- One big table with everything mixed together
- UPDATE anomaly: customer address repeated in every order row
- DELETE anomaly: delete last order → lose customer info
- INSERT anomaly: can't add a customer without an order
- Wasted storage: same data repeated hundreds of times
- Normalization = organize tables to eliminate these problems


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Data Anomalies
Here is the problem. Imagine a single table that stores orders with customer details and product details all in one row. ... Customer name is repeated in every order they make. If the customer changes their address, you must update it in every single row. Miss one and your data is inconsistent. ... Delete the last order of a customer, and you lose the customer's information too. ... Insert a new customer who has not ordered yet? You cannot ... because order ID is required. ... These are called anomalies. Update anomaly, delete anomaly, and insert anomaly. Normalization fixes all three.

- One big table with everything mixed together
- UPDATE anomaly: customer address repeated in every order row
- DELETE anomaly: delete last order → lose customer info
- INSERT anomaly: can't add a customer without an order
- Wasted storage: same data repeated hundreds of times
- Normalization = organize tables to eliminate these problems

### 1NF — First Normal Form
Let us normalize step by step. ... First Normal Form, or 1NF. The rules are: every column must have atomic values ... meaning one value per cell, no lists. Each row must be unique ... you need a primary key. No repeating groups ... do not have product1, product2, product3 columns. ... Our messy table actually already passes 1NF. Each cell has one value, and each row is unique with order_id. ... But let us imagine a worse version where products is a comma-separated list. That would violate 1NF. You must split each product into its own row.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Rule 1** | Atomic values — one value per cell (no lists) |
| **Rule 2** | Unique rows — must have a primary key |
| **Rule 3** | No repeating groups — no product1, product2, product3 |
| **Violates 1NF** | 'Laptop, Mouse' in one cell → must split into rows |
| **Our table** | Already passes 1NF (each cell is atomic) |

**Notes:**
- 1NF is the foundation — every table must at least be in 1NF

### 2NF — Second Normal Form
Second Normal Form, or 2NF. First, the table must be in 1NF. Then, every non-key column must depend on the WHOLE primary key, not just part of it. ... This only matters when you have a composite primary key ... a key made of two or more columns. ... In our table, if the primary key is order_id plus product, then cust_name depends only on order_id, not on product. That is a partial dependency ... and it violates 2NF. ... The fix is to split the table. Customer information goes in a customers table. Product information goes in a products table. Orders reference them.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Prerequisite** | Must already be in 1NF |
| **Rule** | No partial dependency on composite primary key |
| **Partial dep** | cust_name depends on order_id only, not product |
| **Fix** | Split: customers table + products table + orders table |
| **Single PK** | Tables with single-column PK are auto 2NF |

**Notes:**
- Partial dependency = non-key column depends on PART of composite key

### 3NF — Third Normal Form
Third Normal Form, or 3NF. Must be in 2NF first. Then, no transitive dependency. ... What is a transitive dependency? It is when column A determines column B, and column B determines column C. Then C transitively depends on A through B. ... In our table, order_id determines cust_name, and cust_name determines cust_city. So cust_city transitively depends on order_id through cust_name. That violates 3NF. ... The fix is to put city in the customers table, not in orders. Each fact should be stored in exactly one place.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Prerequisite** | Must already be in 2NF |
| **Rule** | No transitive dependency |
| **Transitive** | order_id → cust_name → cust_city (city depends on name, not order) |
| **Fix** | Move cust_city to customers table |
| **Principle** | Every non-key column depends on the key, the whole key, and nothing but the key |

**Notes:**
- "The key, the whole key, and nothing but the key" — the 3NF motto

### BCNF — Boyce-Codd Normal Form
Boyce-Codd Normal Form, or BCNF. This is a stricter version of 3NF. ... In BCNF, every determinant must be a candidate key. A determinant is any column that uniquely determines another column. ... In practice, if your table is in 3NF with a single primary key, it is almost always in BCNF too. BCNF violations are rare and usually involve complex composite keys. ... For most applications, achieving 3NF is sufficient. Do not over-engineer. If your tables are in 3NF, you are in great shape.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Rule** | Every determinant must be a candidate key |
| **Determinant** | A column that uniquely determines another |
| **In practice** | 3NF with single PK is almost always BCNF |
| **Violations** | Rare — only with complex composite keys |
| **Recommendation** | 3NF is sufficient for most applications |

**Notes:**
- Don't over-engineer: 3NF is the practical target for most database designs

### Normal Forms — Quick Comparison
Here is a quick comparison of all four normal forms.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a quick comparison of all four normal forms |

### Benefits of Normalization
Why normalize? ... Benefit 1: no data redundancy. Customer name stored once, not in every order. ... Benefit 2: data consistency. Change it in one place, it is correct everywhere. ... Benefit 3: no anomalies. Insert, update, and delete work cleanly. ... Benefit 4: smaller storage. No repeated data means less disk space. ... Benefit 5: easier maintenance. Schema changes affect fewer tables. ... The trade-off is that queries need JOINs, which can be slower. But for most applications, the benefits far outweigh the cost of JOINs. We will talk about when to break normalization rules in our next class on denormalization.

- No redundancy — each fact stored exactly once
- Consistency — update one place, correct everywhere
- No anomalies — clean INSERT, UPDATE, DELETE
- Smaller storage — no repeated data
- Easier maintenance — schema changes affect fewer tables
- Trade-off: queries need JOINs (slight performance cost)


---

## 3. Hands-On Commands & psql Output

### The Messy Table — Unnormalized
**Explanation:** Let me show you a messy, unnormalized table. This is what bad design looks like. ... An orders table that contains: order ID, customer name, customer email, customer city, product name, product price, quantity, and order date. All in one table. ... Ravi appears in three rows with his email and city repeated. If Ravi moves to a new city, we must update all three rows. This is the kind of mess normalization prevents.

```sql
practice=# CREATE TABLE orders_messy (order_id INT, cust_name VARCHAR(100), cust_email VARCHAR(150), cust_city VARCHAR(100), product VARCHAR(100), price NUMERIC(10,2), qty INT, order_date DATE);
CREATE TABLE

practice=# INSERT INTO orders_messy VALUES (1,'Ravi','ravi@ex.com','Mumbai','Laptop',999.99,1,'2026-10-01'), (2,'Ravi','ravi@ex.com','Mumbai','Mouse',29.99,2,'2026-10-01'), (3,'Priya','priya@ex.com','Delhi','Keyboard',49.99,1,'2026-10-05'), (4,'Ravi','ravi@ex.com','Mumbai','Monitor',299.99,1,'2026-10-10');
INSERT 0 4

practice=# SELECT * FROM orders_messy;
 order_id | cust_name | cust_email   | cust_city | product  |  price | qty
----------+-----------+--------------+-----------+----------+--------+-----
        1 | Ravi      | ravi@ex.com  | Mumbai    | Laptop   | 999.99 |   1
        2 | Ravi      | ravi@ex.com  | Mumbai    | Mouse    |  29.99 |   2
        3 | Priya     | priya@ex.com | Delhi     | Keyboard |  49.99 |   1
        4 | Ravi      | ravi@ex.com  | Mumbai    | Monitor  | 299.99 |   1
-- Ravi's email & city repeated 3 times! BAD!
```

### Normalized Tables — The Right Way
**Explanation:** Now let me show you the properly normalized tables. We split the messy table into three tables. ... Customers table with customer_id, name, email, and city. Each customer appears once. ... Products table with product_id, name, and price. Each product appears once. ... Orders table with order_id, customer_id, product_id, quantity, and order_date. It references customers and products by ID. ... No data is repeated. Change Ravi's city? Update one row in customers. Delete an order? Customer data is safe. Add a customer without an order? No problem.

```sql
practice=# CREATE TABLE customers (id SERIAL PRIMARY KEY, name VARCHAR(100), email VARCHAR(150) UNIQUE, city VARCHAR(100));
CREATE TABLE
practice=# CREATE TABLE products (id SERIAL PRIMARY KEY, name VARCHAR(100), price NUMERIC(10,2));
CREATE TABLE
practice=# CREATE TABLE orders (id SERIAL PRIMARY KEY, customer_id INT REFERENCES customers(id), product_id INT REFERENCES products(id), qty INT, order_date DATE);
CREATE TABLE

practice=# INSERT INTO customers (name, email, city) VALUES ('Ravi','ravi@ex.com','Mumbai'), ('Priya','priya@ex.com','Delhi');
practice=# INSERT INTO products (name, price) VALUES ('Laptop',999.99), ('Mouse',29.99), ('Keyboard',49.99), ('Monitor',299.99);
practice=# INSERT INTO orders (customer_id, product_id, qty, order_date) VALUES (1,1,1,'2026-10-01'), (1,2,2,'2026-10-01'), (2,3,1,'2026-10-05'), (1,4,1,'2026-10-10');
INSERT 0 4
```

### JOINs Reconstruct the Full View
**Explanation:** But how do you see the original data with all the details? Use a JOIN. ... This query joins orders with customers and products to reconstruct the full view. The data is stored normalized but you can always query it denormalized when you need to.

```sql
practice=# SELECT o.id AS order_id, c.name AS customer, c.city, p.name AS product, p.price, o.qty, o.order_date FROM orders o JOIN customers c ON o.customer_id = c.id JOIN products p ON o.product_id = p.id;
 order_id | customer | city   | product  |  price | qty | order_date
----------+----------+--------+----------+--------+-----+------------
        1 | Ravi     | Mumbai | Laptop   | 999.99 |   1 | 2026-10-01
        2 | Ravi     | Mumbai | Mouse    |  29.99 |   2 | 2026-10-01
        3 | Priya    | Delhi  | Keyboard |  49.99 |   1 | 2026-10-05
        4 | Ravi     | Mumbai | Monitor  | 299.99 |   1 | 2026-10-10

-- Same data as the messy table, but stored properly!
-- Ravi's info stored ONCE. Update city → one row only.
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time! ... Exercise 1 ... Look at this unnormalized student_courses table: student_name, student_email, course_name, instructor, grade. Identify the anomalies. ... Exercise 2 ... Normalize it into 3NF. Create separate tables for students, courses, and enrollments. ... Exercise 3 ... Insert sample data into all three tables. ... Exercise 4 ... Write a JOIN query that reconstructs the original view. ... Exercise 5 ... Try updating a student's email in the normalized version versus the unnormalized version. Count how many rows you need to change.

1. Exercise 1: Identify anomalies in student_courses (name, email, course, instructor, grade)
2. Exercise 2: Normalize to 3NF → students, courses, enrollments tables
3. Exercise 3: INSERT sample data into all three tables
4. Exercise 4: JOIN query to reconstruct the original view
5. Exercise 5: Compare UPDATE effort: normalized vs unnormalized


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. ... Normalization organizes tables to eliminate redundancy and anomalies. ... 1NF: atomic values, unique rows, no repeating groups. ... 2NF: no partial dependency on composite keys. ... 3NF: no transitive dependency. The key, the whole key, and nothing but the key. ... BCNF: every determinant is a candidate key. ... For most applications, 3NF is the target. Split your data into subject-based tables and use foreign keys to connect them. JOINs reconstruct the full picture. ... In our next class, we learn when to break these rules ... denormalization!

- **Normalization = organize tables to eliminate redundancy**
- **1NF: atomic values, unique rows, no repeating groups**
- **2NF: no partial dependency on composite primary key**
- **3NF: no transitive dependency (the practical target)**
- **BCNF: every determinant is a candidate key (rare issue)**
- **Split into subject tables, connect with foreign keys**
- **JOINs reconstruct the full view when needed**


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
