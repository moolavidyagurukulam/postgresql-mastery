-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- uuid-ossp & gen_random_uuid (Class 225)
-- Phase 26: Extensions
-- ============================================================

-- ============================================================
-- 1. BUILT-IN UUID SUPPORT (No Extension Needed)
-- ============================================================

-- The uuid type is built-in:
SELECT '550e8400-e29b-41d4-a716-446655440000'::uuid;

-- gen_random_uuid() — built-in since PG 13:
SELECT gen_random_uuid();

-- Generate multiple:
SELECT gen_random_uuid() FROM generate_series(1, 5);

-- ============================================================
-- 2. INSTALL uuid-ossp
-- ============================================================

-- Name has a hyphen — must be quoted!
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Verify:
-- \dx "uuid-ossp"

-- List functions:
-- \df uuid_*

-- ============================================================
-- 3. UUID VERSIONS
-- ============================================================

-- Version 1: time + MAC address (leaks hardware info):
SELECT uuid_generate_v1();

-- Version 1mc: time + random MAC (no hardware leak):
SELECT uuid_generate_v1mc();

-- Version 3: namespace + name → MD5 (deterministic):
SELECT uuid_generate_v3(uuid_ns_dns(), 'example.com');
-- Same input always = same UUID

-- Version 4: completely random:
SELECT uuid_generate_v4();
-- Same as gen_random_uuid()

-- Version 5: namespace + name → SHA-1 (deterministic, preferred):
SELECT uuid_generate_v5(uuid_ns_dns(), 'example.com');

-- Namespace constants:
SELECT uuid_ns_dns();   -- DNS
SELECT uuid_ns_url();   -- URL
SELECT uuid_ns_oid();   -- OID
SELECT uuid_ns_x500();  -- X.500 DN

-- Nil UUID:
SELECT uuid_nil();
-- 00000000-0000-0000-0000-000000000000

-- ============================================================
-- 4. UUID AS PRIMARY KEY
-- ============================================================

CREATE TABLE users (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    email text UNIQUE NOT NULL,
    name text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Insert without specifying id:
INSERT INTO users (email, name)
VALUES ('alice@example.com', 'Alice')
RETURNING id, name;

INSERT INTO users (email, name)
VALUES ('bob@example.com', 'Bob')
RETURNING id, name;

-- Query by UUID:
-- SELECT * FROM users WHERE id = '<uuid-here>';

-- ============================================================
-- 5. UUID FOREIGN KEYS
-- ============================================================

CREATE TABLE orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id),
    product text NOT NULL,
    amount numeric(10,2) NOT NULL,
    ordered_at timestamptz DEFAULT now()
);

-- Insert (use a real user UUID from the users table):
-- INSERT INTO orders (user_id, product, amount)
-- VALUES ('<user-uuid>', 'PostgreSQL Book', 39.99);

-- Join:
SELECT u.name, o.product, o.amount
FROM users u
JOIN orders o ON o.user_id = u.id;

-- ============================================================
-- 6. DUAL ID PATTERN (Internal + External)
-- ============================================================

CREATE TABLE products (
    id bigserial PRIMARY KEY,
    public_id uuid DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    name text NOT NULL,
    price numeric(10,2)
);

CREATE INDEX idx_products_public ON products (public_id);

INSERT INTO products (name, price)
VALUES ('Widget', 29.99)
RETURNING id, public_id;

-- API uses public_id:
-- SELECT name, price FROM products WHERE public_id = '<uuid>';

-- Internal joins use serial id:
-- SELECT p.name FROM products p JOIN order_items oi ON oi.product_id = p.id;

-- ============================================================
-- 7. INDEX STRATEGIES FOR UUID
-- ============================================================

-- B-tree (automatic for PRIMARY KEY):
-- Good for point lookups and sorting

-- Hash index (equality only, smaller):
CREATE INDEX idx_users_id_hash ON users USING hash (id);

-- Time-range queries: index the timestamp, not UUID:
CREATE INDEX idx_users_created ON users (created_at);

-- ============================================================
-- 8. UUID CASTING & VALIDATION
-- ============================================================

-- Valid:
SELECT 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid;

-- Case insensitive:
SELECT 'A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11'::uuid
     = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid;
-- true

-- Invalid — will error:
-- SELECT 'not-a-uuid'::uuid;
-- ERROR: invalid input syntax for type uuid

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Generate 10 random UUIDs using gen_random_uuid().

-- 2. Install uuid-ossp and generate one UUID of each version
--    (v1, v1mc, v3, v4, v5). Compare their formats.

-- 3. Create a table with a UUID primary key and DEFAULT.
--    Insert 5 rows without specifying the id.

-- 4. Generate two v5 UUIDs with the same namespace and name.
--    Verify they are identical.

-- 5. Create the dual-ID pattern (serial + UUID) and test
--    lookups by both internal id and public_id.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TABLE IF EXISTS orders;
-- DROP TABLE IF EXISTS users;
-- DROP TABLE IF EXISTS products;
-- DROP EXTENSION IF EXISTS "uuid-ossp";
