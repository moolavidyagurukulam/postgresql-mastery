# Partial, Expression & Covering Indexes
**Series:** PostgreSQL Mastery | **Phase:** Phase 12: Indexes | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn three advanced indexing techniques that make indexes more targeted and efficient. Partial indexes only index a subset of rows — saving space and speeding up specific queries. Expression indexes index the result of a function — so LOWER of email or EXTRACT of year can use an index. Covering indexes include extra columns so queries can be answered from the index alone, without visiting the table. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Partial Index — Index Only What You Query
A partial index has a WHERE clause — it only indexes rows that match the condition. If your orders table has a million rows but you almost always query WHERE status = 'pending' and only 5 percent of orders are pending, a partial index on status WHERE status = 'pending' indexes only 50,000 rows instead of a million. It is smaller, faster to build, and faster to search.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Syntax** | CREATE INDEX ... ON table (col) WHERE condition; |
| **What** | Indexes only rows matching the WHERE clause |
| **Size** | Much smaller than full index (only subset of rows) |
| **Speed** | Faster to scan (fewer entries) and maintain (fewer writes) |
| **Requirement** | Query WHERE must match or imply the index WHERE |

**Notes:**
- Perfect for: active orders, unread messages, recent records
- The query's WHERE clause must match the index's WHERE clause

### Expression Index — Index Computed Values
An expression index indexes the result of a function or expression applied to a column. The classic example: case-insensitive email search. If you write WHERE LOWER(email) = 'test@example.com', a regular index on email does not help — PostgreSQL cannot use it because the WHERE applies a function. But an expression index on LOWER(email) stores the lowercased values and handles this query perfectly.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Syntax** | CREATE INDEX ... ON table (expression); |
| **What** | Indexes the RESULT of a function/expression |
| **Classic** | CREATE INDEX ... ON users (LOWER(email)) |
| **Date Parts** | CREATE INDEX ... ON orders (EXTRACT(YEAR FROM order_date)) |
| **Requirement** | Query must use the SAME expression in WHERE |

**Notes:**
- Expression must be IMMUTABLE (same input always gives same output)
- Also called functional index

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Covering Index — INCLUDE Extra Columns
A covering index uses INCLUDE to add extra columns to the index without making them part of the search key. This enables Index Only Scans — PostgreSQL reads everything it needs from the index and never visits the table. For example, if you search by customer_id but also need order_date and amount, including them in the index means the query is answered entirely from the index.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Syntax** | CREATE INDEX ... ON table (key_col) INCLUDE (extra_col, ...); |
| **Key columns** | Used for searching (WHERE, JOIN conditions) |
| **INCLUDE columns** | Stored in index but NOT used for searching |
| **Benefit** | Index Only Scan: reads from index, skips table visit |
| **Tradeoff** | Larger index (stores more data per entry) |

**Notes:**
- INCLUDE columns are NOT in the B-Tree structure — stored in leaf pages only
- Available since PostgreSQL 11

### When to Use Each Advanced Index
Here is when to use each advanced index type. Partial indexes save space when you only query a small subset of rows. Expression indexes handle case-insensitive searches, date parts, and computed lookups. Covering indexes enable index-only scans for queries that need a few extra columns. You can even combine them — a partial expression covering index — though keep it readable.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Partial indexes save space when you only query a small subset of rows |
| **Expression indexes handle case** | insensitive searches, date parts, and computed lookups |
| **Covering indexes enable index** | only scans for queries that need a few extra columns |
| **You can even combine them** | a partial expression covering index — though keep it readable |

### Practice Exercises
Practice exercises: create a partial index on a subset of rows, test that queries matching the condition use it. Create an expression index on LOWER of a column, search case-insensitively. Create a covering index with INCLUDE and verify Index Only Scan in EXPLAIN. Try creating a unique partial index.

- 1. CREATE INDEX ... WHERE status = 'pending' (partial)
- 2. Query with matching WHERE → uses partial index
- 3. Query without matching WHERE → does NOT use it
- 4. CREATE INDEX ... (LOWER(email)) (expression)
- 5. Search with LOWER() → Index Scan
- 6. CREATE INDEX ... (col) INCLUDE (extra) (covering)
- 7. EXPLAIN shows Index Only Scan
- 8. CREATE UNIQUE INDEX ... WHERE active = true


