-- =============================================
-- PostgreSQL Mastery: Data Types Part 1 — Numeric & Text
-- Phase 2: Database Objects | Classes 12-13
-- =============================================
-- INTEGER, BIGINT, NUMERIC, SERIAL, VARCHAR, TEXT
-- =============================================

-- === INTEGER TYPES ===

-- SMALLINT  = 2 bytes  | -32,768 to 32,767
-- INTEGER   = 4 bytes  | -2,147,483,648 to 2,147,483,647
-- BIGINT    = 8 bytes  | -9.2 quintillion to 9.2 quintillion

CREATE TABLE int_demo (
    small_val   SMALLINT,
    regular_val INTEGER,
    big_val     BIGINT
);

INSERT INTO int_demo VALUES (100, 1000000, 9000000000000);

-- Overflow errors:
-- INSERT INTO int_demo (small_val) VALUES (50000);     -- ERROR: smallint out of range
-- INSERT INTO int_demo (regular_val) VALUES (3000000000); -- ERROR: integer out of range

-- === DECIMAL / NUMERIC TYPES ===

-- NUMERIC(precision, scale) = exact decimal (ALWAYS use for money!)
-- DECIMAL(p,s) = alias for NUMERIC
-- REAL (FLOAT4)        = 4 bytes, ~6 digits, inexact
-- DOUBLE PRECISION     = 8 bytes, ~15 digits, inexact

-- NUMERIC is EXACT:
SELECT 0.1::NUMERIC + 0.2::NUMERIC AS exact_result;  -- 0.3 (correct!)

-- REAL is INEXACT:
SELECT 0.1::REAL + 0.2::REAL AS float_result;  -- 0.30000001... (wrong for money!)

-- NUMERIC with precision and scale
CREATE TABLE products (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100),
    price NUMERIC(10,2)  -- 10 total digits, 2 after decimal
);

INSERT INTO products (name, price) VALUES ('Laptop', 999.99);
INSERT INTO products (name, price) VALUES ('Mouse', 29.50);

-- Overflow:
-- INSERT INTO products (name, price) VALUES ('Jet', 99999999.999);
-- ERROR: numeric field overflow

-- === AUTO-INCREMENT: SERIAL & IDENTITY ===

-- SERIAL       = INTEGER + auto-increment sequence
-- BIGSERIAL    = BIGINT + auto-increment
-- SMALLSERIAL  = SMALLINT + auto-increment (rarely used)

CREATE TABLE orders (
    id   SERIAL PRIMARY KEY,
    item VARCHAR(100)
);

INSERT INTO orders (item) VALUES ('Keyboard');
INSERT INTO orders (item) VALUES ('Mouse');
INSERT INTO orders (item) VALUES ('Monitor');
SELECT * FROM orders;
-- id auto-fills: 1, 2, 3

-- GENERATED ALWAYS AS IDENTITY (SQL standard, preferred in new code)
CREATE TABLE invoices (
    id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    total NUMERIC(10,2)
);

INSERT INTO invoices (total) VALUES (150.00);
INSERT INTO invoices (total) VALUES (275.50);
SELECT * FROM invoices;

-- === TEXT TYPES ===

-- CHAR(n)    = fixed-length, padded with spaces (rarely used)
-- VARCHAR(n) = variable-length, up to n characters (most common)
-- VARCHAR    = variable-length, no limit (same as TEXT)
-- TEXT       = variable-length, no limit

-- In PostgreSQL: VARCHAR and TEXT have the SAME performance!

CREATE TABLE text_demo (
    code CHAR(5),       -- fixed: always 5 chars (padded)
    name VARCHAR(50),   -- up to 50 chars
    bio  TEXT            -- unlimited
);

INSERT INTO text_demo VALUES ('AB', 'Ravi Kumar', 'A software developer from India');

-- CHAR pads with spaces:
SELECT code, length(code), char_length(code) FROM text_demo;

-- VARCHAR enforces limit:
-- INSERT INTO text_demo (name) VALUES (repeat('x', 51));
-- ERROR: value too long for type character varying(50)

-- TEXT has no limit:
INSERT INTO text_demo (bio) VALUES (repeat('x', 10000));

-- === CHOOSING THE RIGHT TYPE ===

-- IDs / Primary keys     → SERIAL or BIGSERIAL
-- Money / Price           → NUMERIC(10,2) — NEVER REAL or FLOAT!
-- Age / Quantity          → INTEGER
-- Name / Email            → VARCHAR(100) or VARCHAR(255)
-- Description / Content   → TEXT
-- Country code            → CHAR(2) or VARCHAR(2)
-- Scientific data         → DOUBLE PRECISION

-- === COMMON ERRORS ===

-- ERROR: smallint/integer out of range
-- FIX: Use a larger type (INTEGER → BIGINT)

-- ERROR: value too long for type character varying(n)
-- FIX: Increase VARCHAR limit or use TEXT

-- ERROR: numeric field overflow
-- FIX: Increase NUMERIC precision

-- ERROR: invalid input syntax for type integer: "hello"
-- FIX: Check your data — cannot insert text into numeric column

-- === PRACTICE EXERCISES ===

-- Exercise 1:
CREATE TABLE employees (
    id     SERIAL PRIMARY KEY,
    name   VARCHAR(100) NOT NULL,
    age    SMALLINT,
    salary NUMERIC(10,2)
);
INSERT INTO employees (name, age, salary) VALUES ('Ravi', 28, 75000.00);
INSERT INTO employees (name, age, salary) VALUES ('Priya', 32, 92000.50);
INSERT INTO employees (name, age, salary) VALUES ('Arjun', 25, 65000.00);
SELECT * FROM employees;

-- Exercise 2: SMALLINT overflow
-- INSERT INTO employees (name, age) VALUES ('Test', 50000);

-- Exercise 3: TEXT with 5000 chars
CREATE TABLE articles (id SERIAL, content TEXT);
INSERT INTO articles (content) VALUES (repeat('Hello world! ', 400));
SELECT id, length(content) FROM articles;

-- Exercise 4: NUMERIC vs REAL comparison
SELECT 0.1::NUMERIC + 0.2::NUMERIC AS numeric_result,
       0.1::REAL + 0.2::REAL AS real_result;

-- Exercise 5: IDENTITY instead of SERIAL
CREATE TABLE tasks (
    id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title VARCHAR(200) NOT NULL
);
INSERT INTO tasks (title) VALUES ('Learn PostgreSQL');
INSERT INTO tasks (title) VALUES ('Build a project');
INSERT INTO tasks (title) VALUES ('Get certified');
SELECT * FROM tasks;

-- === CLEANUP ===
-- DROP TABLE IF EXISTS int_demo, products, orders, invoices;
-- DROP TABLE IF EXISTS text_demo, employees, articles, tasks;

-- =============================================
-- Next Class: Data Types — Date/Time & Boolean
-- =============================================
