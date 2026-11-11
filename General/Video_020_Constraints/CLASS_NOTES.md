# Constraints — PRIMARY KEY, UNIQUE, CHECK, FOREIGN KEY & More
**Series:** PostgreSQL Mastery | **Phase:** General | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> In the last class, we created tables. But a table without constraints is a table without rules — anyone can insert garbage data. Constraints are the rules that protect your data integrity. Today we cover every constraint PostgreSQL offers: PRIMARY KEY, UNIQUE, CHECK, NOT NULL, FOREIGN KEY, EXCLUDE, and DEFAULT.

### The Problem: Tables Without Rules Accept Bad Data
Without constraints, your database accepts anything. No primary key means duplicate rows with no identity. No unique constraint means two users can share the same email. No check constraint means negative prices and impossible ages. No foreign key means orders pointing to nonexistent customers. And no NOT NULL means required fields left blank. Constraints prevent all of this.


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Tables Without Rules Accept Bad Data
Without constraints, your database accepts anything. No primary key means duplicate rows with no identity. No unique constraint means two users can share the same email. No check constraint means negative prices and impossible ages. No foreign key means orders pointing to nonexistent customers. And no NOT NULL means required fields left blank. Constraints prevent all of this.

| Term | Meaning / Explanation |
| :--- | :--- |
| **No PK** | Duplicate rows with no way to identify which is which |
| **No UNIQUE** | Two users with the same email — which one is real? |
| **No CHECK** | Negative prices, ages of 999, salaries of -50000 |
| **No FK** | Orders pointing to customers that don't exist |
| **No NOT NULL** | Required fields left blank — broken application logic |

### Constraint Naming Conventions
Always name your constraints. The naming convention is: type prefix, underscore, table name, underscore, column or description. Primary key is pk, unique is uq, check is ck, foreign key is fk, exclude is excl. Named constraints make error messages readable and make it easy to alter or drop them later. NOT NULL is the exception — it doesn't get a name.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Always name your constraints |
| **The naming convention is** | type prefix, underscore, table name, underscore, column or description |
| **Primary key is pk** | unique is uq, check is ck, foreign key is fk, exclude is excl |
| **Point 4** | Named constraints make error messages readable and make it easy to alter or drop them later |
| **NOT NULL is the exception** | it doesn't get a name |


---

## 3. Hands-On Commands & psql Output

### PRIMARY KEY — Unique Identity for Every Row
**Explanation:** PRIMARY KEY is the unique identity for every row. It enforces two things: the value must be unique, and it cannot be null. You can define it inline after the column type, or at the table level with a named constraint. For composite primary keys — where the combination of two columns is unique — use table-level syntax. In the enrollments table, each student-course pair must be unique, but the same student can appear in multiple courses.

```sql
-- Inline syntax (single column)
CREATE TABLE users (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100),
    email VARCHAR(150)
);

-- Table-level syntax (names the constraint)
CREATE TABLE users (
    id    SERIAL,
    name  VARCHAR(100),
    email VARCHAR(150),
    CONSTRAINT pk_users PRIMARY KEY (id)
);

-- Composite primary key (multiple columns)
CREATE TABLE enrollments (
    student_id INT,
    course_id  INT,
    grade      CHAR(2),
    PRIMARY KEY (student_id, course_id)
);
-- Each student+course pair must be unique
```

### PRIMARY KEY Violations
**Explanation:** Watch the errors. We insert Ravi with id one — works. Then we try Priya with id one again — error, duplicate key. The primary key already has a one. Then we try null for the id — error, violates not null. A primary key automatically enforces both unique and not null. You never need to add those separately on a primary key column.

```sql
essilor=#INSERT INTO users (id, name) VALUES (1, 'Ravi');
INSERT 0 1
essilor=#INSERT INTO users (id, name) VALUES (1, 'Priya');
ERROR:  duplicate key value violates unique constraint "pk_users"
DETAIL:  Key (id)=(1) already exists.

essilor=#INSERT INTO users (id, name) VALUES (NULL, 'Arjun');
ERROR:  null value in column "id" of relation "users"
        violates not-null constraint

-- PK = UNIQUE + NOT NULL. Both enforced automatically.
```

