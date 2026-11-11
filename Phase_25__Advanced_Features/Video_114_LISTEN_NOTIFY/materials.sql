-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- LISTEN & NOTIFY — Real-Time Notifications (Class 220)
-- Phase 25: Advanced Features
-- ============================================================

-- ============================================================
-- 1. BASIC LISTEN AND NOTIFY
-- ============================================================

-- Session 1: Start listening
LISTEN order_updates;

-- Session 2: Send notification
NOTIFY order_updates;

-- Send with payload:
NOTIFY order_updates, 'order_id=42,status=shipped';

-- Using pg_notify function:
SELECT pg_notify('order_updates', 'order 42 shipped');

-- Stop listening:
UNLISTEN order_updates;

-- Stop all:
UNLISTEN *;

-- ============================================================
-- 2. TRIGGER-BASED NOTIFICATIONS
-- ============================================================

CREATE TABLE orders (
    id serial PRIMARY KEY,
    customer text NOT NULL,
    amount numeric(10,2),
    status text DEFAULT 'pending'
);

CREATE OR REPLACE FUNCTION notify_order_change()
RETURNS trigger AS $$
BEGIN
    PERFORM pg_notify('order_events',
        json_build_object(
            'action', TG_OP,
            'order_id', NEW.id,
            'customer', NEW.customer,
            'status', NEW.status,
            'amount', NEW.amount
        )::text
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_notify
    AFTER INSERT OR UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_change();

-- Test: listen in one session, insert in another:
-- Session 1: LISTEN order_events;
-- Session 2: INSERT INTO orders (customer, amount)
--            VALUES ('Alice', 299.99);

-- ============================================================
-- 3. CACHE INVALIDATION PATTERN
-- ============================================================

CREATE OR REPLACE FUNCTION notify_cache_invalidation()
RETURNS trigger AS $$
DECLARE
    record_id int;
BEGIN
    IF TG_OP = 'DELETE' THEN
        record_id := OLD.id;
    ELSE
        record_id := NEW.id;
    END IF;

    PERFORM pg_notify('cache_invalidation',
        json_build_object(
            'table', TG_TABLE_NAME,
            'action', TG_OP,
            'id', record_id
        )::text
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Attach to any table:
-- CREATE TRIGGER trg_products_cache
--     AFTER INSERT OR UPDATE OR DELETE ON products
--     FOR EACH ROW
--     EXECUTE FUNCTION notify_cache_invalidation();

-- ============================================================
-- 4. PYTHON LISTENER (psycopg2)
-- ============================================================

-- Save as: listen_orders.py
-- import select, psycopg2, json
--
-- conn = psycopg2.connect("dbname=mydb user=postgres")
-- conn.set_isolation_level(
--     psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
--
-- cur = conn.cursor()
-- cur.execute("LISTEN order_events;")
-- print("Listening for order events...")
--
-- while True:
--     select.select([conn], [], [], 5)
--     conn.poll()
--     while conn.notifies:
--         notify = conn.notifies.pop(0)
--         payload = json.loads(notify.payload)
--         print(f"Action: {payload['action']}")
--         print(f"Order: #{payload['order_id']}")

-- ============================================================
-- 5. NODE.JS LISTENER (pg)
-- ============================================================

-- const { Client } = require('pg');
-- const client = new Client({
--   connectionString: 'postgresql://postgres@localhost/mydb'
-- });
-- async function main() {
--   await client.connect();
--   await client.query('LISTEN order_events');
--   client.on('notification', (msg) => {
--     const payload = JSON.parse(msg.payload);
--     console.log(`${payload.action}: #${payload.order_id}`);
--   });
-- }
-- main().catch(console.error);

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Open two psql sessions. In session 1: LISTEN test_channel.
--    In session 2: NOTIFY test_channel, 'hello world'.
--    See the notification arrive in session 1.

-- 2. Create the orders table with the notify trigger.
--    Listen in one session, insert/update in another.
--    Watch the JSON notifications arrive.

-- 3. Test the transactional behavior:
--    BEGIN; INSERT INTO orders ...; ROLLBACK;
--    Was a notification sent? (No)

-- 4. (Bonus) Write a Python or Node.js listener script
--    that prints notifications as they arrive.

-- 5. Test with a cache invalidation trigger on products.
--    Listen on 'cache_invalidation' and update a product.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TRIGGER IF EXISTS trg_order_notify ON orders;
-- DROP FUNCTION IF EXISTS notify_order_change();
-- DROP FUNCTION IF EXISTS notify_cache_invalidation();
-- DROP TABLE IF EXISTS orders;
-- UNLISTEN *;
