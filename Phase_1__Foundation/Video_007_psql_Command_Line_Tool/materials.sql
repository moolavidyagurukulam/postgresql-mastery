-- =============================================
-- PostgreSQL Mastery: psql Command-Line Tool
-- Phase 1: Foundation | Class 07
-- =============================================
-- Master psql: connecting, meta-commands, running SQL,
-- and everyday productivity features.
-- =============================================

-- === CONNECTING WITH psql ===

-- Connect to default database as postgres user (Linux)
-- sudo -u postgres psql

-- Connect to a specific database
-- psql -U postgres -d practice

-- Connect to a remote server
-- psql -h 192.168.1.100 -p 5432 -U postgres -d practice

-- Run a single command and exit
-- psql -U postgres -c 'SELECT version();'

-- Run a SQL file
-- psql -U postgres -d practice -f script.sql

-- === SQL vs META-COMMANDS ===

-- SQL commands: end with semicolon (;)
-- Meta-commands: start with backslash (\), NO semicolon needed

-- === ESSENTIAL LISTING COMMANDS ===

-- \l            List all databases
-- \c dbname     Switch to a database
-- \dn           List schemas
-- \dt           List tables (current schema)
-- \dt schema.*  List tables in a specific schema
-- \di           List indexes
-- \dv           List views
-- \df           List functions
-- \du           List roles/users
-- \d tablename  Describe table structure
-- \d+ tablename Describe with extra detail
-- \?            Show ALL meta-commands help
-- \h            SQL command help
-- \q            Quit psql

-- === DEMO: Create and Describe a Table ===

CREATE TABLE students (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE,
    age   INT CHECK (age > 0)
);

-- Describe it
-- \d students

-- Insert test data
INSERT INTO students (name, email, age) VALUES ('Ravi', 'ravi@example.com', 22);
INSERT INTO students (name, email, age) VALUES ('Priya', 'priya@example.com', 25);
INSERT INTO students (name, email, age) VALUES ('Arjun', 'arjun@example.com', 28);

-- Query
SELECT * FROM students;

-- === USEFUL FEATURES ===

-- \timing       Toggle query execution time display
-- \x            Toggle expanded (vertical) display
-- \o filename   Redirect output to a file (\o alone turns it off)
-- \i filename   Execute commands from a SQL file
-- \e            Open last query in text editor
-- \!            Run a shell command from inside psql

-- === HISTORY & TAB COMPLETION ===

-- UP ARROW      Scroll through previous commands
-- CTRL + R      Search command history
-- TAB           Auto-complete table/column names
-- TAB TAB       Show all completions
-- History file: ~/.psql_history

-- === COMMON MISTAKES ===

-- Mistake 1: Forgot semicolon — prompt changes from # to -
-- Fix: type ; and press Enter, or CTRL+C to cancel

-- Mistake 2: \dt shows nothing — no tables in current schema
-- Fix: check with \conninfo, switch database with \c

-- Mistake 3: typing 'quit' instead of \q
-- Fix: always use \q to exit psql

-- Mistake 4: running bash commands inside psql (sudo, apt, etc.)
-- Fix: use \! for shell commands, or exit psql first

-- === PRACTICE EXERCISES ===

-- Exercise 1:
-- Connect to practice database. Run \l to list databases.
-- Switch to postgres database (\c postgres), then back to practice.

-- Exercise 2:
-- Create a table called products:
CREATE TABLE products (
    id       SERIAL PRIMARY KEY,
    name     VARCHAR(100) NOT NULL,
    price    NUMERIC(10,2),
    in_stock BOOLEAN DEFAULT true
);
-- Describe it: \d products

-- Exercise 3:
-- Insert 3 products, query them, turn on \timing and re-run.
INSERT INTO products (name, price) VALUES ('Keyboard', 49.99);
INSERT INTO products (name, price) VALUES ('Mouse', 29.99);
INSERT INTO products (name, price) VALUES ('Monitor', 299.99);
SELECT * FROM products;

-- Exercise 4:
-- Turn on expanded display (\x), run SELECT * FROM products.
-- See the difference. Turn it off (\x).

-- Exercise 5:
-- Export products to a file:
-- \o /tmp/products.txt
-- SELECT * FROM products;
-- \o
-- Verify: \! cat /tmp/products.txt

-- === CLEANUP ===
-- DROP TABLE IF EXISTS students;
-- DROP TABLE IF EXISTS products;

-- === ANSWER KEY ===

-- Answer 1:
-- \l lists all databases; \c postgres switches to postgres; \c practice returns to practice.

-- Answer 2:
-- \d products shows columns (id, name, price, in_stock), types, NOT NULL, defaults, and PK index.

-- Answer 3:
-- Run \timing once to toggle timing ON; re-running SELECT * FROM products; prints "Time: X.XXX ms".

-- Answer 4:
-- \x switches to expanded vertical card view (great for wide tables); \x again restores normal grid.

-- Answer 5:
-- \o /tmp/products.txt redirects output to file; \o (no path) stops redirection; \! runs OS shell command.

-- =============================================
-- Next Class: pgAdmin GUI Tool
-- =============================================
