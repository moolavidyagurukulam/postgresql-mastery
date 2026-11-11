-- =============================================
-- PostgreSQL Mastery: CREATE TABLE, ALTER TABLE & DROP TABLE
-- Phase 4: DDL | Classes 25-27
-- =============================================
-- Building, modifying, and removing tables.
-- =============================================

-- === CREATE TABLE — Basic Syntax ===

CREATE TABLE employees (
    id          SERIAL PRIMARY KEY,
    first_name  VARCHAR(100) NOT NULL,
    last_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(150) UNIQUE NOT NULL,
    department  VARCHAR(50),
    salary      NUMERIC(10,2) CHECK (salary > 0),
    hire_date   DATE DEFAULT CURRENT_DATE,
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Verify structure:
-- \d employees

-- === IF NOT EXISTS ===

-- No error if table already exists
CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    name TEXT
);
-- NOTICE: relation "employees" already exists, skipping

-- === LIKE — Copy Structure ===

CREATE TABLE employees_backup
  (LIKE employees INCLUDING ALL);
-- INCLUDING ALL copies: defaults, constraints, indexes, comments

-- INCLUDING options:
-- INCLUDING DEFAULTS    — copy default expressions
-- INCLUDING CONSTRAINTS — copy CHECK constraints
-- INCLUDING INDEXES     — copy indexes
-- INCLUDING COMMENTS    — copy comments
-- INCLUDING ALL         — all of the above

-- Verify backup has same structure:
-- \d employees_backup

-- === INHERITS — Table Inheritance ===

CREATE TABLE managers (
    bonus NUMERIC(10,2) DEFAULT 0
) INHERITS (employees);
-- managers has ALL employee columns + bonus

INSERT INTO managers (first_name, last_name, email, department, salary, bonus)
VALUES ('Priya', 'Kumar', 'priya@company.com', 'Engineering', 120000, 15000);

-- Query managers directly:
SELECT first_name, salary, bonus FROM managers;

-- Query employees — INCLUDES managers too!
SELECT first_name, department FROM employees;

-- Query ONLY employees (not children):
SELECT first_name, department FROM ONLY employees;

-- === INSERT Sample Data ===

INSERT INTO employees (first_name, last_name, email, department, salary) VALUES
('Ravi', 'Shah', 'ravi@company.com', 'Engineering', 95000),
('Arjun', 'Patel', 'arjun@company.com', 'Marketing', 75000),
('Meera', 'Joshi', 'meera@company.com', 'Engineering', 88000);

-- === ALTER TABLE — ADD COLUMN ===

-- Add a simple column
ALTER TABLE employees ADD COLUMN phone VARCHAR(20);

-- Add with a default (fills existing rows)
ALTER TABLE employees ADD COLUMN country VARCHAR(50) DEFAULT 'India';

-- Add NOT NULL column (needs default for existing rows)
ALTER TABLE employees ADD COLUMN employee_code VARCHAR(10) NOT NULL DEFAULT 'EMP-000';

-- IF NOT EXISTS: skip if column already exists
ALTER TABLE employees ADD COLUMN IF NOT EXISTS email VARCHAR(150);
-- NOTICE: column "email" of relation "employees" already exists, skipping

-- Error without IF NOT EXISTS:
-- ALTER TABLE employees ADD COLUMN email VARCHAR(150);
-- ERROR: column "email" of relation "employees" already exists

-- === ALTER TABLE — DROP COLUMN ===

ALTER TABLE employees DROP COLUMN phone;

-- CASCADE: also drop dependent objects
-- ALTER TABLE employees DROP COLUMN department CASCADE;

-- IF EXISTS: no error if column doesn't exist
ALTER TABLE employees DROP COLUMN IF EXISTS middle_name;

-- === ALTER TABLE — RENAME ===

-- Rename a column
ALTER TABLE employees RENAME COLUMN is_active TO active;

-- Rename the table
ALTER TABLE employees RENAME TO staff;

-- Rename back for consistency
ALTER TABLE staff RENAME TO employees;
ALTER TABLE employees RENAME COLUMN active TO is_active;

-- === ALTER TABLE — CHANGE DATA TYPE ===

-- Widen a numeric column (safe, no data loss)
ALTER TABLE employees ALTER COLUMN salary TYPE NUMERIC(12,2);

-- Change incompatible types with USING
-- (tells PG how to convert existing data)
ALTER TABLE employees
  ALTER COLUMN employee_code TYPE INT
  USING employee_code::INT;
