-- =============================================
-- PostgreSQL Mastery: Normalization (1NF, 2NF, 3NF, BCNF)
-- Phase 3: Database Design | Class 20
-- =============================================
-- Organize tables to eliminate redundancy and anomalies.
-- =============================================

-- === THE PROBLEM: Unnormalized Table ===

CREATE TABLE orders_messy (
    order_id   INT,
    cust_name  VARCHAR(100),
    cust_email VARCHAR(150),
    cust_city  VARCHAR(100),
    product    VARCHAR(100),
    price      NUMERIC(10,2),
    qty        INT,
    order_date DATE
);

INSERT INTO orders_messy VALUES
(1, 'Ravi',  'ravi@ex.com',  'Mumbai', 'Laptop',   999.99, 1, '2026-10-01'),
(2, 'Ravi',  'ravi@ex.com',  'Mumbai', 'Mouse',     29.99, 2, '2026-10-01'),
(3, 'Priya', 'priya@ex.com', 'Delhi',  'Keyboard',  49.99, 1, '2026-10-05'),
(4, 'Ravi',  'ravi@ex.com',  'Mumbai', 'Monitor',  299.99, 1, '2026-10-10');

-- Problems:
-- UPDATE anomaly: Ravi's email/city repeated 3 times
-- DELETE anomaly: delete Priya's only order → lose her info
-- INSERT anomaly: can't add customer without an order

-- === 1NF — First Normal Form ===
-- Rule 1: Atomic values (one value per cell, no lists)
-- Rule 2: Unique rows (must have a primary key)
-- Rule 3: No repeating groups (no product1, product2 columns)
-- Our table passes 1NF (each cell is atomic)

-- === 2NF — Second Normal Form ===
-- Must be in 1NF
-- No partial dependency on composite primary key
-- If PK = (order_id, product), cust_name depends only on order_id → partial dep!
-- Fix: split into separate tables by subject

-- === 3NF — Third Normal Form ===
-- Must be in 2NF
-- No transitive dependency
-- order_id → cust_name → cust_city (city depends on customer, not order)
-- Fix: move cust_city to customers table
-- Motto: "The key, the whole key, and nothing but the key"

-- === BCNF — Boyce-Codd Normal Form ===
-- Every determinant must be a candidate key
-- In practice: 3NF with single PK is almost always BCNF
-- BCNF violations are rare (complex composite keys)
-- 3NF is sufficient for most applications

-- === THE FIX: Normalized Tables (3NF) ===

CREATE TABLE customers (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    city  VARCHAR(100)
);

CREATE TABLE products (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    price NUMERIC(10,2) NOT NULL
);

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    product_id  INT NOT NULL REFERENCES products(id),
    qty         INT NOT NULL DEFAULT 1,
    order_date  DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Insert data (each fact stored ONCE)
INSERT INTO customers (name, email, city) VALUES
('Ravi', 'ravi@ex.com', 'Mumbai'),
('Priya', 'priya@ex.com', 'Delhi');

INSERT INTO products (name, price) VALUES
('Laptop', 999.99),
('Mouse', 29.99),
('Keyboard', 49.99),
('Monitor', 299.99);

INSERT INTO orders (customer_id, product_id, qty, order_date) VALUES
(1, 1, 1, '2026-10-01'),
(1, 2, 2, '2026-10-01'),
(2, 3, 1, '2026-10-05'),
(1, 4, 1, '2026-10-10');

-- === JOIN to Reconstruct Full View ===

SELECT o.id AS order_id,
       c.name AS customer,
       c.email,
       c.city,
       p.name AS product,
       p.price,
       o.qty,
       o.order_date
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN products p ON o.product_id = p.id
ORDER BY o.id;

-- Same data as messy table, but stored correctly!
-- Ravi's info stored ONCE. Update city → 1 row only.

-- === BENEFITS OF NORMALIZATION ===

-- 1. No redundancy — each fact stored once
-- 2. Consistency — update one place, correct everywhere
-- 3. No anomalies — clean INSERT, UPDATE, DELETE
-- 4. Smaller storage — no repeated data
-- 5. Easier maintenance — schema changes affect fewer tables
-- Trade-off: queries need JOINs (slight performance cost)

-- === NORMAL FORMS SUMMARY ===

