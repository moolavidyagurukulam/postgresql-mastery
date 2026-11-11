-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Projects: Library Management & E-Commerce Database (Classes 282-283)
-- Phase 32: Capstone Projects
-- ============================================================

-- ============================================================
-- PROJECT 1: LIBRARY MANAGEMENT SYSTEM
-- ============================================================

-- ============================================================
-- 1. SCHEMA — Create all tables
-- ============================================================

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
    book_id INT REFERENCES books(id) ON DELETE CASCADE,
    author_id INT REFERENCES authors(id) ON DELETE CASCADE,
    PRIMARY KEY (book_id, author_id)
);

CREATE TABLE members (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    email VARCHAR(200) UNIQUE NOT NULL,
    phone VARCHAR(20),
    membership_type VARCHAR(20) DEFAULT 'regular'
        CHECK (membership_type IN ('student', 'regular', 'premium')),
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
    CHECK (return_date IS NULL OR return_date >= loan_date)
);

CREATE TABLE fines (
    id SERIAL PRIMARY KEY,
    loan_id INT NOT NULL REFERENCES loans(id),
    amount NUMERIC(8,2) NOT NULL CHECK (amount > 0),
    paid BOOLEAN DEFAULT false,
    paid_date DATE
);

-- ============================================================
-- 2. INDEXES
-- ============================================================

CREATE INDEX idx_books_genre ON books(genre);
CREATE INDEX idx_books_title ON books(title);
CREATE INDEX idx_loans_member ON loans(member_id);
CREATE INDEX idx_loans_book ON loans(book_id);
CREATE INDEX idx_loans_overdue ON loans(due_date) WHERE return_date IS NULL;
CREATE INDEX idx_fines_unpaid ON fines(loan_id) WHERE paid = false;

-- ============================================================
-- 3. FUNCTIONS
-- ============================================================

-- Borrow a book (atomic operation)
CREATE OR REPLACE FUNCTION borrow_book(
    p_book_id INT,
    p_member_id INT,
    p_days INT DEFAULT 14
) RETURNS INT AS $$
DECLARE
    v_loan_id INT;
BEGIN
    -- Decrement available copies (fails if 0)
    UPDATE books
    SET available_copies = available_copies - 1
    WHERE id = p_book_id AND available_copies > 0;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book % is not available', p_book_id;
    END IF;

    -- Create loan record
    INSERT INTO loans (book_id, member_id, due_date)
    VALUES (p_book_id, p_member_id, CURRENT_DATE + p_days)
    RETURNING id INTO v_loan_id;

    RETURN v_loan_id;
END;
$$ LANGUAGE plpgsql;

-- Return a book
CREATE OR REPLACE FUNCTION return_book(
    p_loan_id INT
) RETURNS VOID AS $$
DECLARE
    v_book_id INT;
    v_due_date DATE;
    v_days_overdue INT;
BEGIN
    -- Get loan details
    SELECT book_id, due_date INTO v_book_id, v_due_date
    FROM loans WHERE id = p_loan_id AND return_date IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan % not found or already returned', p_loan_id;
    END IF;

    -- Mark as returned
    UPDATE loans SET return_date = CURRENT_DATE WHERE id = p_loan_id;

    -- Increment available copies
    UPDATE books SET available_copies = available_copies + 1
    WHERE id = v_book_id;

    -- Create fine if overdue ($1/day)
    v_days_overdue := CURRENT_DATE - v_due_date;
    IF v_days_overdue > 0 THEN
        INSERT INTO fines (loan_id, amount)
        VALUES (p_loan_id, v_days_overdue * 1.00);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 4. SAMPLE DATA
-- ============================================================

INSERT INTO authors (name, bio) VALUES
    ('Robert C. Martin', 'Author of Clean Code'),
    ('Martin Kleppmann', 'Author of DDIA'),
    ('Alex Xu', 'Author of System Design Interview'),
    ('Donald Knuth', 'Author of The Art of Computer Programming'),
    ('Andrew Hunt', 'Author of The Pragmatic Programmer');

INSERT INTO books (title, isbn, genre, publish_year, total_copies, available_copies) VALUES
    ('Clean Code', '9780132350884', 'Programming', 2008, 5, 5),
    ('Designing Data-Intensive Applications', '9781449373320', 'Databases', 2017, 3, 3),
    ('System Design Interview', '9798664653403', 'Interviews', 2020, 4, 4),
    ('The Art of Computer Programming', '9780201896831', 'Algorithms', 1968, 2, 2),
    ('The Pragmatic Programmer', '9780135957059', 'Programming', 2019, 3, 3);