-- ERROR: invalid input syntax (if data can't convert)
-- Works only if all values are valid integers

-- Reset for examples below
ALTER TABLE employees ALTER COLUMN employee_code TYPE VARCHAR(10);

-- === ALTER TABLE — Defaults & Nullability ===

-- Set a default
ALTER TABLE employees ALTER COLUMN department SET DEFAULT 'Unassigned';

-- Remove a default
ALTER TABLE employees ALTER COLUMN department DROP DEFAULT;

-- Add NOT NULL (fails if nulls exist!)
-- First fill the nulls:
UPDATE employees SET department = 'Unassigned' WHERE department IS NULL;
ALTER TABLE employees ALTER COLUMN department SET NOT NULL;

-- Remove NOT NULL
ALTER TABLE employees ALTER COLUMN department DROP NOT NULL;

-- === DROP TABLE ===

-- Basic drop
CREATE TABLE temp_test (id INT);
DROP TABLE temp_test;
-- Table and data permanently deleted

-- IF EXISTS: no error if table doesn't exist
DROP TABLE IF EXISTS temp_test;
-- NOTICE: table "temp_test" does not exist, skipping

-- CASCADE: drops dependent objects (views, FKs)
CREATE TABLE parent_t (id SERIAL PRIMARY KEY);
CREATE TABLE child_t (id SERIAL, parent_id INT REFERENCES parent_t(id));

DROP TABLE parent_t CASCADE;
-- Also drops the FK constraint on child_t
-- child_t still exists, but FK is gone

DROP TABLE IF EXISTS child_t;

-- RESTRICT (default): refuse if dependencies exist
-- DROP TABLE parent_t RESTRICT;
-- ERROR: cannot drop table parent_t because other objects depend on it

-- Drop multiple tables
-- DROP TABLE IF EXISTS orders, order_items, products;

-- === TRUNCATE — Delete All Rows Fast ===

-- TRUNCATE vs DELETE:
-- DELETE FROM employees;  → row by row, slow, triggers fire
-- TRUNCATE employees;     → instant, resets sequences, no row triggers

-- TRUNCATE with RESTART IDENTITY (reset sequences to 1)
CREATE TABLE demo_truncate (
    id   SERIAL PRIMARY KEY,
    name TEXT
);
INSERT INTO demo_truncate (name) VALUES ('One'), ('Two'), ('Three');
SELECT * FROM demo_truncate;  -- id: 1, 2, 3

TRUNCATE TABLE demo_truncate RESTART IDENTITY;
SELECT * FROM demo_truncate;  -- (0 rows)

INSERT INTO demo_truncate (name) VALUES ('Fresh Start');
SELECT * FROM demo_truncate;  -- id: 1 (reset!)

-- CONTINUE IDENTITY: keep sequence at current value
TRUNCATE TABLE demo_truncate CONTINUE IDENTITY;
INSERT INTO demo_truncate (name) VALUES ('Continues');
SELECT * FROM demo_truncate;  -- id: 2 (continued from 1)

-- TRUNCATE CASCADE: also truncates tables with FK references
-- TRUNCATE TABLE customers CASCADE;

-- === DELETE vs TRUNCATE vs DROP ===

-- DELETE FROM t WHERE ...;  → Remove selected rows, triggers fire, slow
-- TRUNCATE TABLE t;         → Remove ALL rows, no triggers, fast, resets seq
-- DROP TABLE t;             → Remove table entirely, structure + data gone

-- All three are transactional (can be rolled back in a transaction):
BEGIN;
  TRUNCATE TABLE demo_truncate RESTART IDENTITY;
  -- Changed my mind!
ROLLBACK;
SELECT * FROM demo_truncate;  -- Data is still there!

-- === PRACTICE EXERCISES ===

-- Exercise 1: Create a table
CREATE TABLE students (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(150) UNIQUE NOT NULL,
    gpa           NUMERIC(3,2) CHECK (gpa >= 0 AND gpa <= 4.0),
    enrolled_date DATE DEFAULT CURRENT_DATE
);

INSERT INTO students (name, email, gpa) VALUES
('Ravi', 'ravi@uni.com', 3.75),
('Priya', 'priya@uni.com', 3.90),
('Arjun', 'arjun@uni.com', 3.20);

-- Exercise 2: ALTER the table
ALTER TABLE students ADD COLUMN phone VARCHAR(20);
ALTER TABLE students RENAME COLUMN gpa TO grade_point;
ALTER TABLE students ALTER COLUMN email DROP NOT NULL;

-- Exercise 3: Create backup with LIKE
CREATE TABLE students_backup (LIKE students INCLUDING ALL);

-- Exercise 4: TRUNCATE and verify sequence reset
TRUNCATE TABLE students RESTART IDENTITY;
INSERT INTO students (name, email, grade_point) VALUES ('Test', 'test@uni.com', 3.00);
SELECT * FROM students;  -- id should be 1

-- Exercise 5: DROP TABLE
DROP TABLE IF EXISTS students_backup;
DROP TABLE IF EXISTS nonexistent_table;  -- No error, just notice

-- Exercise 6: Transaction safety
BEGIN;
  DROP TABLE students;
ROLLBACK;
SELECT * FROM students;  -- Still exists!

-- === CLEANUP ===
-- DROP TABLE IF EXISTS students, demo_truncate;
-- DROP TABLE IF EXISTS managers, employees_backup, employees;

-- =============================================
-- Next Class: Constraints — PRIMARY KEY, UNIQUE,
-- CHECK, FOREIGN KEY, EXCLUDE & DEFAULT
-- =============================================
