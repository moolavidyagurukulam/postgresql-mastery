-- =============================================
-- PostgreSQL Mastery: Constraints
-- Phase 4: DDL | Classes 28-31
-- =============================================
-- PRIMARY KEY, UNIQUE, CHECK, NOT NULL, FOREIGN KEY,
-- EXCLUDE, DEFAULT — the rules that protect data integrity.
-- =============================================

-- === PRIMARY KEY ===

-- Unique identity for every row (UNIQUE + NOT NULL)
CREATE TABLE users (
    id    SERIAL,
    name  VARCHAR(100),
    email VARCHAR(150),
    CONSTRAINT pk_users PRIMARY KEY (id)
);

-- Short inline syntax:
-- id SERIAL PRIMARY KEY

-- Composite primary key (combination must be unique)
CREATE TABLE enrollments (
    student_id INT,
    course_id  INT,
    grade      CHAR(2),
    CONSTRAINT pk_enrollments PRIMARY KEY (student_id, course_id)
);

-- PK violations:
INSERT INTO users (name) VALUES ('Ravi');   -- id=1
INSERT INTO users (name) VALUES ('Priya');  -- id=2
-- INSERT INTO users (id, name) VALUES (1, 'Arjun');
-- ERROR: duplicate key value violates unique constraint "pk_users"
-- DETAIL: Key (id)=(1) already exists.

-- === UNIQUE ===

ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE (email);

INSERT INTO users (name, email) VALUES ('Arjun', 'arjun@ex.com');
-- INSERT INTO users (name, email) VALUES ('Meera', 'arjun@ex.com');
-- ERROR: duplicate key value violates unique constraint "uq_users_email"
-- DETAIL: Key (email)=(arjun@ex.com) already exists.

-- UNIQUE allows multiple NULLs (NULL != NULL in SQL)
INSERT INTO users (name, email) VALUES ('Test1', NULL);
INSERT INTO users (name, email) VALUES ('Test2', NULL);
-- Both succeed! NULLs are not duplicates.

-- Multi-column unique
CREATE TABLE team_members (
    team_id INT,
    user_id INT,
    role    VARCHAR(50),
    CONSTRAINT uq_team_user UNIQUE (team_id, user_id)
);

-- === NOT NULL ===

-- Column MUST have a value
ALTER TABLE users ALTER COLUMN name SET NOT NULL;

-- INSERT INTO users (email) VALUES ('test@ex.com');
-- ERROR: null value in column "name" violates not-null constraint

-- Add NOT NULL to column with existing nulls:
-- Step 1: Fill nulls
UPDATE users SET email = 'unknown@ex.com' WHERE email IS NULL;
-- Step 2: Add constraint
ALTER TABLE users ALTER COLUMN email SET NOT NULL;

-- Remove NOT NULL:
-- ALTER TABLE users ALTER COLUMN email DROP NOT NULL;

-- === CHECK ===

CREATE TABLE products (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    price NUMERIC(10,2),
    qty   INT,
    CONSTRAINT ck_products_price CHECK (price > 0),
    CONSTRAINT ck_products_qty CHECK (qty >= 0)
);

INSERT INTO products (name, price, qty) VALUES ('Laptop', 999.99, 5);  -- OK

-- INSERT INTO products (name, price, qty) VALUES ('Free', 0, 10);
-- ERROR: new row violates check constraint "ck_products_price"

-- INSERT INTO products (name, price, qty) VALUES ('Widget', 9.99, -3);
-- ERROR: new row violates check constraint "ck_products_qty"

-- Multi-column CHECK
CREATE TABLE events (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date   DATE NOT NULL,
    CONSTRAINT ck_events_dates CHECK (end_date >= start_date)
);

INSERT INTO events (name, start_date, end_date)
VALUES ('Conference', '2026-11-10', '2026-11-12');  -- OK

-- INSERT INTO events (name, start_date, end_date)
-- VALUES ('Bad Event', '2026-11-10', '2026-11-05');
-- ERROR: new row violates check constraint "ck_events_dates"

-- === DEFAULT ===

