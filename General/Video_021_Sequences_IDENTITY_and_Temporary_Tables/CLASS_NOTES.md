# Sequences, IDENTITY & Temporary Tables
**Series:** PostgreSQL Mastery | **Phase:** General | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> You've been using SERIAL for auto-incrementing IDs. But what's actually happening behind the scenes? Today we learn about sequences — the engine behind auto-increment — the modern IDENTITY column that replaces SERIAL, and temporary tables for short-lived data. Let's look under the hood.

### The Problem: How Does Auto-Increment Actually Work?
When you write SERIAL PRIMARY KEY, PostgreSQL doesn't have a built-in auto-increment type. Instead, it creates an integer column and a separate sequence object that generates numbers. SERIAL is a shortcut, not a real type. PostgreSQL 10 introduced IDENTITY columns — the SQL standard way to do auto-increment. In PostgreSQL 16, IDENTITY is preferred over SERIAL. Let's understand both.


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: How Does Auto-Increment Actually Work?
When you write SERIAL PRIMARY KEY, PostgreSQL doesn't have a built-in auto-increment type. Instead, it creates an integer column and a separate sequence object that generates numbers. SERIAL is a shortcut, not a real type. PostgreSQL 10 introduced IDENTITY columns — the SQL standard way to do auto-increment. In PostgreSQL 16, IDENTITY is preferred over SERIAL. Let's understand both.

| Term | Meaning / Explanation |
| :--- | :--- |
| **SERIAL** | Shortcut that creates an INTEGER column + a hidden SEQUENCE object |
| **Sequence** | A separate database object that generates sequential numbers |
| **IDENTITY** | SQL standard replacement for SERIAL — preferred in PG 16 |
| **Question** | What happens with gaps, resets, manual overrides? |

### SERIAL vs IDENTITY — Comparison
Here's why IDENTITY is better. SERIAL is PostgreSQL-specific. IDENTITY is SQL standard. SERIAL always allows manual id inserts, which can cause sequence conflicts. IDENTITY with GENERATED ALWAYS blocks manual inserts. The sequence management is cleaner — no orphaned sequences. And pg dump handles IDENTITY better. SERIAL still works and you'll see it in existing code, but for new tables in PostgreSQL 16, use IDENTITY.

| Term | Meaning / Explanation |
| :--- | :--- |
| **SERIAL** | PostgreSQL-specific |
| **IDENTITY** | SQL standard |
| **SERIAL always** | manual id inserts, which can cause sequence conflicts |
| **The sequence management** | cleaner — no orphaned sequences |
| **SERIAL still** | and you'll see it in existing code, but for new tables in PostgreSQL 16, use IDENTITY |

### Sequence Gaps Are Normal (Not a Bug!)
Important lesson — sequence gaps are normal, not a bug. If a transaction calls nextval but then rolls back, that number is gone. The sequence never goes backward. You might see ids one, two, three, five, eight. That's fine. Sequences guarantee unique values, not contiguous values. Don't try to make them gapless — it requires table locks and destroys performance. If you need gapless numbers like invoice numbers, use a separate counter table with explicit row locks.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Why gaps happen** | Rolled-back transactions, failed INSERTs, cached values — nextval never goes back |
| **Example** | INSERT fails after nextval → id 5 is skipped, next insert gets id 6 |
| **Rule** | Sequences guarantee UNIQUE, not CONTIGUOUS |
| **Don't try to fix** | Gapless sequences require table locks = terrible performance |

**Notes:**
- If your business needs gapless numbers (invoices), use a separate counter table with row locks

### When to Use Temporary Tables
When should you use temp tables? For complex queries — break them into steps and store intermediate results. For ETL — stage incoming data, clean it, then move to the real table. For session caches — compute an expensive result once and reuse it. And for testing — throwaway tables that disappear automatically. One warning — if a temp table has the same name as a real table, the temp table shadows it. Your queries hit the temp table, not the real one.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Complex Queries** | Break a huge query into steps — store intermediate results in temp tables |
| **ETL Processing** | Stage imported data in temp table, clean it, then INSERT into real table |
| **Session Caches** | Cache expensive query results for reuse within the same session |
| **Testing** | Create throwaway tables for testing without polluting the real schema |

**Notes:**
- Temp tables live in a special pg_temp schema
- They shadow real tables with the same name — be careful!

### Regular vs Temporary vs Unlogged Tables
Here's the comparison. Regular tables are visible to everyone, WAL-logged, and survive crashes — your default for permanent data. Temporary tables are session-only and auto-dropped — perfect for scratch work. Unlogged tables are visible to everyone and fast, but data is lost on crash — good for regenerable caches only. Choose based on durability needs.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Regular tables** | visible to everyone, WAL-logged, and survive crashes — your default for permanent data |
| **Temporary tables** | session-only and auto-dropped — perfect for scratch work |
| **Unlogged tables** | visible to everyone and fast, but data is lost on crash — good for regenerable caches only |


---

## 3. Hands-On Commands & psql Output

