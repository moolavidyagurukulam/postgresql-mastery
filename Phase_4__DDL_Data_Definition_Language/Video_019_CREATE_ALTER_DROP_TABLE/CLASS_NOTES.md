# CREATE TABLE, ALTER TABLE & DROP TABLE
**Series:** PostgreSQL Mastery | **Phase:** General | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to Phase 4 — Data Definition Language. DDL is how you build and modify the structure of your database. Today we cover the three most important DDL commands: CREATE TABLE to build tables, ALTER TABLE to modify them, and DROP TABLE to remove them. Let's start building.

### The Problem: You Need Tables Before You Can Store Data
Imagine opening a brand-new database with zero tables—you cannot insert a single customer or order until you define the table structure first! ... That is what DDL—Data Definition Language—does. Think of DDL like constructing the rooms and shelves of a store before stocking any products inside. ... Today you will master CREATE TABLE to build tables safely, ALTER TABLE to evolve columns without losing live data, TRUNCATE to empty test tables instantly, and DROP TABLE when retiring old structures.


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: You Need Tables Before You Can Store Data
Imagine opening a brand-new database with zero tables—you cannot insert a single customer or order until you define the table structure first! ... That is what DDL—Data Definition Language—does. Think of DDL like constructing the rooms and shelves of a store before stocking any products inside. ... Today you will master CREATE TABLE to build tables safely, ALTER TABLE to evolve columns without losing live data, TRUNCATE to empty test tables instantly, and DROP TABLE when retiring old structures.

| Term | Meaning / Explanation |
| :--- | :--- |
| **DDL** | Data Definition Language — commands that define database structure |
| **CREATE TABLE** | Build a new table with columns, types, and constraints |
| **ALTER TABLE** | Modify an existing table — add, drop, rename columns |
| **DROP TABLE** | Permanently remove a table and all its data |

**Notes:**
- DDL changes structure, DML changes data — learn DDL first

### DELETE vs TRUNCATE vs DROP — Comparison
Here's the three-way comparison. DELETE removes selected rows with a WHERE clause, fires triggers per row, and is slow on big tables. TRUNCATE removes ALL rows instantly, doesn't fire per-row triggers, and can reset sequences — but no WHERE clause. DROP removes the entire table, structure and all. All three can be rolled back inside a transaction. Remember: DELETE for some rows, TRUNCATE for all rows, DROP to remove the table entirely.

| Term | Meaning / Explanation |
| :--- | :--- |
| **DELETE** | Removes selected rows (WHERE allowed), fires row triggers, logs each row |
| **TRUNCATE** | Empties ALL rows fast, skips row triggers, can RESTART IDENTITY |
| **DROP TABLE** | Deletes ALL data PLUS the table structure, indexes & rules permanently |
| **Transactions** | In PostgreSQL, ALL three can roll back inside BEGIN ... ROLLBACK! |
| **When to Pick** | DELETE = specific rows | TRUNCATE = wipe data | DROP = delete table |

### DDL Quick Reference
Save this DDL quick reference card—you will use these four commands in almost every backend sprint. ... Use CREATE TABLE IF NOT EXISTS for safe repeatable setup scripts. ... Use ALTER TABLE ADD, DROP, or ALTER COLUMN to evolve tables without rebuilding them. ... Use TRUNCATE RESTART IDENTITY to reset staging tables cleanly, and DROP TABLE IF EXISTS RESTRICT before using CASCADE so you never wipe dependent views by accident.

| Term | Meaning / Explanation |
| :--- | :--- |
| **CREATE TABLE** | Build structure cleanly (add IF NOT EXISTS in deploy scripts) |
| **ALTER TABLE** | ADD/DROP/RENAME column, change TYPE ... USING, SET NOT NULL |
| **TRUNCATE** | Fast full-table wipe + RESTART IDENTITY (keeps columns) |
| **DROP TABLE** | Permanent removal — default RESTRICT protects dependent objects |
| **Safety Tip** | Test destructive ALTER/DROP inside BEGIN ... ROLLBACK first |


---

