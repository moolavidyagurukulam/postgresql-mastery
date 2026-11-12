# INSERT — Adding Data to Tables
**Series:** PostgreSQL Mastery | **Phase:** Phase 5: DML & Essential SQL | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! Imagine you run an expanding retail mobile phone store. A customer walks up to the counter and buys a new smartphone. How does your software record that purchase permanently in the database? The answer is the INSERT statement. In this class, we walk through every form of INSERT — single rows, multi-row bulk loading, generating sequences, and retrieving auto-generated IDs with RETURNING. Let us dive in!

### Why INSERT Exists — Atomicity & Data Safety
Why does structured INSERT exist? In old flat files or CSVs, appending an unvalidated record could overwrite adjacent data or leave half-written corrupt records if the power cut off mid-write. PostgreSQL's INSERT statement guarantees ACID atomicity — every row either completely succeeds, passing all data types and constraints, or safely aborts leaving the database immaculate.

- Flat files & spreadsheets: Risk partial writes and overwritten rows
- ACID Guarantees: Every INSERT is completely written or rolled back
- Constraint Enforcement: Checks NOT NULL, CHECK, UNIQUE, and FOREIGN KEY
- Default Injection: Automatically fills timestamps, UUIDs, and IDENTITY columns


---

## 2. Core Technical Concepts & Mechanisms

### Why INSERT Exists — Atomicity & Data Safety
Why does structured INSERT exist? In old flat files or CSVs, appending an unvalidated record could overwrite adjacent data or leave half-written corrupt records if the power cut off mid-write. PostgreSQL's INSERT statement guarantees ACID atomicity — every row either completely succeeds, passing all data types and constraints, or safely aborts leaving the database immaculate.

- Flat files & spreadsheets: Risk partial writes and overwritten rows
- ACID Guarantees: Every INSERT is completely written or rolled back
- Constraint Enforcement: Checks NOT NULL, CHECK, UNIQUE, and FOREIGN KEY
- Default Injection: Automatically fills timestamps, UUIDs, and IDENTITY columns

### What is INSERT? The Filing Cabinet Analogy
What is INSERT? Think of your database table as a physical metal filing cabinet full of customer folders. An INSERT statement is the formal action of creating a brand-new folder, filling in the pre-printed form fields, and filing it neatly into the drawer. It is the sole command used to add new data into a PostgreSQL relation.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Table** | The filing cabinet drawer holding all records |
| **Row** | A new physical folder being inserted into the drawer |
| **Columns** | The labeled form fields written inside the folder |
| **INSERT** | The transactional action of storing the new record |

### When to Use INSERT vs Multi-Row vs COPY
When should you use standard INSERT versus other techniques? Use single-row INSERT for interactive user web requests like submitting a registration form. Use multi-row INSERT when batching dozens of rows in an API payload. But for importing millions of rows from files, switch to the COPY command, which bypasses individual query parsing for maximum throughput.

| Scenario | Best Tool | Performance & Behavior |
| :--- | :--- | :--- |
| User Web Forms | Single-Row INSERT | Sub-millisecond interactive transactions |
| Batch API Payloads (10-1,000 rows) | Multi-Row VALUES | Single network roundtrip, 10x faster |
| Bulk File Ingestion (>10,000 rows) | COPY Command | Bypasses SQL parser, up to 100x faster |


---

## 3. Hands-On Commands & psql Output

### INSERT — Single Row
**Explanation:** Here's the basic INSERT. Specify the table, list the columns you're providing, and give the values. The id and created at columns fill themselves — id from the identity sequence, created at from the NOW default. You can skip the column list and provide all values in order, using DEFAULT for auto-generated ones. But always list your columns — it's clearer and won't break if the table structure changes.

```sql
-- Setup table
CREATE TABLE users (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(150) UNIQUE NOT NULL,
    age        INT CHECK (age >= 18),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert a single row (specify columns)
INSERT INTO users (name, email, age)
VALUES ('Ravi', 'ravi@ex.com', 28);

-- id and created_at filled automatically!

-- Column list is optional (but recommended)
INSERT INTO users
VALUES (DEFAULT, 'Priya', 'priya@ex.com', 25, DEFAULT);
-- DEFAULT = use the column's default value
```

### INSERT — Multiple Rows at Once
**Explanation:** Multi-row INSERT adds many rows in one statement. Separate each row with a comma. This is dramatically faster than individual inserts — one round trip to the server instead of four. For bulk data loading, always use multi-row inserts. PostgreSQL returns INSERT zero four — meaning four rows were inserted. The zero is an older OID field that's always zero in modern PostgreSQL.

