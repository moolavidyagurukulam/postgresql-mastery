# UPDATE, DELETE & UPSERT
**Series:** PostgreSQL Mastery | **Phase:** General | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> INSERT adds data. SELECT reads it. Now we learn UPDATE to modify existing rows, DELETE to remove them, and UPSERT — PostgreSQL's INSERT ON CONFLICT — to handle the 'insert or update' pattern in one atomic statement.


---

## 2. Core Technical Concepts & Mechanisms

### UPSERT: INSERT ... ON CONFLICT
UPSERT solves a common problem — insert a row if it doesn't exist, update it if it does. The old way was check-then-insert — two queries with a race condition between them. PostgreSQL's ON CONFLICT does it in one atomic statement. DO NOTHING silently skips on conflict. DO UPDATE changes the existing row. No race condition, no duplicate errors.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Problem** | Insert a row, but if it already exists, update it instead |
| **Old Way** | SELECT to check, then INSERT or UPDATE — two queries, race condition |
| **UPSERT** | INSERT ... ON CONFLICT DO UPDATE — one atomic statement |
| **DO NOTHING** | Skip the insert silently if conflict occurs |
| **DO UPDATE** | Update the existing row with new values |

### Safety Checklist for UPDATE and DELETE
Safety checklist. Always write your WHERE clause first. Before running UPDATE or DELETE, run a SELECT with the same WHERE to see which rows match. Use RETURNING to confirm what changed. Wrap dangerous operations in a transaction — BEGIN, do the update, check the result, then COMMIT or ROLLBACK. Use LIMIT to cap how many rows you affect. And back up before bulk operations.

- ALWAYS write WHERE first — never run UPDATE/DELETE without it
- Test with SELECT first: SELECT * FROM t WHERE ... (see which rows match)
- Use RETURNING to confirm what changed
- Wrap in a transaction: BEGIN → UPDATE → check → COMMIT or ROLLBACK
- Use LIMIT to cap damage: DELETE FROM t WHERE ... LIMIT 10
- Back up before bulk operations: CREATE TABLE t_backup AS SELECT * FROM t


---

## 3. Hands-On Commands & psql Output

### Setup: Sample Data
**Explanation:** Our sample data — six products with prices and stock counts. We also have a price updates table with new prices for three products. We'll use both tables to demonstrate UPDATE, DELETE, and UPSERT patterns.

```sql
CREATE TABLE products (
    id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  VARCHAR(100) UNIQUE NOT NULL,
    price NUMERIC(10,2) CHECK (price > 0),
    stock INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO products (name, price, stock) VALUES
('Laptop',     999.99, 10),
('Mouse',       29.99, 50),
('Keyboard',    49.99, 30),
('Monitor',    299.99, 15),
('Headphones',  79.99, 25),
('Webcam',      59.99, 20);

CREATE TABLE price_updates (
    product_name VARCHAR(100),
    new_price    NUMERIC(10,2)
);
INSERT INTO price_updates VALUES
('Laptop', 949.99), ('Mouse', 24.99), ('Webcam', 54.99);
```

### UPDATE — Modify Existing Rows
**Explanation:** UPDATE SET changes existing values. Specify which columns to set and which rows with WHERE. You can update multiple columns at once and use expressions — price times zero point nine gives a ten percent discount. Critical warning: UPDATE without WHERE affects ALL rows. Every single row gets updated. Always double-check your WHERE clause before running an UPDATE.

```sql
-- Update single row
UPDATE products
SET price = 949.99
WHERE name = 'Laptop';
-- UPDATE 1

-- Update multiple columns
UPDATE products
SET price = 24.99,
    stock = 60,
    updated_at = NOW()
WHERE name = 'Mouse';

-- Update with expression
UPDATE products
SET price = price * 0.90
WHERE stock > 20;
-- 10% discount on well-stocked items

-- WARNING: UPDATE without WHERE = ALL ROWS!
UPDATE products SET stock = 0;
-- Every product stock set to 0! Dangerous!
```

### UPDATE ... RETURNING — See What Changed
**Explanation:** RETURNING works with UPDATE too. After updating the monitor's price by five percent, RETURNING shows the new price immediately. You can even compute the old value — stock plus one gives you what it was before the decrement. No separate SELECT needed.