INSERT INTO book_authors (book_id, author_id) VALUES
    (1, 1), (2, 2), (3, 3), (4, 4), (5, 5);

INSERT INTO members (name, email, phone, membership_type) VALUES
    ('Alice Johnson', 'alice@example.com', '555-0101', 'premium'),
    ('Bob Smith', 'bob@example.com', '555-0102', 'regular'),
    ('Carol Davis', 'carol@example.com', '555-0103', 'student'),
    ('Dave Wilson', 'dave@example.com', '555-0104', 'regular'),
    ('Eve Brown', 'eve@example.com', '555-0105', 'student');

-- Borrow some books:
SELECT borrow_book(1, 1, 14);  -- Alice borrows Clean Code
SELECT borrow_book(2, 2, 14);  -- Bob borrows DDIA
SELECT borrow_book(3, 3, 7);   -- Carol borrows System Design (7 days)
SELECT borrow_book(1, 4, 14);  -- Dave borrows Clean Code

-- ============================================================
-- 5. KEY QUERIES
-- ============================================================

-- Search books by title or author:
SELECT b.title, a.name AS author, b.available_copies
FROM books b
JOIN book_authors ba ON b.id = ba.book_id
JOIN authors a ON ba.author_id = a.id
WHERE b.title ILIKE '%design%' OR a.name ILIKE '%martin%';

-- Check book availability:
SELECT title, total_copies, available_copies,
    total_copies - available_copies AS currently_loaned
FROM books ORDER BY available_copies;

-- Overdue loans:
SELECT m.name AS member, b.title AS book,
    l.due_date, CURRENT_DATE - l.due_date AS days_overdue
FROM loans l
JOIN members m ON l.member_id = m.id
JOIN books b ON l.book_id = b.id
WHERE l.return_date IS NULL
    AND l.due_date < CURRENT_DATE
ORDER BY days_overdue DESC;

-- Most popular books:
SELECT b.title, count(*) AS total_loans
FROM loans l JOIN books b ON l.book_id = b.id
GROUP BY b.title ORDER BY total_loans DESC LIMIT 10;

-- Members with unpaid fines:
SELECT m.name, sum(f.amount) AS total_fines
FROM fines f
JOIN loans l ON f.loan_id = l.id
JOIN members m ON l.member_id = m.id
WHERE f.paid = false
GROUP BY m.name ORDER BY total_fines DESC;

-- ============================================================
-- PROJECT 2: E-COMMERCE DATABASE
-- ============================================================

-- ============================================================
-- 1. SCHEMA — Create all tables
-- ============================================================

CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    email VARCHAR(200) UNIQUE NOT NULL,
    password_hash VARCHAR(200) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE customer_addresses (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    label VARCHAR(50) DEFAULT 'home',
    street VARCHAR(300) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(100) DEFAULT 'India',
    is_default BOOLEAN DEFAULT false
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
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    category_id INT REFERENCES categories(id),
    sku VARCHAR(50) UNIQUE NOT NULL,
    stock_qty INT DEFAULT 0 CHECK (stock_qty >= 0),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    status VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')),
    total NUMERIC(12,2),
    shipping_address TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(id),
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL,
    subtotal NUMERIC(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    method VARCHAR(20) NOT NULL
        CHECK (method IN ('card', 'upi', 'wallet', 'cod', 'bank_transfer')),
    status VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    transaction_id VARCHAR(100),
    paid_at TIMESTAMPTZ
);

CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    product_id INT NOT NULL REFERENCES products(id),
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(customer_id, product_id)
);