### UNIQUE — No Duplicate Values
**Explanation:** UNIQUE prevents duplicate values in a column. Define it inline or as a named constraint. Multi-column unique means the combination must be unique — the same user can't be in the same team twice, but the same user can be in different teams. One important difference from PRIMARY KEY — UNIQUE allows multiple nulls. In SQL, null is not equal to null, so multiple null values don't count as duplicates.

```sql
-- Inline syntax
CREATE TABLE users (
    id    SERIAL PRIMARY KEY,
    email VARCHAR(150) UNIQUE
);

-- Named constraint
CREATE TABLE users (
    id    SERIAL PRIMARY KEY,
    email VARCHAR(150),
    CONSTRAINT uq_users_email UNIQUE (email)
);

-- Multi-column unique (combination must be unique)
CREATE TABLE team_members (
    team_id   INT,
    user_id   INT,
    role      VARCHAR(50),
    UNIQUE (team_id, user_id)
);
-- Same user can't be in same team twice
-- But same user CAN be in different teams

-- IMPORTANT: UNIQUE allows multiple NULLs!
-- NULL != NULL in SQL
```

### UNIQUE Constraint Violation
**Explanation:** Here it is. First insert with ravi at ex dot com — works. Second insert with the same email — error, duplicate key. The unique constraint caught it. But watch this — we insert null, then null again. Both succeed. UNIQUE allows multiple nulls because in SQL, null is not equal to null. If you want to prevent nulls too, combine UNIQUE with NOT NULL.

```sql
essilor=#INSERT INTO users (email) VALUES ('ravi@ex.com');
INSERT 0 1
essilor=#INSERT INTO users (email) VALUES ('ravi@ex.com');
ERROR:  duplicate key value violates unique constraint "uq_users_email"
DETAIL:  Key (email)=(ravi@ex.com) already exists.

-- But NULLs are allowed multiple times:
essilor=#INSERT INTO users (email) VALUES (NULL);
INSERT 0 1
essilor=#INSERT INTO users (email) VALUES (NULL);
INSERT 0 1
-- Two NULLs! UNIQUE allows this because NULL != NULL
```

### NOT NULL — Required Fields
**Explanation:** NOT NULL marks a column as required — every row must have a value. It's the simplest constraint but one of the most important. Insert without a name? Error. To add NOT NULL to an existing column, first update all null values to something, then add the constraint. If any nulls remain, SET NOT NULL will fail.

```sql
CREATE TABLE products (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    desc_ TEXT          -- nullable (optional)
);

-- NOT NULL = column MUST have a value
-- NULL allowed = column is optional

INSERT INTO products (name, price)
VALUES ('Laptop', 999.99);  -- OK

INSERT INTO products (price)
VALUES (29.99);
-- ERROR: null value in column "name"
--        violates not-null constraint

-- Add NOT NULL to existing column:
-- Step 1: Fill existing nulls
UPDATE products SET desc_ = 'No description'
  WHERE desc_ IS NULL;
-- Step 2: Add constraint
ALTER TABLE products
  ALTER COLUMN desc_ SET NOT NULL;
```

### CHECK — Custom Business Rules
**Explanation:** CHECK constraints enforce custom business rules. Price must be positive. Quantity can't be negative. Age must be between eighteen and a hundred twenty. Salary can't be negative. You can name your constraints for clear error messages. Multi-column checks work too — here we ensure end date is never before start date. CHECK is your general-purpose data validation tool.

```sql
-- Inline CHECK
CREATE TABLE products (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    price NUMERIC(10,2) CHECK (price > 0),
    qty   INT CHECK (qty >= 0)
);

-- Named CHECK constraint
CREATE TABLE employees (
    id     SERIAL PRIMARY KEY,
    name   VARCHAR(100) NOT NULL,
    age    INT,
    salary NUMERIC(10,2),
    CONSTRAINT ck_emp_age
      CHECK (age >= 18 AND age <= 120),
    CONSTRAINT ck_emp_salary
      CHECK (salary >= 0)
);

-- Multi-column CHECK
CREATE TABLE events (
    id         SERIAL PRIMARY KEY,
    start_date DATE NOT NULL,
    end_date   DATE NOT NULL,
    CHECK (end_date >= start_date)
);
```