```sql
-- RETURNING shows the updated rows
UPDATE products
SET price = price * 1.05
WHERE name = 'Monitor'
RETURNING id, name, price AS new_price;
--  id |  name   | new_price
-- ----+---------+----------
--   4 | Monitor |   314.99

-- Return old and new (use subquery trick)
UPDATE products
SET stock = stock - 1
WHERE name = 'Laptop'
RETURNING name, stock AS new_stock,
          stock + 1 AS old_stock;
-- Shows both the new and computed old value
```

### UPDATE ... FROM — Join Update
**Explanation:** UPDATE FROM is how PostgreSQL does join updates. We update products using prices from the price updates table. The FROM clause brings in the other table, and WHERE matches the rows. Three products get new prices in one statement. This is PostgreSQL's syntax — other databases use UPDATE JOIN, but the concept is the same.

```sql
-- Update products using data from another table
UPDATE products p
SET price = pu.new_price,
    updated_at = NOW()
FROM price_updates pu
WHERE p.name = pu.product_name;
-- UPDATE 3  (Laptop, Mouse, Webcam updated)

-- Verify:
SELECT name, price FROM products
WHERE name IN ('Laptop', 'Mouse', 'Webcam');
--  name   |  price
-- --------+---------
--  Laptop |  949.99
--  Mouse  |   24.99
--  Webcam |   54.99

-- UPDATE...FROM is PostgreSQL's join-update
-- Other databases use UPDATE...JOIN
```

### UPDATE in Action
**Explanation:** Live demo. We add ten to stock for products with less than twenty — Laptop and Monitor get restocked. RETURNING confirms the new values. Then we try setting Mouse price to negative ten — CHECK constraint blocks it. Constraints protect against bad updates, not just bad inserts.

```sql
essilor=#UPDATE products SET stock = stock + 10 WHERE stock < 20
RETURNING name, stock;
   name    | stock
-----------+-------
 Laptop    |    19
 Monitor   |    25
(2 rows)

UPDATE 2

essilor=#UPDATE products SET price = -10 WHERE name = 'Mouse';
ERROR:  new row for relation "products" violates
        check constraint "products_price_check"
-- CHECK constraints protect against bad updates too!
```

### DELETE — Remove Rows
**Explanation:** DELETE removes rows. Always use WHERE to target specific rows. RETURNING shows what was deleted — useful for logging or archiving. Critical warning again: DELETE without WHERE deletes ALL rows. The table becomes empty. Unlike TRUNCATE, DELETE works row by row and fires triggers. Use DELETE for selective removal, TRUNCATE for clearing everything.

```sql
-- Delete specific rows
DELETE FROM products WHERE name = 'Webcam';
-- DELETE 1

-- Delete with condition
DELETE FROM products WHERE stock = 0;

-- Delete with RETURNING (see what was deleted)
DELETE FROM products
WHERE price < 30
RETURNING *;
-- Shows the deleted row(s)

-- WARNING: DELETE without WHERE = ALL ROWS!
DELETE FROM products;
-- Every row deleted! Table is empty!

-- DELETE vs TRUNCATE:
-- DELETE: row by row, can use WHERE, fires triggers
-- TRUNCATE: all rows, no WHERE, faster, resets sequences
```

### DELETE ... USING — Join Delete
**Explanation:** DELETE USING is the join-delete pattern. We have a blacklist table. DELETE from products USING blacklist where the names match. Both blacklisted products are removed in one statement. Same concept as UPDATE FROM but for deletes.

```sql
-- Setup: blacklisted products
CREATE TABLE blacklist (
    product_name VARCHAR(100)
);
INSERT INTO blacklist VALUES ('Webcam'), ('Headphones');

-- Delete products that appear in blacklist
DELETE FROM products p
USING blacklist b
WHERE p.name = b.product_name
RETURNING p.name;
-- Webcam and Headphones deleted

-- DELETE...USING is PostgreSQL's join-delete
-- Same concept as UPDATE...FROM
```

### DELETE with CTE — Delete and Archive
**Explanation:** Writable CTEs make delete-and-archive atomic. The CTE deletes rows and captures them with RETURNING. The outer INSERT puts them into the archive. Both operations happen in one transaction — either both succeed or neither does. No risk of deleting without archiving.

```sql
-- Delete and archive in one atomic statement
CREATE TABLE products_archive (
    id    INT,
    name  VARCHAR(100),
    price NUMERIC(10,2),
    archived_at TIMESTAMPTZ DEFAULT NOW()
);

WITH removed AS (
    DELETE FROM products
    WHERE stock = 0
    RETURNING id, name, price
)
INSERT INTO products_archive (id, name, price)
SELECT id, name, price
FROM removed;
-- Rows deleted from products AND inserted into archive
-- Atomic: both happen or neither happens
```