## 3. Hands-On Commands & psql Output

### CREATE TABLE — Basic Syntax
**Explanation:** Here's CREATE TABLE in action. We define each column with a name, a data type, and optional constraints. The id column is SERIAL PRIMARY KEY — auto-incrementing integer. first name and last name are NOT NULL — they must have values. email is UNIQUE NOT NULL — no duplicates, no blanks. salary has a CHECK constraint — must be positive. hire date defaults to today. is active defaults to true. And created at records when the row was inserted.

```sql
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

-- Each column: name  TYPE  [constraints]
```

### CREATE TABLE — IF NOT EXISTS, LIKE, INHERITS
**Explanation:** CREATE TABLE has useful options. IF NOT EXISTS prevents errors if the table already exists — you get a notice instead. LIKE copies the structure from another table. WITH INCLUDING ALL, it copies defaults, constraints, indexes, and comments — perfect for backups. INHERITS creates a child table that inherits all columns from the parent. The managers table gets every column from employees plus its own bonus column.

```sql
-- IF NOT EXISTS: no error if table already exists
CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    name TEXT
);
-- Returns: NOTICE: relation "employees" already exists

-- LIKE: copy structure from another table
CREATE TABLE employees_backup
  (LIKE employees INCLUDING ALL);
-- INCLUDING ALL copies: defaults, constraints,
-- indexes, comments, storage parameters

-- INHERITS: child table inherits parent columns
CREATE TABLE managers (
    bonus NUMERIC(10,2)
) INHERITS (employees);
-- managers has ALL employee columns + bonus
```

### CREATE TABLE in Action
**Explanation:** Let's see it live. We create a products table with an id, name, price, and stock columns. PostgreSQL says CREATE TABLE — success. Then backslash d shows the table structure — column names, types, nullable flags, and defaults. The id column uses nextval from an auto-created sequence. Name is not null. Stock defaults to zero. This is your table, ready for data.

```sql
essilor=#CREATE TABLE products (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    price NUMERIC(10,2) CHECK (price >= 0),
    stock INT DEFAULT 0
);
CREATE TABLE

essilor=#\d products
                    Table "public.products"
 Column |          Type          | Nullable | Default
--------+------------------------+----------+--------
 id     | integer                | not null | nextval(...)
 name   | character varying(100) | not null | 
 price  | numeric(10,2)          |          | 
 stock  | integer                |          | 0
```

### ALTER TABLE — ADD COLUMN
**Explanation:** ALTER TABLE ADD COLUMN adds new columns to an existing table. You can add a simple column, add one with a default value that fills existing rows, or add a NOT NULL column — but it needs a default so existing rows have a value. If you try to add a column that already exists, you get an error. The fix is IF NOT EXISTS — it skips silently if the column is already there.

```sql
-- Add a single column
ALTER TABLE employees
  ADD COLUMN phone VARCHAR(20);

-- Add with a default (fills existing rows)
ALTER TABLE employees
  ADD COLUMN country VARCHAR(50) DEFAULT 'India';

-- Add with NOT NULL (requires default for existing rows)
ALTER TABLE employees
  ADD COLUMN employee_code VARCHAR(10) NOT NULL
  DEFAULT 'EMP-000';

-- ERROR: column already exists
ALTER TABLE employees ADD COLUMN email VARCHAR(150);
-- ERROR: column "email" of relation
--        "employees" already exists

-- Fix: use IF NOT EXISTS
ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS email VARCHAR(150);
```

### ALTER TABLE — DROP, RENAME, CHANGE TYPE
**Explanation:** DROP COLUMN removes a column. Use CASCADE if other objects depend on it. IF EXISTS prevents errors for missing columns. RENAME COLUMN changes a column's name. You can also rename the entire table. ALTER COLUMN TYPE changes the data type — widening numeric precision works directly. For incompatible type changes, use the USING clause to tell PostgreSQL how to convert existing data. Without USING, it would fail if it can't auto-convert.

