# Hands-On Projects: Library Management & E-Commerce Database
**Series:** PostgreSQL Mastery | **Phase:** 32 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we build two complete database projects from scratch. First, a Library Management System — tracking books, members, and loans. Second, an E-Commerce Database — products, orders, inventory, and payments. These are real schemas you can adapt for your own applications.


---

## 2. Core Technical Concepts & Mechanisms

### Project 1: Library Management System
Project one: Library Management System. The requirements. Track books with title, author, ISBN, genre, and copies available. Track members with name, email, membership type. Track loans — which member borrowed which book, when, and when it is due. Track fines for overdue returns. Support searching books by title, author, or genre. Generate reports on popular books and overdue loans.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Books** | Title, author(s), ISBN, genre, publish year, total copies, available copies. |
| **Members** | Name, email, phone, membership type (student/regular/premium), join date. |
| **Loans** | Which member borrowed which book, loan date, due date, return date. |
| **Fines** | Overdue fines. Amount per day. Paid status. Linked to loan record. |
| **Key features** | Search by title/author/genre. Check availability. Overdue report. Popular books. |

### Project 2: E-Commerce Database
Project two: E-Commerce Database. The requirements. Customers with addresses and payment methods. Products with categories, pricing, and inventory. Orders with multiple items per order. Payments linked to orders. Product reviews with ratings. Inventory tracking — stock levels, low stock alerts. Support for discounts and promotions.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Customers** | Name, email, password hash, addresses (shipping + billing), created date. |
| **Products** | Name, description, price, category, SKU, stock quantity, images. |
| **Orders** | Customer, items, quantities, total, status (pending/paid/shipped/delivered). |
| **Payments** | Order ID, amount, method (card/wallet/COD), status, transaction ID. |
| **Reviews** | Customer, product, rating (1-5), comment, date. One review per product. |
| **Inventory** | Stock levels, reorder point, low stock alerts. Track changes. |

### Comparison
If these hands-on projects are helping you build real database skills, please support the course. Download the complete SQL files from GitHub to practice on your own machine.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Complete .sql files |
| UPI: Link in description | Library schema + sample data |
| Every donation helps! | E-Commerce schema + queries |

### Database Design Principles
Key design principles used in both projects. Use NUMERIC for money — never FLOAT. Use check constraints to enforce valid values. Use foreign keys to enforce relationships. Use partial indexes for common filtered queries. Use functions and triggers for atomic business logic. Store prices at time of purchase — not just product ID. Use TIMESTAMPTZ — not TIMESTAMP — for all dates involving time. And use SERIAL for simple auto-increment primary keys.

- NUMERIC for money — Never FLOAT. NUMERIC(10,2) stores exact decimal values. No rounding errors.
- CHECK constraints — Enforce valid values at database level. rating BETWEEN 1 AND 5, stock_qty >= 0.
- Foreign keys everywhere — Prevent orphan records. ON DELETE CASCADE or RESTRICT based on business rules.
- Snapshot prices in orders — Store unit_price in order_items. Product price may change after the order.
- TIMESTAMPTZ not TIMESTAMP — Always store time zone. TIMESTAMPTZ DEFAULT now() handles time zones correctly.
- Partial indexes — Index only rows that matter. WHERE active = true, WHERE stock_qty < 10.

### Beginner Traps — Project Design
Common traps in project design. Do not store calculated totals without triggers — they get out of sync. Do not use VARCHAR(255) everywhere — choose meaningful lengths. Do not skip foreign keys for speed — the integrity bugs are worse. Do not store prices as integers in cents unless you have a specific reason — NUMERIC is cleaner. And do not forget to index your foreign key columns — PostgreSQL does NOT auto-index them.

- Calculated totals without triggers — order.total must update when items change. Use trigger or GENERATED column.
- VARCHAR(255) everywhere — Use meaningful limits. email VARCHAR(200), SKU VARCHAR(50). Helps catch bugs.
- Skipping foreign keys — Orphan order_items with no order = data corruption. FK = free integrity check.
- FLOAT for money — 0.1 + 0.2 = 0.30000000000000004 in FLOAT. Use NUMERIC(10,2) always.
- No index on foreign keys — PostgreSQL does NOT auto-index FK columns. JOINs and DELETEs will be slow.