```sql
-- Multiple rows in one INSERT (much faster!)
INSERT INTO users (name, email, age) VALUES
    ('Arjun', 'arjun@ex.com', 30),
    ('Meera', 'meera@ex.com', 22),
    ('Kiran', 'kiran@ex.com', 35),
    ('Anita', 'anita@ex.com', 27);
-- INSERT 0 4  (4 rows inserted)

-- Why multi-row is better than single:
-- Single row: 4 round trips to the server
-- Multi row:  1 round trip, all 4 rows at once
-- 10x-100x faster for bulk inserts!

SELECT * FROM users;
-- id | name  | email           | age | created_at
-- ---+-------+-----------------+-----+-----------
--  1 | Ravi  | ravi@ex.com     |  28 | ...
--  2 | Priya | priya@ex.com    |  25 | ...
-- ...
```

### INSERT ... RETURNING — Get Back What You Inserted
**Explanation:** RETURNING is one of PostgreSQL's best features. After inserting, it gives back the inserted data — including auto-generated values like id and created at. You don't need a separate SELECT to find out what id was assigned. Return all columns with star, or pick specific ones. You can even return computed values. Multi-row inserts with RETURNING give back every inserted row. This eliminates the need for a separate query.

```sql
-- RETURNING gives back the inserted data
INSERT INTO users (name, email, age)
VALUES ('Deepak', 'deepak@ex.com', 29)
RETURNING *;
-- Returns the full row including auto-generated id!

-- Return specific columns
INSERT INTO users (name, email, age)
VALUES ('Sonia', 'sonia@ex.com', 31)
RETURNING id, name;
--  id | name
-- ----+-------
--   8 | Sonia

-- Return computed values
INSERT INTO users (name, email, age)
VALUES ('Vikram', 'vikram@ex.com', 26)
RETURNING id, name, created_at::DATE AS join_date;

-- Multi-row with RETURNING
INSERT INTO users (name, email, age) VALUES
    ('Neha', 'neha@ex.com', 24),
    ('Raj', 'raj@ex.com', 33)
RETURNING id, email;
```

### RETURNING in Action
**Explanation:** See it live. We insert Amit and ask for id, name, and created at back. Instantly we know Amit got id eleven and the exact timestamp. Then a multi-row insert with two users — RETURNING gives both ids and emails. No second query needed. In application code, this pattern is essential — insert a row and immediately know its generated id.

```sql
essilor=#INSERT INTO users (name, email, age)
VALUES ('Amit', 'amit@ex.com', 32)
RETURNING id, name, created_at;
 id |  name  |          created_at
----+--------+-------------------------------
 11 | Amit   | 2026-11-03 14:30:22.123456+05:30
(1 row)

essilor=#INSERT INTO users (name, email, age) VALUES
('Test1', 't1@ex.com', 20), ('Test2', 't2@ex.com', 21)
RETURNING id, email;
 id |   email
----+-----------
 12 | t1@ex.com
 13 | t2@ex.com
(2 rows)
```

### INSERT ... SELECT — Copy Data Between Tables
**Explanation:** INSERT SELECT copies data from one table to another. No VALUES clause — the SELECT provides the rows. Here we copy all users aged thirty and above into an archive table. You can transform data during the copy — UPPER on the name, for example. The SELECT can be any valid query — joins, group by, subqueries, CTEs — all work. This is how you do bulk data migrations between tables.

```sql
-- Create an archive table
CREATE TABLE users_archive (
    id         INT,
    name       VARCHAR(100),
    email      VARCHAR(150),
    archived_at TIMESTAMPTZ DEFAULT NOW()
);

-- Copy rows from users into archive
INSERT INTO users_archive (id, name, email)
SELECT id, name, email
FROM users
WHERE age >= 30;
-- Copies all users aged 30+ into archive

-- INSERT...SELECT with transformation
INSERT INTO users_archive (id, name, email)
SELECT id, UPPER(name), email
FROM users
WHERE created_at < '2026-11-01';

-- Bulk copy between tables — no VALUES clause!
-- The SELECT can be as complex as you need:
-- JOINs, GROUP BY, CTEs — all work
```

### INSERT — DEFAULT VALUES & Partial Columns
**Explanation:** DEFAULT VALUES inserts a row using only default values — no data provided at all. It only works if every not-null column has a default. The audit log table works because every column has a default. For partial inserts, just list the columns you have values for — everything else gets its default. This is common in logging and tracking tables.