### ON CONFLICT DO NOTHING — Skip Duplicates
**Explanation:** DO NOTHING silently skips conflicting rows. Insert Laptop — already exists, skipped, no error. Bulk insert three products — Laptop is skipped, Tablet and Speaker are inserted. The result says INSERT zero two — two rows actually inserted. You can specify the conflict target by column name or constraint name.

```sql
-- Insert if not exists, skip if exists
INSERT INTO products (name, price, stock)
VALUES ('Laptop', 999.99, 5)
ON CONFLICT (name) DO NOTHING;
-- Laptop exists → skipped, no error

-- Bulk insert, skipping duplicates
INSERT INTO products (name, price, stock) VALUES
    ('Laptop',   999.99, 5),
    ('Tablet',   499.99, 8),
    ('Speaker',  149.99, 12)
ON CONFLICT (name) DO NOTHING;
-- INSERT 0 2  (Laptop skipped, Tablet+Speaker inserted)

-- Conflict on primary key
INSERT INTO products (name, price, stock)
VALUES ('NewItem', 19.99, 100)
ON CONFLICT ON CONSTRAINT products_pkey DO NOTHING;
```

### ON CONFLICT DO UPDATE — Update Existing Row
**Explanation:** DO UPDATE changes the existing row. EXCLUDED is a special table — it holds the values that would have been inserted. So EXCLUDED dot price is the new price, products dot price is the current price. You can even add a WHERE clause — update only if the new price is lower. This is incredibly powerful for inventory management, price synchronization, and data feeds.

```sql
-- Insert or update
INSERT INTO products (name, price, stock)
VALUES ('Laptop', 899.99, 15)
ON CONFLICT (name) DO UPDATE
SET price = EXCLUDED.price,
    stock = EXCLUDED.stock,
    updated_at = NOW();
-- Laptop exists → updated to 899.99, stock=15

-- EXCLUDED = the row that WOULD have been inserted
-- EXCLUDED.price = 899.99 (the new value)
-- products.price = old value (current row)

-- Conditional update: only if new price is lower
INSERT INTO products (name, price, stock)
VALUES ('Laptop', 799.99, 20)
ON CONFLICT (name) DO UPDATE
SET price = EXCLUDED.price,
    stock = products.stock + EXCLUDED.stock
WHERE EXCLUDED.price < products.price;
-- Updates only if new price is cheaper
```

### UPSERT in Action
**Explanation:** Watch it live. Laptop has price nine forty-nine and stock nineteen. We upsert with price eight ninety-nine and stock five. On conflict, we set the new price but ADD the stock. Result: price updated to eight ninety-nine, stock becomes twenty-four — nineteen plus five. RETURNING confirms the final values. One statement, no race condition.

```sql
essilor=#SELECT name, price, stock FROM products WHERE name = 'Laptop';
  name  |  price  | stock
--------+---------+-------
 Laptop |  949.99 |    19

essilor=#INSERT INTO products (name, price, stock)
VALUES ('Laptop', 899.99, 5)
ON CONFLICT (name) DO UPDATE
SET price = EXCLUDED.price, stock = products.stock + EXCLUDED.stock
RETURNING name, price, stock;
  name  |  price  | stock
--------+---------+-------
 Laptop |  899.99 |    24
(1 row)
-- Price updated to 899.99, stock ADDED (19+5=24)
```

### Common UPSERT Errors
**Explanation:** Two common upsert errors. First — no matching constraint. ON CONFLICT requires a UNIQUE or EXCLUSION constraint on the specified columns. If price has no unique constraint, you can't use it as a conflict target. Second — the same row affected twice. If your VALUES list has two rows that conflict with the same existing row, PostgreSQL refuses. Remove the duplicate from your values.