```sql
-- Drop a column
ALTER TABLE employees DROP COLUMN phone;

-- Drop with CASCADE (also drops dependent objects)
ALTER TABLE employees DROP COLUMN department CASCADE;

-- IF EXISTS: no error if column doesn't exist
ALTER TABLE employees
  DROP COLUMN IF EXISTS middle_name;

-- Rename a column
ALTER TABLE employees
  RENAME COLUMN is_active TO active;

-- Rename the table itself
ALTER TABLE employees RENAME TO staff;

-- Change data type
ALTER TABLE staff
  ALTER COLUMN salary TYPE NUMERIC(12,2);

-- Change type with USING (for incompatible types)
ALTER TABLE staff
  ALTER COLUMN employee_code TYPE INT
  USING employee_code::INT;
```

### ALTER TABLE — Modify Defaults & Nullability
**Explanation:** You can modify defaults and nullability. SET DEFAULT assigns a default value for new rows. DROP DEFAULT removes it. SET NOT NULL adds the not null constraint — but it fails if any existing row has a null in that column. The fix? Update the nulls first, then add the constraint. DROP NOT NULL makes a column nullable again. These are all non-destructive changes — they modify rules, not data.

```sql
-- Set a default value
ALTER TABLE staff
  ALTER COLUMN active SET DEFAULT true;

-- Remove a default
ALTER TABLE staff
  ALTER COLUMN active DROP DEFAULT;

-- Add NOT NULL constraint
ALTER TABLE staff
  ALTER COLUMN last_name SET NOT NULL;

-- Remove NOT NULL constraint
ALTER TABLE staff
  ALTER COLUMN last_name DROP NOT NULL;

-- NOTE: SET NOT NULL fails if column has NULLs!
-- Fix: UPDATE first to fill NULLs
UPDATE staff SET department = 'Unassigned'
  WHERE department IS NULL;
ALTER TABLE staff
  ALTER COLUMN department SET NOT NULL;
```

### ALTER TABLE in Action
**Explanation:** Let's see ALTER TABLE live. We add a category column, rename stock to quantity, and make price NOT NULL. Each command returns ALTER TABLE — success. Backslash d confirms: category is added, stock is now quantity, and price shows not null. Three changes, three commands, zero data loss.

```sql
essilor=#ALTER TABLE products ADD COLUMN category VARCHAR(50);
ALTER TABLE
essilor=#ALTER TABLE products RENAME COLUMN stock TO quantity;
ALTER TABLE
essilor=#ALTER TABLE products ALTER COLUMN price SET NOT NULL;
ALTER TABLE
essilor=#\d products
 Column   |          Type          | Nullable | Default
----------+------------------------+----------+--------
 id       | integer                | not null | nextval(...)
 name     | character varying(100) | not null | 
 price    | numeric(10,2)          | not null | 
 quantity | integer                |          | 0
 category | character varying(50)  |          | 
```

### DROP TABLE — Remove Tables Permanently
**Explanation:** DROP TABLE permanently deletes a table and all its data. There is no undo. IF EXISTS prevents errors if the table is already gone. CASCADE also drops dependent objects — views referencing the table, foreign keys pointing to it. RESTRICT is the default — it refuses to drop if anything depends on the table. This is safer. You can also drop multiple tables in one command. Remember: DROP is permanent. Use with caution.

```sql
-- Basic drop
DROP TABLE products;
-- GONE. Table + data = deleted permanently.

-- IF EXISTS: no error if table doesn't exist
DROP TABLE IF EXISTS products;
-- NOTICE: table "products" does not exist, skipping

-- CASCADE: also drops dependent objects
-- (views, foreign keys, etc.)
DROP TABLE customers CASCADE;
-- WARNING: drops any FK pointing to customers

-- RESTRICT (default): refuse if dependencies exist
DROP TABLE customers RESTRICT;
-- ERROR: cannot drop table customers because
--        other objects depend on it

-- Drop multiple tables at once
DROP TABLE IF EXISTS orders, order_items, products;
```