---

## 3. Hands-On Commands & psql Output

### Partial Index in Action
**Explanation:** Let us create a partial index. We have an orders table where most orders are delivered, but we frequently search for pending and shipped orders. A partial index on status for only non-delivered orders is much smaller than indexing every row. The query must include a WHERE clause that the planner recognizes as compatible with the index condition.

```sql
-- Full index: indexes ALL 100K rows
practice=# CREATE INDEX idx_orders_status ON orders (status);

-- Partial index: indexes ONLY pending orders (~25K rows)
practice=# CREATE INDEX idx_orders_pending ON orders (customer_id)
WHERE status = 'pending';
CREATE INDEX

-- This query uses the partial index
practice=# EXPLAIN SELECT * FROM orders
WHERE status = 'pending' AND customer_id = 42;
 Index Scan using idx_orders_pending on orders
   Index Cond: (customer_id = 42)

-- Size comparison
practice=# SELECT
  pg_size_pretty(pg_relation_size('idx_orders_status')) AS full,
  pg_size_pretty(pg_relation_size('idx_orders_pending')) AS partial;
  full   | partial
---------+---------
 2208 kB | 560 kB
```

### Unique Partial Index
**Explanation:** A unique partial index is a powerful pattern. You can enforce that a column is unique but only for certain rows. For example: each customer can have only ONE active order, but can have many completed orders. A regular unique constraint would block multiple orders per customer. A partial unique index with WHERE status = 'active' enforces uniqueness only on active orders.

```sql
-- Each customer can have only ONE pending order
practice=# CREATE UNIQUE INDEX idx_one_pending_per_customer
ON orders (customer_id)
WHERE status = 'pending';
CREATE INDEX

-- Customer 42 already has a pending order
-- Trying to insert another pending order for 42:
-- INSERT INTO orders (customer_id, ..., status)
-- VALUES (42, ..., 'pending');
-- ERROR: duplicate key value violates unique constraint
--        "idx_one_pending_per_customer"

-- But customer 42 CAN have multiple delivered orders
-- (partial index only enforces on status='pending')

-- Common pattern: soft-delete with unique active
-- CREATE UNIQUE INDEX idx_active_email
--   ON users (email) WHERE deleted_at IS NULL;
```

### Expression Index Examples
**Explanation:** Let us create expression indexes and see them in action. First, a LOWER index for case-insensitive email search. Then an EXTRACT index for querying by year. The query WHERE clause must use the exact same expression as the index — otherwise the planner will not match them.

```sql
-- Table with mixed-case emails
practice=# CREATE TABLE users (
  id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email VARCHAR(200),
  name  VARCHAR(100)
);

practice=# INSERT INTO users (email, name) VALUES
('Alice@Example.COM', 'Alice'),
('Bob@EXAMPLE.com', 'Bob'),
('carol@example.com', 'Carol');

-- Expression index on LOWER(email)
practice=# CREATE INDEX idx_users_email_lower ON users (LOWER(email));
CREATE INDEX

-- Query MUST use LOWER() to match the index
practice=# EXPLAIN SELECT * FROM users
WHERE LOWER(email) = 'alice@example.com';
 Index Scan using idx_users_email_lower on users
   Index Cond: (lower(email) = 'alice@example.com')

-- Date extraction index
practice=# CREATE INDEX idx_orders_year
ON orders (EXTRACT(YEAR FROM order_date));

-- Must use same expression in WHERE
-- WHERE EXTRACT(YEAR FROM order_date) = 2024 → uses index
```

### Covering Index — Index Only Scan
**Explanation:** Let us create a covering index and see the Index Only Scan in action. Without INCLUDE, a query that needs columns beyond the index key must visit the table. With INCLUDE, all needed columns are in the index, enabling a pure index-only read. The EXPLAIN output will show Index Only Scan instead of Index Scan.

