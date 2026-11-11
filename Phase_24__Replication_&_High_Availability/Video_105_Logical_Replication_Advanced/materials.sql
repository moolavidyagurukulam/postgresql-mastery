-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Logical Replication Advanced — Decoding & CDC (Class 206)
-- Phase 24: Replication & High Availability
-- ============================================================

-- ============================================================
-- 1. test_decoding — BUILT-IN OUTPUT PLUGIN
-- ============================================================

-- Create logical slot with test_decoding:
SELECT pg_create_logical_replication_slot(
    'test_slot', 'test_decoding');

-- Make some changes:
INSERT INTO customers (name, email)
    VALUES ('Eve', 'eve@example.com');
UPDATE customers SET name = 'Eve Smith'
    WHERE email = 'eve@example.com';
DELETE FROM customers
    WHERE email = 'eve@example.com';

-- Read and CONSUME changes:
SELECT lsn, xid, data
FROM pg_logical_slot_get_changes('test_slot', NULL, NULL);

-- Read WITHOUT consuming (for debugging):
SELECT lsn, xid, data
FROM pg_logical_slot_peek_changes('test_slot', NULL, NULL);

-- ============================================================
-- 2. wal2json — JSON OUTPUT PLUGIN
-- ============================================================

-- Install (Debian/Ubuntu):
-- sudo apt install postgresql-16-wal2json

-- Create slot with wal2json:
SELECT pg_create_logical_replication_slot(
    'json_slot', 'wal2json');

-- Make changes and read as JSON:
INSERT INTO orders (customer_id, amount, status)
    VALUES (1, 500.00, 'pending');

SELECT data FROM pg_logical_slot_get_changes(
    'json_slot', NULL, NULL);

-- wal2json options:
SELECT data FROM pg_logical_slot_get_changes(
    'json_slot', NULL, NULL,
    'include-timestamp', 'true',
    'include-lsn', 'true',
    'format-version', '2'
);

-- ============================================================
-- 3. pg_recvlogical — COMMAND-LINE STREAMING
-- ============================================================

-- Stream to stdout (runs continuously):
-- pg_recvlogical \
--     -h localhost \
--     -U replicator \
--     -d mydb \
--     --slot=json_slot \
--     --start \
--     -f -

-- Stream to file:
-- pg_recvlogical -d mydb --slot=json_slot --start \
--     -f /var/log/pg_changes.json

-- Pipe to processor:
-- pg_recvlogical ... -f - | python3 process_changes.py

-- ============================================================
-- 4. DEBEZIUM CONNECTOR CONFIGURATION
-- ============================================================

-- Debezium PostgreSQL connector config (JSON):
-- {
--   "name": "pg-connector",
--   "config": {
--     "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
--     "database.hostname": "10.0.1.1",
--     "database.port": "5432",
--     "database.user": "replicator",
--     "database.password": "SecurePass123!",
--     "database.dbname": "mydb",
--     "topic.prefix": "pg",
--     "plugin.name": "pgoutput",
--     "slot.name": "debezium_slot",
--     "table.include.list": "public.orders,public.customers"
--   }
-- }

-- Deploy to Kafka Connect:
-- curl -X POST http://localhost:8083/connectors \
--   -H "Content-Type: application/json" \
--   -d @debezium-pg-connector.json

-- ============================================================
-- 5. SLOT MANAGEMENT
-- ============================================================

-- List all logical slots:
SELECT
    slot_name,
    plugin,
    active,
    pg_size_pretty(
        pg_wal_lsn_diff(
            pg_current_wal_lsn(),
            confirmed_flush_lsn
        )
    ) AS lag
FROM pg_replication_slots
WHERE slot_type = 'logical';

-- Drop unused slots:
SELECT pg_drop_replication_slot('test_slot');
SELECT pg_drop_replication_slot('json_slot');

-- Safety: limit WAL per slot:
ALTER SYSTEM SET max_slot_wal_keep_size = '10GB';
SELECT pg_reload_conf();

-- ============================================================
-- 6. SIMPLE CDC CONSUMER (Python)
-- ============================================================

-- Save as: cdc_consumer.py
-- #!/usr/bin/env python3
-- import subprocess, json
--
-- proc = subprocess.Popen(
--     ['pg_recvlogical',
--      '-d', 'mydb',
--      '--slot=json_slot',
--      '--start', '-f', '-'],
--     stdout=subprocess.PIPE,
--     text=True
-- )
--
-- for line in proc.stdout:
--     event = json.loads(line)
--     for change in event.get('change', []):
--         print(f"{change['kind'].upper()} on {change['table']}")

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a logical slot with test_decoding.
--    Make INSERT/UPDATE/DELETE changes.
--    Read them with pg_logical_slot_get_changes.

-- 2. Install wal2json. Create a slot with it.
--    Make changes and read the JSON output.

-- 3. Use pg_recvlogical to stream changes to stdout.
--    In another session, make changes and watch them appear.

-- 4. Write a simple Python script that reads from
--    pg_recvlogical and prints each change.

-- 5. Clean up: drop all test slots you created.
--    Verify with pg_replication_slots.