### CHECK Constraint Violations
**Explanation:** Watch the errors. Laptop with price nine ninety-nine and quantity five — passes all checks. Free item with price zero — fails. Our check says price must be greater than zero. Widget with quantity negative three — fails. Check says quantity must be zero or above. Notice the error names the exact constraint that failed and shows the failing row. Named constraints make debugging much easier.

```sql
essilor=#INSERT INTO products (name, price, qty) VALUES ('Laptop', 999.99, 5);
INSERT 0 1
essilor=#INSERT INTO products (name, price, qty) VALUES ('Free Item', 0, 10);
ERROR:  new row for relation "products" violates
        check constraint "products_price_check"
DETAIL:  Failing row contains (2, Free Item, 0, 10).

essilor=#INSERT INTO products (name, price, qty) VALUES ('Widget', 9.99, -3);
ERROR:  new row for relation "products" violates
        check constraint "products_qty_check"
DETAIL:  Failing row contains (3, Widget, 9.99, -3).
```

### DEFAULT — Automatic Values for Missing Columns
**Explanation:** DEFAULT provides automatic values when a column is not specified in an INSERT. Quantity defaults to one, status to pending, ordered at to the current timestamp. You only need to provide the product name — everything else fills in. You can always override a default by providing an explicit value. Defaults can be constants, function calls like NOW, or expressions like gen random uuid.

```sql
CREATE TABLE orders (
    id         SERIAL PRIMARY KEY,
    product    VARCHAR(100) NOT NULL,
    qty        INT DEFAULT 1,
    status     VARCHAR(20) DEFAULT 'pending',
    ordered_at TIMESTAMPTZ DEFAULT NOW(),
    notes      TEXT DEFAULT ''
);

-- Insert without defaults — they fill automatically
INSERT INTO orders (product)
VALUES ('Laptop');

SELECT * FROM orders;
-- id=1, product=Laptop, qty=1, status=pending,
-- ordered_at=2026-11-03 ..., notes=''

-- Override a default:
INSERT INTO orders (product, qty, status)
VALUES ('Monitor', 3, 'confirmed');

-- DEFAULT can be expressions:
--   DEFAULT NOW()             → current timestamp
--   DEFAULT CURRENT_DATE      → today's date
--   DEFAULT gen_random_uuid() → random UUID
--   DEFAULT true/false        → boolean
```

### FOREIGN KEY — Enforce Relationships
**Explanation:** FOREIGN KEY enforces relationships between tables. The customer id in orders must point to a real id in customers. You can't insert an order for a customer that doesn't exist. And by default, you can't delete a customer who has orders. The short inline syntax is just REFERENCES — same thing, less typing. Named constraints make errors clearer.

```sql
CREATE TABLE customers (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    product     VARCHAR(100),
    -- Inline FK
    CONSTRAINT fk_orders_customer
      FOREIGN KEY (customer_id)
      REFERENCES customers(id)
);

-- customer_id MUST exist in customers.id
-- Can't insert order for nonexistent customer
-- Can't delete customer who has orders (by default)

-- Short inline syntax:
-- customer_id INT REFERENCES customers(id)
```

### FOREIGN KEY Violations
**Explanation:** Here's the foreign key in action. Insert Ravi as customer one — works. Insert an order for customer one — works, the customer exists. Now insert an order for customer ninety-nine — error, that customer doesn't exist. Try to delete Ravi who has orders — error again. The foreign key protects both sides. No orphan orders, no dangling references.

```sql
essilor=#INSERT INTO customers (name) VALUES ('Ravi');
INSERT 0 1
essilor=#INSERT INTO orders (customer_id, product) VALUES (1, 'Laptop');
INSERT 0 1

-- Insert order for nonexistent customer:
essilor=#INSERT INTO orders (customer_id, product) VALUES (99, 'Mouse');
ERROR:  insert or update on table "orders" violates
        foreign key constraint "fk_orders_customer"
DETAIL:  Key (customer_id)=(99) is not present in table "customers".

-- Delete customer who has orders:
essilor=#DELETE FROM customers WHERE id = 1;
ERROR:  update or delete on table "customers" violates
        foreign key constraint "fk_orders_customer"
```