```sql
-- Regular index: only customer_id in the index
-- (idx_orders_customer already exists)

-- Query needs customer_id + amount → must visit table
practice=# EXPLAIN SELECT customer_id, amount FROM orders
WHERE customer_id = 42;
 Index Scan using idx_orders_customer on orders
   Index Cond: (customer_id = 42)

-- Covering index: customer_id (search) + amount (included)
practice=# CREATE INDEX idx_orders_cust_cover ON orders
(customer_id) INCLUDE (amount, order_date);
CREATE INDEX

-- Now: Index Only Scan (no table visit!)
practice=# EXPLAIN SELECT customer_id, amount FROM orders
WHERE customer_id = 42;
 Index Only Scan using idx_orders_cust_cover
   Index Cond: (customer_id = 42)
```


---


## 6. Hands-On Practice Exercises & Verified Solutions

### Exercise 1: Partial Index for Specific Status
**Challenge:** Create a partial index on `orders(order_date)` specifically for rows where `status = 'shipped'`.
```sql
CREATE INDEX idx_shipped ON orders (order_date)
WHERE status = 'shipped';

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders
WHERE status = 'shipped' AND order_date > '2024-06-01';
```
*Explanation:* The partial index filters out 75% of rows (pending, delivered, cancelled), creating an index that is over 4x smaller and keeps hot cache free.

### Exercise 2: Expression Index for Case-Insensitive Search
**Challenge:** Build an expression index that accelerates case-insensitive lookups on `users(name)`.
```sql
CREATE INDEX idx_users_name_upper ON users (UPPER(name));

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM users WHERE UPPER(name) = 'BOB';
```
*Explanation:* Because `UPPER()` is an `IMMUTABLE` function, PostgreSQL computes the uppercase value once during write operations and stores it in the index leaf pages.

### Exercise 3: Covering Index for Index-Only Scans
**Challenge:** Create a covering index on `orders(order_date)` including `customer_id` and `amount` to eliminate heap reads.
```sql
CREATE INDEX idx_orders_date_cover ON orders
(order_date) INCLUDE (customer_id, amount);

VACUUM orders; -- ensure visibility map is updated

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_date, customer_id, amount
FROM orders WHERE order_date = '2024-06-15';
```
*Explanation:* The `INCLUDE` clause stores `customer_id` and `amount` exclusively at the leaf level, satisfying the query purely from index buffers without touching heap table blocks.

### Exercise 4: Conditional Uniqueness via Partial Unique Index
**Challenge:** Enforce a business rule where each customer can only have one active `pending` order, but unlimited completed orders.
```sql
CREATE UNIQUE INDEX idx_one_pending
ON orders (customer_id) WHERE status = 'pending';
```
*Explanation:* Any attempt to insert a second pending order for the same customer triggers a unique constraint violation, while completed orders are unconstrained.

### Exercise 5: Combined Partial & Covering Index
**Challenge:** Construct an index that covers pending orders while storing order amounts for instant retrieval.
```sql
CREATE INDEX idx_pending_cover ON orders
(customer_id) INCLUDE (amount, order_date)
WHERE status = 'pending';

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, amount, order_date
FROM orders
WHERE status = 'pending' AND customer_id = 42;
```
*Explanation:* Combining partial filtering (`WHERE status = 'pending'`) with payload inclusion (`INCLUDE`) yields the highest query speed with the lowest memory overhead.


## 7. Key Takeaways & Cheat Sheet

Let us recap. Partial indexes have a WHERE clause and index only matching rows — smaller and faster for targeted queries. Expression indexes store function results — essential for LOWER, EXTRACT, and computed searches. Covering indexes use INCLUDE to add extra columns for Index Only Scans — the fastest read path. Combine these techniques for highly optimized indexes. In the next class, we cover multi-column indexes with the leftmost prefix rule, when to index and when not to, and how to handle index bloat with REINDEX. See you there!

- **Partial: CREATE INDEX ... WHERE condition;**
- **Partial: indexes only matching rows (smaller, faster)**
- **Expression: CREATE INDEX ... (LOWER(col));**
- **Expression: query must use same function in WHERE**
- **Covering: CREATE INDEX ... (key) INCLUDE (extra);**
- **Covering: enables Index Only Scan (no table visit)**
- **Unique Partial: enforce uniqueness on a subset**
- **Combine techniques for maximum optimization**


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
