-- =============================================
-- PostgreSQL Mastery: Data Types Part 4 — Special Types & Casting
-- Phase 2: Database Objects | Classes 18-19
-- =============================================
-- UUID, BYTEA, INET, CIDR, MACADDR, Type Casting
-- =============================================

-- === UUID ===

-- 128-bit universally unique identifier
-- gen_random_uuid() available in PG 13+ (no extension needed)

SELECT gen_random_uuid();

-- UUID as primary key
CREATE TABLE api_keys (
    id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name       VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO api_keys (name) VALUES ('Production Key');
INSERT INTO api_keys (name) VALUES ('Staging Key');
INSERT INTO api_keys (name) VALUES ('Development Key');
SELECT * FROM api_keys;

-- UUID vs SERIAL:
-- SERIAL: sequential, predictable, 4 bytes, faster joins
-- UUID: random, unpredictable, 16 bytes, safe for APIs/URLs

-- === BYTEA (Binary Data) ===

-- For small binary: hashes, encrypted tokens, small files
-- NOT for large files — store those in filesystem

CREATE TABLE file_hashes (
    id       SERIAL PRIMARY KEY,
    filename VARCHAR(255),
    hash     BYTEA
);

INSERT INTO file_hashes (filename, hash)
VALUES ('report.pdf', '\xd41d8cd98f00b204e9800998ecf8427e');

-- With pgcrypto extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SELECT digest('hello world', 'sha256');
SELECT encode(digest('hello world', 'sha256'), 'hex');

-- === INET & CIDR (Network Addresses) ===

-- INET: IP address + optional subnet mask (IPv4 or IPv6)
-- CIDR: network address (host bits must be zero)
-- MACADDR: MAC address

CREATE TABLE access_log (
    id         SERIAL PRIMARY KEY,
    ip         INET,
    network    CIDR,
    visited_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO access_log (ip, network) VALUES ('192.168.1.100', '192.168.1.0/24');
INSERT INTO access_log (ip, network) VALUES ('10.0.0.50', '10.0.0.0/8');
INSERT INTO access_log (ip, network) VALUES ('172.16.5.20', '172.16.0.0/12');

-- Check if IP is in a subnet
SELECT ip FROM access_log WHERE ip << '192.168.0.0/16';
-- << means "is contained within"

-- INET functions
SELECT host('192.168.1.100/24'::INET) AS host_part;
SELECT masklen('192.168.1.100/24'::INET) AS mask_bits;
SELECT network('192.168.1.100/24'::INET) AS network_addr;
SELECT broadcast('192.168.1.0/24'::INET) AS broadcast_addr;

-- === MACADDR ===

CREATE TABLE devices (
    id  SERIAL PRIMARY KEY,
    mac MACADDR,
    name VARCHAR(100)
);
INSERT INTO devices (mac, name) VALUES ('08:00:2b:01:02:03', 'Server NIC');

-- === TYPE CASTING ===

-- Two syntaxes (same result):
-- 1. :: (PostgreSQL shorthand, most common)
-- 2. CAST(value AS type) (SQL standard)

SELECT 42::TEXT;              -- integer → text
SELECT CAST(42 AS TEXT);      -- same thing

-- Common casts:
SELECT '100'::INTEGER + 50;          -- text → integer
SELECT 10::NUMERIC / 3;              -- integer → numeric (precise division)
SELECT '2026-12-25'::DATE;           -- text → date
SELECT NOW()::DATE;                  -- timestamp → date (strips time)
SELECT 'true'::BOOLEAN;              -- text → boolean
SELECT 42::TEXT || ' items';         -- integer → text (for concatenation)

-- Integer division vs numeric division
SELECT 10 / 3 AS int_div;           -- 3 (truncated!)
SELECT 10::NUMERIC / 3 AS num_div;  -- 3.3333... (precise)

-- === IMPLICIT vs EXPLICIT CASTING ===

-- Implicit (automatic):
-- INTEGER + NUMERIC → NUMERIC (auto-promoted)
-- SMALLINT + INTEGER → INTEGER
-- Any type → TEXT (in || concatenation)

-- Explicit (you must cast):
-- TEXT → INTEGER: '42'::INTEGER
-- TEXT → DATE: '2026-01-01'::DATE
-- TIMESTAMP → DATE: now()::DATE
-- TEXT → UUID: must be valid UUID format

-- === COMMON ERRORS ===

-- ERROR: invalid input syntax for type integer: "hello"
-- FIX: The text must be a valid number

-- ERROR: cannot cast type integer to uuid
-- FIX: UUID must come from a valid UUID text string

-- ERROR: invalid input syntax for type inet: "not.an.ip"
-- FIX: Must be a valid IP address format

-- ERROR: date/time field value out of range
-- FIX: Use ISO format YYYY-MM-DD

-- === PRACTICE EXERCISES ===

-- Exercise 1: UUID primary key
CREATE TABLE sessions (
    id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_name  VARCHAR(100),
    started_at TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO sessions (user_name) VALUES ('Ravi');
INSERT INTO sessions (user_name) VALUES ('Priya');
INSERT INTO sessions (user_name) VALUES ('Arjun');
SELECT * FROM sessions;

-- Exercise 2: INET subnet query
CREATE TABLE server_log (
    id SERIAL,
    client_ip INET,
    path VARCHAR(255)
);
INSERT INTO server_log (client_ip, path) VALUES
('192.168.1.10', '/api/users'),
('10.0.0.5', '/api/products'),
('192.168.2.20', '/api/orders');
SELECT * FROM server_log WHERE client_ip << '192.168.0.0/16';

-- Exercise 3: Casting practice
SELECT '42'::INTEGER + 8 AS result;
SELECT NOW()::DATE AS today;
SELECT 100::TEXT || ' items in stock' AS message;

-- Exercise 4: Invalid casts (try these to see errors)
-- SELECT 'hello'::INTEGER;
-- SELECT 999::BOOLEAN;    -- ERROR: cannot cast
-- SELECT 42::UUID;         -- ERROR: cannot cast

-- Exercise 5: Precise division
SELECT 10 / 3 AS int_result;           -- 3
SELECT 10::NUMERIC / 3 AS precise;     -- 3.333...
SELECT ROUND(10::NUMERIC / 3, 2) AS rounded;  -- 3.33

-- === CLEANUP ===
-- DROP TABLE IF EXISTS api_keys, file_hashes, access_log;
-- DROP TABLE IF EXISTS devices, sessions, server_log;
-- DROP EXTENSION IF EXISTS pgcrypto;

-- =============================================
-- Phase 2: Database Objects — COMPLETE!
-- Next Phase: Phase 3 — Database Design
-- Next Class: Normalization
-- =============================================

-- === ANSWER KEY ===
-- 1. Table with UUID primary key using gen_random_uuid()
CREATE TABLE api_keys (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), label TEXT);
INSERT INTO api_keys (label) VALUES ('web'), ('mobile'), ('cli');

-- 2. INET column and subnet containment query
CREATE TABLE access_logs (id SERIAL, client_ip INET);
SELECT * FROM access_logs WHERE client_ip << '192.168.0.0/16'::inet;

-- 3. Casting examples
SELECT '42'::int + 8 AS sum_val, NOW()::date AS today, 100::text || ' items' AS label;

-- 4. Invalid casts raise clean errors
-- SELECT 'hello'::int;
-- SELECT 999::boolean;

-- 5. Integer vs NUMERIC division
SELECT 10 / 3 AS int_div, 10::numeric / 3 AS exact_div;
