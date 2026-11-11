-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Logical Replication Setup (Classes 204-205)
-- Phase 24: Replication & High Availability
-- ============================================================

-- ============================================================
-- 1. PUBLISHER SETUP
-- ============================================================

-- Set wal_level to logical (requires restart):
ALTER SYSTEM SET wal_level = 'logical';
-- sudo systemctl restart postgresql

SHOW wal_level;
-- Must show: logical

-- ============================================================
-- 2. CREATE SAMPLE TABLES (Publisher)
-- ============================================================

CREATE TABLE customers (
    id serial PRIMARY KEY,
    name text NOT NULL,
    email text UNIQUE,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE orders (
    id serial PRIMARY KEY,
    customer_id int REFERENCES customers(id),
    amount numeric(10,2),
    status text DEFAULT 'pending',
    ordered_at timestamptz DEFAULT now()
);

INSERT INTO customers (name, email) VALUES
    ('Alice', 'alice@example.com'),
    ('Bob', 'bob@example.com'),
    ('Charlie', 'charlie@example.com');

INSERT INTO orders (customer_id, amount, status) VALUES
    (1, 99.99, 'shipped'),
    (2, 149.50, 'pending'),
    (3, 250.00, 'pending');

-- ============================================================
-- 3. CREATE PUBLICATION (Publisher)
-- ============================================================

-- Publish specific tables:
CREATE PUBLICATION my_pub
    FOR TABLE customers, orders;

-- Or publish all tables:
-- CREATE PUBLICATION all_pub FOR ALL TABLES;

-- Verify:
SELECT * FROM pg_publication;
SELECT * FROM pg_publication_tables;

-- ============================================================
-- 4. GRANT PERMISSIONS (Publisher)
-- ============================================================

-- Replicator needs SELECT on published tables:
GRANT SELECT ON customers, orders TO replicator;

-- pg_hba.conf on publisher:
-- host  mydb  replicator  10.0.2.10/32  scram-sha-256
-- (Use database name, NOT 'replication' keyword)

-- ============================================================
-- 5. CREATE MATCHING TABLES (Subscriber)
-- ============================================================

-- Run on SUBSCRIBER — same structure as publisher:
CREATE TABLE customers (
    id serial PRIMARY KEY,
    name text NOT NULL,
    email text UNIQUE,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE orders (
    id serial PRIMARY KEY,
    customer_id int REFERENCES customers(id),
    amount numeric(10,2),
    status text DEFAULT 'pending',
    ordered_at timestamptz DEFAULT now()
);

-- ============================================================
-- 6. CREATE SUBSCRIPTION (Subscriber)
-- ============================================================

CREATE SUBSCRIPTION my_sub
    CONNECTION 'host=10.0.1.1 port=5432
      dbname=mydb user=replicator password=SecurePass123!'
    PUBLICATION my_pub;

-- This:
-- 1. Creates logical replication slot 'my_sub' on publisher
-- 2. Copies all existing data (initial table sync)
-- 3. Starts streaming new changes

-- ============================================================
-- 7. VERIFY REPLICATION
-- ============================================================

-- On SUBSCRIBER — check data arrived:
SELECT * FROM customers;
SELECT * FROM orders;

-- Check subscription status:
SELECT subname, received_lsn, latest_end_lsn
FROM pg_stat_subscription;

-- Check per-table sync status:
SELECT srsubid, srrelid::regclass, srsubstate
FROM pg_subscription_rel;
-- srsubstate: i=init, d=data copy, s=synced, r=ready

-- On PUBLISHER — check replication slot:
SELECT slot_name, slot_type, active
FROM pg_replication_slots
WHERE slot_type = 'logical';

-- ============================================================
-- 8. TEST REAL-TIME REPLICATION
-- ============================================================

-- ON PUBLISHER:
INSERT INTO customers (name, email)
    VALUES ('Diana', 'diana@example.com');

UPDATE orders SET status = 'delivered' WHERE id = 1;

DELETE FROM orders WHERE id = 2;

-- ON SUBSCRIBER — verify all changes arrived:
SELECT * FROM customers;
SELECT * FROM orders;

-- ============================================================
-- 9. REPLICA IDENTITY
-- ============================================================

-- Check current replica identity:
SELECT relname, relreplident
FROM pg_class
WHERE relname IN ('customers', 'orders');
-- d = default (primary key)

-- For tables without primary key:
-- ALTER TABLE logs REPLICA IDENTITY FULL;
-- (compares all columns for UPDATE/DELETE)

-- Using a unique index:
-- ALTER TABLE logs REPLICA IDENTITY USING INDEX logs_ts_idx;

-- ============================================================
-- 10. ROW FILTERS AND COLUMN LISTS (PG 15+)
-- ============================================================

-- Row filter:
CREATE PUBLICATION filtered_pub
    FOR TABLE orders WHERE (status = 'shipped');

-- Column list:
CREATE PUBLICATION partial_pub
    FOR TABLE customers (id, name);

-- Combined:
CREATE PUBLICATION combo_pub
    FOR TABLE
        customers (id, name, email),
        orders WHERE (amount > 100);

-- ============================================================
-- 11. MANAGE PUBLICATIONS & SUBSCRIPTIONS
-- ============================================================

-- Add/remove tables from publication:
ALTER PUBLICATION my_pub ADD TABLE logs;
ALTER PUBLICATION my_pub DROP TABLE logs;

-- After publication change, refresh on subscriber:
ALTER SUBSCRIPTION my_sub REFRESH PUBLICATION;

-- Pause replication:
ALTER SUBSCRIPTION my_sub DISABLE;

-- Resume:
ALTER SUBSCRIPTION my_sub ENABLE;

-- Drop subscription (also drops slot on publisher):
-- DROP SUBSCRIPTION my_sub;

-- Drop publication:
-- DROP PUBLICATION my_pub;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Set wal_level = logical on your server. Restart.
--    Verify with SHOW wal_level.

-- 2. Create two tables with primary keys.
--    Create a publication for those tables.

-- 3. On a second database (or server), create matching tables.
--    Create a subscription. Verify initial data sync.

-- 4. INSERT, UPDATE, DELETE on publisher.
--    Verify each operation appears on subscriber.

-- 5. Create a table without a primary key.
--    Try to replicate an UPDATE — observe the error.
--    Fix with ALTER TABLE ... REPLICA IDENTITY FULL.