### SERIAL — What It Actually Creates
**Explanation:** Here's what SERIAL actually does. It creates a sequence object called orders id seq. It creates the column as integer, not null, with a default of nextval from that sequence. Then it links the sequence to the column. SERIAL is just a convenience shortcut for these three steps. BIGSERIAL does the same with bigint for tables that will exceed two billion rows. You can see your sequences with backslash ds.

```sql
-- When you write this:
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    product VARCHAR(100)
);

-- PostgreSQL actually does this:
CREATE SEQUENCE orders_id_seq;
CREATE TABLE orders (
    id INT NOT NULL DEFAULT nextval('orders_id_seq'),
    product VARCHAR(100)
);
ALTER SEQUENCE orders_id_seq OWNED BY orders.id;

-- SERIAL = INTEGER + SEQUENCE + DEFAULT
-- BIGSERIAL = BIGINT + SEQUENCE (for huge tables)
-- SMALLSERIAL = SMALLINT + SEQUENCE (rarely used)

-- View the sequence:
-- \ds      (list all sequences)
-- \d orders_id_seq
```

### IDENTITY — The Modern Standard (Preferred in PG 16)
**Explanation:** IDENTITY is the SQL standard way. Two flavors: GENERATED ALWAYS prevents manual id values — the database always generates them. GENERATED BY DEFAULT allows manual values but generates automatically if you don't provide one. GENERATED ALWAYS is recommended because it prevents accidental id collisions. You can customize the starting value and increment — invoices starting at one thousand, for example.

```sql
-- GENERATED ALWAYS AS IDENTITY (recommended)
CREATE TABLE users (
    id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100)
);
-- Cannot manually set id (must use OVERRIDING)

-- GENERATED BY DEFAULT AS IDENTITY
CREATE TABLE products (
    id   INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name VARCHAR(100)
);
-- CAN manually set id (like SERIAL)

-- Custom sequence options:
CREATE TABLE invoices (
    id INT GENERATED ALWAYS AS IDENTITY
      (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    amount NUMERIC(10,2)
);
-- First invoice id = 1000, then 1001, 1002...
```

### IDENTITY in Action
**Explanation:** Watch IDENTITY work. We create users with GENERATED ALWAYS. Insert Ravi and Priya without specifying id — they get one and two automatically. Now try to manually set id to ten for Arjun — error. GENERATED ALWAYS blocks it. PostgreSQL even tells you the escape hatch — OVERRIDING SYSTEM VALUE — but you should rarely need it. The database manages the ids.

```sql
essilor=#CREATE TABLE users (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(100)
);
CREATE TABLE
essilor=#INSERT INTO users (name) VALUES ('Ravi'), ('Priya');
INSERT 0 2
essilor=#SELECT * FROM users;
 id | name
----+-------
  1 | Ravi
  2 | Priya

essilor=#INSERT INTO users (id, name) VALUES (10, 'Arjun');
ERROR:  cannot insert a non-DEFAULT value into column "id"
HINT:  Use OVERRIDING SYSTEM VALUE to override.
```

### Sequence Functions: nextval, currval, setval
**Explanation:** Sequences have three functions. nextval advances the sequence and returns the next number — one thousand, one thousand one, one thousand two. currval returns the last value nextval gave you in this session. setval manually sets the sequence to a specific value — useful after data imports. With the third argument false, the next nextval returns exactly that value instead of the next one.

```sql
-- Create a standalone sequence
CREATE SEQUENCE order_num_seq
  START WITH 1000
  INCREMENT BY 1
  MINVALUE 1000
  MAXVALUE 999999
  NO CYCLE;

-- nextval: get NEXT value (advances the sequence)
SELECT nextval('order_num_seq');  -- 1000
SELECT nextval('order_num_seq');  -- 1001
SELECT nextval('order_num_seq');  -- 1002

-- currval: get CURRENT value (last nextval in this session)
SELECT currval('order_num_seq');  -- 1002

-- setval: manually set the sequence value
SELECT setval('order_num_seq', 5000);
SELECT nextval('order_num_seq');  -- 5001

-- setval with false: next nextval returns this value
SELECT setval('order_num_seq', 5000, false);
SELECT nextval('order_num_seq');  -- 5000
```

### Common Sequence Errors
**Explanation:** Two common errors. First — calling currval before nextval in a session. currval only works after you've called nextval at least once in the current session. Second — after a data import, the sequence is out of sync. You set it to one, but id one already exists. The fix is setval to the maximum id currently in the table. This resyncs the sequence to continue after the highest existing id.

```sql
-- Error 1: currval before nextval
essilor=#SELECT currval('order_num_seq');
ERROR:  currval of sequence "order_num_seq" is not yet
        defined in this session
-- Fix: call nextval first in this session

-- Error 2: Duplicate after bad setval
essilor=#SELECT setval('users_id_seq', 1);
essilor=#INSERT INTO users (name) VALUES ('Test');
ERROR:  duplicate key value violates unique constraint
-- Fix: setval to MAX(id) from the table:
essilor=#SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));
```