```sql
-- Error 1: No matching constraint
essilor=#INSERT INTO products (name, price) VALUES ('X', 9.99)
ON CONFLICT (price) DO NOTHING;
ERROR:  there is no unique or exclusion constraint
        matching the ON CONFLICT specification
-- Fix: price has no UNIQUE constraint. Use (name) instead.

-- Error 2: Same row affected twice
essilor=#INSERT INTO products (name, price) VALUES
('X', 10), ('X', 20) ON CONFLICT (name) DO UPDATE SET price = EXCLUDED.price;
ERROR:  ON CONFLICT DO UPDATE command cannot affect
        row a second time
-- Fix: remove duplicate 'X' from VALUES
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common UPSERT Errors
Two common upsert errors. First — no matching constraint. ON CONFLICT requires a UNIQUE or EXCLUSION constraint on the specified columns. If price has no unique constraint, you can't use it as a conflict target. Second — the same row affected twice. If your VALUES list has two rows that conflict with the same existing row, PostgreSQL refuses. Remove the duplicate from your values.

```sql
-- Error 1: No matching constraint
INSERT INTO products (name, price) VALUES ('X', 9.99)
ON CONFLICT (price) DO NOTHING;
ERROR:  there is no unique or exclusion constraint
        matching the ON CONFLICT specification
-- Fix: price has no UNIQUE constraint. Use (name) instead.

-- Error 2: Same row affected twice
INSERT INTO products (name, price) VALUES
('X', 10), ('X', 20) ON CONFLICT (name) DO UPDATE SET price = EXCLUDED.price;
ERROR:  ON CONFLICT DO UPDATE command cannot affect
        row a second time
-- Fix: remove duplicate 'X' from VALUES
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time. Give all products a ten percent raise with RETURNING. Use UPDATE FROM to apply prices from another table. Delete zero-stock products and log them. Use DELETE USING with a blacklist. Try upsert with DO NOTHING to skip duplicates. Try DO UPDATE to merge new data. And build a writable CTE to delete and archive atomically.

1. UPDATE: Give all products a 10% price increase, use RETURNING to verify
2. UPDATE...FROM: Apply prices from price_updates table to products
3. DELETE specific products with stock = 0, use RETURNING to log them
4. DELETE...USING: Remove products that appear in a blacklist table
5. UPSERT DO NOTHING: Insert 3 products, 1 duplicate — verify skip
6. UPSERT DO UPDATE: Insert product, update price+stock on conflict
7. Writable CTE: DELETE old products and archive them in one statement


---


### Answer Key — UPDATE, DELETE & UPSERT Solutions

```sql
-- 1. Give all products a 10% raise with RETURNING
-- Note: RETURNING displays updated values immediately.
UPDATE products
SET price = ROUND(price * 1.10, 2)
WHERE category = 'Electronics'
RETURNING id, name, price AS new_price;

-- 2. UPDATE FROM join syntax
-- Note: PostgreSQL UPDATE FROM allows joining a source table cleanly.
UPDATE products p
SET price = s.new_price
FROM price_staging s
WHERE p.sku = s.sku;

-- 3. DELETE with safety filter and RETURNING
-- Note: Always double-check WHERE clauses before executing DELETE.
DELETE FROM sessions
WHERE last_active < NOW() - INTERVAL '30 days'
RETURNING id, user_id;

-- 4. UPSERT: ON CONFLICT DO NOTHING
-- Note: Ignores unique constraint violations silently.
INSERT INTO tags (name)
VALUES ('postgresql'), ('database')
ON CONFLICT (name) DO NOTHING;

-- 5. UPSERT: ON CONFLICT DO UPDATE
-- Note: EXCLUDED represents the row proposed for insertion.
INSERT INTO inventory (sku, qty)
VALUES ('PROD-001', 50)
ON CONFLICT (sku) DO UPDATE
SET qty = inventory.qty + EXCLUDED.qty,
    updated_at = NOW();

```

---

## 7. Key Takeaways & Cheat Sheet

Let's recap. UPDATE and DELETE both need WHERE — without it, you affect all rows. UPDATE FROM and DELETE USING handle join operations. RETURNING works with both to show what changed. UPSERT with ON CONFLICT handles insert-or-update in one atomic statement. EXCLUDED holds the new values. And writable CTEs chain operations atomically. Always test with SELECT first, and wrap dangerous operations in transactions.

- **UPDATE SET ... WHERE ... — always include WHERE (no WHERE = all rows!)**
- **UPDATE...FROM joins another table for updates**
- **DELETE FROM ... WHERE ... — always include WHERE**
- **DELETE...USING joins another table for deletes**
- **RETURNING works with UPDATE and DELETE (see what changed)**
- **UPSERT: INSERT ... ON CONFLICT (col) DO NOTHING | DO UPDATE**
- **EXCLUDED holds the would-be-inserted values in DO UPDATE**
- **Writable CTEs chain DELETE+INSERT atomically**


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