### TRUNCATE — Delete All Rows Fast
**Explanation:** TRUNCATE removes all rows from a table but keeps the table structure. It's much faster than DELETE on large tables because it doesn't process rows one by one. It doesn't fire per-row triggers. And by default with RESTART IDENTITY, it resets auto-increment sequences back to one. Use CONTINUE IDENTITY to keep sequences at their current value. TRUNCATE CASCADE also truncates tables that reference this one via foreign keys.

```sql
-- TRUNCATE: removes ALL rows, keeps table structure
TRUNCATE TABLE employees;

-- TRUNCATE vs DELETE:
-- DELETE FROM employees;  → row by row, triggers fire,
--                           logged, slow on big tables
-- TRUNCATE employees;    → instant, resets sequences,
--                           no per-row triggers, minimal logging

-- TRUNCATE resets SERIAL/IDENTITY sequences!
TRUNCATE TABLE employees RESTART IDENTITY;
-- Next INSERT gets id = 1 again

-- Keep sequences at current value:
TRUNCATE TABLE employees CONTINUE IDENTITY;

-- TRUNCATE with CASCADE (truncates referencing tables too)
TRUNCATE TABLE customers CASCADE;
-- Also truncates orders (which has FK to customers)
```

### DROP and TRUNCATE in Action
**Explanation:** Watch this. We insert a laptop into products and see it with id one. Then TRUNCATE with RESTART IDENTITY — table is empty, zero rows. But the table structure is still there. If we insert again, the next id will be one, not two, because the sequence was reset. The table is clean and ready for fresh data.

```sql
essilor=#INSERT INTO products (name, price) VALUES ('Laptop', 999.99);
INSERT 0 1
essilor=#SELECT * FROM products;
 id |  name  |  price  | quantity | category
----+--------+---------+----------+----------
  1 | Laptop |  999.99 |        0 | 

essilor=#TRUNCATE TABLE products RESTART IDENTITY;
TRUNCATE TABLE
essilor=#SELECT * FROM products;
 id | name | price | quantity | category
----+------+-------+----------+----------
(0 rows)
-- Table empty, structure intact, sequence reset to 1
```

### Common DDL Errors
**Explanation:** Here are the common DDL errors you'll hit. Error one — adding a column that already exists. Fix: use IF NOT EXISTS. Error two — dropping a table that other tables depend on. PostgreSQL refuses to protect your data. Fix: use CASCADE if you really want to drop everything. Error three — dropping a column that's referenced by a foreign key. Fix: drop the foreign key constraint first, or use CASCADE. These errors are safety features, not bugs.

```sql
-- Error 1: Column already exists
essilor=#ALTER TABLE products ADD COLUMN name VARCHAR(100);
ERROR:  column "name" of relation "products" already exists
-- Fix: ADD COLUMN IF NOT EXISTS name VARCHAR(100);

-- Error 2: Dependencies prevent DROP
essilor=#DROP TABLE customers;
ERROR:  cannot drop table customers because other objects depend on it
HINT:  Use DROP ... CASCADE to drop the dependent objects too.
-- Fix: DROP TABLE customers CASCADE;

-- Error 3: FK prevents column change
essilor=#ALTER TABLE customers DROP COLUMN id;
ERROR:  column "id" is still referenced from table "orders"
-- Fix: Drop the FK constraint first, or use CASCADE
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common DDL Errors
Here are the common DDL errors you'll hit. Error one — adding a column that already exists. Fix: use IF NOT EXISTS. Error two — dropping a table that other tables depend on. PostgreSQL refuses to protect your data. Fix: use CASCADE if you really want to drop everything. Error three — dropping a column that's referenced by a foreign key. Fix: drop the foreign key constraint first, or use CASCADE. These errors are safety features, not bugs.

```sql
-- Error 1: Column already exists
ALTER TABLE products ADD COLUMN name VARCHAR(100);
ERROR:  column "name" of relation "products" already exists
-- Fix: ADD COLUMN IF NOT EXISTS name VARCHAR(100);

-- Error 2: Dependencies prevent DROP
DROP TABLE customers;
ERROR:  cannot drop table customers because other objects depend on it
HINT:  Use DROP ... CASCADE to drop the dependent objects too.
-- Fix: DROP TABLE customers CASCADE;