CREATE TABLE orders (
    id         SERIAL PRIMARY KEY,
    product    VARCHAR(100) NOT NULL,
    qty        INT DEFAULT 1,
    status     VARCHAR(20) DEFAULT 'pending',
    ordered_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert with defaults:
INSERT INTO orders (product) VALUES ('Laptop');
SELECT * FROM orders;
-- qty=1, status='pending', ordered_at=now

-- Override defaults:
INSERT INTO orders (product, qty, status)
VALUES ('Monitor', 3, 'confirmed');

-- === FOREIGN KEY ===

CREATE TABLE customers (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE customer_orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    product     VARCHAR(100),
    CONSTRAINT fk_custord_customer
      FOREIGN KEY (customer_id)
      REFERENCES customers(id)
);

INSERT INTO customers (name) VALUES ('Ravi'), ('Priya');

INSERT INTO customer_orders (customer_id, product) VALUES (1, 'Laptop');  -- OK

-- INSERT INTO customer_orders (customer_id, product) VALUES (99, 'Mouse');
-- ERROR: violates foreign key constraint "fk_custord_customer"
-- DETAIL: Key (customer_id)=(99) is not present in table "customers".

-- DELETE FROM customers WHERE id = 1;
-- ERROR: violates foreign key constraint on table "customer_orders"

-- === FOREIGN KEY — ON DELETE Actions ===

-- CASCADE: delete child rows when parent is deleted
CREATE TABLE orders_cascade (
    id          SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id) ON DELETE CASCADE,
    product     VARCHAR(100)
);

INSERT INTO orders_cascade (customer_id, product) VALUES (1, 'Laptop'), (1, 'Mouse');
DELETE FROM customers WHERE id = 1;
SELECT * FROM orders_cascade WHERE customer_id = 1;  -- (0 rows) — auto deleted!

-- SET NULL: set FK to NULL when parent is deleted
CREATE TABLE orders_setnull (
    id          SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id) ON DELETE SET NULL,
    product     VARCHAR(100)
);

INSERT INTO customers (name) VALUES ('Arjun');  -- gets id=3
INSERT INTO orders_setnull (customer_id, product) VALUES (2, 'Keyboard');
DELETE FROM customers WHERE id = 2;
SELECT * FROM orders_setnull;  -- customer_id is NULL now

-- RESTRICT (default): refuse delete if children exist
-- NO ACTION: same, but checked at transaction end