### FOREIGN KEY — ON DELETE and ON UPDATE Actions
**Explanation:** Foreign keys have action options. ON DELETE CASCADE automatically deletes child rows when the parent is deleted — delete a customer, all their orders disappear. ON DELETE SET NULL sets the foreign key to null — the order remains but loses its customer reference. RESTRICT is the default — refuse the delete entirely. NO ACTION is similar but checks at transaction end. ON UPDATE CASCADE updates the foreign key when the parent's primary key changes. Choose based on your business rules.

```sql
-- ON DELETE CASCADE: delete child rows automatically
CREATE TABLE orders_cascade (
    id          SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id)
                ON DELETE CASCADE
);
-- Delete customer → their orders auto-deleted

-- ON DELETE SET NULL: set FK to NULL
CREATE TABLE orders_setnull (
    id          SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id)
                ON DELETE SET NULL
);
-- Delete customer → orders.customer_id = NULL

-- ON DELETE RESTRICT: refuse (same as default)
-- ON DELETE NO ACTION: refuse, but check at txn end

-- ON UPDATE CASCADE: update FK when PK changes
CREATE TABLE orders_update (
    id          SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id)
                ON UPDATE CASCADE
);
-- Update customer.id → orders.customer_id updated too
```

### ON DELETE CASCADE in Action
**Explanation:** Watch CASCADE in action. Priya is customer two. We insert three orders for her. Confirm — three orders exist. Now delete Priya from customers. DELETE one — she's gone. Check her orders — zero. All three orders were automatically deleted because the foreign key has ON DELETE CASCADE. Powerful, but dangerous if you're not careful. Use it when child rows have no meaning without the parent.

```sql
essilor=#INSERT INTO customers (name) VALUES ('Priya');
INSERT 0 1
essilor=#INSERT INTO orders_cascade (customer_id) VALUES (2), (2), (2);
INSERT 0 3
essilor=#SELECT COUNT(*) FROM orders_cascade WHERE customer_id = 2;
 count 
-------
     3

essilor=#DELETE FROM customers WHERE id = 2;
DELETE 1
essilor=#SELECT COUNT(*) FROM orders_cascade WHERE customer_id = 2;
 count 
-------
     0
-- All 3 orders automatically deleted with the customer!
```

### EXCLUDE — Prevent Overlapping Ranges
**Explanation:** EXCLUDE is PostgreSQL's special constraint for preventing overlapping ranges. Perfect for scheduling. We create a room bookings table and say: exclude any row where the room is the same AND the booked time range overlaps. This uses the btree gist extension. The double ampersand means 'overlaps'. So if Room A is booked from nine to ten, nobody else can book Room A during that time.

```sql
-- Enable the btree_gist extension (required)
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Prevent overlapping meeting times in same room
CREATE TABLE room_bookings (
    id        SERIAL PRIMARY KEY,
    room      VARCHAR(50) NOT NULL,
    booked    TSTZRANGE NOT NULL,
    booked_by VARCHAR(100),
    CONSTRAINT no_overlap
      EXCLUDE USING GIST (
        room WITH =,
        booked WITH &&
      )
);
-- room WITH =    → same room
-- booked WITH && → overlapping time range
-- Together: no overlapping bookings in same room

INSERT INTO room_bookings (room, booked, booked_by)
VALUES ('Room A',
  '[2026-11-03 09:00, 2026-11-03 10:00)',
  'Ravi');
```

### EXCLUDE Constraint Violation
**Explanation:** Ravi books Room A from nine to ten — works. Priya tries to book Room A from nine thirty to eleven — error, conflicting key violates exclusion constraint. The times overlap in the same room. But Priya books Room B for the same time — works fine, different room. The EXCLUDE constraint checks both conditions: same room AND overlapping times. This is something no other database does this elegantly.