```sql
-- Insert a row with ALL defaults
INSERT INTO users DEFAULT VALUES;
-- ERROR: null value in column "name" violates not-null
-- Only works if ALL columns have defaults or allow NULL

-- Table where it works:
CREATE TABLE audit_log (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    action     VARCHAR(50) DEFAULT 'unknown',
    details    TEXT DEFAULT '',
    logged_at  TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO audit_log DEFAULT VALUES;
SELECT * FROM audit_log;
-- id=1, action='unknown', details='', logged_at=now

-- Partial columns: provide only what you have
INSERT INTO audit_log (action)
VALUES ('user_login');
-- id=2, action='user_login', details='', logged_at=now
```

### INSERT with CTE (Common Table Expression)
**Explanation:** CTEs — Common Table Expressions — work with INSERT. The first example generates five batch users with a CTE and inserts them. The second is a writable CTE — it deletes users under twenty, captures the deleted rows with RETURNING, and inserts them into the archive. Delete and archive in one atomic statement. No chance of losing data between the delete and the insert.

```sql
-- CTE to prepare data, then INSERT
WITH new_users AS (
    SELECT 'Batch User ' || n AS name,
           'batch' || n || '@ex.com' AS email,
           20 + n AS age
    FROM generate_series(1, 5) AS n
)
INSERT INTO users (name, email, age)
SELECT name, email, age
FROM new_users
RETURNING id, name, email;

-- CTE with INSERT...RETURNING (writable CTE)
WITH deleted AS (
    DELETE FROM users
    WHERE age < 20
    RETURNING *
)
INSERT INTO users_archive (id, name, email)
SELECT id, name, email
FROM deleted;
-- Delete and archive in ONE statement!
```

### Common INSERT Errors
**Explanation:** Here are the three most common INSERT errors. NOT NULL violation — you forgot a required column. Fix: provide it. UNIQUE violation — the value already exists. Fix: use a different value or handle it with ON CONFLICT, which we cover in a later class. CHECK violation — the value breaks a business rule. Fix: provide a valid value. Every error tells you exactly which constraint failed and why.

```sql
-- Error 1: NOT NULL violation
essilor=#INSERT INTO users (email, age) VALUES ('x@ex.com', 25);
ERROR:  null value in column "name" of relation "users"
        violates not-null constraint
-- Fix: provide the name column

-- Error 2: UNIQUE violation
essilor=#INSERT INTO users (name, email, age) VALUES ('X', 'ravi@ex.com', 20);
ERROR:  duplicate key value violates unique constraint
DETAIL:  Key (email)=(ravi@ex.com) already exists.
-- Fix: use a different email, or use ON CONFLICT

-- Error 3: CHECK violation
essilor=#INSERT INTO users (name, email, age) VALUES ('Kid', 'kid@ex.com', 15);
ERROR:  new row violates check constraint "users_age_check"
-- Fix: age must be >= 18
```

### Preview: INSERT ... ON CONFLICT (UPSERT)
**Explanation:** Quick preview of ON CONFLICT — the upsert pattern. Instead of getting an error on duplicate email, DO NOTHING silently skips the insert. DO UPDATE changes the existing row with the new values. EXCLUDED refers to the rejected row. We'll cover upsert in full detail in the UPDATE and DELETE class. For now, know that INSERT doesn't have to fail on conflicts.

```sql
-- Handle duplicate key gracefully
-- (Full coverage in UPDATE/DELETE/UPSERT class)

-- DO NOTHING: skip if conflict
INSERT INTO users (name, email, age)
VALUES ('Ravi', 'ravi@ex.com', 28)
ON CONFLICT (email) DO NOTHING;
-- No error! Row simply not inserted.

-- DO UPDATE: update existing row on conflict
INSERT INTO users (name, email, age)
VALUES ('Ravi Kumar', 'ravi@ex.com', 29)
ON CONFLICT (email) DO UPDATE
SET name = EXCLUDED.name, age = EXCLUDED.age;
-- Updates existing row with new name and age!

-- EXCLUDED = the row that was rejected
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common INSERT Errors
Here are the three most common INSERT errors. NOT NULL violation — you forgot a required column. Fix: provide it. UNIQUE violation — the value already exists. Fix: use a different value or handle it with ON CONFLICT, which we cover in a later class. CHECK violation — the value breaks a business rule. Fix: provide a valid value. Every error tells you exactly which constraint failed and why.

```sql
-- Error 1: NOT NULL violation
INSERT INTO users (email, age) VALUES ('x@ex.com', 25);
ERROR:  null value in column "name" of relation "users"
        violates not-null constraint