-- ON UPDATE CASCADE: update FK when parent PK changes
-- (Rarely used — PKs shouldn't change)

-- === EXCLUDE — Prevent Overlapping Ranges ===

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE room_bookings (
    id        SERIAL PRIMARY KEY,
    room      VARCHAR(50) NOT NULL,
    booked    TSTZRANGE NOT NULL,
    booked_by VARCHAR(100),
    CONSTRAINT excl_bookings_overlap
      EXCLUDE USING GIST (
        room WITH =,
        booked WITH &&
      )
);

-- Book Room A from 9am to 10am
INSERT INTO room_bookings (room, booked, booked_by)
VALUES ('Room A', '[2026-11-03 09:00, 2026-11-03 10:00)', 'Ravi');

-- Overlapping booking in same room:
-- INSERT INTO room_bookings (room, booked, booked_by)
-- VALUES ('Room A', '[2026-11-03 09:30, 2026-11-03 11:00)', 'Priya');
-- ERROR: conflicting key value violates exclusion constraint "excl_bookings_overlap"

-- Different room at same time → OK!
INSERT INTO room_bookings (room, booked, booked_by)
VALUES ('Room B', '[2026-11-03 09:30, 2026-11-03 11:00)', 'Priya');

-- Same room, non-overlapping → OK!
INSERT INTO room_bookings (room, booked, booked_by)
VALUES ('Room A', '[2026-11-03 10:00, 2026-11-03 11:00)', 'Arjun');

-- === Adding & Dropping Constraints ===

-- Add constraint to existing table
ALTER TABLE products ADD CONSTRAINT uq_products_name UNIQUE (name);

-- Drop constraint by name
ALTER TABLE products DROP CONSTRAINT uq_products_name;

-- Drop IF EXISTS
ALTER TABLE products DROP CONSTRAINT IF EXISTS uq_products_name;

-- View constraints: \d products

-- === CONSTRAINT NAMING CONVENTIONS ===

-- pk_table           → PRIMARY KEY
-- uq_table_column    → UNIQUE
-- ck_table_column    → CHECK
-- fk_table_ref       → FOREIGN KEY
-- excl_table_desc    → EXCLUDE
-- NOT NULL has no name (applied inline)

-- === PRACTICE EXERCISES ===

-- Exercise 1: Full constraint table
CREATE TABLE students (
    id    SERIAL,
    name  VARCHAR(100) NOT NULL,
    email VARCHAR(150),
    age   INT,
    CONSTRAINT pk_students PRIMARY KEY (id),
    CONSTRAINT uq_students_email UNIQUE (email),
    CONSTRAINT ck_students_age CHECK (age >= 18 AND age <= 120)
);

-- Exercise 2: FK with CASCADE
CREATE TABLE assignments (
    id         SERIAL PRIMARY KEY,
    student_id INT NOT NULL,
    title      VARCHAR(200) NOT NULL,
    due_date   DATE DEFAULT CURRENT_DATE + INTERVAL '7 days',
    CONSTRAINT fk_assign_student
      FOREIGN KEY (student_id)
      REFERENCES students(id)
      ON DELETE CASCADE
);

-- Exercise 3: Insert and violate each constraint
INSERT INTO students (name, email, age) VALUES ('Ravi', 'ravi@uni.com', 22);
INSERT INTO assignments (student_id, title) VALUES (1, 'SQL Homework');

-- Try these (each should error):
-- INSERT INTO students (id, name, age) VALUES (1, 'Dup', 25);     -- PK violation
-- INSERT INTO students (name, email, age) VALUES ('X', 'ravi@uni.com', 25);  -- UNIQUE violation
-- INSERT INTO students (name, age) VALUES (NULL, 25);              -- NOT NULL violation
-- INSERT INTO students (name, age) VALUES ('Young', 15);           -- CHECK violation
-- INSERT INTO assignments (student_id, title) VALUES (99, 'HW');   -- FK violation

-- Exercise 4: Cascade delete
DELETE FROM students WHERE id = 1;
SELECT * FROM assignments;  -- (0 rows) — cascade deleted!

-- Exercise 5: EXCLUDE constraint (schedule)
CREATE TABLE doctor_appointments (
    id        SERIAL PRIMARY KEY,
    doctor    VARCHAR(100) NOT NULL,
    slot      TSTZRANGE NOT NULL,
    patient   VARCHAR(100),
    CONSTRAINT excl_doctor_overlap
      EXCLUDE USING GIST (doctor WITH =, slot WITH &&)
);

INSERT INTO doctor_appointments (doctor, slot, patient)
VALUES ('Dr. Shah', '[2026-11-03 14:00, 2026-11-03 14:30)', 'Ravi');

-- This should fail (overlapping):
-- INSERT INTO doctor_appointments (doctor, slot, patient)
-- VALUES ('Dr. Shah', '[2026-11-03 14:15, 2026-11-03 14:45)', 'Priya');

-- This should work (different doctor):
INSERT INTO doctor_appointments (doctor, slot, patient)
VALUES ('Dr. Kumar', '[2026-11-03 14:15, 2026-11-03 14:45)', 'Priya');


-- =============================================
-- ANSWER KEY — CONSTRAINTS SOLUTIONS
-- =============================================
-- 1. Table with PRIMARY KEY, UNIQUE, and CHECK constraints
-- Note: Named constraints make error debugging much easier.
CREATE TABLE team_members (
    id SERIAL PRIMARY KEY,
    email VARCHAR(100) NOT NULL UNIQUE,
    age INT CHECK (age BETWEEN 18 AND 70),
    role VARCHAR(30) DEFAULT 'Developer'
);

-- 2. FOREIGN KEY with ON DELETE CASCADE and SET NULL
-- Note: CASCADE deletes children; SET NULL clears reference.
CREATE TABLE projects (id SERIAL PRIMARY KEY, lead_id INT REFERENCES team_members(id) ON DELETE SET NULL);
CREATE TABLE tasks (id SERIAL PRIMARY KEY, project_id INT REFERENCES projects(id) ON DELETE CASCADE);

-- 3. EXCLUDE constraint preventing overlapping room bookings
-- Note: Requires btree_gist extension for scalar + range exclusion.
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE TABLE room_bookings (
    room_id INT,
    during TSTZRANGE,
    EXCLUDE USING GIST (room_id WITH =, during WITH &&)
);

-- 4. ALTER TABLE ADD and DROP constraint
-- Note: Always name constraints explicitly for simple alteration.
ALTER TABLE team_members ADD CONSTRAINT ck_min_age CHECK (age >= 18);
ALTER TABLE team_members DROP CONSTRAINT ck_min_age;

-- 5. Checking constraint violations in psql
-- Note: Familiarize yourself with exact error strings.
INSERT INTO team_members (email, age) VALUES ('test@co.com', 15); -- triggers check constraint
INSERT INTO team_members (email, age) VALUES ('test@co.com', 25); -- succeeds
INSERT INTO team_members (email, age) VALUES ('test@co.com', 25); -- triggers unique constraint


-- === CLEANUP ===
-- DROP TABLE IF EXISTS assignments, students;
-- DROP TABLE IF EXISTS doctor_appointments, room_bookings;
-- DROP TABLE IF EXISTS orders_cascade, orders_setnull, customer_orders, orders;
-- DROP TABLE IF EXISTS customers, products, events, team_members;
-- DROP TABLE IF EXISTS enrollments, users;
-- DROP EXTENSION IF EXISTS btree_gist;

-- =============================================
-- Next Class: Sequences, IDENTITY & Temporary Tables
-- =============================================