```sql
essilor=#INSERT INTO room_bookings (room, booked, booked_by)
VALUES ('Room A', '[2026-11-03 09:00, 2026-11-03 10:00)', 'Ravi');
INSERT 0 1

-- Overlapping booking in same room:
essilor=#INSERT INTO room_bookings (room, booked, booked_by)
VALUES ('Room A', '[2026-11-03 09:30, 2026-11-03 11:00)', 'Priya');
ERROR:  conflicting key value violates exclusion
        constraint "no_overlap"

-- Different room at same time → OK!
essilor=#INSERT INTO room_bookings (room, booked, booked_by)
VALUES ('Room B', '[2026-11-03 09:30, 2026-11-03 11:00)', 'Priya');
INSERT 0 1
```

### Adding & Dropping Constraints on Existing Tables
**Explanation:** You can add constraints to existing tables with ALTER TABLE ADD CONSTRAINT. This works for CHECK, UNIQUE, FOREIGN KEY, and EXCLUDE. To remove a constraint, use DROP CONSTRAINT with the constraint name — this is why naming them is important. IF EXISTS prevents errors if the constraint is already gone. To see all constraints on a table, use backslash d.

```sql
-- Add a constraint to an existing table
ALTER TABLE products
  ADD CONSTRAINT ck_products_price
  CHECK (price > 0);

ALTER TABLE products
  ADD CONSTRAINT uq_products_name
  UNIQUE (name);

ALTER TABLE orders
  ADD CONSTRAINT fk_orders_customer
  FOREIGN KEY (customer_id)
  REFERENCES customers(id)
  ON DELETE CASCADE;

-- Drop a constraint by name
ALTER TABLE products
  DROP CONSTRAINT ck_products_price;

-- Drop IF EXISTS
ALTER TABLE products
  DROP CONSTRAINT IF EXISTS ck_products_price;

-- View all constraints on a table:
-- \d products
```


---

## 5. Common Beginner Traps & How to Fix Them

### PRIMARY KEY Violations
Watch the errors. We insert Ravi with id one — works. Then we try Priya with id one again — error, duplicate key. The primary key already has a one. Then we try null for the id — error, violates not null. A primary key automatically enforces both unique and not null. You never need to add those separately on a primary key column.

```sql
INSERT INTO users (id, name) VALUES (1, 'Ravi');
INSERT 0 1
INSERT INTO users (id, name) VALUES (1, 'Priya');
ERROR:  duplicate key value violates unique constraint "pk_users"
DETAIL:  Key (id)=(1) already exists.

INSERT INTO users (id, name) VALUES (NULL, 'Arjun');
ERROR:  null value in column "id" of relation "users"
        violates not-null constraint

-- PK = UNIQUE + NOT NULL. Both enforced automatically.
```

### UNIQUE Constraint Violation
Here it is. First insert with ravi at ex dot com — works. Second insert with the same email — error, duplicate key. The unique constraint caught it. But watch this — we insert null, then null again. Both succeed. UNIQUE allows multiple nulls because in SQL, null is not equal to null. If you want to prevent nulls too, combine UNIQUE with NOT NULL.

```sql
INSERT INTO users (email) VALUES ('ravi@ex.com');
INSERT 0 1
INSERT INTO users (email) VALUES ('ravi@ex.com');
ERROR:  duplicate key value violates unique constraint "uq_users_email"
DETAIL:  Key (email)=(ravi@ex.com) already exists.

-- But NULLs are allowed multiple times:
INSERT INTO users (email) VALUES (NULL);
INSERT 0 1
INSERT INTO users (email) VALUES (NULL);
INSERT 0 1
-- Two NULLs! UNIQUE allows this because NULL != NULL
```

### CHECK Constraint Violations
Watch the errors. Laptop with price nine ninety-nine and quantity five — passes all checks. Free item with price zero — fails. Our check says price must be greater than zero. Widget with quantity negative three — fails. Check says quantity must be zero or above. Notice the error names the exact constraint that failed and shows the failing row. Named constraints make debugging much easier.

```sql
INSERT INTO products (name, price, qty) VALUES ('Laptop', 999.99, 5);
INSERT 0 1
INSERT INTO products (name, price, qty) VALUES ('Free Item', 0, 10);
ERROR:  new row for relation "products" violates
        check constraint "products_price_check"
DETAIL:  Failing row contains (2, Free Item, 0, 10).

INSERT INTO products (name, price, qty) VALUES ('Widget', 9.99, -3);
ERROR:  new row for relation "products" violates
        check constraint "products_qty_check"
DETAIL:  Failing row contains (3, Widget, 9.99, -3).
```