-- 1NF: Atomic values, unique rows, no repeating groups
-- 2NF: 1NF + no partial dependency on composite key
-- 3NF: 2NF + no transitive dependency (PRACTICAL TARGET)
-- BCNF: Every determinant is a candidate key (rare issue)

-- === PRACTICE EXERCISES ===

-- Exercise 1: Identify anomalies in this table:
CREATE TABLE student_courses_messy (
    student_name  VARCHAR(100),
    student_email VARCHAR(150),
    course_name   VARCHAR(100),
    instructor    VARCHAR(100),
    grade         CHAR(2)
);
INSERT INTO student_courses_messy VALUES
('Ravi', 'ravi@ex.com', 'Database 101', 'Prof. Shah', 'A'),
('Ravi', 'ravi@ex.com', 'Web Dev', 'Prof. Kumar', 'B+'),
('Priya', 'priya@ex.com', 'Database 101', 'Prof. Shah', 'A+'),
('Arjun', 'arjun@ex.com', 'Web Dev', 'Prof. Kumar', 'B');
-- What are the anomalies?

-- Exercise 2: Normalize to 3NF
CREATE TABLE students (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL
);

CREATE TABLE courses (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    instructor VARCHAR(100)
);

CREATE TABLE enrollments (
    id         SERIAL PRIMARY KEY,
    student_id INT REFERENCES students(id),
    course_id  INT REFERENCES courses(id),
    grade      CHAR(2),
    UNIQUE(student_id, course_id)
);

-- Exercise 3: Insert data
INSERT INTO students (name, email) VALUES
('Ravi', 'ravi@ex.com'), ('Priya', 'priya@ex.com'), ('Arjun', 'arjun@ex.com');

INSERT INTO courses (name, instructor) VALUES
('Database 101', 'Prof. Shah'), ('Web Dev', 'Prof. Kumar');

INSERT INTO enrollments (student_id, course_id, grade) VALUES
(1, 1, 'A'), (1, 2, 'B+'), (2, 1, 'A+'), (3, 2, 'B');

-- Exercise 4: JOIN to reconstruct
SELECT s.name AS student, s.email, c.name AS course, c.instructor, e.grade
FROM enrollments e
JOIN students s ON e.student_id = s.id
JOIN courses c ON e.course_id = c.id
ORDER BY s.name, c.name;

-- Exercise 5: Update Ravi's email
-- Normalized: UPDATE students SET email = 'ravi.new@ex.com' WHERE name = 'Ravi';
-- (1 row updated!)
-- Messy: UPDATE student_courses_messy SET student_email = 'ravi.new@ex.com' WHERE student_name = 'Ravi';
-- (2 rows updated — and if you miss one, data is inconsistent!)

-- === CLEANUP ===
-- DROP TABLE IF EXISTS orders, products, customers, orders_messy;
-- DROP TABLE IF EXISTS enrollments, courses, students, student_courses_messy;

-- =============================================
-- Next Class: Denormalization
-- =============================================

-- === ANSWER KEY ===
-- 1. Separate authors and books via Foreign Key
CREATE TABLE authors (id SERIAL PRIMARY KEY, name TEXT);
CREATE TABLE books (id SERIAL PRIMARY KEY, title TEXT, author_id INT REFERENCES authors(id));

-- 2. Junction table for 1NF (no comma-separated tags)
CREATE TABLE post_tags (post_id INT REFERENCES posts(id), tag_id INT REFERENCES tags(id), PRIMARY KEY (post_id, tag_id));

-- 3. Junction table for 2NF / 3NF enrollments
CREATE TABLE enrollments (student_id INT REFERENCES students(id), course_id INT REFERENCES courses(id), enrolled_on DATE, PRIMARY KEY (student_id, course_id));

-- 4. Update one customer city and verify joined orders
UPDATE customers SET city = 'Bengaluru' WHERE id = 1;
SELECT o.id, c.name, c.city FROM orders o JOIN customers c ON c.id = o.customer_id;

-- 5. Multi-table JOIN for clean receipts
SELECT o.id, c.name, p.title, oi.qty FROM orders o JOIN customers c ON c.id = o.customer_id JOIN order_items oi ON oi.order_id = o.id JOIN products p ON p.id = oi.product_id;