CREATE TABLE inventory_log (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(id),
    change_qty INT NOT NULL,
    reason VARCHAR(50) NOT NULL
        CHECK (reason IN ('purchase', 'sale', 'return', 'adjustment')),
    reference_id INT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 2. INDEXES
-- ============================================================

CREATE INDEX idx_products_category ON products(category_id) WHERE active = true;
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_low_stock ON products(stock_qty)
    WHERE stock_qty < 10 AND active = true;
CREATE INDEX idx_orders_customer ON orders(customer_id, created_at DESC);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_reviews_product ON reviews(product_id);
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_customer_addresses ON customer_addresses(customer_id);
CREATE INDEX idx_inventory_log_product ON inventory_log(product_id, created_at DESC);

-- Full-text search on products:
CREATE INDEX idx_products_search ON products USING GIN(
    to_tsvector('english', name || ' ' || coalesce(description, ''))
);

-- ============================================================
-- 3. TRIGGERS
-- ============================================================

-- Auto deduct stock when order item is added:
CREATE OR REPLACE FUNCTION deduct_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE products
    SET stock_qty = stock_qty - NEW.quantity
    WHERE id = NEW.product_id
        AND stock_qty >= NEW.quantity;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient stock for product %', NEW.product_id;
    END IF;

    INSERT INTO inventory_log (product_id, change_qty, reason, reference_id)
    VALUES (NEW.product_id, -NEW.quantity, 'sale', NEW.order_id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_deduct_stock
    AFTER INSERT ON order_items
    FOR EACH ROW EXECUTE FUNCTION deduct_stock();

-- Auto update order.updated_at:
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_orders_updated
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================================
-- 4. SAMPLE DATA
-- ============================================================

INSERT INTO customers (name, email, password_hash) VALUES
    ('Rahul Sharma', 'rahul@example.com', 'hashed_pw_1'),
    ('Priya Patel', 'priya@example.com', 'hashed_pw_2'),
    ('Amit Kumar', 'amit@example.com', 'hashed_pw_3');

INSERT INTO categories (name, parent_id) VALUES
    ('Electronics', NULL),
    ('Books', NULL),
    ('Clothing', NULL);
INSERT INTO categories (name, parent_id) VALUES
    ('Phones', 1),
    ('Laptops', 1),
    ('Programming', 2);

INSERT INTO products (name, description, price, category_id, sku, stock_qty) VALUES
    ('PostgreSQL 16 Administration', 'Complete guide to PG 16 admin', 599.00, 6, 'BOOK-PG16', 50),
    ('USB-C Hub', '7-in-1 USB-C dock', 1299.00, 1, 'ELEC-USBC7', 100),
    ('Mechanical Keyboard', 'Cherry MX Blue switches', 3499.00, 1, 'ELEC-KB-MX', 25),
    ('Cotton T-Shirt', '100% cotton, round neck', 499.00, 3, 'CLO-TS-001', 200),
    ('Laptop Stand', 'Adjustable aluminum stand', 1899.00, 5, 'ELEC-LS-01', 40);

-- Place a test order:
INSERT INTO orders (customer_id, status, shipping_address)
VALUES (1, 'pending', '123 MG Road, Bangalore 560001');

-- This triggers stock deduction automatically:
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES
    (1, 1, 2, 599.00),   -- 2x PG16 book
    (1, 2, 1, 1299.00);  -- 1x USB-C Hub

-- Update order total:
UPDATE orders SET total = (
    SELECT sum(subtotal) FROM order_items WHERE order_id = 1
) WHERE id = 1;

-- ============================================================
-- 5. KEY QUERIES
-- ============================================================

-- Customer order history:
SELECT o.id, o.status, o.total, o.created_at,
    count(oi.id) AS items
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
WHERE o.customer_id = 1
GROUP BY o.id ORDER BY o.created_at DESC;

-- Product search with rating:
SELECT p.name, p.price, p.stock_qty,
    round(avg(r.rating), 1) AS avg_rating,
    count(r.id) AS reviews
FROM products p
LEFT JOIN reviews r ON p.id = r.product_id
WHERE p.active = true
GROUP BY p.id ORDER BY avg_rating DESC NULLS LAST;

-- Low stock alert:
SELECT name, sku, stock_qty
FROM products
WHERE stock_qty < 10 AND active = true
ORDER BY stock_qty;

-- Monthly revenue:
SELECT date_trunc('month', o.created_at) AS month,
    count(DISTINCT o.id) AS orders,
    sum(o.total) AS revenue
FROM orders o
WHERE o.status != 'cancelled'
GROUP BY month ORDER BY month DESC;

-- Best sellers:
SELECT p.name,
    sum(oi.quantity) AS units_sold,
    sum(oi.subtotal) AS revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.id
GROUP BY p.id ORDER BY units_sold DESC LIMIT 10;

-- Inventory audit trail:
SELECT p.name, il.change_qty, il.reason,
    il.created_at
FROM inventory_log il
JOIN products p ON il.product_id = p.id
ORDER BY il.created_at DESC LIMIT 20;

-- Full-text product search:
SELECT name, price, stock_qty
FROM products
WHERE to_tsvector('english', name || ' ' || coalesce(description, ''))
    @@ to_tsquery('english', 'postgresql & guide')
ORDER BY ts_rank(
    to_tsvector('english', name || ' ' || coalesce(description, '')),
    to_tsquery('english', 'postgresql & guide')
) DESC;

-- ============================================================
-- CLEANUP
-- ============================================================

-- DROP TABLE IF EXISTS fines, loans, book_authors, members, books, authors CASCADE;
-- DROP TABLE IF EXISTS inventory_log, reviews, payments, order_items, orders,
--   customer_addresses, products, categories, customers CASCADE;