### Temporary Tables — Session-Scoped, Auto-Dropped
**Explanation:** Temporary tables exist only for your current session. Create them with CREATE TEMP TABLE. Use them like normal tables — insert, select, join. But they're invisible to other sessions and automatically dropped when your session ends. No cleanup needed. The ON COMMIT options control behavior within transactions — PRESERVE ROWS keeps data, DELETE ROWS empties after each commit, DROP removes the table after the transaction commits.

```sql
-- Create a temporary table
CREATE TEMP TABLE cart_items (
    id         SERIAL PRIMARY KEY,
    product    VARCHAR(100),
    qty        INT DEFAULT 1,
    added_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Use it like a normal table
INSERT INTO cart_items (product, qty)
VALUES ('Laptop', 1), ('Mouse', 2);

SELECT * FROM cart_items;

-- Temp table is INVISIBLE to other sessions!
-- When your session ends → table auto-dropped

-- ON COMMIT options (for transactions):
-- ON COMMIT PRESERVE ROWS  (default)
-- ON COMMIT DELETE ROWS    (empty after each commit)
-- ON COMMIT DROP           (dropped after commit)
```

### Unlogged Tables — Faster, But Risky
**Explanation:** Unlogged tables skip the Write-Ahead Log, making writes two to three times faster. But there's a big risk — if PostgreSQL crashes, unlogged tables are automatically truncated. The table structure survives, but all data is gone. Use unlogged tables only for data you can regenerate — session caches, intermediate computation results, scratch data. Never use them for data you can't afford to lose.

```sql
-- Create an unlogged table
CREATE UNLOGGED TABLE session_cache (
    id        SERIAL PRIMARY KEY,
    user_id   INT,
    data      JSONB,
    cached_at TIMESTAMPTZ DEFAULT NOW()
);

-- Faster writes: no WAL (Write-Ahead Log)
-- 2-3x faster INSERT/UPDATE than regular tables

-- THE RISK:
-- If PostgreSQL crashes → unlogged table is TRUNCATED
-- Data is LOST. Table structure survives, data doesn't.

-- Good for:
-- Session caches, materialized intermediate results,
-- scratch data you can regenerate

-- BAD for:
-- Anything you can't afford to lose!
-- Orders, users, financial data → NEVER unlogged
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common Sequence Errors
Two common errors. First — calling currval before nextval in a session. currval only works after you've called nextval at least once in the current session. Second — after a data import, the sequence is out of sync. You set it to one, but id one already exists. The fix is setval to the maximum id currently in the table. This resyncs the sequence to continue after the highest existing id.

```sql
-- Error 1: currval before nextval
SELECT currval('order_num_seq');
ERROR:  currval of sequence "order_num_seq" is not yet
        defined in this session
-- Fix: call nextval first in this session

-- Error 2: Duplicate after bad setval
SELECT setval('users_id_seq', 1);
INSERT INTO users (name) VALUES ('Test');
ERROR:  duplicate key value violates unique constraint
-- Fix: setval to MAX(id) from the table:
SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time. Create a table with IDENTITY and verify auto-generated ids. Try manual insert — see the error. Create a standalone sequence starting at five thousand, practice nextval, currval, setval. Create a temp table, use it, then disconnect and reconnect — it's gone. Create an unlogged table and verify it works. Compare the three table types side by side.

1. Create a table with IDENTITY (GENERATED ALWAYS), insert 3 rows, verify auto-generated ids
2. Try to manually INSERT an id — see the error, then use OVERRIDING SYSTEM VALUE
3. Create a standalone sequence starting at 5000, use nextval() 3 times
4. Use setval() to reset the sequence, verify with nextval()
5. Create a TEMP TABLE, insert data, disconnect and reconnect — table is gone
6. Create an UNLOGGED TABLE, insert data, verify it works like a normal table
7. Compare: regular table vs temp table vs unlogged table behavior


---

## 7. Key Takeaways & Cheat Sheet

Let's recap. SERIAL creates an integer column with a sequence behind it. IDENTITY is the modern standard — use GENERATED ALWAYS in PostgreSQL 16. Sequences have three functions: nextval advances, currval reads, setval resets. Gaps in sequences are normal. After importing data, resync with setval to max id. Temp tables live for one session and auto-drop. Unlogged tables are fast but lose data on crash — caches only.

- **SERIAL is a shortcut for INTEGER + SEQUENCE + DEFAULT nextval()**
- **IDENTITY (GENERATED ALWAYS) is preferred in PG 16 — SQL standard, safer**
- **Sequence functions: nextval() (advance), currval() (current), setval() (reset)**
- **Sequence gaps are normal — don't try to fix them**
- **After data import: setval(seq, (SELECT MAX(id) FROM table))**
- **TEMP TABLE: session-only, auto-dropped, invisible to others**
- **UNLOGGED TABLE: fast writes, but data lost on crash — use for caches only**


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