### Practice Exercises
Practice exercises. First, build the complete Library schema — create all tables, constraints, and indexes. Insert sample data — 20 books, 10 members, 30 loans. Write the overdue query. Second, build the E-Commerce schema. Insert sample products and categories. Place test orders using the stock trigger. Verify stock decrements automatically. Third, write a monthly revenue report and a best-selling products query. All SQL is in the downloadable materials.

- Exercise 1 — Create Library schema. Insert 20 books, 10 members, 30 loans. Query overdue loans.
- Exercise 2 — Use borrow_book() function. Try borrowing when no copies available. Verify error.
- Exercise 3 — Create E-Commerce schema. Insert categories, products. Place orders via trigger.
- Exercise 4 — Try ordering more than stock. Verify trigger prevents overselling.
- Exercise 5 — Write monthly revenue report. Best-selling products. Low stock alert query.


---

## 3. Hands-On Commands & psql Output

### Library Schema — Tables
**Explanation:** The schema has four main tables. Authors is separate because one book can have multiple authors — we use a junction table. Books stores the catalog. Members stores people who borrow. Loans connects members to books with dates. And fines links to loans. We use proper constraints — check constraints for membership type, unique on ISBN, foreign keys everywhere.

```sql
CREATE TABLE authors (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    bio TEXT
);

CREATE TABLE books (
    id SERIAL PRIMARY KEY,
    title VARCHAR(300) NOT NULL,
    isbn VARCHAR(13) UNIQUE,
    genre VARCHAR(50),
    publish_year INT,
    total_copies INT DEFAULT 1,
    available_copies INT DEFAULT 1,
    CHECK (available_copies >= 0),
    CHECK (available_copies <= total_copies)
);

CREATE TABLE book_authors (
    book_id INT REFERENCES books(id),
    author_id INT REFERENCES authors(id),
    PRIMARY KEY (book_id, author_id)
);
```

### Library Schema — Members, Loans, Fines
**Explanation:** Members has a check constraint on membership_type — only student, regular, or premium allowed. The loans table has foreign keys to both members and books. We add a check constraint — return_date must be after loan_date. The fines table links to loans with a computed amount. We use DEFAULT now for timestamps so the application does not need to supply them.

```sql
CREATE TABLE members (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    email VARCHAR(200) UNIQUE NOT NULL,
    phone VARCHAR(20),
    membership_type VARCHAR(20) DEFAULT 'regular'
        CHECK (membership_type IN
        ('student', 'regular', 'premium')),
    join_date DATE DEFAULT CURRENT_DATE,
    active BOOLEAN DEFAULT true
);

CREATE TABLE loans (
    id SERIAL PRIMARY KEY,
    book_id INT NOT NULL REFERENCES books(id),
    member_id INT NOT NULL REFERENCES members(id),
    loan_date DATE DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    return_date DATE,
    CHECK (return_date IS NULL
           OR return_date >= loan_date)
);

CREATE TABLE fines (
    id SERIAL PRIMARY KEY,
    loan_id INT NOT NULL REFERENCES loans(id),
    amount NUMERIC(8,2) NOT NULL,
    paid BOOLEAN DEFAULT false,
    paid_date DATE
);
```

### Library — Key Queries
**Explanation:** Here are the essential queries. Search books by title or author using ILIKE for case-insensitive matching. Check book availability. Find overdue loans — where return_date is null and due_date is past. Calculate fines at 1 dollar per day overdue. And the most popular books — books with the most loans. These queries use JOINs, aggregation, and date arithmetic.

```sql
-- Search books by title or author
SELECT b.title, a.name AS author,
  b.available_copies
FROM books b
JOIN book_authors ba ON b.id = ba.book_id
JOIN authors a ON ba.author_id = a.id
WHERE b.title ILIKE '%postgres%'
   OR a.name ILIKE '%postgres%';

-- Find overdue loans
SELECT m.name, b.title,
  l.due_date,
  CURRENT_DATE - l.due_date AS days_overdue
FROM loans l
JOIN members m ON l.member_id = m.id
JOIN books b ON l.book_id = b.id
WHERE l.return_date IS NULL
  AND l.due_date < CURRENT_DATE
ORDER BY days_overdue DESC;

-- Most popular books (most loans)
SELECT b.title, count(*) AS total_loans
FROM loans l JOIN books b ON l.book_id = b.id
GROUP BY b.title
ORDER BY total_loans DESC LIMIT 10;
```