### FOREIGN KEY Violations
Here's the foreign key in action. Insert Ravi as customer one — works. Insert an order for customer one — works, the customer exists. Now insert an order for customer ninety-nine — error, that customer doesn't exist. Try to delete Ravi who has orders — error again. The foreign key protects both sides. No orphan orders, no dangling references.

```sql
INSERT INTO customers (name) VALUES ('Ravi');
INSERT 0 1
INSERT INTO orders (customer_id, product) VALUES (1, 'Laptop');
INSERT 0 1

-- Insert order for nonexistent customer:
INSERT INTO orders (customer_id, product) VALUES (99, 'Mouse');
ERROR:  insert or update on table "orders" violates
        foreign key constraint "fk_orders_customer"
DETAIL:  Key (customer_id)=(99) is not present in table "customers".

-- Delete customer who has orders:
DELETE FROM customers WHERE id = 1;
ERROR:  update or delete on table "customers" violates
        foreign key constraint "fk_orders_customer"
```

### EXCLUDE Constraint Violation
Ravi books Room A from nine to ten — works. Priya tries to book Room A from nine thirty to eleven — error, conflicting key violates exclusion constraint. The times overlap in the same room. But Priya books Room B for the same time — works fine, different room. The EXCLUDE constraint checks both conditions: same room AND overlapping times. This is something no other database does this elegantly.

```sql
INSERT INTO room_bookings (room, booked, booked_by)
VALUES ('Room A', '[2026-11-03 09:00, 2026-11-03 10:00)', 'Ravi');
INSERT 0 1

-- Overlapping booking in same room:
INSERT INTO room_bookings (room, booked, booked_by)
VALUES ('Room A', '[2026-11-03 09:30, 2026-11-03 11:00)', 'Priya');
ERROR:  conflicting key value violates exclusion
        constraint "no_overlap"

-- Different room at same time → OK!
INSERT INTO room_bookings (room, booked, booked_by)
VALUES ('Room B', '[2026-11-03 09:30, 2026-11-03 11:00)', 'Priya');
INSERT 0 1
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time. Create a users table with every constraint type — primary key, not null, unique, and check on age. Create a posts table with a foreign key to users with on delete cascade. Insert valid data, then try to violate each constraint — see every error message. Delete a user and watch their posts cascade away. Add a check constraint to posts ensuring titles aren't empty. And build a room bookings table with an exclude constraint.

1. Create a users table with: PK, name NOT NULL, email UNIQUE NOT NULL, age CHECK (18-120)
2. Create a posts table with: PK, user_id FK to users ON DELETE CASCADE, title NOT NULL, created_at DEFAULT NOW()
3. Insert valid data into both tables — verify it works
4. Try violating each constraint: duplicate PK, duplicate email, null name, age=15, FK to nonexistent user
5. Delete a user and verify their posts are cascade-deleted
6. Add a CHECK constraint to posts: title length > 0
7. Create a room_bookings table with EXCLUDE to prevent overlapping bookings


---

## 7. Key Takeaways & Cheat Sheet

Let's recap. PRIMARY KEY is unique plus not null — every table needs one. UNIQUE prevents duplicates but allows multiple nulls. NOT NULL makes a column required. CHECK enforces custom rules. DEFAULT fills in missing values. FOREIGN KEY enforces relationships with cascade, set null, or restrict options. EXCLUDE prevents overlapping ranges. And always name your constraints with standard prefixes.

- **PRIMARY KEY = UNIQUE + NOT NULL — every table needs one**
- **UNIQUE prevents duplicates but allows multiple NULLs**
- **NOT NULL makes a column required**
- **CHECK enforces custom business rules (price > 0, age BETWEEN 18 AND 120)**
- **DEFAULT fills in values when INSERT doesn't provide them**
- **FOREIGN KEY enforces relationships — ON DELETE CASCADE/SET NULL/RESTRICT**
- **EXCLUDE prevents overlapping ranges (scheduling, resource booking)**
- **Always name constraints: pk_, uq_, ck_, fk_, excl_**


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