-- Fix: provide the name column

-- Error 2: UNIQUE violation
INSERT INTO users (name, email, age) VALUES ('X', 'ravi@ex.com', 20);
ERROR:  duplicate key value violates unique constraint
DETAIL:  Key (email)=(ravi@ex.com) already exists.
-- Fix: use a different email, or use ON CONFLICT

-- Error 3: CHECK violation
INSERT INTO users (name, email, age) VALUES ('Kid', 'kid@ex.com', 15);
ERROR:  new row violates check constraint "users_age_check"
-- Fix: age must be >= 18
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

INSERT best practices. Always list your columns — don't rely on column order. Use multi-row inserts for bulk data. Use RETURNING to get generated values. Use INSERT SELECT for migrations. Use ON CONFLICT for duplicates. Wrap bulk inserts in a transaction so they either all succeed or all fail. And for very large imports — millions of rows — use the COPY command, which we cover later. It's even faster than multi-row INSERT.

1. Always list columns explicitly — INSERT INTO t (col1, col2) VALUES (...)
2. Use multi-row INSERT for bulk data — much faster than individual inserts
3. Use RETURNING to get auto-generated values (id, timestamps)
4. Use INSERT...SELECT for table-to-table data migration
5. Use ON CONFLICT for graceful duplicate handling
6. Wrap bulk inserts in a transaction for atomicity
7. Use COPY for very large imports (faster than INSERT)

Practice time. Create a products table with identity, constraints, and defaults. Insert a single product with RETURNING to see the generated id. Do a multi-row insert with five products. Create a sale table and use INSERT SELECT to copy expensive products. Try violating constraints to see the errors. Use a CTE with generate series to create test data. And try DEFAULT VALUES on a logging table.

1. Create a products table with: id (IDENTITY), name (NOT NULL), price (CHECK > 0), stock (DEFAULT 0)
2. INSERT a single product with RETURNING *
3. INSERT 5 products in one multi-row INSERT
4. Create a products_sale table, INSERT...SELECT products with price > 100
5. Try inserting a duplicate name (if UNIQUE) — see the error
6. Use a CTE with generate_series to insert 10 test products
7. Use INSERT...DEFAULT VALUES on a logging table


---


### Answer Key — INSERT Solutions

```sql
-- 1. Basic INSERT with explicit column list
-- Note: Always specify column list so table alterations don't break queries.
INSERT INTO employees (first_name, last_name, email, hire_date, salary)
VALUES ('Ravi', 'Kumar', 'ravi@company.com', '2026-01-15', 75000.00);

-- 2. Multi-row INSERT in a single statement
-- Note: Multi-row inserts run in a single transaction round-trip.
INSERT INTO products (name, price, stock)
VALUES
  ('Mechanical Keyboard', 89.99, 50),
  ('Wireless Mouse', 45.50, 120),
  ('USB-C Dock', 129.00, 30);

-- 3. INSERT ... RETURNING clause
-- Note: RETURNING avoids a secondary SELECT query for auto-generated IDs.
INSERT INTO orders (customer_id, total)
VALUES (101, 249.99)
RETURNING id, created_at, total;

-- 4. INSERT INTO ... SELECT from another table
-- Note: Copies query output directly into the target table.
INSERT INTO high_value_customers (customer_id, total_spent)
SELECT customer_id, SUM(total)
FROM orders GROUP BY customer_id HAVING SUM(total) > 5000;

-- 5. DEFAULT values in INSERT
-- Note: Explicitly requests the column default expression.
INSERT INTO tasks (title, status)
VALUES ('Audit Security Logs', DEFAULT);

```

---

## 7. Key Takeaways & Cheat Sheet

Let's recap. Always list columns in your INSERT. Multi-row inserts are much faster than individual ones. RETURNING gives back auto-generated values without a separate query. INSERT SELECT copies data between tables. DEFAULT VALUES works when all columns have defaults. CTEs prepare data or chain operations. And ON CONFLICT handles duplicates without errors. INSERT is simple but has powerful variants.

- **INSERT INTO t (cols) VALUES (...) — always list columns**
- **Multi-row: VALUES (...), (...), (...) — faster than individual inserts**
- **RETURNING * gives back inserted data including auto-generated values**
- **INSERT...SELECT copies data between tables (with optional transformation)**
- **DEFAULT VALUES inserts a row using all column defaults**
- **CTEs work with INSERT — prepare data or chain operations**
- **ON CONFLICT handles duplicates gracefully (UPSERT preview)**


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