### Library — Indexes & Borrow Function
**Explanation:** For performance, add indexes on the columns we search and filter by. A GIN trigram index on book title enables fast ILIKE searches. Indexes on loans for overdue queries. And a function to borrow a book — it checks availability, decrements available copies, and creates the loan record in a single transaction. This prevents race conditions where two people borrow the last copy.

```sql
-- Indexes for performance
CREATE INDEX idx_books_genre
  ON books(genre);
CREATE INDEX idx_loans_member
  ON loans(member_id);
CREATE INDEX idx_loans_overdue
  ON loans(due_date)
  WHERE return_date IS NULL;

-- Function to borrow a book (atomic)
CREATE OR REPLACE FUNCTION borrow_book(
  p_book_id INT, p_member_id INT,
  p_days INT DEFAULT 14
) RETURNS INT AS $$
DECLARE v_loan_id INT;
BEGIN
  UPDATE books
  SET available_copies = available_copies - 1
  WHERE id = p_book_id
    AND available_copies > 0;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Book not available';
  END IF;
  INSERT INTO loans
    (book_id, member_id, due_date)
  VALUES
    (p_book_id, p_member_id,
     CURRENT_DATE + p_days)
  RETURNING id INTO v_loan_id;
  RETURN v_loan_id;
END; $$ LANGUAGE plpgsql;
```

### E-Commerce — Core Tables
**Explanation:** The core schema starts with customers and categories. Categories use a self-referencing foreign key for subcategories — Electronics has Phones and Laptops as children. Products reference categories. We use NUMERIC for prices — never use FLOAT for money. The SKU is unique. Stock quantity has a check constraint to prevent negative values.

```sql
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    email VARCHAR(200) UNIQUE NOT NULL,
    password_hash VARCHAR(200) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    parent_id INT REFERENCES categories(id),
    UNIQUE(name, parent_id)
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(300) NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL
        CHECK (price > 0),
    category_id INT REFERENCES categories(id),
    sku VARCHAR(50) UNIQUE NOT NULL,
    stock_qty INT DEFAULT 0
        CHECK (stock_qty >= 0),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

### E-Commerce — Orders & Items
**Explanation:** Orders use a two-table pattern — orders for the header and order_items for the line items. This is a classic one-to-many relationship. The order has a status that progresses through pending, paid, shipped, delivered, or cancelled. Each order_item captures the price at the time of purchase — because product prices change. The subtotal is computed as quantity times unit_price.

```sql
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL
        REFERENCES customers(id),
    status VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid',
        'shipped', 'delivered', 'cancelled')),
    total NUMERIC(12,2),
    shipping_address TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL
        REFERENCES orders(id),
    product_id INT NOT NULL
        REFERENCES products(id),
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL,
    subtotal NUMERIC(12,2) GENERATED ALWAYS
        AS (quantity * unit_price) STORED
);

CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id),
    amount NUMERIC(12,2) NOT NULL,
    method VARCHAR(20) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    transaction_id VARCHAR(100),
    paid_at TIMESTAMPTZ
);
```

### E-Commerce — Reviews & Inventory
**Explanation:** Reviews have a unique constraint — one review per customer per product. Rating is constrained between 1 and 5. For inventory tracking, we create an inventory_log table that records every stock change — purchases, sales, returns, adjustments. This gives us a complete audit trail. A trigger automatically updates the product stock quantity whenever an order is placed.

```sql
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL
        REFERENCES customers(id),
    product_id INT NOT NULL
        REFERENCES products(id),
    rating INT NOT NULL
        CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(customer_id, product_id)
);