-- Error 3: FK prevents column change
ALTER TABLE customers DROP COLUMN id;
ERROR:  column "id" is still referenced from table "orders"
-- Fix: Drop the FK constraint first, or use CASCADE
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time. First, create a students table with a serial primary key, name not null, unique email, a gpa with a check constraint between zero and four, and an enrolled date defaulting to today. Insert three students and inspect the table. Then alter it — add a phone column, rename gpa, and modify nullability. Create a backup with LIKE. Truncate to clear data, then drop the backup. That's the full DDL lifecycle.

1. CREATE TABLE students with: id (SERIAL PK), name (NOT NULL), email (UNIQUE NOT NULL), gpa (NUMERIC CHECK 0-4), enrolled_date (DEFAULT today)
2. INSERT 3 students, then verify with SELECT and \d
3. ALTER TABLE: ADD phone column, RENAME gpa to grade_point, SET email DROP NOT NULL
4. CREATE TABLE students_backup (LIKE students INCLUDING ALL)
5. TRUNCATE students RESTART IDENTITY, verify id resets
6. DROP TABLE students_backup, then try DROP without IF EXISTS on a nonexistent table
7. Create, modify, truncate, drop — the full DDL lifecycle


---


### Answer Key — CREATE, ALTER & DROP TABLE Solutions

```sql
-- 1. CREATE TABLE with constraints and inspect with \d
-- Note: \d displays column types, modifiers, and bound sequences.
CREATE TABLE students (id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, name VARCHAR(100) NOT NULL, email VARCHAR(100) UNIQUE, grade_point NUMERIC(3,2));
\d students

-- 2. ALTER TABLE ADD, RENAME, and ALTER TYPE
-- Note: USING allows explicit casting during column type alteration.
ALTER TABLE students ADD COLUMN phone VARCHAR(20);
ALTER TABLE students RENAME COLUMN grade_point TO gpa;
ALTER TABLE students ALTER COLUMN gpa TYPE NUMERIC(4,2) USING gpa::numeric(4,2);

-- 3. Duplicate table structure with LIKE
-- Note: INCLUDING ALL copies defaults, constraints, and indexes.
CREATE TABLE students_backup (LIKE students INCLUDING ALL);

-- 4. TRUNCATE and reset identity sequence
-- Note: RESTART IDENTITY forces the counter back to 1.
TRUNCATE TABLE students RESTART IDENTITY;
INSERT INTO students (name, email, gpa) VALUES ('Ravi', 'ravi@uni.com', 3.85);
SELECT id, name FROM students;

-- 5. Transactional DROP safety with ROLLBACK
-- Note: PostgreSQL DDL runs inside transactions safely.
BEGIN;
DROP TABLE students;
SELECT to_regclass('students'); -- returns NULL
ROLLBACK;
SELECT to_regclass('students'); -- returns 'students'

```

---

## 7. Key Takeaways & Cheat Sheet

Let's recap. CREATE TABLE defines your columns with types, defaults, and constraints. Use IF NOT EXISTS to avoid errors. ALTER TABLE handles every kind of modification — adding, dropping, renaming columns, changing types, modifying defaults and nullability. DROP TABLE is permanent — always use IF EXISTS. TRUNCATE is the fast way to empty a table while keeping its structure. Remember the trio: DELETE for some rows, TRUNCATE for all rows, DROP to remove the table.

- **CREATE TABLE defines columns with types, defaults, and constraints**
- **IF NOT EXISTS prevents errors on duplicate creates**
- **LIKE copies structure; INHERITS creates a child table**
- **ALTER TABLE: ADD/DROP COLUMN, RENAME, change TYPE, modify defaults/nullability**
- **DROP TABLE is permanent — use IF EXISTS and CASCADE carefully**
- **TRUNCATE is fast DELETE of all rows — resets sequences, keeps structure**
- **DELETE (some rows) vs TRUNCATE (all rows) vs DROP (table gone)**


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