CREATE TABLE inventory_log (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL
        REFERENCES products(id),
    change_qty INT NOT NULL,
    reason VARCHAR(50) NOT NULL
        CHECK (reason IN ('purchase',
        'sale', 'return', 'adjustment')),
    reference_id INT,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

### E-Commerce — Auto Stock Deduction
**Explanation:** This trigger fires after an order item is inserted. It decreases the product stock by the ordered quantity. If stock would go below zero, it raises an exception — preventing overselling. It also logs the change in inventory_log for audit. This is atomic — if the stock check fails, the entire order item insert is rolled back. No overselling, no inconsistency.

```sql
CREATE OR REPLACE FUNCTION deduct_stock()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE products
  SET stock_qty = stock_qty - NEW.quantity
  WHERE id = NEW.product_id
    AND stock_qty >= NEW.quantity;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Insufficient stock for product %',
      NEW.product_id;
  END IF;

  INSERT INTO inventory_log
    (product_id, change_qty, reason,
     reference_id)
  VALUES
    (NEW.product_id, -NEW.quantity,
     'sale', NEW.order_id);

  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_deduct_stock
  AFTER INSERT ON order_items
  FOR EACH ROW
  EXECUTE FUNCTION deduct_stock();
```

### E-Commerce — Key Queries
**Explanation:** Essential e-commerce queries. Customer order history with item details. Product search with average rating and review count. Low stock alert — products below their reorder point. Revenue report by month using date_trunc. And best-selling products using a window function for ranking. These cover reporting, search, and inventory management.

```sql
-- Customer order history
SELECT o.id, o.status, o.total,
  o.created_at, count(oi.id) AS items
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
WHERE o.customer_id = 42
GROUP BY o.id ORDER BY o.created_at DESC;

-- Product search with avg rating
SELECT p.name, p.price, p.stock_qty,
  round(avg(r.rating), 1) AS avg_rating,
  count(r.id) AS review_count
FROM products p
LEFT JOIN reviews r ON p.id = r.product_id
WHERE p.active = true
GROUP BY p.id ORDER BY avg_rating DESC;

-- Monthly revenue report
SELECT date_trunc('month', o.created_at)
    AS month,
  count(DISTINCT o.id) AS orders,
  sum(o.total) AS revenue
FROM orders o
WHERE o.status != 'cancelled'
GROUP BY month ORDER BY month DESC;
```

### E-Commerce — Performance Indexes
**Explanation:** Performance indexes for the e-commerce schema. Index on products for category browsing and active filtering. Index on orders for customer lookup and date range queries. Partial index on stock quantity for low-stock alerts — only indexes rows where stock is low. And a GIN index on product name for full-text search. These indexes cover the most common query patterns.

```sql
-- Product browsing by category
CREATE INDEX idx_products_category
  ON products(category_id)
  WHERE active = true;

-- Customer order history
CREATE INDEX idx_orders_customer
  ON orders(customer_id, created_at DESC);

-- Low stock alert (partial index)
CREATE INDEX idx_products_low_stock
  ON products(stock_qty)
  WHERE stock_qty < 10 AND active = true;

-- Product search (full-text)
CREATE INDEX idx_products_search
  ON products USING GIN(
    to_tsvector('english', name || ' '
    || coalesce(description, '')));

-- Order items for order total calc
CREATE INDEX idx_order_items_order
  ON order_items(order_id);

-- Reviews per product
CREATE INDEX idx_reviews_product
  ON reviews(product_id);
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — Project Design
Common traps in project design. Do not store calculated totals without triggers — they get out of sync. Do not use VARCHAR(255) everywhere — choose meaningful lengths. Do not skip foreign keys for speed — the integrity bugs are worse. Do not store prices as integers in cents unless you have a specific reason — NUMERIC is cleaner. And do not forget to index your foreign key columns — PostgreSQL does NOT auto-index them.

- Calculated totals without triggers — order.total must update when items change. Use trigger or GENERATED column.
- VARCHAR(255) everywhere — Use meaningful limits. email VARCHAR(200), SKU VARCHAR(50). Helps catch bugs.
- Skipping foreign keys — Orphan order_items with no order = data corruption. FK = free integrity check.
- FLOAT for money — 0.1 + 0.2 = 0.30000000000000004 in FLOAT. Use NUMERIC(10,2) always.
- No index on foreign keys — PostgreSQL does NOT auto-index FK columns. JOINs and DELETEs will be slow.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Summary. We built two complete database projects. The Library system uses books, members, loans, and fines with an atomic borrow function that prevents double-booking. The E-Commerce system uses customers, products, orders, and payments with a stock deduction trigger that prevents overselling. Both use proper constraints, foreign keys, indexes, and NUMERIC for money. Download the complete SQL files from GitHub and build these on your own PostgreSQL server.

- **Library: books, authors, members, loans, fines — complete schema**
- **Atomic borrow_book() function prevents double-borrowing**
- **E-Commerce: customers, products, orders, payments, reviews**
- **Stock deduction trigger prevents overselling automatically**
- **NUMERIC(10,2) for all money columns — never FLOAT**
- **CHECK constraints enforce valid data at the database level**
- **Partial indexes for common filtered queries (active, low stock)**
- **TIMESTAMPTZ for all timestamps — always store time zone**


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
